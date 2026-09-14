import Foundation
import Darwin

@MainActor
public protocol DeckTransport: AnyObject {
    var onMessage: ((JSONValue) -> Void)? { get set }
    var onClose: ((String) -> Void)? { get set }
    func start(executable: String, directory: String) throws
    func request(_ method: String, params: JSONValue) async throws -> JSONValue
    func notify(_ method: String, params: JSONValue) throws
    func respond(id: JSONValue, result: JSONValue) throws
    func reject(id: JSONValue, message: String) throws
    func stop()
}

@MainActor
public final class CodexRPCTransport: DeckTransport {
    public var onMessage: ((JSONValue) -> Void)?
    public var onClose: ((String) -> Void)?
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var errorOutput: FileHandle?
    private var decoder = JSONLineDecoder()
    private var nextID = 0
    private var generation = UUID()
    private struct PendingRequest {
        let continuation: CheckedContinuation<JSONValue, Error>
        let timeout: Task<Void, Never>
    }
    private var pending: [String: PendingRequest] = [:]
    private let arguments: [String]
    private let requestTimeout: Duration
    private let writer = DispatchQueue(label: "km16.codex.writer")
    private var readerTask: Task<Void, Never>?
    public init(arguments: [String] = ["app-server", "--listen", "stdio://"], requestTimeout: Duration = .seconds(30)) {
        self.arguments = arguments; self.requestTimeout = requestTimeout
    }

    public func start(executable: String, directory: String) throws {
        stop()
        guard executable.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: executable) else { throw IntegrationError.message("Codex executable must be an installed absolute path.") }
        let task = Process(), stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        task.currentDirectoryURL = URL(fileURLWithPath: directory)
        task.standardInput = stdin; task.standardOutput = stdout; task.standardError = stderr
        let token = UUID(); generation = token; decoder = JSONLineDecoder()
        input = stdin.fileHandleForWriting; output = stdout.fileHandleForReading; errorOutput = stderr.fileHandleForReading
        let (stream, continuation) = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingOldest(64))
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { continuation.finish(); return }
            if case .dropped = continuation.yield(data) { continuation.finish() }
        }
        readerTask = Task { [weak self] in
            for await data in stream {
                guard let self, self.generation == token else { return }
                do { for message in try self.decoder.append(data) { self.receive(message) } }
                catch { self.fail(error.localizedDescription); return }
            }
            guard let self, self.generation == token else { return }
            self.fail("Codex stream closed or exceeded the pending-input limit.")
        }
        // Drain stderr without collecting potentially sensitive account/configuration diagnostics.
        stderr.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }
        task.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.fail("Codex exited (\(status)).")
            }
        }
        process = task
        do { try task.run() } catch { stop(); throw error }
    }
    public func request(_ method: String, params: JSONValue) async throws -> JSONValue {
        try Task.checkCancellation()
        guard pending.count < 64 else { throw IntegrationError.message("Too many pending Codex requests.") }
        nextID += 1
        let id = JSONValue.number(Double(nextID)), key = id.idKey!
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timeout = Task { [weak self, requestTimeout] in
                    do { try await Task.sleep(for: requestTimeout) } catch { return }
                    self?.complete(key, with: .failure(IntegrationError.message("Codex request timed out: \(method).")))
                }
                pending[key] = PendingRequest(continuation: continuation, timeout: timeout)
                do { try send(.object(["id": id, "method": .string(method), "params": params])) }
                catch { complete(key, with: .failure(error)) }
            }
        } onCancel: { Task { @MainActor [weak self] in self?.complete(key, with: .failure(CancellationError())) } }
    }
    public func notify(_ method: String, params: JSONValue) throws { try send(.object(["method": .string(method), "params": params])) }
    public func respond(id: JSONValue, result: JSONValue) throws { try send(.object(["id": id, "result": result])) }
    public func reject(id: JSONValue, message: String) throws { try send(.object(["id": id, "error": .object(["code": .number(-32601), "message": .string(message)])])) }
    private func send(_ message: JSONValue) throws {
        guard let input, process?.isRunning == true else { throw IntegrationError.message("Connect to Codex first.") }
        var data = try JSONEncoder().encode(message); data.append(10)
        guard data.count <= 2_000_000 else { throw IntegrationError.message("Outgoing Codex request is too large.") }
        let bytes = data, token = generation
        writer.async { [weak self] in
            do { try input.write(contentsOf: bytes) }
            catch {
                let message = error.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.fail("Codex write failed: \(message)")
                }
            }
        }
    }
    private func receive(_ message: JSONValue) {
        if message["method"].string != nil { onMessage?(message); return }
        guard let key = message["id"].idKey else { return }
        if message["error"] != .null { complete(key, with: .failure(IntegrationError.message(message["error"]["message"].string ?? "Codex request failed."))) }
        else { complete(key, with: .success(message["result"])) }
    }
    private func complete(_ key: String, with result: Result<JSONValue, Error>) {
        guard let request = pending.removeValue(forKey: key) else { return }
        request.timeout.cancel()
        request.continuation.resume(with: result)
    }
    private func fail(_ reason: String) { stop(); onClose?(reason) }
    public func stop() {
        generation = UUID()
        readerTask?.cancel(); readerTask = nil
        output?.readabilityHandler = nil; errorOutput?.readabilityHandler = nil
        try? input?.close(); try? output?.close(); try? errorOutput?.close()
        input = nil; output = nil; errorOutput = nil
        if let task = process, task.isRunning {
            task.terminate()
            Task { try? await Task.sleep(for: .seconds(1)); if task.isRunning { kill(task.processIdentifier, SIGKILL) } }
        }
        process = nil
        let requests = pending; pending.removeAll()
        for request in requests.values {
            request.timeout.cancel()
            request.continuation.resume(throwing: IntegrationError.message("Codex connection closed."))
        }
    }
}
