import Foundation
import Testing
@testable import KM16Integrations
import KM16ControlCore

@Suite struct CaptureReplayTests {
    static var captureRoot: URL {
        if let overridden = ProcessInfo.processInfo.environment["KM16_CAPTURE_ROOT"], !overridden.isEmpty {
            return URL(fileURLWithPath: overridden, isDirectory: true)
        }
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repositoryRoot.appending(path: "evidence/captures", directoryHint: .isDirectory)
    }
    static var summaryURL: URL { captureRoot.appendingPathComponent("knob-mapping-summary.json") }

    // Enabled only when private capture evidence is present on this machine; not a public fixture.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: CaptureReplayTests.summaryURL.path)))
    func nineHistoricalKnobCapturesReplayAsEighteenVerifiedInputEvents() throws {
        let directory = Self.captureRoot
        let summary = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: Self.summaryURL))
        var count = 0
        let mapping = [
            "upper-left-cw": "encoder-0-cw", "upper-left-ccw": "encoder-0-ccw",
            "upper-right-cw": "encoder-1-cw", "upper-right-ccw": "encoder-1-ccw", "upper-right-click": "encoder-1-press",
            "bottom-cw": "encoder-2-cw", "bottom-ccw": "encoder-2-ccw"
        ]
        for item in summary["tests"].array {
            let folder = try #require(item["evidence_directory"].string, "Capture summary malformed")
            let action = try #require(item["action"].string, "Capture summary malformed")
            let inputs = try CaptureReplay.controls(from: Data(contentsOf: directory.appendingPathComponent(folder).appendingPathComponent("composite.jsonl")))
            if case .number(let expected) = item["press_release_pairs"] {
                #expect(inputs.count == Int(expected), "Capture count mismatch: \(action)")
            }
            if let expectedID = mapping[action] {
                #expect(inputs.allSatisfy { $0.rawValue == expectedID }, "Capture control mismatch: \(action)")
            } else {
                #expect(inputs.isEmpty, "Host-invisible input was invented")
            }
            count += inputs.count
        }
        #expect(count == 18, "Historical capture total differs")
    }
}
