import Foundation
import KM16Integrations
import KM16ControlCore

@MainActor
func approvalChecks() async throws {
    let mock = MockTransport()
    let deck = CodexDeckClient(transport: mock)
    deck.workspacePath = "/tmp"
    try await deck.connect()
    try await deck.selectThread("one")
    try await deck.sendPrompt("Approval checks")

    func commandRequest(id: JSONValue, itemID: String, extra: [String: JSONValue] = [:]) -> JSONValue {
        var params: [String: JSONValue] = [
            "threadId": .string("one"), "turnId": .string("turn-1"),
            "itemId": .string(itemID), "startedAtMs": .number(1)
        ]
        for (key, value) in extra { params[key] = value }
        return .object(["method": .string("item/commandExecution/requestApproval"), "id": id, "params": .object(params)])
    }
    func fileRequest(id: JSONValue, itemID: String, extra: [String: JSONValue] = [:]) -> JSONValue {
        var params: [String: JSONValue] = [
            "threadId": .string("one"), "turnId": .string("turn-1"),
            "itemId": .string(itemID), "startedAtMs": .number(1)
        ]
        for (key, value) in extra { params[key] = value }
        return .object(["method": .string("item/fileChange/requestApproval"), "id": id, "params": .object(params)])
    }
    func itemStarted(item: JSONValue) -> JSONValue {
        .object(["method": .string("item/started"), "params": .object([
            "threadId": .string("one"), "turnId": .string("turn-1"),
            "startedAtMs": .number(1), "item": item
        ])])
    }
    func change(_ path: String, diff: String, move: String? = nil) -> JSONValue {
        var kind: [String: JSONValue] = ["type": .string("update")]
        if let move { kind["move_path"] = .string(move) }
        return .object(["path": .string(path), "kind": .object(kind), "diff": .string(diff)])
    }
    func presentAndAccept(_ request: DeckRequest) throws {
        guard let approval = request.approval else { throw IntegrationError.message("Approval model missing") }
        deck.markApprovalPresented(requestID: request.id, evidenceToken: approval.evidenceToken)
        try deck.respond(to: request.id, decision: "accept", evidenceToken: approval.evidenceToken)
    }

    // A legacy command approval (kind absent) is complete when exact command and cwd are in the request.
    mock.onMessage?(commandRequest(id: .number(101), itemID: "command-direct", extra: [
        "command": .string("printf exact"), "cwd": .string("/tmp")
    ]))
    try expect(deck.requests.last?.approval?.canAccept == true, "Complete legacy command approval stayed disabled")
    try presentAndAccept(deck.requests.last!)
    try expect(mock.replies.last?.0 == .number(101) && mock.replies.last?.1["decision"].string == "accept", "Numeric approval ID or decision changed")

    // Missing nullable fields may fall back only to the exact parent command item.
    mock.onMessage?(commandRequest(id: .string("fallback"), itemID: "command-fallback", extra: ["approvalId": .null]))
    try expect(deck.requests.last?.approval?.canAccept == false, "Command without operation evidence was enabled")
    mock.onMessage?(itemStarted(item: .object([
        "type": .string("commandExecution"), "id": .string("command-fallback"),
        "command": .string("swift test"), "cwd": .string("/tmp"),
        "commandActions": .array([]), "status": .string("inProgress")
    ])))
    guard let readyFallback = deck.requests.last, let firstEvidence = readyFallback.approval else {
        throw IntegrationError.message("Matching command item did not complete evidence")
    }
    try expect(firstEvidence.canAccept && firstEvidence.details.contains("swift test"), "Exact fallback command was not displayed")
    deck.markApprovalPresented(requestID: readyFallback.id, evidenceToken: firstEvidence.evidenceToken)
    mock.onMessage?(itemStarted(item: .object([
        "type": .string("commandExecution"), "id": .string("command-fallback"),
        "command": .string("swift test --changed"), "cwd": .string("/tmp"),
        "commandActions": .array([]), "status": .string("inProgress")
    ])))
    do {
        try deck.respond(to: readyFallback.id, decision: "accept", evidenceToken: firstEvidence.evidenceToken)
        throw IntegrationError.message("Changed evidence accepted with a stale presentation")
    } catch IntegrationError.message(let text) {
        try expect(text.contains("complete current"), "Unexpected changed-evidence rejection")
    }
    try presentAndAccept(deck.requests.last!)
    try expect(mock.replies.last?.0 == .string("fallback"), "String approval ID changed")

    // A fully specified child describes its own bounded command; the shared parent item is context only.
    mock.onMessage?(commandRequest(id: .string("child-request-first"), itemID: "parent-request-first", extra: [
        "approvalId": .string("child-request-first-id"), "command": .string("child exact one"),
        "cwd": .string("/tmp/child-one")
    ]))
    mock.onMessage?(itemStarted(item: .object([
        "type": .string("commandExecution"), "id": .string("parent-request-first"),
        "command": .string("different parent one"), "cwd": .string("/tmp"),
        "commandActions": .array([]), "status": .string("inProgress")
    ])))
    try expect(deck.requests.last?.approval?.canAccept == true && deck.requests.last?.approval?.details.contains("child exact one") == true,
               "Fully specified request-before-item child approval was compared with its parent")
    try presentAndAccept(deck.requests.last!)

    mock.onMessage?(itemStarted(item: .object([
        "type": .string("commandExecution"), "id": .string("parent-item-first"),
        "command": .string("different parent two"), "cwd": .string("/tmp"),
        "commandActions": .array([]), "status": .string("inProgress")
    ])))
    mock.onMessage?(commandRequest(id: .string("child-item-first"), itemID: "parent-item-first", extra: [
        "approvalId": .string("child-item-first-id"), "command": .string("child exact two"),
        "cwd": .string("/tmp/child-two")
    ]))
    try expect(deck.requests.last?.approval?.canAccept == true && deck.requests.last?.approval?.details.contains("child exact two") == true,
               "Fully specified item-before-request child approval was compared with its parent")
    try presentAndAccept(deck.requests.last!)

    // Child and stdin approvals cannot borrow unsafe or undisclosed parent operation details.
    mock.onMessage?(commandRequest(id: .string("subcommand"), itemID: "parent", extra: ["approvalId": .string("child")]))
    mock.onMessage?(itemStarted(item: .object([
        "type": .string("commandExecution"), "id": .string("parent"),
        "command": .string("parent command"), "cwd": .string("/tmp"),
        "commandActions": .array([]), "status": .string("inProgress")
    ])))
    try expect(deck.requests.last?.approval?.canAccept == false, "Subcommand borrowed its parent command")
    try deck.respond(to: deck.requests.last!.id, decision: "decline")
    mock.onMessage?(commandRequest(id: .string("stdin"), itemID: "stdin-parent", extra: [
        "kind": .string("writeStdin"), "approvalId": .string("stdin-child"),
        "command": .string("write input"), "cwd": .string("/tmp")
    ]))
    try expect(deck.requests.last?.approval?.acceptDisabledReason?.contains("stdin characters") == true, "Undisclosed stdin approval was enabled")
    try deck.respond(to: deck.requests.last!.id, decision: "cancel")

    mock.onMessage?(commandRequest(id: .string("unknown"), itemID: "unknown", extra: [
        "command": .string("true"), "cwd": .string("/tmp"), "futureSemantic": .bool(true)
    ]))
    try expect(deck.requests.last?.approval?.acceptDisabledReason?.contains("unknown fields") == true, "Unknown approval semantics were accepted")
    try deck.respond(to: deck.requests.last!.id, decision: "decline")
    mock.onMessage?(commandRequest(id: .string("oversize"), itemID: "oversize", extra: [
        "command": .string(String(repeating: "x", count: 17_000)), "cwd": .string("/tmp")
    ]))
    try expect(deck.requests.last?.approval?.acceptDisabledReason?.contains("16 KiB") == true, "Oversized approval evidence was enabled")
    try deck.respond(to: deck.requests.last!.id, decision: "decline")

    // File evidence is accepted in either notification order and includes moves and full diffs.
    let firstChanges = [change("Sources/A.swift", diff: "@@ -1 +1 @@\n-old\n+new", move: "Sources/B.swift")]
    mock.onMessage?(.object(["method": .string("item/fileChange/patchUpdated"), "params": .object([
        "threadId": .string("one"), "turnId": .string("turn-1"),
        "itemId": .string("file-before"), "changes": .array(firstChanges)
    ])]))
    mock.onMessage?(fileRequest(id: .string("file-before-id"), itemID: "file-before"))
    try expect(deck.requests.last?.approval?.canAccept == true && deck.requests.last?.approval?.details.contains("Sources/B.swift") == true,
               "Patch-before-request evidence was not joined or displayed")
    try presentAndAccept(deck.requests.last!)

    mock.onMessage?(fileRequest(id: .string("file-after-id"), itemID: "file-after"))
    try expect(deck.requests.last?.approval?.canAccept == false, "File approval enabled before changes arrived")
    mock.onMessage?(itemStarted(item: .object([
        "type": .string("fileChange"), "id": .string("file-after"), "status": .string("inProgress"),
        "changes": .array([change("README.md", diff: "@@ -1 +1 @@\n-a\n+b")])
    ])))
    try expect(deck.requests.last?.approval?.canAccept == true && deck.requests.last?.approval?.details.contains("README.md") == true,
               "Request-before-item file evidence was not joined or displayed")
    try presentAndAccept(deck.requests.last!)

    mock.onMessage?(fileRequest(id: .string("mismatch"), itemID: "wanted"))
    mock.onMessage?(itemStarted(item: .object([
        "type": .string("fileChange"), "id": .string("other"), "status": .string("inProgress"),
        "changes": .array([change("wrong", diff: "wrong")])
    ])))
    try expect(deck.requests.last?.approval?.canAccept == false, "Mismatched file item completed approval evidence")
    try deck.respond(to: deck.requests.last!.id, decision: "decline")

    // A request for another active thread remains visible but cannot be accepted until selected.
    try await deck.selectThread("two")
    try await deck.sendPrompt("Background approval setup")
    mock.onMessage?(commandRequest(id: .string("background"), itemID: "background", extra: [
        "command": .string("true"), "cwd": .string("/tmp")
    ]))
    try expect(deck.requests.last?.approval?.acceptDisabledReason?.contains("Select this request's thread") == true, "Background approval was enabled")
    do {
        try deck.respond(to: deck.requests.last!.id, decision: "accept", evidenceToken: deck.requests.last!.approval?.evidenceToken)
        throw IntegrationError.message("Background approval bypassed the response guard")
    } catch IntegrationError.message(let text) {
        try expect(text.contains("complete current"), "Unexpected background approval rejection")
    }
    try deck.respond(to: deck.requests.last!.id, decision: "decline")

    // Completion makes a previously presented approval stale.
    let staleRequest: JSONValue = .object(["method": .string("item/commandExecution/requestApproval"), "id": .string("stale-completion"), "params": .object([
        "threadId": .string("two"), "turnId": .string("turn-1"), "itemId": .string("complete-me"),
        "startedAtMs": .number(1), "command": .string("true"), "cwd": .string("/tmp")
    ])])
    mock.onMessage?(staleRequest)
    let staleID = deck.requests.last!.id
    mock.onMessage?(.object(["method": .string("item/completed"), "params": .object([
        "threadId": .string("two"), "turnId": .string("turn-1"), "completedAtMs": .number(2),
        "item": .object(["type": .string("commandExecution"), "id": .string("complete-me")])
    ])]))
    do {
        try deck.respond(to: staleID, decision: "accept", evidenceToken: "stale")
        throw IntegrationError.message("Completed item approval remained live")
    } catch IntegrationError.message(let text) {
        try expect(text.contains("stale"), "Unexpected completion rejection")
    }

    let rejectedBefore = mock.rejections.count
    mock.onMessage?(.object(["method": .string("item/tool/requestUserInput"), "id": .string("duplicate-questions"), "params": .object([
        "threadId": .string("two"), "turnId": .string("turn-1"), "questions": .array([
            .object(["id": .string("same"), "header": .string("One")]),
            .object(["id": .string("same"), "header": .string("Two")])
        ])
    ])]))
    try expect(mock.rejections.count == rejectedBefore + 1, "Duplicate question IDs were not rejected")
}
