public enum OBSOperation: String, CaseIterable, Codable, Sendable {
    case scene1 = "scene-1"
    case scene2 = "scene-2"
    case scene3 = "scene-3"
    case scene4 = "scene-4"
    case scene5 = "scene-5"
    case scene6 = "scene-6"
    case scene7 = "scene-7"
    case scene8 = "scene-8"
    case startRecording = "start-recording"
    case stopRecording = "stop-recording"
    case pauseRecording = "pause-recording"
    case resumeRecording = "resume-recording"
    case saveReplay = "save-replay"
    case toggleStudioMode = "toggle-studio-mode"
    case transition
    case microphoneDown = "mic-down"
    case microphoneUp = "mic-up"
    case microphoneMute = "mic-mute"
    case playbackDown = "playback-down"
    case playbackUp = "playback-up"
    case playbackMute = "playback-mute"
    case previousScene = "previous-scene"
    case nextScene = "next-scene"

    public var sceneNumber: Int? {
        guard rawValue.hasPrefix("scene-") else { return nil }
        return Int(rawValue.dropFirst("scene-".count))
    }
}
