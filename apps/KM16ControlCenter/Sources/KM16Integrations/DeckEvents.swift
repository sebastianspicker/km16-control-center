import Foundation

extension CodexDeckClient {
    func receive(_ message: JSONValue) {
        guard let method = message["method"].string else { return }
        let params = message["params"]
        if message["id"].idKey != nil {
            receiveRequest(message, method: method)
            return
        }
        if method == "serverRequest/resolved" {
            if let id = params["requestId"].idKey {
                requests.removeAll { $0.id == id }
                removeApprovalState(requestID: id)
            }
            if let id = selectedThreadID { publish(id) }; return
        }
        receiveThreadEvent(method, params: params)
    }
    private func receiveThreadEvent(_ method: String, params: JSONValue) {
        guard let id = params["threadId"].string, var snapshot = snapshots[id] else { return }
        let turnScoped = ["turn/diff/updated", "turn/plan/updated", "item/agentMessage/delta", "item/started", "item/completed", "item/fileChange/patchUpdated"]
        if turnScoped.contains(method), params["turnId"].string != snapshot.turnID { return }
        if method == "item/started" || method == "item/fileChange/patchUpdated" {
            cacheApprovalEvidence(method, params: params)
            if method == "item/fileChange/patchUpdated" { return }
        }
        let turn = params["turn"]
        switch method {
        case "turn/started":
            requests.removeAll { $0.threadID == id }
            clearApprovalState(threadID: id)
            snapshot.turnID = turn["id"].string; snapshot.state = "Running"
            snapshot.diff = ""; snapshot.plan = ""
        case "turn/completed":
            guard let completed = turn["id"].string else { return }
            snapshot.completedTurns.insert(completed)
            if snapshot.completedTurns.count > 128 { snapshot.completedTurns = [completed] }
            guard snapshot.turnID == nil || snapshot.turnID == completed else { snapshots[id] = snapshot; return }
            snapshot.turnID = nil; snapshot.state = turn["status"].string ?? "Completed"
            let resolved = requests.filter { $0.threadID == id && $0.turnID == turn["id"].string }.map(\.id)
            requests.removeAll { $0.threadID == id && $0.turnID == turn["id"].string }
            for requestID in resolved { removeApprovalState(requestID: requestID) }
            clearApprovalState(threadID: id)
            if let error = turn["error"]["message"].string { lastError = error }
        case "turn/diff/updated":
            snapshot.diff = String((params["diff"].string ?? "").prefix(500_000))
        case "turn/plan/updated":
            snapshot.plan = params["plan"].array.map { "\($0["status"].string ?? "pending"): \($0["step"].string ?? "")" }.joined(separator: "\n")
        case "item/agentMessage/delta":
            let key = params["itemId"].string ?? "latest"
            let delta = params["delta"].string ?? ""
            snapshot.messages[key] = String((snapshot.messages[key, default: ""] + delta).suffix(100_000))
            snapshot.output = String((snapshot.output + delta).suffix(200_000))
        case "item/completed":
            let item = params["item"]
            if let itemID = item["id"].string {
                let stale = requests.filter { $0.threadID == id && $0.turnID == params["turnId"].string && approvalSources[$0.id]?.key.itemID == itemID }.map(\.id)
                requests.removeAll { stale.contains($0.id) }
                for requestID in stale { removeApprovalState(requestID: requestID) }
                let key = DeckApprovalKey(threadID: id, turnID: params["turnId"].string ?? "", itemID: itemID)
                approvalEvidence.removeValue(forKey: key)
                approvalEvidenceOrder.removeAll { $0 == key }
            }
            if item["type"].string == "agentMessage", let key = item["id"].string, snapshot.messages[key] == nil {
                snapshot.output = String((snapshot.output + "\n" + (item["text"].string ?? "")).suffix(200_000))
            }
        case "error": lastError = params["error"]["message"].string ?? "Codex reported an error."
        default: return
        }
        // Bound auxiliary per-item bookkeeping independently of the visible transcript.
        if snapshot.messages.count > 128 { snapshot.messages.removeAll() }
        snapshots[id] = snapshot; publish(id)
    }
    private func receiveRequest(_ message: JSONValue, method: String) {
        let supported = ["item/commandExecution/requestApproval", "item/fileChange/requestApproval", "item/tool/requestUserInput"]
        guard supported.contains(method), let parsedRequest = DeckRequest(message), requests.count < 64,
              !requests.contains(where: { $0.id == parsedRequest.id }),
              snapshots[parsedRequest.threadID]?.turnID == parsedRequest.turnID else {
            try? transport.reject(id: message["id"], message: "This client cannot handle this request or its turn is no longer active.")
            lastError = "Unsupported or stale server request: \(method)"; return
        }
        var request = parsedRequest
        if let source = approvalSource(for: request, params: message["params"]) {
            approvalSources[request.id] = source
            request.approval = makeApprovalForRequest(request, source: source)
        }
        requests.append(request)
        state = "Needs input"
    }
    func hydrate(_ thread: JSONValue) {
        guard let id = thread["id"].string else { return }
        var snapshot = DeckSnapshot()
        for turn in thread["turns"].array {
            if turn["status"].string == "inProgress" { snapshot.turnID = turn["id"].string; snapshot.state = "Running" }
            for item in turn["items"].array where item["type"].string == "agentMessage" {
                snapshot.output = String((snapshot.output + (item["text"].string ?? "") + "\n\n").suffix(200_000))
            }
        }
        snapshots[id] = snapshot
    }
    func publish(_ id: String) {
        guard id == selectedThreadID, let snapshot = snapshots[id] else { return }
        output = snapshot.output; plan = snapshot.plan; activeTurnID = snapshot.turnID
        state = requests.contains(where: { $0.threadID == id }) ? "Needs input" : snapshot.state
        // Text deltas and approval updates do not change the diff. Avoid scanning it
        // again on the main actor for every streamed token.
        if diff != snapshot.diff {
            diff = snapshot.diff
            var seen = Set<String>()
            changedFiles = diff.split(separator: "\n").compactMap { line in
                guard line.hasPrefix("+++ b/") else { return nil }
                let name = String(line.dropFirst(6)); return seen.insert(name).inserted ? name : nil
            }
        }
        selectedFileIndex = min(max(0, selectedFileIndex), max(0, changedFiles.count - 1))
    }
}
