import Foundation
import Darwin
import KM16ProcessSupport

/// Pipe callbacks may run off the main actor; all retained output and EOF state are locked.
final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var ended = false
    private let limit: Int
    init(limit: Int = 65_536) { self.limit = limit }
    func append(_ bytes: Data) {
        lock.lock(); defer { lock.unlock() }
        if bytes.isEmpty { ended = true }
        data.append(bytes); if data.count > limit { data.removeFirst(data.count - limit) }
    }
    var text: String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
    var isFinished: Bool { lock.lock(); defer { lock.unlock() }; return ended }
}

public struct ProcessResult: Sendable {
    public let status: Int32
    public let output: String
}

@MainActor
public final class BoundedProcessRunner {
    private var pid: pid_t?
    private var cancelled = false
    public init() {}
    public func cancel() { cancelled = true; if let pid { kill(-pid, SIGTERM) } }
    public func run(executable: String, arguments: [String], directory: String?, timeout: Double) async throws -> ProcessResult {
        guard pid == nil else { throw IntegrationError.message("A command is already running.") }
        guard executable.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: executable) else { throw IntegrationError.message("Choose an executable using an absolute path.") }
        guard timeout.isFinite, timeout > 0, timeout <= 3600 else { throw IntegrationError.message("Timeout must be between 0 and 3600 seconds.") }
        guard ([executable] + arguments + [directory ?? ""]).allSatisfy({ !$0.utf8.contains(0) }) else { throw IntegrationError.message("Process arguments cannot contain NUL characters.") }
        let pipe = Pipe(), buffer = OutputBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in buffer.append(handle.availableData) }
        let strings = ([executable] + arguments).map { strdup($0) }
        defer { strings.forEach { free($0) } }
        var argv = strings + [nil], child: pid_t = 0
        let code = argv.withUnsafeMutableBufferPointer { args in
            if let directory { return km16_spawn_group(executable, args.baseAddress, directory, pipe.fileHandleForWriting.fileDescriptor, &child) }
            return km16_spawn_group(executable, args.baseAddress, nil, pipe.fileHandleForWriting.fileDescriptor, &child)
        }
        try? pipe.fileHandleForWriting.close()
        guard code == 0 else {
            pipe.fileHandleForReading.readabilityHandler = nil
            throw IntegrationError.message("Could not start command (\(code)): \(String(cString: strerror(code))).")
        }
        pid = child; cancelled = false
        defer {
            // Command ownership includes its process group, including background children.
            kill(-child, SIGKILL)
            pipe.fileHandleForReading.readabilityHandler = nil
            try? pipe.fileHandleForReading.close(); pid = nil
        }
        let start = Date()
        var deadline: Date?, status: Int32 = 0
        while true {
            if Task.isCancelled { cancelled = true }
            if cancelled || Date().timeIntervalSince(start) >= timeout {
                if deadline == nil { kill(-child, SIGTERM); deadline = Date().addingTimeInterval(1) }
                if let deadline, Date() >= deadline { kill(-child, SIGKILL) }
            }
            let result = waitpid(child, &status, WNOHANG)
            if result == child { break }
            if result < 0 && errno != EINTR { throw IntegrationError.message("Could not collect command status.") }
            try? await Task.sleep(for: .milliseconds(20))
        }
        kill(-child, SIGKILL)
        for _ in 0..<25 {
            if buffer.isFinished { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        if cancelled { throw CancellationError() }
        if deadline != nil { throw IntegrationError.message("Command timed out after \(timeout) seconds.") }
        let exitStatus = status & 0x7f == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
        return ProcessResult(status: exitStatus, output: buffer.text)
    }
}
