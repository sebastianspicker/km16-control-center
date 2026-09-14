import Foundation

public struct DeckThread: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let cwd: String
    init?(_ json: JSONValue) {
        guard let id = json["id"].string else { return nil }
        self.id = id
        self.title = String((json["name"].string ?? json["preview"].string ?? id).prefix(160))
        self.cwd = json["cwd"].string ?? ""
    }
}
public struct DeckModel: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let efforts: [String]
    init?(_ json: JSONValue) {
        guard let id = json["model"].string ?? json["id"].string else { return nil }
        self.id = id; name = json["displayName"].string ?? id
        efforts = json["supportedReasoningEfforts"].array.compactMap { $0["reasoningEffort"].string }
    }
}
public struct DeckQuestion: Identifiable, Sendable {
    public let id: String
    public let header: String
    public let question: String
    public let options: [String]
    public let isSecret: Bool
    init?(_ value: JSONValue) {
        guard let id = value["id"].string, !id.isEmpty else { return nil }
        self.id = id; header = value["header"].string ?? "Question"
        question = value["question"].string ?? ""
        options = value["options"].array.compactMap { $0["label"].string }
        isSecret = value["isSecret"] == .bool(true)
    }
}
public struct DeckRequest: Identifiable, Sendable {
    public let id: String
    public let method: String
    public let summary: String
    public let questions: [DeckQuestion]
    public let threadID: String
    public let turnID: String
    public let decisions: [String]
    public internal(set) var approval: DeckApproval?
    let wireID: JSONValue
    init?(_ message: JSONValue) {
        guard let id = message["id"].idKey, let method = message["method"].string else { return nil }
        self.id = id; self.method = method; wireID = message["id"]
        let p = message["params"]
        threadID = p["threadId"].string ?? ""; turnID = p["turnId"].string ?? ""
        let rawQuestions = p["questions"].array
        let parsedQuestions = rawQuestions.compactMap(DeckQuestion.init)
        guard rawQuestions.count == parsedQuestions.count,
              Set(parsedQuestions.map(\.id)).count == parsedQuestions.count else { return nil }
        questions = parsedQuestions
        let data = try? JSONEncoder().encode(p)
        summary = method == "item/tool/requestUserInput"
            ? String(String(decoding: data ?? Data(), as: UTF8.self).prefix(16_384))
            : ""
        let supplied = p["availableDecisions"].array.compactMap(\.string)
        decisions = supplied.isEmpty ? ["accept", "decline", "cancel"] : supplied.filter { ["accept", "decline", "cancel"].contains($0) }
        approval = nil
    }
}
struct DeckSnapshot {
    var output = ""
    var diff = ""
    var plan = ""
    var turnID: String?
    var state = "Ready"
    var messages: [String: String] = [:]
    var completedTurns = Set<String>()
}
