import AppKit
import Carbon
import KM16ControlCore

@MainActor
enum DesktopEvents {
    static func shortcut(_ spec: ShortcutSpec, targetPID: pid_t) throws {
        guard let (key, implicitFlags) = keyCode(spec.key) else { throw IntegrationError.message("This key is unavailable in the current keyboard layout.") }
        let flags = spec.modifiers.reduce(implicitFlags) { result, modifier in
            result.union(["cmd": .maskCommand, "shift": .maskShift, "alt": .maskAlternate, "ctrl": .maskControl][modifier] ?? [])
        }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false) else { throw IntegrationError.message("Could not create keyboard events.") }
        down.flags = flags; up.flags = flags
        down.postToPid(targetPID); up.postToPid(targetPID)
    }
    static func text(_ text: String, targetPID: pid_t) throws {
        guard text.utf16.count <= 16_384 else { throw IntegrationError.message("Snippets are limited to 16,384 UTF-16 units.") }
        // Each Character keeps surrogate pairs and composed Unicode intact. No clipboard is modified.
        for character in text {
            let units = Array(String(character).utf16)
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { throw IntegrationError.message("Could not create text events.") }
            units.withUnsafeBufferPointer { buffer in
                down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
                up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            }
            down.postToPid(targetPID); up.postToPid(targetPID)
        }
    }
    static func media(_ name: String) throws {
        let code = ["playPause": 16, "nextTrack": 17, "previousTrack": 18][name]!
        for state in [0xA, 0xB] {
            guard let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)), timestamp: 0,
                windowNumber: 0, context: nil, subtype: 8, data1: (code << 16) | (state << 8), data2: -1)?.cgEvent else {
                throw IntegrationError.message("Could not create a media key event.")
            }
            event.post(tap: .cghidEventTap)
        }
    }
    static func keyCode(_ sourceKey: String) -> (CGKeyCode, CGEventFlags)? {
        let key = ["plus": "+", "minus": "-", "backtick": "`"] [sourceKey] ?? sourceKey
        let special: [String: CGKeyCode] = ["return":36,"enter":36,"tab":48,"space":49,"delete":51,"backspace":51,"escape":53,"esc":53,"left":123,"right":124,"down":125,"up":126,"home":115,"end":119,"pageup":116,"pagedown":121,"forwarddelete":117,"f1":122,"f2":120,"f3":99,"f4":118,"f5":96,"f6":97,"f7":98,"f8":100,"f9":101,"f10":109,"f11":103,"f12":111,"f13":105,"f14":107,"f15":113,"f16":106,"f17":64,"f18":79,"f19":80,"f20":90]
        if let value = special[key] { return (value, []) }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        for shift: UInt32 in [0, 2, 8, 10] {
        for code in UInt16(0)..<UInt16(128) {
            var dead: UInt32 = 0, length = 0
            var chars = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), shift, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &dead, 8, &length, &chars)
            if status == noErr && String(utf16CodeUnits: chars, count: length).lowercased() == key { return (code, (shift & 2 == 0 ? CGEventFlags() : .maskShift).union(shift & 8 == 0 ? [] : .maskAlternate)) }
        }
        }
        return nil
    }
}

/// Resolves a shortcut against the selected keyboard layout without sending input.
@MainActor public enum DesktopShortcutResolver {
    public static func canResolve(_ shortcut: ShortcutSpec) -> Bool { DesktopEvents.keyCode(shortcut.key) != nil }
}
