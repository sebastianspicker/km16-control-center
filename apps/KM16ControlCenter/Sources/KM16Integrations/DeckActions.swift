import Foundation
import KM16ControlCore

extension CodexDeckClient {
    public func perform(_ action: ControlAction) async throws -> String {
        try requireConnection()
        switch action.parameter {
        case "new-task":
            return try await startThread()
        case "previous-task", "next-task":
            guard !threads.isEmpty else { throw IntegrationError.message("No threads in this workspace.") }
            let current = threads.firstIndex { $0.id == selectedThreadID } ?? 0
            let delta = action.parameter == "next-task" ? 1 : -1
            let next = (current + delta + threads.count) % threads.count
            try await selectThread(threads[next].id)
            return "Opened \(threads[next].title)."
        case "open-task":
            guard let id = selectedThreadID else { throw IntegrationError.message("Select a thread first.") }
            try await selectThread(id); return "Opened selected thread."
        case "stop-current-task":
            guard let id = selectedThreadID, let turn = snapshots[id]?.turnID else { throw IntegrationError.message("The selected thread has no active turn.") }
            _ = try await transport.request("turn/interrupt", params: .object(["threadId": .string(id), "turnId": .string(turn)]))
            return "Interrupt requested; waiting for turn completion."
        case "previous-changed-file", "next-changed-file":
            guard !changedFiles.isEmpty else { throw IntegrationError.message("The selected thread has no changed files.") }
            let delta = action.parameter == "next-changed-file" ? 1 : -1
            selectedFileIndex = (selectedFileIndex + delta + changedFiles.count) % changedFiles.count
            diffRevealCounter += 1
            return "Selected \(changedFiles[selectedFileIndex])."
        case "open-diff":
            guard !diff.isEmpty else { throw IntegrationError.message("No diff is available for the selected thread.") }
            diffRevealCounter += 1
            return "Opened the Agent Deck diff."
        case "scroll-up": outputScrollOffset = max(0, outputScrollOffset - 1); return "Moved output selection up."
        case "scroll-down": outputScrollOffset += 1; return "Moved output selection down."
        default:
            let prompts = [
                "review-changes": "Review the current working-tree changes for bugs and regressions. Report findings with file references. Do not modify files.",
                "run-tests": "Identify and run the project's appropriate tests. Report failures and what was not tested. Do not change code.",
                "explain-selection": "Explain the code or context supplied in this thread. If no code was provided, ask which code to explain. Do not assume access to an editor selection.",
                "summarize-context": "Summarize this task, decisions, changed files, verification and unfinished work. Do not modify files.",
                "draft-commit": "Inspect the current changes and draft a concise commit message. Do not commit, push or modify files."
            ]
            let prompt = action.parameter.hasPrefix("prompt:") ? String(action.parameter.dropFirst(7)) : prompts[action.parameter]
            guard let prompt else { throw IntegrationError.message("Unknown Agent Deck action.") }
            try await sendPrompt(prompt)
            return "Submitted \(action.label) to the selected thread."
        }
    }

    private func startThread() async throws -> String {
        guard !busy else { throw IntegrationError.message("Wait for the current Codex request.") }
        busy = true; defer { busy = false }
        var params: [String: JSONValue] = ["cwd": .string(connectedWorkspace), "approvalPolicy": .string("on-request"), "sandbox": .string("workspace-write"), "serviceName": .string("km16-control-center")]
        if !selectedModel.isEmpty {
            guard models.contains(where: { $0.id == selectedModel }) else { throw IntegrationError.message("Choose a supported model.") }
            params["model"] = .string(selectedModel)
        }
        let token = epoch
        let result = try await transport.request("thread/start", params: .object(params))
        guard epoch == token else { throw CancellationError() }
        guard let thread = DeckThread(result["thread"]), thread.cwd == connectedWorkspace else { throw IntegrationError.message("Codex returned an unexpected workspace.") }
        threads.removeAll { $0.id == thread.id }; threads.insert(thread, at: 0)
        selectedThreadID = thread.id; snapshots[thread.id] = DeckSnapshot(); publish(thread.id)
        return "Created task \(thread.title)."
    }

    public func respond(to requestID: String, decision: String, evidenceToken: String? = nil) throws {
        try requireConnection()
        guard let request = requests.first(where: { $0.id == requestID }),
              ["item/commandExecution/requestApproval", "item/fileChange/requestApproval"].contains(request.method),
              request.decisions.contains(decision),
              snapshots[request.threadID]?.turnID == request.turnID else { throw IntegrationError.message("This approval is unsupported, stale or already resolved.") }
        if decision == "accept" {
            guard selectedThreadID == request.threadID,
                  threads.contains(where: { $0.id == request.threadID && $0.cwd == connectedWorkspace }),
                  let approval = request.approval, approval.canAccept,
                  let evidenceToken, approval.evidenceToken == evidenceToken,
                  presentedApprovalEvidence[requestID] == evidenceToken else {
                throw IntegrationError.message("Accept is disabled until the complete current approval evidence is displayed for the selected thread.")
            }
        }
        try transport.respond(id: request.wireID, result: .object(["decision": .string(decision)]))
        requests.removeAll { $0.id == requestID }
        removeApprovalState(requestID: requestID)
        if let selectedThreadID { publish(selectedThreadID) }
    }
    public func answer(requestID: String, answers: [String: [String]]) throws {
        try requireConnection()
        guard let request = requests.first(where: { $0.id == requestID }), request.method == "item/tool/requestUserInput",
              snapshots[request.threadID]?.turnID == request.turnID,
              Set(answers.keys) == Set(request.questions.map(\.id)),
              answers.values.allSatisfy({ !$0.isEmpty && $0.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }) else { throw IntegrationError.message("Answer each question in the current request.") }
        try transport.respond(id: request.wireID, result: .object(["answers": .object(answers.mapValues { .object(["answers": .array($0.map(JSONValue.string))]) })]))
        requests.removeAll { $0.id == requestID }
        removeApprovalState(requestID: requestID)
        if let selectedThreadID { publish(selectedThreadID) }
    }
}
