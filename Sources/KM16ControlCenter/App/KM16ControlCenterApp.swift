import SwiftUI
import KM16ControlCore
import KM16Integrations

@main
struct KM16ControlCenterApp: App {
    @State private var store = ControlCenterStore(persistence: ProfilePersistence(url: AppConfiguration.profilesURL()))
    @State private var runner = DesktopActionRunner()
    @State private var codex = CodexDeckClient(defaults: .standard)
    @State private var obs = OBSController()
    @NSApplicationDelegateAdaptor(KM16ApplicationDelegate.self) private var applicationDelegate

    var body: some Scene {
        WindowGroup("KM16 Control Center", id: "main") {
            ContentView()
                .environment(store)
                .environment(runner)
                .environment(codex)
                .environment(obs)
                .onAppear { applicationDelegate.configure(store: store, runner: runner, codex: codex) }
                .frame(minWidth: 1020, minHeight: 680)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1360, height: 840)

        Window("KM16 Overlay", id: "overlay") {
            OverlayView()
                .environment(store)
                .environment(runner)
                .environment(codex)
                .environment(obs)
        }
        .defaultSize(width: 600, height: 520)

        Window("Connections", id: "integrations") {
            IntegrationsView()
                .environment(runner)
                .environment(codex)
                .environment(obs)
        }
        .defaultSize(width: 780, height: 720)

        Settings {
            SettingsView()
                .environment(store)
                .frame(minWidth: 620, minHeight: 520)
        }

        .commands {
            CommandMenu("KM16") {
                Button("Save Profiles") { store.save() }
                    .keyboardShortcut("s", modifiers: [.command])
                Button("Undo") { store.undo() }
                    .keyboardShortcut("z", modifiers: [.command])
                    .disabled(!store.canUndo)
                Button("Redo") { store.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!store.canRedo)
                Button("Cycle Software Profile") { store.cycleProfile() }
                    .keyboardShortcut("]", modifiers: [.command])
                Button("Preview Selected Control") { store.simulate(store.selectedControlID) }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }
}

enum UnsavedQuitChoice { case save, discard, keepEditing }

@MainActor
final class KM16ApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var store: ControlCenterStore?
    weak var runner: DesktopActionRunner?
    weak var codex: CodexDeckClient?
    /// Modal prompts, so quitting works even when no main window is open. Tests replace them.
    var confirmUnsavedQuit: @MainActor () -> UnsavedQuitChoice = KM16ApplicationDelegate.askUnsavedQuit
    /// Returns true when the user chose Overwrite for a file that changed on disk.
    var showProblem: @MainActor (LibraryProblem) -> Bool = KM16ApplicationDelegate.show

    func configure(store: ControlCenterStore, runner: DesktopActionRunner, codex: CodexDeckClient) {
        self.store = store; self.runner = runner; self.codex = codex
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let store, store.isDirty {
            switch confirmUnsavedQuit() {
            case .keepEditing: return .terminateCancel
            case .discard: store.discardUnsavedChanges()
            case .save:
                guard saveOrReport(store) else { return .terminateCancel }
            }
        }
        // Stop work only once quitting is certain; "Keep Editing" must leave commands and Codex alone.
        runner?.cancel()
        codex?.disconnect()
        return .terminateNow
    }

    /// Reports a failed save here, because the main window that reports it otherwise may be closed.
    /// A file changed on disk can be overwritten once from that report.
    private func saveOrReport(_ store: ControlCenterStore) -> Bool {
        var overwriting = false
        while !store.save(overwritingExternalChanges: overwriting) {
            guard let problem = store.libraryProblem else { return false }
            store.dismissLibraryProblem(problem.id)
            guard showProblem(problem), problem.offersOverwrite, !overwriting else { return false }
            overwriting = true
        }
        return true
    }

    private static func askUnsavedQuit() -> UnsavedQuitChoice {
        let alert = NSAlert()
        alert.messageText = "Unsaved Profile Changes"
        alert.informativeText = "Profiles have unsaved changes. Save or discard them before quitting."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard").hasDestructiveAction = true
        alert.addButton(withTitle: "Keep Editing").keyEquivalent = "\u{1b}"
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .keepEditing
        }
    }

    private static func show(_ problem: LibraryProblem) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = problem.title
        alert.informativeText = problem.message
        guard problem.offersOverwrite else { _ = alert.runModal(); return false }
        alert.addButton(withTitle: "Overwrite").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
