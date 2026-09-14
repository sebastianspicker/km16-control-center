import SwiftUI
import KM16ControlCore

struct ControlInspectorView: View {
    @Environment(ControlCenterStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var appPickerError: String?
    @State private var notesExpanded = false
    private let customPrompt = "__custom_prompt__"
    private let agentChoices = ["new-task", "review-changes", "run-tests", "explain-selection", "stop-current-task", "summarize-context", "draft-commit", "previous-task", "next-task", "open-task", "previous-changed-file", "next-changed-file", "open-diff", "scroll-up", "scroll-down"]
    private let systemChoices = ["volumeDown", "volumeUp", "mute", "playPause", "nextTrack", "previousTrack", "scrollUp", "scrollDown", "dictation"] + WindowOperation.allCases.map(\.rawValue)

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("ASSIGNMENT").font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Image(systemName: StudioStyle.actionSymbol(store.selectedBinding.action.kind))
                            .font(.system(size: 21, weight: .light)).foregroundStyle(Color.accentColor)
                            .frame(width: 40, height: 40).background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.selectedControlID.gridTitle).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.tail)
                            Text(store.selectedBinding.action.kind.displayName).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    inspectorField("Action name") {
                        TextField("Action name", text: labelBinding, axis: .vertical)
                            .font(.system(size: 18, weight: .medium)).textFieldStyle(.plain).lineLimit(1...3)
                            .accessibilityLabel("Action name").help("Rename this action")
                    }
                    if !store.selectedBinding.action.detail.isEmpty {
                        Text(store.selectedBinding.action.detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider()
                StudioSection("Action") {
                    inspectorField("Action type") {
                        Picker("Action type", selection: kindBinding) { ForEach(ActionKind.allCases, id: \.self) { Text($0.displayName).lineLimit(1).truncationMode(.tail).tag($0) } }
                            .labelsHidden().pickerStyle(.menu).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    actionFields
                }
                targetFields
                if !issues.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(issues, id: \.self) { Label($0, systemImage: "exclamationmark.circle").font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
                    }.padding(12).studioSurface(cornerRadius: 10)
                }
                Divider()
                Button { store.simulate(store.selectedControlID) } label: {
                    HStack { Image(systemName: "play"); Text("Preview action"); Spacer(); Text("⌘↩").foregroundStyle(.secondary) }
                        .font(.system(size: 12, weight: .medium)).padding(.vertical, 6)
                }.buttonStyle(.bordered).controlSize(.large)
                Text("Preview stays on this Mac. No action is sent.").font(.system(size: 10)).foregroundStyle(.secondary)
                DisclosureGroup("Notes & details", isExpanded: $notesExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        inspectorField("Description") { TextField("Description", text: detailBinding, axis: .vertical).lineLimit(3...8) }
                        Text(store.selectedControlID.rawValue).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).textSelection(.enabled)
                    }.padding(.top, 10)
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(width: max(0, proxy.size.width - 32), alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 18)
            }
        }
        .textFieldStyle(.roundedBorder).controlSize(.regular)
        .alert("Application picker", isPresented: Binding(get: { appPickerError != nil }, set: { if !$0 { appPickerError = nil } })) { Button("OK", role: .cancel) {} } message: { Text(appPickerError ?? "") }
    }

    @ViewBuilder private var actionFields: some View {
        switch store.selectedBinding.action.kind {
        case .shortcut:
            Text(StudioStyle.shortcutLabel(store.selectedBinding.action.parameter)).font(.system(size: 25, weight: .light, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 64).studioSurface(cornerRadius: 12)
            inspectorField("Keyboard shortcut") {
                ShortcutCaptureField(value: parameterBinding).frame(maxWidth: .infinity).frame(height: 26).accessibilityLabel("Keyboard shortcut capture")
            }
            Text("Click to record a shortcut.").font(.system(size: 10)).foregroundStyle(.secondary)
        case .launchApp:
            inspectorField("Bundle identifier") { TextField("Bundle identifier", text: parameterBinding) }
            Button("Choose Application…") { chooseApplication { action, identifier in action.parameter = identifier; action.targetBundleID = nil } }
        case .snippet:
            inspectorField("Snippet") { TextEditor(text: parameterBinding).font(.body.monospaced()).frame(minHeight: 110).accessibilityLabel("Multiline snippet") }
        case .shell:
            if processSpec.executable == "/usr/bin/shortcuts", processSpec.args.count == 2, processSpec.args.first == "run" {
                inspectorField("Shortcut name") { TextField("Name in Shortcuts", text: processArgumentBinding(1)) }
                Text("Create this named routine in Shortcuts. Run Selected starts it on this Mac.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Process details") { processFields }
            } else { processFields }
        case .obsAction:
            inspectorField("OBS action") {
                Picker("OBS action", selection: parameterBinding) {
                    ForEach(OBSOperation.allCases, id: \.self) { Text(friendlyName($0.rawValue)).tag($0.rawValue) }
                }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Uses the OBS WebSocket connection and audio sources in Connections.").font(.caption).foregroundStyle(.secondary)
            Button("Configure OBS…") { openWindow(id: "integrations") }
        case .agentAction:
            inspectorField("Agent command") {
                Picker("Agent command", selection: agentChoiceBinding) {
                    ForEach(agentChoices, id: \.self) { Text(friendlyName($0)).lineLimit(1).truncationMode(.tail).tag($0) }
                    Text("Custom prompt").lineLimit(1).truncationMode(.tail).tag(customPrompt)
                }
                .labelsHidden().pickerStyle(.menu).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
            if agentChoiceBinding.wrappedValue == customPrompt { inspectorField("Custom prompt") { TextEditor(text: customPromptBinding).font(.body.monospaced()).frame(minHeight: 100).accessibilityLabel("Custom agent prompt") } }
        case .system:
            inspectorField("System action") {
                Picker("System action", selection: parameterBinding) { ForEach(systemChoices, id: \.self) { Text(friendlyName($0)).lineLimit(1).truncationMode(.tail).tag($0) } }
                    .labelsHidden().pickerStyle(.menu).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
        case .profileSwitch:
            inspectorField("Profile") {
                Picker("Profile", selection: profileSwitchBinding) {
                    Text("Cycle profile").lineLimit(1).truncationMode(.tail).tag("cycle-profile")
                    ForEach(store.orderedProfiles) { Text($0.name).lineLimit(1).truncationMode(.tail).tag($0.id.uuidString) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            }
        case .disabled:
            Text("No action is assigned to this control.").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var targetFields: some View {
        let kind = store.selectedBinding.action.kind
        if kind == .shortcut || kind == .snippet || kind == .system {
            StudioSection("Destination", subtitle: store.selectedBinding.action.targetBundleID == nil ? "Uses the last active app." : nil) {
                inspectorField("Bundle identifier") { TextField("Last active app", text: targetBundleBinding).font(.system(size: 11)) }
                HStack {
                    Button("Choose App…") { chooseApplication { action, identifier in action.targetBundleID = identifier } }
                    Spacer()
                    Menu {
                        Button("Use Last Active App") { updateTarget(store.lastExternalBundleID) }.disabled(store.lastExternalBundleID == nil)
                        Button("Clear Destination") { updateTarget(nil) }.disabled(store.selectedBinding.action.targetBundleID == nil)
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
                }.controlSize(.small)
            }
        }
    }

    private var processFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspectorField("Executable path") { TextField("Executable path", text: processExecutableBinding) }
            Button("Choose Executable…") { ProfilePanels.chooseExecutable { url in if let url { processExecutableBinding.wrappedValue = url.path } } }
            Text("Arguments").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            if processArgumentsBinding.wrappedValue.isEmpty {
                Text("No arguments").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(processArgumentsBinding.wrappedValue.indices, id: \.self) { index in
                    HStack {
                        TextField("Argument \(index + 1)", text: processArgumentBinding(index))
                        Button("Remove", systemImage: "minus.circle") { removeProcessArgument(at: index) }
                            .accessibilityLabel("Remove argument \(index + 1)")
                    }
                }
            }
            Button("Add Argument", systemImage: "plus") { appendProcessArgument() }
            Text("Each row is one literal process argument; empty arguments are retained.").font(.caption).foregroundStyle(.secondary)
            inspectorField("Working directory") { TextField("Optional", text: processDirectoryBinding) }
            inspectorField("Timeout seconds") { TextField("Timeout seconds", text: processTimeoutBinding) }
        }
    }

    private func inspectorField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func friendlyName(_ value: String) -> String {
        let names = ["volumeDown":"Volume down", "volumeUp":"Volume up", "playPause":"Play / Pause", "previousTrack":"Previous track", "nextTrack":"Next track", "scrollUp":"Scroll up", "scrollDown":"Scroll down", "dictation":"Dictation shortcut", "stop-current-task":"Interrupt task"]
        return WindowOperation(rawValue: value)?.title ?? names[value] ?? value.replacingOccurrences(of: "-", with: " ").capitalized
    }

    private var issues: [String] {
        var values = ActionValidator.issues(for: store.selectedBinding.action)
        let action = store.selectedBinding.action
        if action.kind == .profileSwitch, action.parameter != "cycle-profile", !store.document.profiles.contains(where: { $0.id.uuidString.caseInsensitiveCompare(action.parameter) == .orderedSame || $0.presetID == action.parameter || $0.name == action.parameter }) { values.append("The selected profile switch target no longer exists.") }
        return values
    }

    private func chooseApplication(_ apply: @escaping (inout ControlAction, String) -> Void) {
        ProfilePanels.chooseApplication { url in
            guard let url else { return }
            guard let identifier = Bundle(url: url)?.bundleIdentifier else { appPickerError = "The selected application has no bundle identifier."; return }
            var action = store.selectedBinding.action; apply(&action, identifier); store.updateSelected(action: action)
        }
    }

    private func updateTarget(_ target: String?) { var action = store.selectedBinding.action; action.targetBundleID = target; store.updateSelected(action: action) }
    private var labelBinding: SwiftUI.Binding<String> { binding(\.label) }
    private var parameterBinding: SwiftUI.Binding<String> { binding(\.parameter) }
    private var detailBinding: SwiftUI.Binding<String> { binding(\.detail) }
    private var targetBundleBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { store.selectedBinding.action.targetBundleID ?? "" }, set: { updateTarget($0.isEmpty ? nil : $0) }) }
    private var kindBinding: SwiftUI.Binding<ActionKind> { SwiftUI.Binding(get: { store.selectedBinding.action.kind }, set: { value in var action = store.selectedBinding.action; action.kind = value; store.updateSelected(action: action) }) }
    private var agentChoiceBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { store.selectedBinding.action.parameter.hasPrefix("prompt:") ? customPrompt : store.selectedBinding.action.parameter }, set: { value in var action = store.selectedBinding.action; action.parameter = value == customPrompt ? "prompt:" : value; store.updateSelected(action: action) }) }
    private var customPromptBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { String(store.selectedBinding.action.parameter.dropFirst("prompt:".count)) }, set: { value in var action = store.selectedBinding.action; action.parameter = "prompt:\(value)"; store.updateSelected(action: action) }) }
    private var profileSwitchBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { profileSwitchSelection }, set: { value in var action = store.selectedBinding.action; action.parameter = value; store.updateSelected(action: action) }) }
    private var profileSwitchSelection: String {
        let parameter = store.selectedBinding.action.parameter
        if parameter == "cycle-profile" || store.document.profiles.contains(where: { $0.id.uuidString.caseInsensitiveCompare(parameter) == .orderedSame }) { return parameter }
        if let profile = store.document.profiles.first(where: { $0.presetID == parameter || $0.name == parameter }) { return profile.id.uuidString }
        return parameter
    }

    private var processExecutableBinding: SwiftUI.Binding<String> { processBinding(\.executable) }
    private var processDirectoryBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { processSpec.workingDirectory ?? "" }, set: { value in updateProcess { $0.workingDirectory = value.isEmpty ? nil : value } }) }
    private var processTimeoutBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { String(processSpec.timeoutSeconds) }, set: { value in updateProcess { $0.timeoutSeconds = Double(value) ?? 0 } }) }
    private var processArgumentsBinding: SwiftUI.Binding<[String]> { SwiftUI.Binding(get: { processSpec.args }, set: { value in updateProcess { $0.args = value } }) }
    private var processSpec: ProcessSpec {
        guard let data = store.selectedBinding.action.parameter.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ProcessSpec.self, from: data) else {
            return ProcessSpec(executable: "", args: [], timeoutSeconds: 30)
        }
        return decoded
    }
    private func processBinding(_ keyPath: WritableKeyPath<ProcessSpec, String>) -> SwiftUI.Binding<String> { SwiftUI.Binding(get: { processSpec[keyPath: keyPath] }, set: { value in updateProcess { $0[keyPath: keyPath] = value } }) }
    private func updateProcess(_ change: (inout ProcessSpec) -> Void) { var spec = processSpec; change(&spec); var action = store.selectedBinding.action; action.parameter = spec.encoded(); store.updateSelected(action: action) }
    private func processArgumentBinding(_ index: Int) -> SwiftUI.Binding<String> { SwiftUI.Binding(get: { processSpec.args.indices.contains(index) ? processSpec.args[index] : "" }, set: { value in var args = processArgumentsBinding.wrappedValue; guard args.indices.contains(index) else { return }; args[index] = value; processArgumentsBinding.wrappedValue = args }) }
    private func appendProcessArgument() { var args = processArgumentsBinding.wrappedValue; args.append(""); processArgumentsBinding.wrappedValue = args }
    private func removeProcessArgument(at index: Int) { var args = processArgumentsBinding.wrappedValue; guard args.indices.contains(index) else { return }; args.remove(at: index); processArgumentsBinding.wrappedValue = args }
    private func binding(_ keyPath: WritableKeyPath<ControlAction, String>) -> SwiftUI.Binding<String> { SwiftUI.Binding(get: { store.selectedBinding.action[keyPath: keyPath] }, set: { value in var action = store.selectedBinding.action; action[keyPath: keyPath] = value; store.updateSelected(action: action) }) }
}
