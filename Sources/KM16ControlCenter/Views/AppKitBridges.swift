import AppKit
import SwiftUI

struct ShortcutCaptureField: NSViewRepresentable {
    @Binding var value: String
    /// Identifies the control being edited; typing in progress is dropped when it changes.
    var scope: String
    var placeholder: String = "Click and press a shortcut"
    func makeNSView(context: Context) -> ShortcutCaptureTextField {
        let field = ShortcutCaptureTextField()
        field.placeholderString = placeholder
        field.stringValue = value
        field.displayedValue = value
        field.scope = scope
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.onCapture = { value = $0 }
        return field
    }
    func updateNSView(_ nsView: ShortcutCaptureTextField, context: Context) {
        nsView.onCapture = { value = $0 }
        if nsView.scope != scope {
            nsView.scope = scope
            nsView.discardTyping(showing: value)
        } else if nsView.displayedValue != value {
            // Only an outside change replaces the text; an unchanged binding keeps any typing.
            nsView.displayedValue = value
            nsView.stringValue = value
        }
    }
}

/// Records modifier shortcuts as they are pressed. Keys without modifiers (j, space, f12,
/// pageup) are typed by name and committed when editing ends.
final class ShortcutCaptureTextField: NSTextField {
    var onCapture: ((String) -> Void)?
    var scope = ""
    /// The binding value the field last showed or committed.
    var displayedValue = ""
    /// The scope an edit started in; typing is committed only to the control it was typed for.
    private var editingScope: String?
    private var monitor: Any?

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        guard accepted, monitor == nil else { return accepted }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.firstResponder === self.currentEditor() || self.window?.firstResponder === self else { return event }
            return self.capture(event) ? nil : event
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        removeMonitor()
        return super.resignFirstResponder()
    }

    /// AppKit offers key equivalents to every view in the window, so only claim them while this
    /// field is being edited; otherwise Command-S, Command-Z and the like reach their menu commands.
    override func performKeyEquivalent(with event: NSEvent) -> Bool { currentEditor() != nil && capture(event) }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        editingScope = scope
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        defer { editingScope = nil }
        guard editingScope == scope else { stringValue = displayedValue; return }
        let typed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        stringValue = typed
        guard typed != displayedValue else { return }
        displayedValue = typed
        onCapture?(typed)
    }

    /// Drops uncommitted typing, for example when the inspector switches to another control.
    func discardTyping(showing value: String) {
        editingScope = nil
        abortEditing()
        displayedValue = value
        stringValue = value
    }

    func capture(_ event: NSEvent) -> Bool {
        let modifiers: [(NSEvent.ModifierFlags, String)] = [(.command, "cmd"), (.shift, "shift"), (.option, "alt"), (.control, "ctrl")]
        let names = modifiers.compactMap { event.modifierFlags.contains($0.0) ? $0.1 : nil }
        guard !names.isEmpty, let key = canonicalKey(for: event) else { return false }
        let result = (names + [key]).joined(separator: "+")
        stringValue = result
        displayedValue = result
        onCapture?(result)
        return true
    }

    private func canonicalKey(for event: NSEvent) -> String? {
        let special: [UInt16: String] = [36: "enter", 48: "tab", 49: "space", 51: "delete", 53: "esc", 117: "forwarddelete", 123: "left", 124: "right", 125: "down", 126: "up", 115: "home", 119: "end", 116: "pageup", 121: "pagedown", 122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6", 98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12"]
        if let special = special[event.keyCode] { return special }
        guard let characters = event.charactersIgnoringModifiers?.lowercased(), characters.count == 1 else { return nil }
        return ["`": "backtick", "+": "plus", "-": "minus"][characters] ?? characters
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
}

enum ProfilePanels {
    @MainActor static func chooseImport(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowsMultipleSelection = false; panel.allowedContentTypes = [.json]
        panel.begin { completion($0 == .OK ? panel.url : nil) }
    }
    @MainActor static func chooseExport(completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "KM16 Profiles.json"
        panel.begin { completion($0 == .OK ? panel.url : nil) }
    }
    @MainActor static func chooseApplication(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowsMultipleSelection = false; panel.allowedContentTypes = [.applicationBundle]
        panel.begin { completion($0 == .OK ? panel.url : nil) }
    }
    @MainActor static func chooseExecutable(message: String = "Choose an executable file. It only starts after an explicit live Run Selected action.", completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowsMultipleSelection = false
        panel.message = message
        panel.begin { completion($0 == .OK ? panel.url : nil) }
    }
    @MainActor static func chooseFolder(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.message = "Choose the workspace folder that Codex works in."
        panel.begin { completion($0 == .OK ? panel.url : nil) }
    }
    @MainActor static func chooseSavedCapture(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowsMultipleSelection = false
        panel.message = "Replay a saved composite.jsonl capture. This reads a file only; it never opens a HID device."
        panel.begin { completion($0 == .OK ? panel.url : nil) }
    }
}

struct OverlayWindowConfigurator: NSViewRepresentable {
    var floating: Bool
    func makeNSView(context: Context) -> NSView { let view = NSView(); DispatchQueue.main.async { configure(view.window) }; return view }
    func updateNSView(_ nsView: NSView, context: Context) { configure(nsView.window) }
    private func configure(_ window: NSWindow?) { guard let window else { return }; window.setFrameAutosaveName("KM16OverlayWindow"); window.level = floating ? .floating : .normal }
}

struct WindowCloseGuard: NSViewRepresentable {
    let store: ControlCenterStore
    func makeCoordinator() -> Coordinator { Coordinator(store: store) }
    func makeNSView(context: Context) -> NSView { let view = NSView(); DispatchQueue.main.async { context.coordinator.install(on: view.window) }; return view }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.store = store; context.coordinator.install(on: nsView.window) }
    @MainActor final class Coordinator: NSObject, NSWindowDelegate {
        var store: ControlCenterStore
        weak var window: NSWindow?
        init(store: ControlCenterStore) { self.store = store }
        func install(on window: NSWindow?) { guard let window, self.window !== window else { return }; self.window = window; window.delegate = self }
        func windowShouldClose(_ sender: NSWindow) -> Bool { guard store.isDirty else { return true }; store.closeConfirmationRequested = true; return false }
    }
}
