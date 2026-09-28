import Foundation
import Testing
@testable import KM16Integrations
import KM16ControlCore

@Suite struct FramingTests {
    @Test func partialAndMultipleFramesAreDecodedCorrectly() throws {
        var decoder = JSONLineDecoder(limit: 128)
        #expect(try decoder.append(Data("{\"id\":1".utf8)).isEmpty, "Partial frame decoded.")
        let frames = try decoder.append(Data("}\n{\"result\":true}\n".utf8))
        #expect(frames.count == 2, "Multiple frames lost.")
    }

    @Test func oversizedFrameIsRejected() throws {
        var decoder = JSONLineDecoder(limit: 128)
        #expect(performing: {
            try decoder.append(Data(repeating: 65, count: 129))
        }, throws: { error in
            if error is DecodingError { return true }
            guard case IntegrationError.message(let value) = error else { return false }
            return value.contains("size limit")
        })
    }

    @Test func malformedJSONIsRejected() throws {
        var malformed = JSONLineDecoder()
        #expect(throws: DecodingError.self) { try malformed.append(Data("{oops}\n".utf8)) }
    }

    @Test func everyByteSplitIncludingInsideAMultibyteCharacterPreservesFrames() throws {
        // Every split, including a split inside a multibyte character, must preserve frames.
        let stream = Data("\n\"Grüße\"\n{\"n\":2}\r\n\n".utf8)
        let expected: [JSONValue] = [.string("Grüße"), .object(["n": .number(2)])]
        for split in 0...stream.count {
            var fragmented = JSONLineDecoder(limit: 16)
            let first = try fragmented.append(stream.prefix(split))
            let second = try fragmented.append(stream.suffix(stream.count - split))
            #expect(first + second == expected, "Frame changed at byte split \(split)")
        }
    }

    @Test func sizeLimitAppliesPerFrameNotPerBatch() throws {
        var boundary = JSONLineDecoder(limit: 3)
        #expect(try boundary.append(Data("123\n456\n".utf8)) == [.number(123), .number(456)], "Limit incorrectly applied to the whole batch")
        _ = try boundary.append(Data("123".utf8))
        #expect(performing: {
            try boundary.append(Data("4\n".utf8))
        }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("size limit")
        })
    }

    @Test func stringAndIntegerRequestIDsDoNotCollide() {
        #expect(JSONValue.string("1").idKey != JSONValue.number(1).idKey, "String/integer request IDs collided")
    }
}

@Suite struct HIDDecoderTests {
    @Test func topLeftKeyIsDecodedAndDoesNotRetriggerWhileHeld() throws {
        var decoder = StockHIDDecoder()
        var key = [UInt8](repeating: 0, count: 32); key[0] = 6; key[2 + 0x1e / 8] = 1 << (0x1e % 8)
        #expect(try decoder.decode(key) == [ControlID.keys[0]], "Captured top-left key mismatch")
        #expect(try decoder.decode(key).isEmpty, "Held key retriggered")
        _ = try decoder.decode([6] + Array(repeating: 0, count: 31))
        #expect(try decoder.decode(key).count == 1, "Release did not rearm input")
    }

    @Test func mediaKnobIsDecodedAndDoesNotRetriggerWhileHeld() throws {
        var decoder = StockHIDDecoder()
        #expect(try decoder.decode([4, 0xb5, 0]) == [ControlID.encoder(1, .clockwise)!], "Media knob mismatch")
        #expect(try decoder.decode([4, 0xb5, 0]).isEmpty, "Held consumer usage retriggered")
        _ = try decoder.decode([4, 0, 0])
        #expect(try decoder.decode([4, 0xb5, 0]).count == 1, "Consumer release did not rearm")
    }

    @Test func reportsFromAnotherVendorAreRejected() throws {
        var decoder = StockHIDDecoder()
        var key = [UInt8](repeating: 0, count: 32); key[0] = 6; key[2 + 0x1e / 8] = 1 << (0x1e % 8)
        #expect(performing: {
            try decoder.decode(key, vendorID: 0x1234)
        }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("not from")
        })
    }

    @Test func shortNKROReportsAreRejected() throws {
        var decoder = StockHIDDecoder()
        #expect(performing: {
            try decoder.decode([6, 0])
        }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("32 bytes")
        })
    }

    @Test func capturedJSONLReportsReplayToControlEvents() throws {
        let capture = Data("{\"hex\":\"04b500\"}\n{\"hex\":\"040000\"}\n{\"hex\":\"04b500\"}\n".utf8)
        #expect(try CaptureReplay.controls(from: capture).count == 2, "JSONL replay mismatch")
    }

    @Test func malformedCaptureHexIsRejected() throws {
        #expect(performing: {
            try CaptureReplay.controls(from: Data("{\"hex\":\"zz\"}".utf8))
        }, throws: { error in
            guard case IntegrationError.message(let text) = error else { return false }
            return text.contains("Invalid hex")
        })
    }
}

@Suite struct ConsoleDecoderTests {
    @Test func consolePacketsAreJoinedAcrossFixedSizeReports() throws {
        var decoder = StockConsoleDecoder()
        let prefix = Array("first".utf8)
        #expect(try decoder.append(prefix + Array(repeating: 0, count: 32 - prefix.count)).isEmpty, "Console prematurely emitted a line")
        let suffix = Array(" line\nsecond\n".utf8)
        #expect(try decoder.append(suffix + Array(repeating: 0, count: 32 - suffix.count)) == ["first line", "second"], "Console packet joining failed")
    }
}
