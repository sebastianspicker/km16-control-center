// From the repository root:
// swiftc -O apps/KM16ControlCenter/Sources/KM16Integrations/JSONValue.swift scripts/benchmarks/JSONLineBenchmark.swift -o /tmp/km16-json-bench
import Foundation

@main enum JSONLineBenchmark {
    static func main() throws {
        let payload = String(repeating: "x", count: 262_144)
        let frame = Data(("\"" + payload + "\"\n").utf8)
        let fragmented = stride(from: 0, to: frame.count, by: 64).map {
            frame.subdata(in: $0..<min($0 + 64, frame.count))
        }
        try measure("262144-byte string, 64-byte chunks", chunks: fragmented, expected: [.string(payload)])
        try measure("262144-byte string, single chunk", chunks: [frame], expected: [.string(payload)])
        try measure("4096 small frames, single chunk", chunks: [Data(String(repeating: "123\n", count: 4096).utf8)], expected: Array(repeating: .number(123), count: 4096))
    }

    static func measure(_ label: String, chunks: [Data], expected: [JSONValue]) throws {
        var samples: [Double] = []
        for iteration in 0..<8 {
            var decoder = JSONLineDecoder()
            let start = ContinuousClock.now
            var output: [JSONValue] = []
            for chunk in chunks { output += try decoder.append(chunk) }
            let elapsed = start.duration(to: .now).components
            guard output == expected else { fatalError("Decoded output changed") }
            if iteration > 0 { samples.append(Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15) }
        }
        print("\(label), one warmup, seven runs (ms): \(samples)")
        print("median ms: \(samples.sorted()[samples.count / 2])")
    }
}
