import Foundation
import Testing
@testable import KM16Integrations
import KM16ControlCore

/// Measures the real client event path and raw frame decoding. Enabled only when explicitly
/// requested: `KM16_BENCHMARK=1 swift test --filter Benchmark`.
@Suite("Benchmark", .enabled(if: ProcessInfo.processInfo.environment["KM16_BENCHMARK"] == "1"))
struct BenchmarkTests {
    @MainActor
    @Test func deckClientEventPath() async throws {
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
            #expect(client.output == String(repeating: "x", count: (iteration + 1) * 100), "Benchmark transcript changed")
            #expect(client.changedFiles == ["test.swift"] && client.diff == diff, "Benchmark diff changed")
        }
        print("Deck: 100 text deltas with a \(diff.utf8.count)-byte diff; one warmup, seven runs (ms): \(samples)")
        print("median ms: \(samples.sorted()[samples.count / 2])")
        client.disconnect()
    }

    @Test func jsonLineDecoderThroughput() throws {
        let payload = String(repeating: "x", count: 262_144)
        let frame = Data(("\"" + payload + "\"\n").utf8)
        let fragmented = stride(from: 0, to: frame.count, by: 64).map {
            frame.subdata(in: $0..<min($0 + 64, frame.count))
        }
        try measure("262144-byte string, 64-byte chunks", chunks: fragmented, expected: [.string(payload)])
        try measure("262144-byte string, single chunk", chunks: [frame], expected: [.string(payload)])
        try measure("4096 small frames, single chunk", chunks: [Data(String(repeating: "123\n", count: 4096).utf8)], expected: Array(repeating: .number(123), count: 4096))
    }

    private func measure(_ label: String, chunks: [Data], expected: [JSONValue]) throws {
        var samples: [Double] = []
        for iteration in 0..<8 {
            var decoder = JSONLineDecoder()
            let start = ContinuousClock.now
            var output: [JSONValue] = []
            for chunk in chunks { output += try decoder.append(chunk) }
            let elapsed = start.duration(to: .now).components
            #expect(output == expected, "Decoded output changed")
            if iteration > 0 { samples.append(Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15) }
        }
        print("\(label), one warmup, seven runs (ms): \(samples)")
        print("median ms: \(samples.sorted()[samples.count / 2])")
    }
}
