import Foundation
import Observation
import KM16ControlCore

@MainActor @Observable
public final class CodexDeckClient {
    public var executablePath = "/opt/homebrew/bin/codex"
    public var workspacePath = ""
    public var selectedModel = ""
    public var selectedEffort = ""
    public internal(set) var state = "Disconnected"
    public internal(set) var isConnected = false
    public internal(set) var threads: [DeckThread] = []
    public var selectedThreadID: String?
    public internal(set) var models: [DeckModel] = []
    public internal(set) var output = ""
    public internal(set) var diff = ""
    public internal(set) var plan = ""
    public internal(set) var activeTurnID: String?
    public internal(set) var requests: [DeckRequest] = []
    public internal(set) var changedFiles: [String] = []
    public var selectedFileIndex = 0
    public internal(set) var diffRevealCounter = 0
    public internal(set) var lastError: String?
    public var outputScrollOffset = 0
    @ObservationIgnored let transport: any DeckTransport
    @ObservationIgnored var snapshots: [String: DeckSnapshot] = [:]
    @ObservationIgnored var epoch = UUID()
    @ObservationIgnored var connectedWorkspace = ""
    @ObservationIgnored var busy = false
    @ObservationIgnored var approvalSources: [String: DeckApprovalSource] = [:]
    @ObservationIgnored var approvalEvidence: [DeckApprovalKey: DeckApprovalEvidence] = [:]
    @ObservationIgnored var approvalEvidenceOrder: [DeckApprovalKey] = []
    @ObservationIgnored var presentedApprovalEvidence: [String: String] = [:]

    public init(transport: (any DeckTransport)? = nil) {
        self.transport = transport ?? CodexRPCTransport()
        self.transport.onMessage = { [weak self] message in self?.receive(message) }
        self.transport.onClose = { [weak self] reason in
            guard let self else { return }
            self.epoch = UUID(); self.isConnected = false; self.state = "Disconnected"
            self.activeTurnID = nil; self.requests.removeAll(); self.clearApprovalState(); self.lastError = reason
        }
    }
    public func connect() async throws {
        guard !isConnected, state != "Connecting" else { return }
        var isDirectory: ObjCBool = false
        guard workspacePath.hasPrefix("/"), FileManager.default.fileExists(atPath: workspacePath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw IntegrationError.message("Choose an existing workspace folder before connecting.")
        }
        state = "Connecting"; lastError = nil
        let token = UUID(); epoch = token
        do {
            connectedWorkspace = URL(fileURLWithPath: workspacePath).standardizedFileURL.path
            try transport.start(executable: executablePath, directory: connectedWorkspace)
            _ = try await transport.request("initialize", params: .object([
                "clientInfo": .object(["name": .string("km16_control_center"), "title": .string("KM16 Control Center"), "version": .string("0.2.0")]),
                "capabilities": .object(["experimentalApi": .bool(false)])
            ]))
            guard epoch == token else { throw CancellationError() }
            try transport.notify("initialized", params: .object([:]))
            isConnected = true; state = "Connected"
            let result = try await transport.request("model/list", params: .object([:]))
            guard epoch == token else { throw CancellationError() }
            models = result["data"].array.compactMap(DeckModel.init)
            if !selectedModel.isEmpty && !models.contains(where: { $0.id == selectedModel }) { selectedModel = ""; selectedEffort = "" }
            try await refreshThreads()
        } catch {
            if epoch == token { disconnect(); lastError = error.localizedDescription }
            throw error
        }
    }
    public func disconnect() {
        epoch = UUID(); transport.stop(); isConnected = false; state = "Disconnected"
        requests.removeAll(); clearApprovalState(); activeTurnID = nil; selectedThreadID = nil
        threads.removeAll(); snapshots.removeAll(); output = ""; diff = ""; plan = ""; changedFiles = []; busy = false
    }
    public func refreshThreads() async throws {
        try requireConnection()
        let token = epoch
        var found: [DeckThread] = [], cursor: String?, seen = Set<String>()
        repeat {
            var params: [String: JSONValue] = ["limit": .number(100), "cwd": .string(connectedWorkspace), "archived": .bool(false)]
            if let cursor { params["cursor"] = .string(cursor) }
            let result = try await transport.request("thread/list", params: .object(params))
            guard token == epoch else { throw CancellationError() }
            found += result["data"].array.compactMap(DeckThread.init).filter { $0.cwd == connectedWorkspace }
            cursor = result["nextCursor"].string
            if let cursor, !seen.insert(cursor).inserted { throw IntegrationError.message("Codex repeated a pagination cursor.") }
            guard found.count <= 10_000 else { throw IntegrationError.message("Too many threads in this workspace.") }
        } while cursor != nil
        var unique = Set<String>(); threads = found.filter { unique.insert($0.id).inserted }
    }
    public func selectThread(_ id: String) async throws {
        try requireConnection()
        guard !busy else { throw IntegrationError.message("Wait for the current Codex request.") }
        guard threads.contains(where: { $0.id == id && $0.cwd == connectedWorkspace }) else { throw IntegrationError.message("Select a thread from the connected workspace.") }
        busy = true; defer { busy = false }
        let token = epoch
        let result = try await transport.request("thread/resume", params: .object(["threadId": .string(id)]))
        guard token == epoch else { throw CancellationError() }
        let thread = result["thread"]
        guard thread["id"].string == id else { throw IntegrationError.message("Codex resumed an unexpected thread.") }
        selectedThreadID = id
        hydrate(thread)
        publish(id); refreshApprovals()
    }
    public func sendPrompt(_ text: String) async throws {
        try requireConnection()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 100_000 else { throw IntegrationError.message("Enter a prompt up to 100 KB.") }
        guard !busy else { throw IntegrationError.message("Wait for the current Codex request.") }
        guard let id = selectedThreadID, snapshots[id] != nil else { throw IntegrationError.message("Create or open a thread before sending a prompt.") }
        busy = true; defer { busy = false }
        let token = epoch, input = JSONValue.array([.object(["type": .string("text"), "text": .string(text), "text_elements": .array([])])])
        if let turn = snapshots[id]?.turnID {
            _ = try await transport.request("turn/steer", params: .object(["threadId": .string(id), "expectedTurnId": .string(turn), "input": input]))
        } else {
            var params: [String: JSONValue] = ["threadId": .string(id), "input": input]
            try addModelOptions(to: &params)
            let result = try await transport.request("turn/start", params: .object(params))
            guard token == epoch else { throw CancellationError() }
            let turn = result["turn"]
            if turn["status"].string == "inProgress", let turnID = turn["id"].string, snapshots[id]?.completedTurns.contains(turnID) != true {
                snapshots[id, default: DeckSnapshot()].turnID = turn["id"].string
                snapshots[id, default: DeckSnapshot()].state = "Running"
            }
        }
        guard token == epoch else { throw CancellationError() }
        publish(id)
    }
    func requireConnection() throws {
        guard isConnected else { throw IntegrationError.message("Connect to Codex first.") }
        guard URL(fileURLWithPath: workspacePath).standardizedFileURL.path == connectedWorkspace else { throw IntegrationError.message("Reconnect after changing the workspace.") }
    }
    func addModelOptions(to params: inout [String: JSONValue]) throws {
        if !selectedModel.isEmpty {
            guard let model = models.first(where: { $0.id == selectedModel }) else { throw IntegrationError.message("Choose a model returned by this server.") }
            params["model"] = .string(selectedModel)
            if !selectedEffort.isEmpty {
                guard model.efforts.contains(selectedEffort) else { throw IntegrationError.message("This model does not support the selected effort.") }
                params["effort"] = .string(selectedEffort)
            }
        } else if !selectedEffort.isEmpty { throw IntegrationError.message("Choose a model before selecting effort.") }
    }
}
