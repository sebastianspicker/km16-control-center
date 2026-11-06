import CoreAudio

/// CoreAudio output controls; unsupported fixed-volume devices fail visibly.
enum SystemAudio {
    static func perform(_ action: String) throws {
        var device = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr, device != 0 else { throw IntegrationError.message("No default audio output is available.") }
        if action == "mute" {
            var mute: UInt32 = 0
            address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            size = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &mute) == noErr else { throw IntegrationError.message("This output device does not expose mute control.") }
            mute = mute == 0 ? 1 : 0
            guard AudioObjectSetPropertyData(device, &address, 0, nil, size, &mute) == noErr else { throw IntegrationError.message("The output device rejected mute control.") }
            return
        }
        func volumeAddress(_ channel: UInt32) -> AudioObjectPropertyAddress {
            AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: channel)
        }
        func writable(_ channel: UInt32) -> Bool {
            var channelAddress = volumeAddress(channel), settable: DarwinBoolean = false
            return AudioObjectHasProperty(device, &channelAddress) && AudioObjectIsPropertySettable(device, &channelAddress, &settable) == noErr && settable.boolValue
        }
        // The main element, or both stereo channels together so the balance never shifts.
        let channels: [UInt32] = writable(0) ? [0] : (writable(1) && writable(2) ? [1, 2] : [])
        guard !channels.isEmpty else { throw IntegrationError.message("This output device has no writable volume control.") }
        for channel in channels {
            var channelAddress = volumeAddress(channel), value: Float32 = 0
            size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(device, &channelAddress, 0, nil, &size, &value) == noErr else { throw IntegrationError.message("The output device did not report its volume.") }
            value = min(1, max(0, value + (action == "volumeUp" ? 0.0625 : -0.0625)))
            guard AudioObjectSetPropertyData(device, &channelAddress, 0, nil, size, &value) == noErr else { throw IntegrationError.message("The output device rejected volume control.") }
        }
    }
}
