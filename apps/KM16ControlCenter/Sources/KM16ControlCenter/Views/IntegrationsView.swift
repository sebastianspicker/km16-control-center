import SwiftUI
import KM16ControlCore
import KM16Integrations

struct IntegrationsView: View {
    @Environment(DesktopActionRunner.self) private var runner
    @Environment(CodexDeckClient.self) private var client
    @AppStorage("KM16.liveActionsEnabled") private var liveActionsEnabled = false
    @State private var prompt = ""
    @State private var operationError: String?
    @State private var selectedOutput = DeckOutputKind.response

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    actionAccess
                    OBSSettingsView()
                    Divider()
                    connection
                    if client.isConnected { workspace }
                }
                .padding(32)
                .frame(maxWidth: 980, alignment: .leading)
            }
            .onAppear {
                guard client.diffRevealCounter > 0 else { return }
                selectedOutput = .diff
                proxy.scrollTo("agent-diff", anchor: .center)
            }
            .onChange(of: client.diffRevealCounter) { _, _ in
                selectedOutput = .diff
                DispatchQueue.main.async { proxy.scrollTo("agent-diff", anchor: .center) }
            }
        }
        .frame(minWidth: 700, minHeight: 600)
        .alert("Connection Action Failed", isPresented: Binding(get: { operationError != nil }, set: { if !$0 { operationError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(operationError ?? "") }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Connections").font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Configure OBS and connect a Codex workspace when you need them.").foregroundStyle(.secondary)
            }
            Spacer(minLength: 20)
            StudioStatus(client.isConnected ? "Connected" : "Not connected", symbol: client.isConnected ? "checkmark.circle.fill" : "circle", tint: client.isConnected ? StudioStyle.accent : .secondary)
        }
    }

    private var actionAccess: some View {
        StudioSection("Action access", subtitle: "Run Selected can send desktop input, run commands, control OBS, or submit Agent Deck actions.") {
            Toggle("Enable live actions for Run Selected", isOn: $liveActionsEnabled)
            Text("Review imported assignments before running them. This setting is remembered across imports and app launches.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: runner.accessibilityGranted ? "checkmark.shield" : "lock.shield")
                    .foregroundStyle(runner.accessibilityGranted ? StudioStyle.accent : .secondary)
                Text(runner.accessibilityGranted ? "Accessibility permission is available." : "Accessibility permission has not been granted.")
                    .foregroundStyle(.secondary)
                Spacer()
                if runner.isRunning {
                    Button("Cancel", role: .destructive) { runner.cancel() }.controlSize(.small)
                }
            }
            .font(.caption)
        }
    }

    private var connection: some View {
        StudioSection("Connection", subtitle: "Nothing connects until you select Connect.") {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow { Text("Codex command").foregroundStyle(.secondary); TextField("/opt/homebrew/bin/codex", text: executableBinding) }
                GridRow { Text("Workspace").foregroundStyle(.secondary); TextField("Choose a local workspace", text: workspaceBinding) }
                GridRow {
                    Text("Model").foregroundStyle(.secondary)
                    Picker("Model", selection: modelBinding) {
                        Text("Default").tag("")
                        ForEach(client.models, id: \.id) { Text($0.name).tag($0.id) }
                    }.labelsHidden()
                }
                GridRow {
                    Text("Reasoning").foregroundStyle(.secondary)
                    Picker("Reasoning effort", selection: effortBinding) {
                        Text("Default").tag("")
                        ForEach(selectedModelEfforts, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden()
                }
            }
            .controlSize(.small)
            HStack(spacing: 10) {
                Button(client.isConnected ? "Refresh threads" : "Connect") { Task { await connectOrRefresh() } }
                    .buttonStyle(.borderedProminent).tint(StudioStyle.accent)
                if client.isConnected { Button("Disconnect") { client.disconnect() } }
                Text(client.state).font(.caption).foregroundStyle(.secondary)
            }
            Text("New tasks request Codex’s workspace-write mode and on-request approvals. Existing tasks keep their previous Codex permissions, which may be broader; this app does not verify those permissions. Sending a message is separate from the Run Selected setting.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = client.lastError, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.secondary).padding(.top, 2)
            }
        }
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 22) {
            StudioSection("Workspace", subtitle: "Select the thread that should receive the next prompt.") {
                Picker("Thread", selection: threadSelection) {
                    Text("Choose a thread").tag(String?.none)
                    ForEach(client.threads, id: \.id) { thread in
                        Text(thread.cwd.isEmpty ? thread.title : "\(thread.title)  ·  \(thread.cwd)").tag(Optional(thread.id))
                    }
                }
                .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            }
            if !client.requests.isEmpty { pendingRequests }
            StudioSection("Message", subtitle: "Send to the selected thread.") {
                TextEditor(text: $prompt).font(.body).scrollContentBackground(.hidden).frame(minHeight: 104).padding(8).studioSurface(cornerRadius: 10)
                HStack {
                    Text("Up to 100 KB").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Send") { let text = prompt; Task { await sendPrompt(text) } }
                        .buttonStyle(.borderedProminent).tint(StudioStyle.accent)
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            output
        }
    }

    private var pendingRequests: some View {
        StudioSection("Awaiting your decision", subtitle: "These requests pause the active turn until you respond.") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(client.requests, id: \.id) { request in
                    DeckRequestCard(request: request, client: client) { requestID, decision, evidenceToken in
                        respond(requestID, decision: decision, evidenceToken: evidenceToken)
                    }
                }
            }
        }
        .studioSurface(cornerRadius: 16)
    }

    private var output: some View {
        StudioSection("Activity") {
            Picker("Activity", selection: $selectedOutput) {
                ForEach(DeckOutputKind.allCases) { kind in Text(kind.title).tag(kind) }
            }
            .pickerStyle(.segmented)
            switch selectedOutput {
            case .response:
                DeckOutputView(text: client.output, offset: client.outputScrollOffset)
            case .plan:
                DeckTextSurface(text: client.plan, placeholder: "No plan yet.")
            case .diff:
                VStack(alignment: .leading, spacing: 10) {
                    if !client.changedFiles.isEmpty {
                        Picker("File", selection: selectedFileBinding) {
                            ForEach(client.changedFiles.indices, id: \.self) { index in Text(client.changedFiles[index]).tag(index) }
                        }.controlSize(.small)
                    }
                    Text(diffScope).font(.caption).foregroundStyle(.secondary)
                    DeckTextSurface(text: client.diff, placeholder: "No diff yet.")
                }
                .id("agent-diff")
            }
        }
    }

    private var diffScope: String {
        client.changedFiles.indices.contains(client.selectedFileIndex)
            ? "Full diff · selected file: \(client.changedFiles[client.selectedFileIndex])"
            : "Full diff · no file selected"
    }
    private var selectedModelEfforts: [String] { client.models.first(where: { $0.id == client.selectedModel })?.efforts ?? [] }
    private var threadSelection: SwiftUI.Binding<String?> {
        SwiftUI.Binding(get: { client.selectedThreadID }, set: { id in guard let id, id != client.selectedThreadID else { return }; Task { await selectThread(id) } })
    }
    private var executableBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { client.executablePath }, set: { client.executablePath = $0 }) }
    private var workspaceBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { client.workspacePath }, set: { client.workspacePath = $0 }) }
    private var modelBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { client.selectedModel }, set: { client.selectedModel = $0 }) }
    private var effortBinding: SwiftUI.Binding<String> { SwiftUI.Binding(get: { client.selectedEffort }, set: { client.selectedEffort = $0 }) }
    private var selectedFileBinding: SwiftUI.Binding<Int> { SwiftUI.Binding(get: { client.selectedFileIndex }, set: { client.selectedFileIndex = $0 }) }

    @MainActor private func connectOrRefresh() async { do { if client.isConnected { try await client.refreshThreads() } else { try await client.connect() } } catch { operationError = error.localizedDescription } }
    @MainActor private func selectThread(_ id: String) async { do { try await client.selectThread(id) } catch { operationError = error.localizedDescription } }
    @MainActor private func sendPrompt(_ text: String) async { do { try await client.sendPrompt(text); prompt = "" } catch { operationError = error.localizedDescription } }
    private func respond(_ requestID: String, decision: String, evidenceToken: String?) {
        do { try client.respond(to: requestID, decision: decision, evidenceToken: evidenceToken) }
        catch { operationError = error.localizedDescription }
    }
}

private enum DeckOutputKind: String, CaseIterable, Identifiable {
    case response, plan, diff
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

private struct DeckOutputView: View {
    let text: String
    let offset: Int
    private var lines: [String] { text.isEmpty ? ["No response yet."] : text.components(separatedBy: .newlines) }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(lines.indices, id: \.self) { index in
                        Text(lines[index]).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).id(index)
                    }
                }.padding(12)
            }
            .frame(minHeight: 160, maxHeight: 320).studioSurface(cornerRadius: 12)
            .onChange(of: offset) { _, value in guard !lines.isEmpty else { return }; proxy.scrollTo(min(max(0, value), lines.count - 1), anchor: .center) }
        }
    }
}

private struct DeckTextSurface: View {
    let text: String
    let placeholder: String
    var body: some View {
        ScrollView {
            Text(text.isEmpty ? placeholder : text).font(.system(.body, design: .monospaced)).foregroundStyle(text.isEmpty ? .secondary : .primary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
        .frame(minHeight: 160, maxHeight: 320).studioSurface(cornerRadius: 12)
    }
}

private struct DeckRequestCard: View {
    let request: DeckRequest
    let client: CodexDeckClient
    let respond: (String, String, String?) -> Void
    @State private var selections: [String: String] = [:]
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(request.questions.isEmpty ? "Confirmation needed" : "Your input is needed").font(.headline)
            if request.questions.isEmpty {
                approvalDetails
                HStack {
                    if request.decisions.contains("accept") {
                        decisionButton("Accept", decision: "accept")
                            .disabled(request.approval?.canAccept != true)
                    }
                    if request.decisions.contains("decline") { decisionButton("Decline", decision: "decline") }
                    if request.decisions.contains("cancel") { decisionButton("Cancel", decision: "cancel") }
                }
            } else {
                questions
                Button("Submit answers") { submitAnswers() }.buttonStyle(.borderedProminent).tint(StudioStyle.accent)
            }
        }
        .padding(14).studioSurface(cornerRadius: 12)
        .onAppear { markApprovalPresented() }
        .onChange(of: request.approval?.evidenceToken) { _, _ in markApprovalPresented() }
        .alert("Answers Not Sent", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
    }

    @ViewBuilder private var approvalDetails: some View {
        if let approval = request.approval {
            ApprovalEvidenceView(approval: approval)
        } else {
            Text("This request cannot be accepted because complete approval evidence is unavailable.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var questions: some View {
        ForEach(request.questions, id: \.id) { question in
            VStack(alignment: .leading, spacing: 5) {
                if question.options.isEmpty {
                    if question.isSecret { SecureField(question.header, text: answerBinding(for: question)) }
                    else { TextField(question.header, text: answerBinding(for: question)) }
                } else {
                    Picker(question.header, selection: answerBinding(for: question)) { ForEach(question.options, id: \.self) { Text($0).tag($0) } }
                }
                if !question.question.isEmpty { Text(question.question).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private func decisionButton(_ title: String, decision: String) -> some View {
        Button(title) { respond(request.id, decision, decision == "accept" ? request.approval?.evidenceToken : nil) }
            .controlSize(.small)
    }
    private func markApprovalPresented() {
        guard let approval = request.approval, approval.canAccept else { return }
        client.markApprovalPresented(requestID: request.id, evidenceToken: approval.evidenceToken)
    }
    private func answerBinding(for question: DeckQuestion) -> SwiftUI.Binding<String> { SwiftUI.Binding(get: { selections[question.id] ?? question.options.first ?? "" }, set: { selections[question.id] = $0 }) }
    private func submitAnswers() {
        let values = Dictionary(uniqueKeysWithValues: request.questions.map { ($0.id, [selections[$0.id] ?? $0.options.first ?? ""]) })
        do { try client.answer(requestID: request.id, answers: values) } catch { self.error = error.localizedDescription }
    }
}

private struct ApprovalEvidenceView: View {
    let approval: DeckApproval
    var body: some View {
        Text(approval.type).font(.subheadline.weight(.semibold))
        ScrollView([.horizontal, .vertical]) {
            Text(approval.details)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(minHeight: 140, maxHeight: 360)
        .studioSurface(cornerRadius: 10)
        if let reason = approval.acceptDisabledReason {
            Label(reason, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ApprovalDesignFixture: View {
    private let command = DeckApproval(
        type: "Command execution",
        details: """
        Approval type: Command execution
        Connected workspace: /Users/example/Project
        Wire request ID: 17
        Thread ID: thread-example
        Turn ID: turn-example
        Item ID: command-example

        Request parameters (complete):
        {
          "command" : "swift test --package-path apps/KM16ControlCenter",
          "cwd" : "/Users/example/Project",
          "itemId" : "command-example",
          "reason" : "Run the affected package checks",
          "startedAtMs" : 1789286400000,
          "threadId" : "thread-example",
          "turnId" : "turn-example"
        }
        """,
        acceptDisabledReason: nil,
        evidenceToken: "preview-command"
    )
    private let files = DeckApproval(
        type: "File change",
        details: """
        Approval type: File change
        Connected workspace: /Users/example/Project
        Wire request ID: "file-request"
        Thread ID: thread-example
        Turn ID: turn-example
        Item ID: patch-example

        Relevant item/fileChange/patchUpdated evidence (complete):
        {
          "changes" : [
            {
              "diff" : "@@ -1 +1 @@\n-old value\n+new value",
              "kind" : { "move_path" : "Sources/NewName.swift", "type" : "update" },
              "path" : "Sources/OldName.swift"
            }
          ]
        }
        """,
        acceptDisabledReason: nil,
        evidenceToken: "preview-file"
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Approval card layout").font(.title2.weight(.semibold))
                fixtureCard(command)
                fixtureCard(files)
            }
            .padding(20)
        }
    }

    private func fixtureCard(_ approval: DeckApproval) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirmation needed").font(.headline)
            ApprovalEvidenceView(approval: approval)
            HStack {
                Button("Accept") {}.buttonStyle(.borderedProminent).tint(StudioStyle.accent)
                Button("Decline") {}
                Button("Cancel", role: .cancel) {}
            }
            .controlSize(.small)
        }
        .padding(14).studioSurface(cornerRadius: 12)
    }
}
