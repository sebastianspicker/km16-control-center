import Foundation
import KM16ControlCore

/// Decoder for the user's captured stock layer, not a raw physical-event protocol.
/// Fn, upper-left press and lower press have no captured host report.
public struct StockHIDDecoder {
    private var keyboard = Set<Int>()
    private var consumer = 0
    private static let consumerControls = [
        0xb5: ControlID.encoder(1, .clockwise)!,
        0xb6: ControlID.encoder(1, .counterClockwise)!,
        0xcd: ControlID.encoder(1, .press)!,
        0xe9: ControlID.encoder(2, .clockwise)!,
        0xea: ControlID.encoder(2, .counterClockwise)!
    ]
    public init() {}
    public mutating func decode(_ bytes: [UInt8], vendorID: Int = 0x28e9, productID: Int = 0x3145, usagePage: Int = 1, usage: Int = 2) throws -> [ControlID] {
        guard vendorID == 0x28e9, productID == 0x3145, usagePage == 1, usage == 2 else { throw IntegrationError.message("Report is not from the KM16 Pro composite interface.") }
        guard let report = bytes.first else { throw IntegrationError.message("Empty HID report.") }
        if report == 6 {
            guard bytes.count == 32 else { throw IntegrationError.message("NKRO report must contain 32 bytes including ID.") }
            var pressed = Set<Int>()
            for index in 0..<240 where bytes[2 + index / 8] & (1 << (index % 8)) != 0 { pressed.insert(index) }
            let new = pressed.subtracting(keyboard); keyboard = pressed
            // Modified or rollover reports cannot identify this captured unmodified mapping.
            guard bytes[1] == 0, pressed.isDisjoint(with: [1, 2, 3]) else { return [] }
            let usages = [0x1e,0x1f,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x52,0x28,-1,0x50,0x51,0x4f]
            return new.sorted().compactMap { code in
                if code == 0x4b { return ControlID.encoder(0, .counterClockwise) }
                if code == 0x4e { return ControlID.encoder(0, .clockwise) }
                guard let index = usages.firstIndex(of: code) else { return nil }
                return ControlID.keys[index]
            }
        }
        if report == 4 {
            guard bytes.count == 3 else { throw IntegrationError.message("Consumer report must contain three bytes including ID.") }
            let value = Int(bytes[1]) | Int(bytes[2]) << 8
            defer { consumer = value }
            guard value != 0, value != consumer else { return [] }
            return Self.consumerControls[value].map { [$0] } ?? []
        }
        // Other composite report IDs (mouse/system controls) do not identify pad positions.
        return []
    }
    public mutating func reset() { keyboard.removeAll(); consumer = 0 }
}

public enum CaptureReplay {
    /// Input is a saved composite.jsonl file. Provenance is selected explicitly by the user;
    /// historical files have no VID/PID fields and cannot prove an actual attached device identity.
    public static func controls(from data: Data) throws -> [ControlID] {
        guard data.count <= 8_000_000 else { throw IntegrationError.message("Capture exceeds the 8 MB replay limit.") }
        guard let text = String(data: data, encoding: .utf8) else { throw IntegrationError.message("Capture must be UTF-8 JSON lines.") }
        var decoder = StockHIDDecoder(), results: [ControlID] = []
        for (index, line) in text.split(whereSeparator: \.isNewline).enumerated() {
            let object = try JSONDecoder().decode(JSONValue.self, from: Data(line.utf8))
            guard let hex = object["hex"].string, hex.count % 2 == 0, hex.count <= 64 else { throw IntegrationError.message("Invalid hex report on capture line \(index + 1).") }
            let chars = Array(hex)
            var bytes: [UInt8] = []
            for offset in stride(from: 0, to: chars.count, by: 2) {
                guard let byte = UInt8(String(chars[offset...offset+1]), radix: 16) else { throw IntegrationError.message("Invalid hex byte on capture line \(index + 1).") }
                bytes.append(byte)
            }
            results += try decoder.decode(bytes)
            guard results.count <= 20_000 else { throw IntegrationError.message("Capture contains too many input events.") }
        }
        return results
    }
}

public struct StockConsoleDecoder {
    private var buffer = Data()
    public init() {}
    public mutating func append(_ packet: [UInt8]) throws -> [String] {
        guard packet.count == 32 else { throw IntegrationError.message("Console packets must contain 32 bytes.") }
        buffer.append(contentsOf: packet.prefix { $0 != 0 })
        guard buffer.count <= 4096 else { buffer.removeAll(); throw IntegrationError.message("Console line exceeds 4096 bytes.") }
        var lines: [String] = []
        while let end = buffer.firstIndex(of: 10) {
            lines.append(String(decoding: buffer[..<end], as: UTF8.self).trimmingCharacters(in: .newlines))
            buffer.removeSubrange(...end)
        }
        return lines
    }
}
