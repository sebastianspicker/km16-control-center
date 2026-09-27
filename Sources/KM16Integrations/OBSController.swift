import CryptoKit
import Darwin
import Foundation
import Observation
import KM16ControlCore

@MainActor @Observable
public final class OBSController {
    public var hostURL: String {
        didSet { persist(hostURL, key: Self.hostURLKey) }
    }
    public var microphoneSource: String {
        didSet { persist(microphoneSource, key: Self.microphoneSourceKey) }
    }
    public var playbackSource: String {
        didSet { persist(playbackSource, key: Self.playbackSourceKey) }
    }
    /// Retained only by this controller for the lifetime of the app process.
    public var password = ""
    public private(set) var isRunning = false
    public private(set) var status = "Idle"

    @ObservationIgnored private let transportFactory: (URL) -> any OBSWebSocketTransport
    @ObservationIgnored private let defaults: UserDefaults?

    private static let hostURLKey = "KM16.obs.hostURL"
    private static let microphoneSourceKey = "KM16.obs.microphoneSource"
    private static let playbackSourceKey = "KM16.obs.playbackSource"

    public init() {
        let defaults = UserDefaults.standard
        hostURL = defaults.string(forKey: Self.hostURLKey) ?? "ws://localhost:4455"
        microphoneSource = defaults.string(forKey: Self.microphoneSourceKey) ?? ""
        playbackSource = defaults.string(forKey: Self.playbackSourceKey) ?? ""
        self.defaults = defaults
        transportFactory = { URLSessionOBSTransport(url: $0) }
    }

    public func perform(_ operation: OBSOperation) async throws -> String {
        guard !isRunning else { throw IntegrationError.message("An OBS action is already running.") }
        let url = try Self.validatedURL(hostURL)
        let microphoneSource = try validatedSource(microphoneSource, for: operation, matching: [.microphoneDown, .microphoneUp, .microphoneMute], label: "microphone")
        let playbackSource = try validatedSource(playbackSource, for: operation, matching: [.playbackDown, .playbackUp, .playbackMute], label: "playback")

        isRunning = true
        status = "Running \(operation.rawValue)…"
        defer { isRunning = false }

        let transport = transportFactory(url)
        transport.start()
        defer { transport.close() }

        do {
            let session = OBSProtocolSession(transport: transport)
            try await session.identify(password: password)
            let message = try await OBSActionExecutor(
                session: session,
                microphoneSource: microphoneSource,
                playbackSource: playbackSource
            ).perform(operation)
            status = message
            return message
        } catch {
            status = "Failed: \(error.localizedDescription)"
            throw error
        }
    }

    private func persist(_ value: String, key: String) {
        defaults?.set(value, forKey: key)
    }

    private func validatedSource(
        _ source: String,
        for operation: OBSOperation,
        matching operations: Set<OBSOperation>,
        label: String
    ) throws -> String {
        guard operations.contains(operation) else { return source }
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 512, !value.utf8.contains(0) else {
            throw IntegrationError.message("Configure an OBS \(label) source before using this action.")
        }
        return value
    }

    fileprivate static func validatedURL(_ source: String) throws -> URL {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= 2_048 else {
            throw IntegrationError.message("Enter an OBS WebSocket host URL.")
        }
        let candidate = value.contains("://") ? value : "ws://\(value)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(), ["ws", "wss"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              let url = components.url else {
            throw IntegrationError.message("Use a ws:// or wss:// OBS WebSocket URL without credentials, a query, or a fragment.")
        }
        guard scheme == "wss" || isLoopback(host) else {
            throw IntegrationError.message("Remote OBS connections require wss:// with TLS. Use ws:// only for localhost or a loopback address.")
        }
        return url
    }

    private static func isLoopback(_ host: String) -> Bool {
        let host = host.lowercased()
        if host == "localhost" || host == "localhost." { return true }
        let address = host.hasPrefix("[") && host.hasSuffix("]") ? String(host.dropFirst().dropLast()) : host
        var ipv4 = in_addr(), ipv6 = in6_addr()
        if address.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
            return withUnsafeBytes(of: ipv4) { $0.first == 127 }
        }
        if address.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
            return withUnsafeBytes(of: ipv6) { $0.dropLast().allSatisfy { $0 == 0 } && $0.last == 1 }
        }
        return false
    }
}

@MainActor
private struct OBSActionExecutor {
    let session: OBSProtocolSession
    let microphoneSource: String
    let playbackSource: String

    private static let simpleCommands: [OBSOperation: (request: String, message: String)] = [
        .startRecording: ("StartRecord", "Started OBS recording."),
        .stopRecording: ("StopRecord", "Stopped OBS recording."),
        .pauseRecording: ("PauseRecord", "Paused OBS recording."),
        .resumeRecording: ("ResumeRecord", "Resumed OBS recording."),
        .saveReplay: ("SaveReplayBuffer", "Saved the OBS replay buffer."),
        .transition: ("TriggerStudioModeTransition", "Triggered the OBS Studio Mode transition.")
    ]

    func perform(_ operation: OBSOperation) async throws -> String {
        if let number = operation.sceneNumber {
            return try await selectScene(number: number)
        }
        if let command = Self.simpleCommands[operation] {
            _ = try await session.request(command.request)
            return command.message
        }
        switch operation {
        case .toggleStudioMode:
            let response = try await session.request("GetStudioModeEnabled")
            guard let enabled = response["studioModeEnabled"].bool else {
                throw IntegrationError.message("OBS did not return its Studio Mode state.")
            }
            _ = try await session.request("SetStudioModeEnabled", data: ["studioModeEnabled": .bool(!enabled)])
            return enabled ? "Disabled OBS Studio Mode." : "Enabled OBS Studio Mode."
        case .microphoneDown:
            return try await changeVolume(source: microphoneSource, delta: -0.05, label: "microphone")
        case .microphoneUp:
            return try await changeVolume(source: microphoneSource, delta: 0.05, label: "microphone")
        case .microphoneMute:
            return try await toggleMute(source: microphoneSource, label: "microphone")
        case .playbackDown:
            return try await changeVolume(source: playbackSource, delta: -0.05, label: "playback")
        case .playbackUp:
            return try await changeVolume(source: playbackSource, delta: 0.05, label: "playback")
        case .playbackMute:
            return try await toggleMute(source: playbackSource, label: "playback")
        case .previousScene:
            return try await selectScene(offset: -1)
        case .nextScene:
            return try await selectScene(offset: 1)
        default:
            throw IntegrationError.message("Invalid OBS scene operation.")
        }
    }

    private func selectScene(number: Int? = nil, offset: Int = 0) async throws -> String {
        let response = try await session.request("GetSceneList")
        let scenes = try sceneNames(from: response)
        let index: Int
        if let number {
            guard scenes.indices.contains(number - 1) else {
                throw IntegrationError.message("OBS does not have scene \(number) in the current collection.")
            }
            index = number - 1
        } else {
            guard let current = response["currentProgramSceneName"].string,
                  let currentIndex = scenes.firstIndex(of: current) else {
                throw IntegrationError.message("OBS did not report a current scene from its scene list.")
            }
            index = (currentIndex + offset + scenes.count) % scenes.count
        }
        let name = scenes[index]
        _ = try await session.request("SetCurrentProgramScene", data: ["sceneName": .string(name)])
        return "Switched OBS to \(name)."
    }

    private func sceneNames(from response: JSONValue) throws -> [String] {
        let rawScenes = response["scenes"].array
        let names = rawScenes.compactMap { $0["sceneName"].string }
        guard !names.isEmpty, names.count == rawScenes.count else {
            throw IntegrationError.message("OBS returned a malformed or empty scene list.")
        }
        // OBS WebSocket scene arrays use bottom-to-top order; present scene slots in UI order.
        return Array(names.reversed())
    }

    private func changeVolume(source: String, delta: Double, label: String) async throws -> String {
        let response = try await session.request("GetInputVolume", data: ["inputName": .string(source)])
        guard let current = response["inputVolumeMul"].number, current.isFinite else {
            throw IntegrationError.message("OBS did not return a valid volume for the \(label) source.")
        }
        let updated = min(1, max(0, current + delta))
        _ = try await session.request("SetInputVolume", data: [
            "inputName": .string(source),
            "inputVolumeMul": .number(updated)
        ])
        return "Set OBS \(label) volume to \(Int((updated * 100).rounded()))%."
    }

    private func toggleMute(source: String, label: String) async throws -> String {
        _ = try await session.request("ToggleInputMute", data: ["inputName": .string(source)])
        return "Toggled OBS \(label) mute."
    }
}

@MainActor
private protocol OBSWebSocketTransport: AnyObject {
    func start()
    func send(_ text: String) async throws
    func receive() async throws -> String
    func close()
}

@MainActor
private final class URLSessionOBSTransport: OBSWebSocketTransport {
    private let url: URL
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private let timeout: Duration = .seconds(5)
    private let messageLimit = 2_000_000

    init(url: URL) { self.url = url }

    func start() {
        guard task == nil else { return }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration, delegate: OBSRedirectBlocker(), delegateQueue: nil)
        let task = session.webSocketTask(with: url, protocols: ["obswebsocket.json"])
        task.maximumMessageSize = messageLimit
        self.session = session
        self.task = task
        task.resume()
    }

    func send(_ text: String) async throws {
        guard let task else { throw IntegrationError.message("The OBS WebSocket is not open.") }
        guard text.utf8.count <= messageLimit else { throw IntegrationError.message("The OBS request exceeds the size limit.") }
        try await withTimeout(task: task) { try await task.send(.string(text)) }
    }

    func receive() async throws -> String {
        guard let task else { throw IntegrationError.message("The OBS WebSocket is not open.") }
        let message = try await withTimeout(task: task) { try await task.receive() }
        switch message {
        case .string(let text):
            guard text.utf8.count <= messageLimit else { throw IntegrationError.message("The OBS response exceeds the size limit.") }
            return text
        case .data(let data):
            guard data.count <= messageLimit, let text = String(data: data, encoding: .utf8) else {
                throw IntegrationError.message("OBS returned an invalid or oversized message.")
            }
            return text
        @unknown default:
            throw IntegrationError.message("OBS returned an unsupported WebSocket message.")
        }
    }

    func close() {
        task?.cancel(with: .normalClosure, reason: nil)
        session?.finishTasksAndInvalidate()
        task = nil
        session = nil
    }

    private func withTimeout<T: Sendable>(
        task: URLSessionWebSocketTask,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask { [timeout] in
                try await Task.sleep(for: timeout)
                task.cancel(with: .goingAway, reason: nil)
                throw IntegrationError.message("The OBS WebSocket request timed out.")
            }
            guard let result = try await group.next() else {
                throw IntegrationError.message("The OBS WebSocket request did not complete.")
            }
            group.cancelAll()
            return result
        }
    }
}

/// Keep authentication and commands bound to the exact endpoint reviewed in settings.
private final class OBSRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
private final class OBSProtocolSession {
    private let transport: any OBSWebSocketTransport
    private let requestID: () -> String
    private var identified = false

    init(transport: any OBSWebSocketTransport, requestID: @escaping () -> String = { UUID().uuidString }) {
        self.transport = transport
        self.requestID = requestID
    }

    func identify(password: String) async throws {
        guard !identified else { throw IntegrationError.message("The OBS WebSocket session is already identified.") }
        let hello = try await receiveJSON()
        guard hello["op"].integer == 0, let serverRPC = hello["d"]["rpcVersion"].integer, serverRPC >= 1 else {
            throw IntegrationError.message("OBS did not send a compatible WebSocket v5 Hello message.")
        }
        var identifyData: [String: JSONValue] = ["rpcVersion": .number(1), "eventSubscriptions": .number(0)]
        let authentication = hello["d"]["authentication"]
        if authentication != .null {
            guard let challenge = authentication["challenge"].string,
                  let salt = authentication["salt"].string else {
                throw IntegrationError.message("OBS sent a malformed authentication challenge.")
            }
            guard !password.isEmpty else { throw IntegrationError.message("OBS requires a WebSocket password.") }
            identifyData["authentication"] = .string(Self.authentication(password: password, salt: salt, challenge: challenge))
        }
        try await sendJSON(.object(["op": .number(1), "d": .object(identifyData)]))
        let response = try await receiveJSON()
        guard response["op"].integer == 2, response["d"]["negotiatedRpcVersion"].integer == 1 else {
            throw IntegrationError.message("OBS did not accept the WebSocket v5 session.")
        }
        identified = true
    }

    func request(_ type: String, data: [String: JSONValue] = [:]) async throws -> JSONValue {
        guard identified else { throw IntegrationError.message("The OBS WebSocket session is not identified.") }
        let id = requestID()
        var request: [String: JSONValue] = [
            "requestType": .string(type),
            "requestId": .string(id)
        ]
        if !data.isEmpty { request["requestData"] = .object(data) }
        try await sendJSON(.object(["op": .number(6), "d": .object(request)]))

        let response = try await receiveJSON()
        guard response["op"].integer == 7 else { throw IntegrationError.message("OBS returned an unexpected message instead of a request response.") }
        let payload = response["d"]
        guard payload["requestId"].string == id, payload["requestType"].string == type else {
            throw IntegrationError.message("OBS returned a response for a different request.")
        }
        let requestStatus = payload["requestStatus"]
        guard requestStatus["result"].bool == true, requestStatus["code"].integer == 100 else {
            let code = requestStatus["code"].integer.map(String.init) ?? "unknown"
            let comment = requestStatus["comment"].string.map { ": \($0)" } ?? ""
            throw IntegrationError.message("OBS request \(type) failed (\(code))\(comment).")
        }
        let responseData = payload["responseData"]
        return responseData == .null ? .object([:]) : responseData
    }

    static func authentication(password: String, salt: String, challenge: String) -> String {
        let secret = Data(SHA256.hash(data: Data((password + salt).utf8))).base64EncodedString()
        return Data(SHA256.hash(data: Data((secret + challenge).utf8))).base64EncodedString()
    }

    private func sendJSON(_ value: JSONValue) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        try await transport.send(String(decoding: data, as: UTF8.self))
    }

    private func receiveJSON() async throws -> JSONValue {
        let text = try await transport.receive()
        guard let data = text.data(using: .utf8) else { throw IntegrationError.message("OBS returned non-UTF-8 JSON.") }
        do { return try JSONDecoder().decode(JSONValue.self, from: data) }
        catch { throw IntegrationError.message("OBS returned malformed JSON.") }
    }
}

public enum OBSProtocolSelfTest {
    @MainActor public static func run() async throws {
        for endpoint in ["ws://localhost:4455", "ws://LOCALHOST.:4455", "ws://127.0.0.1:4455", "ws://127.2.3.4:4455", "ws://[::1]:4455", "ws://[0:0:0:0:0:0:0:1]:4455", "wss://obs.example:4455"] {
            _ = try OBSController.validatedURL(endpoint)
        }
        for endpoint in ["ws://obs.example:4455", "ws://localhost.example:4455", "ws://192.168.1.2:4455", "ws://[::2]:4455", "ws://[::ffff:192.168.1.2]:4455", "ws://127.0.0.1@obs.example:4455"] {
            do {
                _ = try OBSController.validatedURL(endpoint)
                throw IntegrationError.message("OBS accepted an insecure remote endpoint: \(endpoint)")
            } catch IntegrationError.message(let message) where message.contains("require wss") || message.contains("without credentials") {}
        }
        let expectedAuthentication = "1Ct943GAT+6YQUUX47Ia/ncufilbe6+oD6lY+5kaCu4="
        guard OBSProtocolSession.authentication(
            password: "supersecretpassword",
            salt: "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI=",
            challenge: "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY="
        ) == expectedAuthentication else {
            throw IntegrationError.message("OBS authentication fixture failed.")
        }

        let fixture = OBSFixtureTransport(incoming: [
            #"{"op":0,"d":{"rpcVersion":1,"authentication":{"challenge":"+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=","salt":"lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI="}}}"#,
            #"{"op":2,"d":{"negotiatedRpcVersion":1}}"#,
            #"{"op":7,"d":{"requestType":"GetSceneList","requestId":"fixture-1","requestStatus":{"result":true,"code":100},"responseData":{"currentProgramSceneName":"Second","scenes":[{"sceneName":"Third"},{"sceneName":"Second"},{"sceneName":"First"}]}}}"#,
            #"{"op":7,"d":{"requestType":"SetCurrentProgramScene","requestId":"fixture-2","requestStatus":{"result":true,"code":100}}}"#,
            #"{"op":7,"d":{"requestType":"GetInputVolume","requestId":"fixture-3","requestStatus":{"result":true,"code":100},"responseData":{"inputVolumeMul":0.98}}}"#,
            #"{"op":7,"d":{"requestType":"SetInputVolume","requestId":"fixture-4","requestStatus":{"result":true,"code":100}}}"#,
            #"{"op":7,"d":{"requestType":"GetStudioModeEnabled","requestId":"fixture-5","requestStatus":{"result":true,"code":100},"responseData":{"studioModeEnabled":false}}}"#,
            #"{"op":7,"d":{"requestType":"SetStudioModeEnabled","requestId":"fixture-6","requestStatus":{"result":true,"code":100}}}"#
        ])
        var nextID = 0
        let session = OBSProtocolSession(transport: fixture) {
            nextID += 1
            return "fixture-\(nextID)"
        }
        fixture.start()
        try await session.identify(password: "supersecretpassword")
        let executor = OBSActionExecutor(session: session, microphoneSource: "Mic/Aux", playbackSource: "Desktop Audio")
        guard try await executor.perform(.previousScene) == "Switched OBS to First." else {
            throw IntegrationError.message("OBS scene navigation fixture failed.")
        }
        guard try await executor.perform(.microphoneUp) == "Set OBS microphone volume to 100%." else {
            throw IntegrationError.message("OBS volume fixture failed.")
        }
        guard try await executor.perform(.toggleStudioMode) == "Enabled OBS Studio Mode." else {
            throw IntegrationError.message("OBS Studio Mode fixture failed.")
        }
        guard fixture.sent.count == 7,
              try decoded(fixture.sent[0])["d"]["authentication"].string == expectedAuthentication,
              try decoded(fixture.sent[2])["d"]["requestData"]["sceneName"].string == "First",
              try decoded(fixture.sent[4])["d"]["requestData"]["inputVolumeMul"].number == 1,
              try decoded(fixture.sent[6])["d"]["requestData"]["studioModeEnabled"].bool == true else {
            throw IntegrationError.message("OBS request encoding fixture failed.")
        }

        for (id, response, expectedError) in [
            ("expected", #"{"op":7,"d":{"requestType":"StartRecord","requestId":"wrong","requestStatus":{"result":true,"code":100}}}"#, ["different request"]),
            ("failed", #"{"op":7,"d":{"requestType":"StartRecord","requestId":"failed","requestStatus":{"result":false,"code":501,"comment":"Output is already running."}}}"#, ["501", "already running"])
        ] {
            let transport = OBSFixtureTransport(incoming: [
                #"{"op":0,"d":{"rpcVersion":1}}"#,
                #"{"op":2,"d":{"negotiatedRpcVersion":1}}"#,
                response
            ])
            let session = OBSProtocolSession(transport: transport, requestID: { id })
            transport.start()
            try await session.identify(password: "")
            do {
                _ = try await session.request("StartRecord")
                throw IntegrationError.message("OBS accepted an invalid request response.")
            } catch IntegrationError.message(let message) where expectedError.allSatisfy(message.contains) {}
        }
    }

    private static func decoded(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }
}

@MainActor
private final class OBSFixtureTransport: OBSWebSocketTransport {
    private var incoming: [String]
    private(set) var sent: [String] = []
    private var started = false

    init(incoming: [String]) { self.incoming = incoming }
    func start() { started = true }
    func send(_ text: String) async throws {
        guard started else { throw IntegrationError.message("OBS fixture was not started.") }
        sent.append(text)
    }
    func receive() async throws -> String {
        guard started, !incoming.isEmpty else { throw IntegrationError.message("OBS fixture has no response.") }
        return incoming.removeFirst()
    }
    func close() { started = false }
}

private extension JSONValue {
    var integer: Int? {
        guard case .number(let value) = self else { return nil }
        return Int(exactly: value)
    }
    var number: Double? { if case .number(let value) = self { return value }; return nil }
    var bool: Bool? { if case .bool(let value) = self { return value }; return nil }
}
