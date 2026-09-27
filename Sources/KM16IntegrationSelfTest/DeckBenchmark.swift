import Foundation
import KM16Integrations

/// Measures the real client event path using the same local transport as the integration checks.
@MainActor
func benchmarkDeckUpdates() async throws {
    let mock = MockTransport()
    let client = CodexDeckClient(transport: mock)
    client.workspacePath = "/tmp"
    try await client.connect()
    try await client.selectThread("one")
    try await client.sendPrompt("Fixture")
    let diff = "--- a/test.swift\n+++ b/test.swift\n" + String(repeating: "+changed line\n", count: 20_000)
    mock.onMessage?(.object(["method": .string("turn/diff/updated"), "params": .object([
        "threadId": .string("one"), "turnId": .string("turn-1"), "diff": .string(diff)
    ])]))
    let delta: JSONValue = .object(["method": .string("item/agentMessage/delta"), "params": .object([
        "threadId": .string("one"), "turnId": .string("turn-1"), "itemId": .string("m"), "delta": .string("x")
    ])])
    var samples: [Double] = []
    for iteration in 0..<8 {
        let start = ContinuousClock.now
        for _ in 0..<100 { mock.onMessage?(delta) }
        let elapsed = start.duration(to: .now).components
        if iteration > 0 { samples.append(Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15) }
        try expect(client.output == String(repeating: "x", count: (iteration + 1) * 100), "Benchmark transcript changed")
        try expect(client.changedFiles == ["test.swift"] && client.diff == diff, "Benchmark diff changed")
    }
    print("Deck: 100 text deltas with a \(diff.utf8.count)-byte diff; one warmup, seven runs (ms): \(samples)")
    print("median ms: \(samples.sorted()[samples.count / 2])")
    client.disconnect()
}
