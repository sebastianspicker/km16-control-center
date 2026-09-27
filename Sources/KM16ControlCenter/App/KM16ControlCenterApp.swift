import SwiftUI
import KM16ControlCore
import KM16Integrations
import Darwin

@main
struct KM16ControlCenterApp: App {
    @State private var store = ControlCenterStore(persistence: ProfilePersistence(url: AppConfiguration.profilesURL()))
    @State private var runner = DesktopActionRunner()
    @State private var codex = CodexDeckClient()
    @State private var obs = OBSController()
    @NSApplicationDelegateAdaptor(KM16ApplicationDelegate.self) private var applicationDelegate

    init() {
        if let index = CommandLine.arguments.firstIndex(of: "--render-design"), CommandLine.arguments.indices.contains(index + 1) {
            do {
                try DesignPreviewRenderer.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                exit(EXIT_SUCCESS)
            } catch {
                fputs("Design export failed: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }

        if AppConfiguration.requestsStoreSelfTest {
            do {
                try ControlCenterStoreSelfTest.run()
                print("KM16ControlCenter store self-test passed.")
                exit(EXIT_SUCCESS)
            } catch {
                fputs("KM16ControlCenter store self-test failed: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }
        if AppConfiguration.requestsSmokeTest {
            let persistence = ProfilePersistence(url: AppConfiguration.profilesURL())
            do {
                let document: ProfileDocument
                if FileManager.default.fileExists(atPath: persistence.url.path) {
                    document = try persistence.load()
                } else {
                    document = Presets.factoryDocument()
                }
                try ProfileValidator.validate(document)
                print("KM16ControlCenter smoke test passed: \(document.profiles.count) profiles, \(ControlID.all.count) inputs, \(persistence.url.path)")
                exit(EXIT_SUCCESS)
            } catch {
                fputs("KM16ControlCenter smoke test failed: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }
    }

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

enum ControlCenterStoreSelfTest {
    @MainActor static func run() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "KM16StoreSelfTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        let store = ControlCenterStore(persistence: persistence)
        guard store.recoveryMessage == nil, store.document.profiles.count == Presets.all.count,
              !FileManager.default.fileExists(atPath: persistence.url.path) else {
            throw StoreSelfTestError.assertion("first launch must load factory presets without recovery warnings or creating storage")
        }
        try presetLibraryChecks(directory: directory)
        try profileMergeChecks(directory: directory)
        let originalCount = store.document.profiles.count
        guard let desktop = store.document.profiles.first(where: { $0.presetID == "desktop" }) else { throw StoreSelfTestError.assertion("desktop fallback preset is missing") }
        store.select(profileID: desktop.id, isManual: false)
        store.selectedControlID = ControlID.all.last!
        store.simulate(store.selectedControlID)
        guard store.activeProfile.presetID == "agent-deck" else { throw StoreSelfTestError.assertion("preset profile switch did not resolve its preset ID") }
        store.manualProfileOverrideID = nil
        store.recordForegroundApplication(bundleID: "com.microsoft.VSCode")
        guard store.activeProfile.presetID == "developer", store.lastExternalBundleID == "com.microsoft.VSCode" else { throw StoreSelfTestError.assertion("foreground app matching did not use the notification bundle") }
        store.createProfile(named: "Self Test")
        guard store.document.profiles.count == originalCount + 1, store.isDirty else { throw StoreSelfTestError.assertion("create did not mark a dirty profile library") }
        store.renameActiveProfile(to: "Renamed Self Test")
        guard store.activeProfile.name == "Renamed Self Test" else { throw StoreSelfTestError.assertion("rename failed") }
        store.duplicateActiveProfile()
        guard store.document.profiles.count == originalCount + 2 else { throw StoreSelfTestError.assertion("duplicate failed") }
        store.undo()
        guard store.document.profiles.count == originalCount + 1 else { throw StoreSelfTestError.assertion("undo failed") }
        store.redo()
        guard store.document.profiles.count == originalCount + 2 else { throw StoreSelfTestError.assertion("redo failed") }
        store.save()
        guard !store.isDirty else { throw StoreSelfTestError.assertion("save did not clear dirty tracking") }
        let exportURL = directory.appending(path: "export.json")
        store.exportProfiles(to: exportURL)
        store.importProfiles(from: exportURL, mode: .mergeKeepingExisting)
        guard store.document.profiles.count == originalCount + 2 else { throw StoreSelfTestError.assertion("merge duplicated same-name profiles") }
        let existingDesktopID = store.document.profiles.first(where: { $0.presetID == "desktop" })!.id
        var importedSource = Presets.blank(name: "Imported Source")
        importedSource.id = existingDesktopID
        var importedDesktop = Presets.blank(name: "Desktop")
        importedDesktop.id = UUID()
        importedSource.replace(Binding(controlID: .keys[0], action: ControlAction(kind: .profileSwitch, label: "Imported destination", parameter: importedDesktop.id.uuidString)))
        let mergeURL = directory.appending(path: "merge.json")
        try ProfilePersistence(url: mergeURL).exportDocument(ProfileDocument(activeProfileID: importedSource.id, profiles: [importedSource, importedDesktop]), to: mergeURL)
        store.importProfiles(from: mergeURL, mode: .mergeKeepingExisting)
        guard let mergedSource = store.document.profiles.first(where: { $0.name == "Imported Source" }),
              mergedSource.id != existingDesktopID,
              mergedSource.binding(for: .keys[0])?.action.parameter.caseInsensitiveCompare(existingDesktopID.uuidString) == .orderedSame else {
            throw StoreSelfTestError.assertion("merged UUID profile switches were not remapped to retained destinations")
        }
        store.simulate(.keys[0])
        guard !store.events.isEmpty, store.events[0].message.contains("Would run") else { throw StoreSelfTestError.assertion("simulation escaped the local dispatcher") }
        while store.document.profiles.count < ProfilePersistence.maximumProfileCount { store.createProfile(named: "Capacity Test") }
        let cappedCount = store.document.profiles.count
        store.createProfile(named: "Over Capacity")
        guard store.document.profiles.count == cappedCount, store.statusMessage?.contains("at most") == true else { throw StoreSelfTestError.assertion("profile library cap was not enforced") }
    }
}

enum StoreSelfTestError: Error, LocalizedError {
    case assertion(String)
    var errorDescription: String? { if case .assertion(let value) = self { return value }; return nil }
}
