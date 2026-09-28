import SwiftUI
import KM16ControlCore
import KM16Integrations

struct ContentView: View {
    @Environment(ControlCenterStore.self) private var store
    @Environment(DesktopActionRunner.self) private var runner
    @Environment(CodexDeckClient.self) private var codex
    @Environment(OBSController.self) private var obs
    @Environment(\.openWindow) private var openWindow
    @AppStorage("KM16.liveActionsEnabled") private var liveActionsEnabled = false
    @State private var importMode: ProfileImportMode = .mergeKeepingExisting
    @State private var showingImportPolicy = false
    @SceneStorage("KM16.inspectorVisible") private var inspectorVisible = true
    @State private var showingStatus = false

    var body: some View {
        VStack(spacing: 0) {
            workspace
            statusBar
        }
        .background(WindowCloseGuard(store: store).frame(width: 0, height: 0))
        .sheet(isPresented: $showingImportPolicy) { importPolicySheet }
        .alert("Unsaved Profile Changes", isPresented: Bindable(store).closeConfirmationRequested) {
            Button("Save") { store.save(); finishQuitIfNeeded() }
            Button("Discard", role: .destructive) { store.discardUnsavedChanges(); finishQuitIfNeeded() }
            Button("Keep Editing", role: .cancel) { store.cancelCloseRequest() }
        } message: { Text("Profiles have unsaved changes. Save or discard them before closing this window.") }
        .onAppear { store.matchForegroundApplication() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { notification in
            store.recordForegroundApplication(bundleID: (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier)
        }
    }

    private var workspace: some View {
        NavigationSplitView {
            SidebarView().navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            GeometryReader { geometry in
                ConfiguratorView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .toolbar { toolbar }
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: $inspectorVisible) {
            ControlInspectorView().inspectorColumnWidth(min: 280, ideal: 280, max: 360)
        }
        .navigationTitle("KM16 Control Center")
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { store.simulate(store.selectedControlID) } label: { Label("Preview", systemImage: "play") }
                .help("Preview the selected action · ⌘ Return")
            Menu {
                Button("Run Selected", systemImage: "play.fill") { Task { await runSelected() } }
                    .disabled(!liveActionsEnabled || runner.isRunning || obs.isRunning)
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                Divider()
                Toggle("Enable Live Actions", isOn: $liveActionsEnabled)
                Button("Connections…", systemImage: "point.3.connected.trianglepath.dotted") { openWindow(id: "integrations") }
            } label: { Image(systemName: "chevron.down") }
            .menuIndicator(.hidden)
            .help("Live action options")
            Button("Save", systemImage: "square.and.arrow.down") { store.save() }
                .help("Save profiles · ⌘ S")
        }
        ToolbarItemGroup(placement: .automatic) {
            Button { openWindow(id: "overlay") } label: { Image(systemName: "rectangle.on.rectangle") }
                .help("Open overlay").accessibilityLabel("Open overlay")
            Button { inspectorVisible.toggle() } label: { Image(systemName: "sidebar.right") }
                .help(inspectorVisible ? "Hide assignment inspector" : "Show assignment inspector")
                .accessibilityLabel("Toggle assignment inspector")
            Menu {
                Button("Undo", systemImage: "arrow.uturn.backward") { store.undo() }.disabled(!store.canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward") { store.redo() }.disabled(!store.canRedo)
                Divider()
                Button("Import Profiles…", systemImage: "square.and.arrow.down") { showingImportPolicy = true }
                Button("Export Profiles…", systemImage: "square.and.arrow.up") { ProfilePanels.chooseExport { url in if let url { store.exportProfiles(to: url) } } }
                Button("Replay Saved Capture…", systemImage: "arrow.triangle.2.circlepath") {
                    ProfilePanels.chooseSavedCapture { url in if let url { Task { await replaySavedCapture(url) } } }
                }
                Divider()
                Button("Use Automatic Matching", systemImage: "arrow.triangle.2.circlepath") { store.clearManualOverride() }
                SettingsLink { Text("Settings…") }
            } label: { Image(systemName: "ellipsis") }
            .help("Workspace options").accessibilityLabel("Workspace options")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            StudioStatus(store.isDirty ? "Unsaved changes" : "Saved locally", symbol: store.isDirty ? "circle.fill" : "checkmark", tint: store.isDirty ? .orange : .secondary)
            Divider().frame(height: 10)
            Text(store.statusMessage ?? "Ready").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            if liveActionsEnabled { StudioStatus("Live actions enabled", symbol: "bolt.fill", tint: .orange) }
            Button { showingStatus.toggle() } label: { Image(systemName: "info.circle").font(.system(size: 11)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Status and storage details")
                .popover(isPresented: $showingStatus) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Workspace status").font(.headline)
                        Text(store.statusMessage ?? "Ready").font(.callout).textSelection(.enabled)
                        if let recovery = store.recoveryMessage { Text(recovery).font(.caption).foregroundStyle(.secondary) }
                        Text(store.persistence.url.path).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }.padding(22).frame(width: 350)
                }
        }
        .padding(.horizontal, 18).frame(height: 34)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var importPolicySheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Import Profile Library").font(.title2.weight(.semibold))
            Text("Choose an explicit conflict policy before selecting JSON. Invalid files leave the working library unchanged.").foregroundStyle(.secondary)
            Label("Profiles can contain commands, text, and agent prompts. Importing does not run them. Review the assignments before using Run Selected; your live-action setting stays unchanged.", systemImage: "exclamationmark.shield")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Picker("Conflict policy", selection: $importMode) {
                ForEach(ProfileImportMode.allCases) { Text($0.title).tag($0) }
            }
            Text(importMode.detail).font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { showingImportPolicy = false }; Button("Choose JSON…") {
                showingImportPolicy = false
                ProfilePanels.chooseImport { url in if let url { store.importProfiles(from: url, mode: importMode) } }
            }.keyboardShortcut(.defaultAction) }
        }
        .padding(24).frame(width: 500)
    }

    @MainActor private func runSelected() async {
        let controlID = store.selectedControlID
        let action = store.selectedBinding.action
        if action.kind == .profileSwitch { store.simulate(controlID); return }
        guard liveActionsEnabled else { store.simulate(controlID); return }
        do {
            let result: String
            if action.kind == .agentAction {
                guard codex.isConnected else { store.recordLiveResult("Codex Deck is not connected. Preview remains available.", for: controlID); return }
                result = try await codex.perform(action)
            } else if action.kind == .obsAction {
                guard let operation = OBSOperation(rawValue: action.parameter) else { throw LiveActionError.unknownOBSOperation }
                result = try await obs.perform(operation)
            } else {
                result = try await runner.perform(action, fallbackTargetBundleID: action.targetBundleID ?? store.lastExternalBundleID)
            }
            store.recordLiveResult(result, for: controlID)
            if action.kind == .agentAction, ["new-task", "open-task", "previous-task", "next-task", "open-diff"].contains(action.parameter) {
                openWindow(id: "integrations")
            }
        } catch { store.recordLiveResult("Run failed: \(error.localizedDescription)", for: controlID) }
    }

    @MainActor private func replaySavedCapture(_ url: URL) async {
        do {
            let controls = try await Task.detached(priority: .userInitiated) {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard let size = attributes[.size] as? NSNumber, size.intValue <= 8 * 1024 * 1024 else {
                    throw CaptureReplayError.tooLarge
                }
                return try CaptureReplay.controls(from: Data(contentsOf: url, options: .mappedIfSafe))
            }.value
            await store.replaySavedCapture(controls)
        } catch {
            store.recordLiveResult("Replay rejected: \(error.localizedDescription)", for: store.selectedControlID)
        }
    }

    @MainActor private func finishQuitIfNeeded() {
        guard store.quitRequested else { return }
        store.quitRequested = false
        NSApp.terminate(nil)
    }
}

private enum CaptureReplayError: Error, LocalizedError { case tooLarge; var errorDescription: String? { "Saved capture exceeds the 8 MB limit." } }

private enum LiveActionError: Error, LocalizedError {
    case unknownOBSOperation
    var errorDescription: String? { "Unknown OBS action." }
}
