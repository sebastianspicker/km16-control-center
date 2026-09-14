import Foundation
import KM16Integrations
import KM16ControlCore

func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw IntegrationError.message(message) }
}
func json(_ text: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)) }

@MainActor final class MockTransport: DeckTransport {
    var onMessage: ((JSONValue) -> Void)?
    var onClose: ((String) -> Void)?
    var calls: [(String, JSONValue)] = []
    var replies: [(JSONValue, JSONValue)] = []
    var rejections: [JSONValue] = []
    var closed = false
    var response: ((String, JSONValue) throws -> JSONValue)?
    var beforeResponse: ((String, JSONValue) -> Void)?
    func start(executable: String, directory: String) throws { closed = false }
    func stop() { closed = true }
    func notify(_ method: String, params: JSONValue) throws { calls.append((method, params)) }
    func request(_ method: String, params: JSONValue) async throws -> JSONValue {
        calls.append((method, params))
        beforeResponse?(method, params)
        if let response { return try response(method, params) }
        switch method {
        case "model/list": return try json(#"{"data":[{"id":"test-model","model":"test-model","displayName":"Test","supportedReasoningEfforts":[{"reasoningEffort":"low"}]}]}"#)
        case "thread/list": return try json(#"{"data":[{"id":"one","name":"First","cwd":"/tmp"},{"id":"two","name":"Second","cwd":"/tmp"},{"id":"foreign","cwd":"/private"}],"nextCursor":null}"#)
        case "thread/resume": return .object(["thread": .object(["id":params["threadId"],"cwd":.string("/tmp"),"turns":.array([])])])
        case "thread/start": return try json(#"{"thread":{"id":"new","name":"New","cwd":"/tmp"}}"#)
        case "turn/start": return try json(#"{"turn":{"id":"turn-1","status":"inProgress"}}"#)
        default: return .object([:])
        }
    }
    func respond(id: JSONValue, result: JSONValue) throws { replies.append((id,result)) }
    func reject(id: JSONValue, message: String) throws { rejections.append(id) }
}

@main enum IntegrationSelfTest {
    @MainActor static func main() async {
        do {
            if CommandLine.arguments.contains("--benchmark-deck") {
                try await benchmarkDeckUpdates()
                return
            }
            try framing(); try hid(); try console(); try capturedInputs(); try keyboardLayouts()
            try await codex(); try await approvalChecks(); try await processes(); try await processDescriptorChecks(); try await transportChecks(); try await obsProtocolChecks(); try await processGroupChecks()
            print("PASS: integration framing, HID replay, console, Codex lifecycle/events/requests and bounded process checks. No device, GUI input or live Codex connection used.")
        } catch { FileHandle.standardError.write(Data("FAIL: \(error.localizedDescription)\n".utf8)); exit(1) }
    }
    @MainActor static func keyboardLayouts() throws {
        for profile in Presets.all {
            for binding in profile.bindings where binding.action.kind == .shortcut {
                let spec = try ShortcutSpec.parse(binding.action.parameter)
                try expect(DesktopShortcutResolver.canResolve(spec), "Preset shortcut cannot resolve in this keyboard layout: \(profile.name) / \(binding.action.label) / \(binding.action.parameter)")
            }
        }
    }
    static func capturedInputs() throws {
        guard let index = CommandLine.arguments.firstIndex(of: "--capture-root"), CommandLine.arguments.indices.contains(index+1) else { return }
        let directory = URL(fileURLWithPath: CommandLine.arguments[index+1])
        let summary = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: directory.appendingPathComponent("knob-mapping-summary.json")))
        var count = 0
        let mapping = ["upper-left-cw":"encoder-0-cw", "upper-left-ccw":"encoder-0-ccw", "upper-right-cw":"encoder-1-cw", "upper-right-ccw":"encoder-1-ccw", "upper-right-click":"encoder-1-press", "bottom-cw":"encoder-2-cw", "bottom-ccw":"encoder-2-ccw"]
        for item in summary["tests"].array {
            guard let folder = item["evidence_directory"].string, let action = item["action"].string else { throw IntegrationError.message("Capture summary malformed") }
            let inputs = try CaptureReplay.controls(from: Data(contentsOf: directory.appendingPathComponent(folder).appendingPathComponent("composite.jsonl")))
            if case .number(let expected) = item["press_release_pairs"] { try expect(inputs.count == Int(expected), "Capture count mismatch: \(action)") }
            if let expectedID = mapping[action] { try expect(inputs.allSatisfy { $0.rawValue == expectedID }, "Capture control mismatch: \(action)") }
            else { try expect(inputs.isEmpty, "Host-invisible input was invented") }
            count += inputs.count
        }
        try expect(count == 18, "Historical capture total differs")
        print("PASS: nine historical knob captures replayed as 18 verified input events.")
    }
    static func framing() throws {
        var decoder = JSONLineDecoder(limit: 128)
        try expect(try decoder.append(Data("{\"id\":1".utf8)).isEmpty, "Partial frame decoded.")
        let frames = try decoder.append(Data("}\n{\"result\":true}\n".utf8))
        try expect(frames.count == 2, "Multiple frames lost.")
        do { _ = try decoder.append(Data(repeating: 65, count: 129)); throw IntegrationError.message("Oversized frame accepted.") } catch is DecodingError {} catch IntegrationError.message(let value) { try expect(value.contains("size limit"), "Unexpected overflow error") }
        var malformed = JSONLineDecoder()
        do { _ = try malformed.append(Data("{oops}\n".utf8)); throw IntegrationError.message("Malformed JSON accepted.") } catch is DecodingError {}
        // Every split, including a split inside a multibyte character, must preserve frames.
        let stream = Data("\n\"Grüße\"\n{\"n\":2}\r\n\n".utf8)
        let expected: [JSONValue] = [.string("Grüße"), .object(["n": .number(2)])]
        for split in 0...stream.count {
            var fragmented = JSONLineDecoder(limit: 16)
            let first = try fragmented.append(stream.prefix(split))
            let second = try fragmented.append(stream.suffix(stream.count - split))
            try expect(first + second == expected, "Frame changed at byte split \(split)")
        }
        var boundary = JSONLineDecoder(limit: 3)
        try expect(try boundary.append(Data("123\n456\n".utf8)) == [.number(123), .number(456)], "Limit incorrectly applied to the whole batch")
        _ = try boundary.append(Data("123".utf8))
        do { _ = try boundary.append(Data("4\n".utf8)); throw IntegrationError.message("Fragmented oversized frame accepted") }
        catch IntegrationError.message(let text) { try expect(text.contains("size limit"), "Unexpected fragmented overflow error") }
        try expect(JSONValue.string("1").idKey != JSONValue.number(1).idKey, "String/integer request IDs collided")
    }
    static func hid() throws {
        var decoder = StockHIDDecoder()
        var key = [UInt8](repeating:0,count:32); key[0] = 6; key[2 + 0x1e / 8] = 1 << (0x1e % 8)
        try expect(try decoder.decode(key) == [ControlID.keys[0]], "Captured top-left key mismatch")
        try expect(try decoder.decode(key).isEmpty, "Held key retriggered")
        _ = try decoder.decode([6] + Array(repeating:0,count:31))
        try expect(try decoder.decode(key).count == 1, "Release did not rearm input")
        try expect(try decoder.decode([4,0xb5,0]) == [ControlID.encoder(1,.clockwise)!], "Media knob mismatch")
        try expect(try decoder.decode([4,0xb5,0]).isEmpty, "Held consumer usage retriggered")
        _ = try decoder.decode([4,0,0])
        try expect(try decoder.decode([4,0xb5,0]).count == 1, "Consumer release did not rearm")
        do { _ = try decoder.decode(key,vendorID:0x1234); throw IntegrationError.message("Other keyboard accepted") } catch IntegrationError.message(let text) { try expect(text.contains("not from"), "VID rejection failed") }
        do { _ = try decoder.decode([6,0]); throw IntegrationError.message("Short NKRO accepted") } catch IntegrationError.message(let text) { try expect(text.contains("32 bytes"), "Length rejection failed") }
        let capture = Data("{\"hex\":\"04b500\"}\n{\"hex\":\"040000\"}\n{\"hex\":\"04b500\"}\n".utf8)
        try expect(try CaptureReplay.controls(from:capture).count == 2, "JSONL replay mismatch")
        do { _ = try CaptureReplay.controls(from:Data("{\"hex\":\"zz\"}".utf8)); throw IntegrationError.message("Bad capture accepted") } catch IntegrationError.message(let text) { try expect(text.contains("Invalid hex"), "Hex rejection failed") }
    }
    static func console() throws {
        var decoder = StockConsoleDecoder()
        let prefix = Array("first".utf8)
        try expect(try decoder.append(prefix + Array(repeating:0,count:32-prefix.count)).isEmpty, "Console prematurely emitted a line")
        let suffix = Array(" line\nsecond\n".utf8)
        try expect(try decoder.append(suffix + Array(repeating:0,count:32-suffix.count)) == ["first line","second"], "Console packet joining failed")
    }
    @MainActor static func codex() async throws {
        let mock = MockTransport(), client = CodexDeckClient(transport: MockTransport())
        client.workspacePath = "relative"
        do { try await client.connect(); throw IntegrationError.message("Relative workspace accepted") } catch IntegrationError.message(let text) { try expect(text.contains("workspace"), "Workspace validation failed") }
        let deck = CodexDeckClient(transport:mock); deck.workspacePath = "/tmp"
        try await deck.connect()
        try expect(mock.calls.prefix(2).map(\.0) == ["initialize","initialized"], "Initialization handshake order wrong")
        try expect(deck.threads.count == 2 && deck.models.count == 1, "Catalog/workspace filtering failed")
        let created = try await deck.perform(ControlAction(kind: .agentAction, label: "New task", parameter: "new-task"))
        try expect(created == "Created task New." && deck.selectedThreadID == "new", "New-task dispatch did not select the returned thread")
        try await deck.selectThread("one")
        deck.selectedModel = "test-model"; deck.selectedEffort = "low"
        try await deck.sendPrompt("Test prompt")
        try expect(deck.activeTurnID == "turn-1", "Turn start not tracked")
        try await deck.sendPrompt("Steer current task")
        try expect(mock.calls.last?.0 == "turn/steer" && mock.calls.last?.1["expectedTurnId"].string == "turn-1", "Steer did not address the active turn")
        mock.onMessage?(try json(#"{"method":"item/agentMessage/delta","params":{"threadId":"one","turnId":"turn-1","itemId":"m","delta":"hello"}}"#))
        try expect(deck.output == "hello", "Text delta lost")
        mock.onMessage?(try json(#"{"method":"turn/diff/updated","params":{"threadId":"one","turnId":"turn-1","diff":"--- a/test.swift\n+++ b/test.swift\n+one"}}"#))
        try expect(deck.changedFiles == ["test.swift"], "Changed file extraction failed")
        mock.onMessage?(try json(#"{"method":"item/agentMessage/delta","params":{"threadId":"one","turnId":"turn-1","itemId":"m","delta":""}}"#))
        try expect(deck.changedFiles == ["test.swift"], "Text update cleared changed files")
        let visibleDiff = deck.diff
        for method in ["turn/diff/updated", "turn/plan/updated", "item/agentMessage/delta", "item/completed"] {
            mock.onMessage?(.object(["method": .string(method), "params": .object([
                "threadId": .string("one"), "turnId": .string("stale-turn"),
                "diff": .string("unexpected"), "delta": .string("unexpected"),
                "plan": .array([.object(["step": .string("unexpected")])]),
                "item": .object(["type": .string("agentMessage"), "id": .string("stale-item"), "text": .string("unexpected")])
            ])]))
            try expect(deck.output == "hello" && deck.diff == visibleDiff && deck.plan.isEmpty, "Stale turn changed the selected thread through \(method)")
        }
        mock.onMessage?(try json(#"{"method":"item/commandExecution/requestApproval","id":17,"params":{"threadId":"one","turnId":"turn-1","command":"echo test","availableDecisions":["accept","decline"]}}"#))
        try expect(deck.requests.count == 1, "Approval request missing")
        do { try deck.respond(to:deck.requests[0].id,decision:"acceptForSession"); throw IntegrationError.message("Persistent approval accepted") } catch IntegrationError.message(let text) { try expect(text.contains("unsupported"), "Decision restriction failed") }
        let approval = deck.requests[0].id
        try deck.respond(to:approval,decision:"decline")
        try expect(mock.replies.last?.0 == .number(17), "Approval ID was not preserved")
        do { try deck.respond(to:approval,decision:"accept"); throw IntegrationError.message("Stale approval accepted") } catch IntegrationError.message(let text) { try expect(text.contains("stale"), "Stale approval rejection failed") }
        mock.onMessage?(try json(#"{"method":"item/tool/requestUserInput","id":"question","params":{"threadId":"one","turnId":"turn-1","questions":[{"id":"q","header":"Choice","question":"Which?","options":[{"label":"One"}]}]}}"#))
        try deck.answer(requestID:deck.requests[0].id,answers:["q":["One"]])
        try expect(mock.replies.last?.1["answers"]["q"]["answers"].array == [.string("One")], "Question response shape wrong")
        mock.onMessage?(try json(#"{"method":"unknown/request","id":99,"params":{}}"#))
        try expect(mock.rejections.last == .number(99), "Unknown server request not rejected")
        try await deck.selectThread("two")
        try expect(deck.diff.isEmpty && deck.changedFiles.isEmpty, "Thread switch retained another thread's changed files")
        mock.onMessage?(try json(#"{"method":"item/agentMessage/delta","params":{"threadId":"one","turnId":"turn-1","itemId":"m","delta":" hidden"}}"#))
        try expect(deck.output.isEmpty, "Background thread contaminated selected output")
        mock.onMessage?(try json(#"{"method":"turn/completed","params":{"threadId":"one","turn":{"id":"turn-1","status":"completed"}}}"#))
        mock.beforeResponse = { method, _ in
            if method == "turn/start" {
                mock.onMessage?(try! json(#"{"method":"turn/completed","params":{"threadId":"two","turn":{"id":"turn-1","status":"completed"}}}"#))
            }
        }
        try await deck.sendPrompt("Immediate completion")
        try expect(deck.activeTurnID == nil, "Late start response resurrected a completed turn")
        deck.disconnect()
        try expect(mock.closed && !deck.isConnected && deck.requests.isEmpty, "Disconnect did not clear live state")
    }
    @MainActor static func processes() async throws {
        let runner = BoundedProcessRunner()
        let result = try await runner.run(executable:"/usr/bin/printf",arguments:["%s","literal $(not-a-command)"],directory:nil,timeout:2)
        try expect(result.status == 0 && result.output == "literal $(not-a-command)", "Literal argv/output handling failed")
        do { _ = try await runner.run(executable:"/bin/sleep",arguments:["2"],directory:nil,timeout:0.05); throw IntegrationError.message("Timeout not enforced") } catch IntegrationError.message(let text) { try expect(text.contains("timed out"), "Unexpected timeout error") }
        let failed = try await runner.run(executable:"/usr/bin/false",arguments:[],directory:nil,timeout:2)
        try expect(failed.status != 0, "Nonzero exit lost")
    }
}
