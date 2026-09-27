import Foundation
import Testing
@testable import KM16Integrations
import KM16ControlCore

@MainActor
@Suite struct CodexDeckClientTests {
    @Test func fullCodexLifecycleEventsAndRequestsBehaveCorrectly() async throws {
        let mock = MockTransport(), client = CodexDeckClient(transport: MockTransport())
        client.workspacePath = "relative"
        await #expect(performing: { try await client.connect() }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("workspace")
        })
        let deck = CodexDeckClient(transport: mock); deck.workspacePath = "/tmp"
        try await deck.connect()
        #expect(mock.calls.prefix(2).map(\.0) == ["initialize", "initialized"], "Initialization handshake order wrong")
        #expect(deck.threads.count == 2 && deck.models.count == 1, "Catalog/workspace filtering failed")
        let created = try await deck.perform(ControlAction(kind: .agentAction, label: "New task", parameter: "new-task"))
        #expect(created == "Created task New." && deck.selectedThreadID == "new", "New-task dispatch did not select the returned thread")
        try await deck.selectThread("one")
        deck.selectedModel = "test-model"; deck.selectedEffort = "low"
        try await deck.sendPrompt("Test prompt")
        #expect(deck.activeTurnID == "turn-1", "Turn start not tracked")
        try await deck.sendPrompt("Steer current task")
        #expect(mock.calls.last?.0 == "turn/steer" && mock.calls.last?.1["expectedTurnId"].string == "turn-1", "Steer did not address the active turn")
        mock.onMessage?(try json(#"{"method":"item/agentMessage/delta","params":{"threadId":"one","turnId":"turn-1","itemId":"m","delta":"hello"}}"#))
        #expect(deck.output == "hello", "Text delta lost")
        mock.onMessage?(try json(#"{"method":"turn/diff/updated","params":{"threadId":"one","turnId":"turn-1","diff":"--- a/test.swift\n+++ b/test.swift\n+one"}}"#))
        #expect(deck.changedFiles == ["test.swift"], "Changed file extraction failed")
        mock.onMessage?(try json(#"{"method":"item/agentMessage/delta","params":{"threadId":"one","turnId":"turn-1","itemId":"m","delta":""}}"#))
        #expect(deck.changedFiles == ["test.swift"], "Text update cleared changed files")
        let visibleDiff = deck.diff
        for method in ["turn/diff/updated", "turn/plan/updated", "item/agentMessage/delta", "item/completed"] {
            mock.onMessage?(.object(["method": .string(method), "params": .object([
                "threadId": .string("one"), "turnId": .string("stale-turn"),
                "diff": .string("unexpected"), "delta": .string("unexpected"),
                "plan": .array([.object(["step": .string("unexpected")])]),
                "item": .object(["type": .string("agentMessage"), "id": .string("stale-item"), "text": .string("unexpected")])
            ])]))
            #expect(deck.output == "hello" && deck.diff == visibleDiff && deck.plan.isEmpty, "Stale turn changed the selected thread through \(method)")
        }
        mock.onMessage?(try json(#"{"method":"item/commandExecution/requestApproval","id":17,"params":{"threadId":"one","turnId":"turn-1","command":"echo test","availableDecisions":["accept","decline"]}}"#))
        #expect(deck.requests.count == 1, "Approval request missing")
        #expect(performing: { try deck.respond(to: deck.requests[0].id, decision: "acceptForSession") }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("unsupported")
        })
        let approval = deck.requests[0].id
        try deck.respond(to: approval, decision: "decline")
        #expect(mock.replies.last?.0 == .number(17), "Approval ID was not preserved")
        #expect(performing: { try deck.respond(to: approval, decision: "accept") }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("stale")
        })
        mock.onMessage?(try json(#"{"method":"item/tool/requestUserInput","id":"question","params":{"threadId":"one","turnId":"turn-1","questions":[{"id":"q","header":"Choice","question":"Which?","options":[{"label":"One"}]}]}}"#))
        try deck.answer(requestID: deck.requests[0].id, answers: ["q": ["One"]])
        #expect(mock.replies.last?.1["answers"]["q"]["answers"].array == [.string("One")], "Question response shape wrong")
        mock.onMessage?(try json(#"{"method":"unknown/request","id":99,"params":{}}"#))
        #expect(mock.rejections.last == .number(99), "Unknown server request not rejected")
        try await deck.selectThread("two")
        #expect(deck.diff.isEmpty && deck.changedFiles.isEmpty, "Thread switch retained another thread's changed files")
        mock.onMessage?(try json(#"{"method":"item/agentMessage/delta","params":{"threadId":"one","turnId":"turn-1","itemId":"m","delta":" hidden"}}"#))
        #expect(deck.output.isEmpty, "Background thread contaminated selected output")
        mock.onMessage?(try json(#"{"method":"turn/completed","params":{"threadId":"one","turn":{"id":"turn-1","status":"completed"}}}"#))
        mock.beforeResponse = { method, _ in
            if method == "turn/start" {
                mock.onMessage?(try! json(#"{"method":"turn/completed","params":{"threadId":"two","turn":{"id":"turn-1","status":"completed"}}}"#))
            }
        }
        try await deck.sendPrompt("Immediate completion")
        #expect(deck.activeTurnID == nil, "Late start response resurrected a completed turn")
        deck.disconnect()
        #expect(mock.closed && !deck.isConnected && deck.requests.isEmpty, "Disconnect did not clear live state")
    }
}
