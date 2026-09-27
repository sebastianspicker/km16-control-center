import Foundation
import Darwin
import Testing
@testable import KM16Integrations
import KM16ControlCore

// These suites spawn real subprocesses and depend on timing; run them serialized.
@MainActor
@Suite(.serialized) struct ProcessAndTransportTests {
    @Test func literalArgumentsAreNeverInterpretedByAShellAndTimeoutsAndExitCodesAreEnforced() async throws {
        let runner = BoundedProcessRunner()
        let result = try await runner.run(executable: "/usr/bin/printf", arguments: ["%s", "literal $(not-a-command)"], directory: nil, timeout: 2)
        #expect(result.status == 0 && result.output == "literal $(not-a-command)", "Literal argv/output handling failed")
        await #expect(performing: {
            try await runner.run(executable: "/bin/sleep", arguments: ["2"], directory: nil, timeout: 0.05)
        }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("timed out")
        })
        let failed = try await runner.run(executable: "/usr/bin/false", arguments: [], directory: nil, timeout: 2)
        #expect(failed.status != 0, "Nonzero exit lost")
    }

    @Test func childCommandsDoNotInheritUnrelatedParentFileDescriptors() async throws {
        // Deliberately omit CLOEXEC on a harmless parent descriptor to detect inheritance.
        let descriptor = open("/dev/null", O_RDONLY)
        guard descriptor >= 0 else {
            Issue.record("Could not open descriptor fixture")
            return
        }
        defer { close(descriptor) }
        let program = "import errno,os,sys\ntry: os.fstat(int(sys.argv[1]))\nexcept OSError as error: sys.exit(0 if error.errno == errno.EBADF else 1)\nelse: sys.exit(99)"
        let result = try await BoundedProcessRunner().run(executable: "/usr/bin/python3", arguments: ["-c", program, String(descriptor)], directory: nil, timeout: 2)
        #expect(result.status == 0, "Child inherited an unrelated parent file descriptor")
    }

    @Test func realPipeFramingCorrelationTimeoutDisconnectAndReconnectAgainstALocalFixtureProcess() async throws {
        // A local fixture process exercises actual pipes, framing and request correlation.
        // It never reads user configuration, starts Codex or opens a network connection.
        let fixture = #"""
        import sys, json
        for line in sys.stdin:
            message = json.loads(line)
            method = message.get('method')
            if method == 'hang':
                continue
            if method == 'disconnect':
                sys.exit(3)
            if 'id' in message:
                data = {'id':message['id'], 'result': {'method': method}}
                encoded = json.dumps(data)
                sys.stdout.write(encoded[:5]); sys.stdout.flush()
                sys.stdout.write(encoded[5:]+'\n'); sys.stdout.flush()
        """#
        let transport = CodexRPCTransport(arguments: ["-u", "-c", fixture], requestTimeout: .milliseconds(200))
        try transport.start(executable: "/usr/bin/python3", directory: "/tmp")
        defer { transport.stop() }
        async let first = transport.request("first", params: .object([:]))
        async let second = transport.request("second", params: .object([:]))
        let responses = try await [first, second]
        #expect(responses.map { $0["method"].string } == ["first", "second"], "Pipe responses correlated to wrong requests")
        await #expect(performing: {
            try await transport.request("hang", params: .object([:]))
        }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("timed out")
        })
        await #expect(performing: {
            try await transport.request("disconnect", params: .object([:]))
        }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("closed")
        })
        try transport.start(executable: "/usr/bin/python3", directory: "/tmp")
        let reconnected = try await transport.request("again", params: .object([:]))
        #expect(reconnected["method"].string == "again", "RPC reconnect failed")
        // Cancellation before entry must never send a command to the fixture.
        let cancelled = Task { try await transport.request("disconnect", params: .object([:])) }
        cancelled.cancel()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        let stillConnected = try await transport.request("still-connected", params: .object([:]))
        #expect(stillConnected["method"].string == "still-connected", "Cancelled RPC was sent")
        let hanging = Task { try await transport.request("hang", params: .object([:])) }
        try await Task.sleep(for: .milliseconds(20))
        hanging.cancel()
        await #expect(throws: CancellationError.self) { try await hanging.value }
        try await Task.sleep(for: .milliseconds(220))
        _ = try await transport.request("after-cancellation", params: .object([:]))
    }

    @Test func cancellingALauncherAlsoStopsItsChildProcessGroup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("km16-group-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pidFile = directory.appendingPathComponent("child.pid")
        let heartbeat = directory.appendingPathComponent("heartbeat")
        let childProgram = "import sys,time\nfor i in range(2000):\n with open(sys.argv[1],'w') as f: f.write(str(i))\n time.sleep(0.01)"
        let program = "import subprocess,sys,time; p=subprocess.Popen([sys.executable,'-c',sys.argv[3],sys.argv[2]]); open(sys.argv[1],'w').write(str(p.pid)); time.sleep(20)"
        let runner = BoundedProcessRunner()
        let task = Task { try await runner.run(executable: "/usr/bin/python3", arguments: ["-c", program, pidFile.path, heartbeat.path, childProgram], directory: nil, timeout: 5) }
        var recordedPID: Int32?
        for _ in 0..<100 {
            if let text = try? String(contentsOf: pidFile, encoding: .utf8), let parsed = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) { recordedPID = parsed; break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard let child = recordedPID else {
            runner.cancel(); _ = try? await task.value
            Issue.record("Fixture did not record its child PID")
            return
        }
        // Always clean up our fixture even if a regression leaves it running.
        defer { kill(child, SIGKILL) }
        var progressed = false
        for _ in 0..<100 {
            if let text = try? String(contentsOf: heartbeat, encoding: .utf8), let tick = Int(text), tick >= 2 { progressed = true; break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard progressed else {
            runner.cancel(); _ = try? await task.value
            Issue.record("Fixture child did not produce a heartbeat")
            return
        }
        runner.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        // Check the owned child's observable work without requiring system-wide process
        // inspection. A killed child awaiting reaping cannot advance this heartbeat.
        let stoppedHeartbeat = try String(contentsOf: heartbeat, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(250))
        #expect(try String(contentsOf: heartbeat, encoding: .utf8) == stoppedHeartbeat, "Cancellation left a child process running")
    }
}
