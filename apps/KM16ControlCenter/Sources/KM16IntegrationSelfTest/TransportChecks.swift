import Foundation
import Darwin
import KM16Integrations

@MainActor
func transportChecks() async throws {
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
    let transport = CodexRPCTransport(arguments:["-u", "-c", fixture], requestTimeout:.milliseconds(200))
    try transport.start(executable:"/usr/bin/python3",directory:"/tmp")
    defer { transport.stop() }
    async let first = transport.request("first",params:.object([:]))
    async let second = transport.request("second",params:.object([:]))
    let responses = try await [first, second]
    try expect(responses.map { $0["method"].string } == ["first","second"], "Pipe responses correlated to wrong requests")
    do { _ = try await transport.request("hang",params:.object([:])); throw IntegrationError.message("RPC timeout not enforced") }
    catch IntegrationError.message(let text) { try expect(text.contains("timed out"), "Unexpected RPC timeout error") }
    do { _ = try await transport.request("disconnect",params:.object([:])); throw IntegrationError.message("Disconnected RPC succeeded") }
    catch IntegrationError.message(let text) { try expect(text.contains("closed"), "Pending RPC did not fail on close") }
    try transport.start(executable:"/usr/bin/python3",directory:"/tmp")
    let reconnected = try await transport.request("again",params:.object([:]))
    try expect(reconnected["method"].string == "again", "RPC reconnect failed")
    // Cancellation before entry must never send a command to the fixture.
    let cancelled = Task { try await transport.request("disconnect", params: .object([:])) }
    cancelled.cancel()
    do { _ = try await cancelled.value; throw IntegrationError.message("Cancelled RPC succeeded") }
    catch is CancellationError {}
    let stillConnected = try await transport.request("still-connected", params: .object([:]))
    try expect(stillConnected["method"].string == "still-connected", "Cancelled RPC was sent")
    let hanging = Task { try await transport.request("hang", params: .object([:])) }
    try await Task.sleep(for: .milliseconds(20))
    hanging.cancel()
    do { _ = try await hanging.value; throw IntegrationError.message("Pending cancelled RPC succeeded") }
    catch is CancellationError {}
    try await Task.sleep(for: .milliseconds(220))
    _ = try await transport.request("after-cancellation", params: .object([:]))
    print("PASS: real pipe framing/correlation, timeout, disconnect and reconnect against a local fixture process.")
}

@MainActor
func processDescriptorChecks() async throws {
    // Deliberately omit CLOEXEC on a harmless parent descriptor to detect inheritance.
    let descriptor = open("/dev/null", O_RDONLY)
    guard descriptor >= 0 else { throw IntegrationError.message("Could not open descriptor fixture") }
    defer { close(descriptor) }
    let program = "import errno,os,sys\ntry: os.fstat(int(sys.argv[1]))\nexcept OSError as error: sys.exit(0 if error.errno == errno.EBADF else 1)\nelse: sys.exit(99)"
    let result = try await BoundedProcessRunner().run(executable: "/usr/bin/python3", arguments: ["-c", program, String(descriptor)], directory: nil, timeout: 2)
    try expect(result.status == 0, "Child inherited an unrelated parent file descriptor")
    print("PASS: child commands do not inherit unrelated parent file descriptors.")
}

@MainActor
func processGroupChecks() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("km16-group-" + UUID().uuidString)
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:directory) }
    let pidFile = directory.appendingPathComponent("child.pid")
    let heartbeat = directory.appendingPathComponent("heartbeat")
    let childProgram = "import sys,time\nfor i in range(2000):\n with open(sys.argv[1],'w') as f: f.write(str(i))\n time.sleep(0.01)"
    let program = "import subprocess,sys,time; p=subprocess.Popen([sys.executable,'-c',sys.argv[3],sys.argv[2]]); open(sys.argv[1],'w').write(str(p.pid)); time.sleep(20)"
    let runner = BoundedProcessRunner()
    let task = Task { try await runner.run(executable:"/usr/bin/python3",arguments:["-c",program,pidFile.path,heartbeat.path,childProgram],directory:nil,timeout:5) }
    var recordedPID: Int32?
    for _ in 0..<100 {
        if let text = try? String(contentsOf:pidFile,encoding:.utf8), let parsed = Int32(text.trimmingCharacters(in:.whitespacesAndNewlines)) { recordedPID = parsed; break }
        try await Task.sleep(for:.milliseconds(10))
    }
    guard let child = recordedPID else { runner.cancel(); _ = try? await task.value; throw IntegrationError.message("Fixture did not record its child PID") }
    // Always clean up our fixture even if a regression leaves it running.
    defer { kill(child, SIGKILL) }
    var progressed = false
    for _ in 0..<100 {
        if let text = try? String(contentsOf: heartbeat, encoding: .utf8), let tick = Int(text), tick >= 2 { progressed = true; break }
        try await Task.sleep(for: .milliseconds(10))
    }
    guard progressed else { runner.cancel(); _ = try? await task.value; throw IntegrationError.message("Fixture child did not produce a heartbeat") }
    runner.cancel()
    do { _ = try await task.value; throw IntegrationError.message("Cancelled process succeeded") } catch is CancellationError {}
    // Check the owned child's observable work without requiring system-wide process
    // inspection. A killed child awaiting reaping cannot advance this heartbeat.
    let stoppedHeartbeat = try String(contentsOf: heartbeat, encoding: .utf8)
    try await Task.sleep(for: .milliseconds(250))
    try expect(try String(contentsOf: heartbeat, encoding: .utf8) == stoppedHeartbeat, "Cancellation left a child process running")
    print("PASS: cancelling a launcher also stops its child process group.")
}
