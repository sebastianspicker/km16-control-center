import Foundation
@testable import KM16Integrations
import KM16ControlCore

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
