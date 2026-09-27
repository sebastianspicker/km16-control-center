import SwiftUI
import KM16ControlCore
import KM16Integrations

@main
struct KM16ControlCenterApp: App {
    @State private var store = ControlCenterStore(persistence: ProfilePersistence(url: AppConfiguration.profilesURL()))
    @State private var runner = DesktopActionRunner()
    @State private var codex = CodexDeckClient()
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

@MainActor
final class KM16ApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var store: ControlCenterStore?
    weak var runner: DesktopActionRunner?
    weak var codex: CodexDeckClient?

    func configure(store: ControlCenterStore, runner: DesktopActionRunner, codex: CodexDeckClient) {
        self.store = store; self.runner = runner; self.codex = codex
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        runner?.cancel()
        codex?.disconnect()
        guard let store, store.isDirty else { return .terminateNow }
        store.quitRequested = true
        store.closeConfirmationRequested = true
        return .terminateCancel
    }
}
