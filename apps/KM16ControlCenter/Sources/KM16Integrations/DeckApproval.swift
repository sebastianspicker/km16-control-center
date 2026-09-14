import Foundation

public struct DeckApproval: Equatable, Sendable {
    public let type: String
    public let details: String
    public let acceptDisabledReason: String?
    public let evidenceToken: String

    public init(type: String, details: String, acceptDisabledReason: String?, evidenceToken: String) {
        self.type = type
        self.details = details
        self.acceptDisabledReason = acceptDisabledReason
        self.evidenceToken = evidenceToken
    }

    public var canAccept: Bool { acceptDisabledReason == nil }
}

struct DeckApprovalKey: Hashable, Sendable {
    let threadID: String
    let turnID: String
    let itemID: String
}

struct DeckApprovalSource: Sendable {
    let key: DeckApprovalKey
    let method: String
    let params: JSONValue?
    let paramsText: String?
    let issue: String?
    let revision = UUID()
}

struct DeckApprovalEvidence: Sendable {
    let method: String
    let params: JSONValue
    let text: String
    let byteCount: Int
    let issue: String?
    let revision = UUID()
}

extension CodexDeckClient {
    static let approvalEvidenceLimit = 16_384
    static let approvalCacheEntryLimit = 128
    static let approvalCacheByteLimit = 512 * 1_024

    func approvalSource(for request: DeckRequest, params: JSONValue) -> DeckApprovalSource? {
        guard ["item/commandExecution/requestApproval", "item/fileChange/requestApproval"].contains(request.method),
              let itemID = params["itemId"].string, !itemID.isEmpty else { return nil }
        let key = DeckApprovalKey(threadID: request.threadID, turnID: request.turnID, itemID: itemID)
        guard let text = Self.approvalJSON(params) else {
            return DeckApprovalSource(key: key, method: request.method, params: nil, paramsText: nil,
                                      issue: "Accept is disabled because the request parameters are malformed.")
        }
        guard text.utf8.count <= Self.approvalEvidenceLimit else {
            return DeckApprovalSource(key: key, method: request.method, params: nil, paramsText: nil,
                                      issue: "Accept is disabled because the complete request exceeds the 16 KiB evidence limit.")
        }
        return DeckApprovalSource(key: key, method: request.method, params: params, paramsText: text,
                                  issue: Self.requestSemanticsIssue(method: request.method, params: params))
    }

    func cacheApprovalEvidence(_ method: String, params: JSONValue) {
        guard let threadID = params["threadId"].string,
              let turnID = params["turnId"].string,
              let itemID = params["itemId"].string ?? params["item"]["id"].string,
              snapshots[threadID]?.turnID == turnID else { return }
        let key = DeckApprovalKey(threadID: threadID, turnID: turnID, itemID: itemID)
        guard let text = Self.approvalJSON(params) else {
            storeApprovalEvidence(DeckApprovalEvidence(method: method, params: .null, text: "", byteCount: 0,
                                                        issue: "Accept is disabled because the matching evidence is malformed."), for: key)
            refreshApprovals(for: key)
            return
        }
        guard text.utf8.count <= Self.approvalEvidenceLimit else {
            storeApprovalEvidence(DeckApprovalEvidence(method: method, params: .null, text: "", byteCount: 0,
                                                        issue: "Accept is disabled because the complete matching evidence exceeds the 16 KiB evidence limit."), for: key)
            refreshApprovals(for: key)
            return
        }
        let entry = DeckApprovalEvidence(method: method, params: params, text: text, byteCount: text.utf8.count,
                                         issue: Self.evidenceSemanticsIssue(method: method, params: params))
        storeApprovalEvidence(entry, for: key)
        refreshApprovals(for: key)
    }

    public func markApprovalPresented(requestID: String, evidenceToken: String) {
        guard let request = requests.first(where: { $0.id == requestID }),
              request.approval?.canAccept == true,
              request.approval?.evidenceToken == evidenceToken,
              selectedThreadID == request.threadID,
              snapshots[request.threadID]?.turnID == request.turnID else { return }
        presentedApprovalEvidence[requestID] = evidenceToken
    }

    func refreshApprovals(for key: DeckApprovalKey? = nil) {
        for index in requests.indices {
            let request = requests[index]
            guard let source = approvalSources[request.id], key == nil || source.key == key else { continue }
            requests[index].approval = makeApprovalForRequest(request, source: source)
            if presentedApprovalEvidence[request.id] != requests[index].approval?.evidenceToken {
                presentedApprovalEvidence.removeValue(forKey: request.id)
            }
        }
    }

    func removeApprovalState(requestID: String) {
        approvalSources.removeValue(forKey: requestID)
        presentedApprovalEvidence.removeValue(forKey: requestID)
    }

    func clearApprovalState(threadID: String? = nil) {
        if let threadID {
            let requestIDs = approvalSources.filter { $0.value.key.threadID == threadID }.map(\.key)
            for requestID in requestIDs { removeApprovalState(requestID: requestID) }
            approvalEvidence = approvalEvidence.filter { $0.key.threadID != threadID }
            approvalEvidenceOrder.removeAll { $0.threadID == threadID }
        } else {
            approvalSources.removeAll(); presentedApprovalEvidence.removeAll()
            approvalEvidence.removeAll(); approvalEvidenceOrder.removeAll()
        }
    }

    func makeApprovalForRequest(_ request: DeckRequest, source: DeckApprovalSource) -> DeckApproval {
        let title = request.method == "item/fileChange/requestApproval" ? "File change" : "Command execution"
        let token = "\(epoch.uuidString):\(source.revision.uuidString):\(approvalEvidence[source.key]?.revision.uuidString ?? "none")"
        var issue = source.issue
        var sections = [
            "Approval type: \(title)",
            "Connected workspace: \(connectedWorkspace)",
            "Wire request ID: \(Self.approvalJSON(request.wireID) ?? request.id)",
            "Thread ID: \(request.threadID)",
            "Turn ID: \(request.turnID)",
            "Item ID: \(source.key.itemID)"
        ]
        if let paramsText = source.paramsText { sections.append("Request parameters (complete):\n\(paramsText)") }
        else { sections.append(source.issue ?? "Complete request parameters are unavailable.") }

        if selectedThreadID != request.threadID {
            issue = issue ?? "Select this request's thread before accepting."
        } else if snapshots[request.threadID]?.turnID != request.turnID {
            issue = issue ?? "Accept is disabled because this request is no longer the active turn."
        } else if !threads.contains(where: { $0.id == request.threadID && $0.cwd == connectedWorkspace }) {
            issue = issue ?? "Accept is disabled because the request is not bound to the connected workspace."
        }

        if let params = source.params {
            let evidence = approvalEvidence[source.key]
            if request.method == "item/commandExecution/requestApproval" {
                let result = commandEvidence(params: params, evidence: evidence)
                issue = issue ?? result.issue
                if let detail = result.detail { sections.append(detail) }
            } else {
                let result = fileEvidence(params: params, evidence: evidence)
                issue = issue ?? result.issue
                if let detail = result.detail { sections.append(detail) }
            }
        }
        let details = sections.joined(separator: "\n\n")
        if details.utf8.count > Self.approvalEvidenceLimit {
            issue = "Accept is disabled because the complete combined evidence exceeds the 16 KiB evidence limit."
            return DeckApproval(type: title, details: sections.prefix(6).joined(separator: "\n"), acceptDisabledReason: issue, evidenceToken: token)
        }
        return DeckApproval(type: title, details: details, acceptDisabledReason: issue, evidenceToken: token)
    }

    private func commandEvidence(params: JSONValue, evidence: DeckApprovalEvidence?) -> (detail: String?, issue: String?) {
        let kind = params.object["kind"]?.string ?? "command"
        guard kind == "command" else {
            return (nil, kind == "writeStdin"
                    ? "Accept is disabled because this protocol request does not expose the stdin characters."
                    : "Accept is disabled because the command approval kind is unknown.")
        }
        var command = params.object["command"]?.string
        var cwd = params.object["cwd"]?.string
        let evidenceDetail = evidence.flatMap { value in
            value.text.isEmpty ? nil : "Relevant \(value.method) evidence (complete):\n\(value.text)"
        }
        if params.object["approvalId"]?.string != nil {
            guard let command, !command.isEmpty, let cwd, !cwd.isEmpty else {
                return (evidenceDetail, "Accept is disabled because a subcommand approval must include its own exact command and working directory.")
            }
            return (evidenceDetail, nil)
        }
        var detail: String?
        if let evidence {
            detail = evidenceDetail
            if let issue = evidence.issue { return (detail, issue) }
            guard evidence.params["item"]["type"].string == "commandExecution" else {
                return (detail, "Accept is disabled because the matching item is not a command execution.")
            }
            let item = evidence.params["item"]
            if let supplied = command, supplied != item["command"].string {
                return (detail, "Accept is disabled because the request command differs from the matching item.")
            }
            if let supplied = cwd, supplied != item["cwd"].string {
                return (detail, "Accept is disabled because the request working directory differs from the matching item.")
            }
            command = command ?? item["command"].string
            cwd = cwd ?? item["cwd"].string
        }
        guard let command, !command.isEmpty, let cwd, !cwd.isEmpty else {
            return (detail, "Accept is disabled until the exact command and working directory are available.")
        }
        return (detail, nil)
    }

    private func fileEvidence(params: JSONValue, evidence: DeckApprovalEvidence?) -> (detail: String?, issue: String?) {
        if let root = params.object["grantRoot"]?.string, !root.isEmpty {
            return (nil, "Accept is disabled because grantRoot requests session-wide write access, which this one-shot approval UI does not grant.")
        }
        guard let evidence else { return (nil, "Accept is disabled until the exact file changes and diffs are available.") }
        if let issue = evidence.issue {
            return (evidence.text.isEmpty ? nil : "Relevant \(evidence.method) evidence (complete):\n\(evidence.text)", issue)
        }
        let changes: [JSONValue]
        if evidence.method == "item/fileChange/patchUpdated" {
            changes = evidence.params["changes"].array
        } else if evidence.method == "item/started", evidence.params["item"]["type"].string == "fileChange" {
            changes = evidence.params["item"]["changes"].array
        } else {
            return ("Relevant \(evidence.method) evidence (complete):\n\(evidence.text)",
                    "Accept is disabled because the matching evidence is not a file change.")
        }
        let detail = "Relevant \(evidence.method) evidence (complete):\n\(evidence.text)"
        guard !changes.isEmpty, changes.allSatisfy(Self.validFileChange) else {
            return (detail, "Accept is disabled because the file change paths, kinds, or diffs are incomplete or unknown.")
        }
        return (detail, nil)
    }

    private func trimApprovalEvidenceCache() {
        var bytes = approvalEvidence.values.reduce(0) { $0 + $1.byteCount }
        while approvalEvidence.count > Self.approvalCacheEntryLimit || bytes > Self.approvalCacheByteLimit {
            guard let key = approvalEvidenceOrder.first else { break }
            approvalEvidenceOrder.removeFirst()
            if let removed = approvalEvidence.removeValue(forKey: key) { bytes -= removed.byteCount }
            refreshApprovals(for: key)
        }
    }

    private func storeApprovalEvidence(_ entry: DeckApprovalEvidence, for key: DeckApprovalKey) {
        approvalEvidence[key] = entry
        approvalEvidenceOrder.removeAll { $0 == key }
        approvalEvidenceOrder.append(key)
        trimApprovalEvidenceCache()
    }

    private static func approvalJSON(_ value: JSONValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func requestSemanticsIssue(method: String, params: JSONValue) -> String? {
        let common = Set(["threadId", "turnId", "itemId", "startedAtMs", "reason", "availableDecisions"])
        let allowed: Set<String>
        if method == "item/commandExecution/requestApproval" {
            allowed = common.union(["approvalId", "command", "commandActions", "cwd", "environmentId", "kind", "networkApprovalContext", "proposedExecpolicyAmendment", "proposedNetworkPolicyAmendments"])
        } else {
            allowed = common.union(["grantRoot"])
        }
        guard Set(params.object.keys).isSubset(of: allowed) else {
            return "Accept is disabled because the request contains unknown fields with unverified semantics."
        }
        guard params["threadId"].string?.isEmpty == false,
              params["turnId"].string?.isEmpty == false,
              params["itemId"].string?.isEmpty == false,
              case .number(let startedAt) = params["startedAtMs"], startedAt.isFinite, startedAt.rounded() == startedAt else {
            return "Accept is disabled because required request identifiers or timing fields are malformed."
        }
        let object = params.object
        guard validNullableString("reason", in: object),
              validStringArray("availableDecisions", in: object) else {
            return "Accept is disabled because the request contains malformed fields."
        }
        if method == "item/commandExecution/requestApproval" {
            guard validNullableString("approvalId", in: object),
                  validNullableString("command", in: object),
                  validNullableString("cwd", in: object),
                  validNullableString("environmentId", in: object),
                  validNullableObject("networkApprovalContext", in: object),
                  validNullableArray("commandActions", in: object),
                  validNullableStringArray("proposedExecpolicyAmendment", in: object),
                  validNullableObjectArray("proposedNetworkPolicyAmendments", in: object),
                  object["kind"] == nil || ["command", "writeStdin"].contains(params["kind"].string ?? "") else {
                return "Accept is disabled because the command request contains malformed or unknown fields."
            }
        } else if !validNullableString("grantRoot", in: object) {
            return "Accept is disabled because the file request contains malformed fields."
        }
        return nil
    }

    private static func evidenceSemanticsIssue(method: String, params: JSONValue) -> String? {
        let outer: Set<String>
        switch method {
        case "item/started": outer = ["threadId", "turnId", "item", "startedAtMs"]
        case "item/fileChange/patchUpdated": outer = ["threadId", "turnId", "itemId", "changes"]
        default: return "Accept is disabled because the evidence event type is unknown."
        }
        guard Set(params.object.keys).isSubset(of: outer) else {
            return "Accept is disabled because the matching evidence contains unknown fields with unverified semantics."
        }
        if method == "item/fileChange/patchUpdated" { return nil }
        let item = params["item"]
        switch item["type"].string {
        case "commandExecution":
            let allowed = Set(["aggregatedOutput", "command", "commandActions", "cwd", "durationMs", "exitCode", "id", "pluginId", "processId", "scriptPath", "source", "status", "type"])
            guard Set(item.object.keys).isSubset(of: allowed) else {
                return "Accept is disabled because the command item contains unknown fields with unverified semantics."
            }
            guard item["id"].string?.isEmpty == false,
                  item["command"].string != nil,
                  item["cwd"].string?.isEmpty == false,
                  case .array = item["commandActions"],
                  ["inProgress", "completed", "failed", "declined"].contains(item["status"].string ?? "") else {
                return "Accept is disabled because the command item contains malformed fields."
            }
        case "fileChange":
            guard Set(item.object.keys).isSubset(of: Set(["changes", "id", "status", "type"])) else {
                return "Accept is disabled because the file item contains unknown fields with unverified semantics."
            }
        default: break
        }
        return nil
    }

    private static func validNullableString(_ key: String, in object: [String: JSONValue]) -> Bool {
        guard let value = object[key] else { return true }
        return value == .null || value.string != nil
    }

    private static func validNullableObject(_ key: String, in object: [String: JSONValue]) -> Bool {
        guard let value = object[key] else { return true }
        if value == .null { return true }
        if case .object = value { return true }
        return false
    }

    private static func validNullableArray(_ key: String, in object: [String: JSONValue]) -> Bool {
        guard let value = object[key] else { return true }
        if value == .null { return true }
        if case .array = value { return true }
        return false
    }

    private static func validStringArray(_ key: String, in object: [String: JSONValue]) -> Bool {
        guard let value = object[key] else { return true }
        guard case .array(let values) = value else { return false }
        return values.allSatisfy { $0.string != nil }
    }

    private static func validNullableStringArray(_ key: String, in object: [String: JSONValue]) -> Bool {
        guard let value = object[key] else { return true }
        if value == .null { return true }
        guard case .array(let values) = value else { return false }
        return values.allSatisfy { $0.string != nil }
    }

    private static func validNullableObjectArray(_ key: String, in object: [String: JSONValue]) -> Bool {
        guard let value = object[key] else { return true }
        if value == .null { return true }
        guard case .array(let values) = value else { return false }
        return values.allSatisfy { if case .object = $0 { return true }; return false }
    }

    private static func validFileChange(_ value: JSONValue) -> Bool {
        let keys = Set(value.object.keys)
        guard keys == Set(["path", "kind", "diff"]),
              value["path"].string?.isEmpty == false,
              value["diff"].string != nil else { return false }
        let kind = value["kind"], type = kind["type"].string
        switch type {
        case "add", "delete": return Set(kind.object.keys) == Set(["type"])
        case "update":
            return Set(kind.object.keys).isSubset(of: Set(["type", "move_path"])) &&
                (kind.object["move_path"] == nil || kind["move_path"] == .null || kind["move_path"].string != nil)
        default: return false
        }
    }
}
