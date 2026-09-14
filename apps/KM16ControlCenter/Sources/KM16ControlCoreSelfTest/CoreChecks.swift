import Foundation
import Darwin
import KM16ControlCore

enum SelfTestFailure: Error, LocalizedError {
    case assertion(String)
    var errorDescription: String? {
        if case .assertion(let message) = self { return message }
        return nil
    }
}

func expect(_ condition: Bool, _ message: String) throws {
    guard condition else { throw SelfTestFailure.assertion(message) }
}

@main
enum KM16ControlCoreSelfTest {
    static func main() {
        do {
            if CommandLine.arguments.count > 1 {
                guard CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--export-presets" else {
                    throw SelfTestFailure.assertion("usage: KM16ControlCoreSelfTest [--export-presets <directory>]")
                }
                try exportPresets(to: URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true))
                return
            }

            let original = Presets.factoryDocument()
            try ProfileValidator.validate(original)
            try expect(original.schemaVersion == 2, "factory document is not schema 2")
            try expect(original.profiles.count == 16, "expected sixteen factory presets")
            try expect(original.profiles.flatMap(\.bindings).count == 400, "expected 400 factory slots")
            try expect(original.profiles.allSatisfy { Set($0.bindings.map(\.controlID)) == Set(ControlID.all) }, "factory profile coverage failed")
            try expect(original.profiles.flatMap(\.bindings).allSatisfy { ActionValidator.issues(for: $0.action).isEmpty }, "factory action validation failed")
            try expect(original.profiles.flatMap(\.bindings).allSatisfy { !$0.action.detail.isEmpty }, "factory action detail is missing")
            try expect(original.profiles.flatMap(\.bindings).allSatisfy { $0.action.parameter != "dictation" }, "factory preset promises unsupported dictation")
            try expect(ControlID.key(4, 0) == nil && ControlID.encoder(3, .press) == nil, "out-of-range controls are constructible")
            try expect(Presets.developer().matchingBundleIDs == ["com.microsoft.VSCode"], "Developer target changed")
            try expect(Presets.meetings().matchingBundleIDs == ["us.zoom.xos"], "Meetings target changed")
            try expect(Presets.creative().matchingBundleIDs == ["com.apple.Preview"], "Creative target changed")

            try presetExpansionChecks()
            let shortcut = try ShortcutSpec.parse("Control + Option + Shift + Command + P")
            try expect(shortcut == ShortcutSpec(key: "p", modifiers: ["cmd", "shift", "alt", "ctrl"]), "shortcut canonicalization failed")
            let process = ProcessSpec(executable: "/usr/bin/xcrun", args: ["swift", "test"], timeoutSeconds: 30)
            try expect(try ProcessSpec.parse(process.encoded()) == process, "process specification round trip failed")
            do { _ = try ProcessSpec.parse("swift test"); throw SelfTestFailure.assertion("plain shell text was accepted") } catch is ActionSpecificationError {}
            let nulProcess = #"{"executable":"/usr/bin/swift","args":["bad\u0000argument"],"timeoutSeconds":30}"#
            do { _ = try ProcessSpec.parse(nulProcess); throw SelfTestFailure.assertion("NUL process argument was accepted") } catch ActionSpecificationError.invalidProcessJSON {}

            let privateParameter = "prompt:private customer text"
            let privateBinding = Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .agentAction, label: "Private prompt", parameter: privateParameter))
            let event = SimulationDispatcher().dispatch(binding: privateBinding, profile: Presets.agentDeck())
            try expect(event.message.contains("Would run") && !event.message.contains(privateParameter), "simulation exposed raw action parameter")
            let invalidBinding = Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .agentAction, label: "Invalid", parameter: "fictional-toggle"))
            let refused = SimulationDispatcher().dispatch(binding: invalidBinding, profile: Presets.agentDeck())
            try expect(refused.message.contains("Refused") && !refused.message.contains("fictional-toggle"), "invalid simulation was not safely refused")

            var isolated = original
            isolated.profiles[1].replace(Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .snippet, label: "Changed", parameter: "value")))
            try expect(isolated.profiles[0].binding(for: ControlID.keys[0])!.action != isolated.profiles[1].binding(for: ControlID.keys[0])!.action, "profiles are not isolated")

            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            defer { try? FileManager.default.removeItem(at: directory) }
            let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
            try persistence.save(original)
            let firstBytes = try Data(contentsOf: persistence.url)
            var edited = original
            edited.profiles[0].name = "Desktop edited"
            try persistence.save(edited)
            try expect(try Data(contentsOf: persistence.backupURL) == firstBytes, "overwrite backup did not preserve original bytes")

            let invalidBytes = Data("{invalid user data".utf8)
            try invalidBytes.write(to: persistence.url, options: [.atomic])
            do { _ = try persistence.load(); throw SelfTestFailure.assertion("invalid saved file loaded") } catch is ProfilePersistenceError {}
            try expect(try Data(contentsOf: persistence.url) == invalidBytes, "failed load changed invalid file")
            try persistence.save(original)
            let recoveryURL = try require(try persistence.latestRecoveryURL(), "explicit recovery did not create a durable snapshot")
            try expect(try Data(contentsOf: recoveryURL) == invalidBytes, "recovery snapshot did not preserve invalid bytes")
            try persistence.save(edited)
            try expect(try Data(contentsOf: recoveryURL) == invalidBytes, "backup rotation erased durable recovery data")
            try expect(try persistence.recoveryURLs() == [recoveryURL], "recovery snapshot inventory changed unexpectedly")

            let linkedURL = directory.appending(path: "linked-profiles.json")
            try FileManager.default.createSymbolicLink(at: linkedURL, withDestinationURL: persistence.url)
            let savedBytes = try Data(contentsOf: persistence.url)
            do { _ = try ProfilePersistence(url: linkedURL).load(); throw SelfTestFailure.assertion("symbolic-link profile loaded") } catch ProfilePersistenceError.invalidPath {}
            do { try ProfilePersistence(url: linkedURL).save(original); throw SelfTestFailure.assertion("symbolic-link profile overwritten") } catch ProfilePersistenceError.invalidPath {}
            do { _ = try persistence.importDocument(from: linkedURL); throw SelfTestFailure.assertion("symbolic-link profile imported") } catch ProfilePersistenceError.invalidPath {}
            do { try persistence.exportDocument(original, to: linkedURL); throw SelfTestFailure.assertion("symbolic-link profile exported") } catch ProfilePersistenceError.invalidPath {}
            try expect(try Data(contentsOf: persistence.url) == savedBytes, "symbolic-link rejection changed its target")

            let schemaOneURL = directory.appending(path: "schema-one.json")
            var object = try require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any], "factory JSON was not an object")
            object["schemaVersion"] = 1
            var profiles = try require(object["profiles"] as? [[String: Any]], "factory profiles were not JSON objects")
            profiles[0].removeValue(forKey: "summary")
            profiles[0].removeValue(forKey: "matchingBundleIDs")
            profiles[0].removeValue(forKey: "presetID")
            object["profiles"] = profiles
            let schemaOneData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            try schemaOneData.write(to: schemaOneURL)
            let migrated = try ProfilePersistence(url: schemaOneURL).load()
            try expect(migrated.schemaVersion == 2 && migrated.profiles[0].summary.isEmpty, "schema 1 migration defaults failed")
            try expect(try Data(contentsOf: schemaOneURL) == schemaOneData, "migration silently rewrote source file")

            let oversizedURL = directory.appending(path: "oversized.json")
            try Data(count: ProfilePersistence.maximumDocumentBytes + 1).write(to: oversizedURL)
            do { _ = try ProfilePersistence(url: oversizedURL).load(); throw SelfTestFailure.assertion("oversized file loaded") } catch is ProfilePersistenceError {}
            let tooManyProfiles = (0...ProfilePersistence.maximumProfileCount).map { Presets.blank(name: "Profile \($0)") }
            let oversizedDocument = ProfileDocument(activeProfileID: tooManyProfiles[0].id, profiles: tooManyProfiles)
            do { try ProfilePersistence(url: directory.appending(path: "too-many.json")).save(oversizedDocument); throw SelfTestFailure.assertion("oversized profile collection saved") } catch is ProfilePersistenceError {}

            print("KM16ControlCoreSelfTest passed: schema migration, durable recovery, path and size bounds, sixteen presets/400 slots, parsers, validation, isolation, and private simulation logs.")
        } catch {
            fputs("KM16ControlCoreSelfTest failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw SelfTestFailure.assertion(message) }
        return value
    }

    private static func exportPresets(to directory: URL) throws {
        let profiles = Presets.all
        for profile in profiles {
            guard let presetID = profile.presetID else {
                throw SelfTestFailure.assertion("factory profile \(profile.name) has no preset identifier")
            }
            let outputURL = directory.appending(path: "\(presetID).json")
            let document = ProfileDocument(activeProfileID: profile.id, profiles: [profile])
            try ProfilePersistence(url: outputURL).exportDocument(document, to: outputURL)
        }
        let allURL = directory.appending(path: "all.json")
        let document = ProfileDocument(activeProfileID: profiles[0].id, profiles: profiles)
        try ProfilePersistence(url: allURL).exportDocument(document, to: allURL)
        print("Exported \(profiles.count) presets and all.json to \(directory.path)")
    }
}
