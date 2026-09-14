import Foundation

public indirect enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let x = try? c.decode(Bool.self) { self = .bool(x) }
        else if let x = try? c.decode(Double.self) { self = .number(x) }
        else if let x = try? c.decode(String.self) { self = .string(x) }
        else if let x = try? c.decode([JSONValue].self) { self = .array(x) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let x): try c.encode(x)
        case .array(let x): try c.encode(x)
        case .string(let x): try c.encode(x)
        case .number(let x): try c.encode(x)
        case .bool(let x): try c.encode(x)
        case .null: try c.encodeNil()
        }
    }
    public subscript(_ key: String) -> JSONValue {
        guard case .object(let x) = self else { return .null }; return x[key] ?? .null
    }
    public var string: String? { if case .string(let x) = self { return x }; return nil }
    public var array: [JSONValue] { if case .array(let x) = self { return x }; return [] }
    public var object: [String: JSONValue] { if case .object(let x) = self { return x }; return [:] }
    public var idKey: String? {
        switch self { case .string(let x): return "s:" + x; case .number(let x): return "n:\(x)"; default: return nil }
    }
}

public enum IntegrationError: Error, LocalizedError, Sendable {
    case message(String)
    public var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}

/// Newline-delimited protocol framing. A single oversized/malformed frame fails the connection.
public struct JSONLineDecoder: Sendable {
    private var buffer = Data()
    public let limit: Int
    public init(limit: Int = 2_000_000) { self.limit = limit }
    public mutating func append(_ data: Data) throws -> [JSONValue] {
        guard limit >= 0 else { throw IntegrationError.message("App-server frame exceeds the size limit.") }
        var messages: [JSONValue] = []
        let decoder = JSONDecoder()
        var cursor = data.startIndex
        while cursor < data.endIndex {
            // Search only new bytes. Rescanning the partial frame makes fragmented input quadratic.
            let newline = data[cursor...].firstIndex(of: 10)
            let end = newline ?? data.endIndex
            guard end - cursor <= limit - buffer.count else {
                throw IntegrationError.message("App-server frame exceeds the size limit.")
            }
            if buffer.isEmpty { buffer = data[cursor..<end] }
            else { buffer.append(data[cursor..<end]) }
            guard let newline else { break }
            if !buffer.isEmpty { messages.append(try decoder.decode(JSONValue.self, from: buffer)) }
            buffer = Data()
            cursor = newline + 1
        }
        return messages
    }
}
