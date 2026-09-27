#if canImport(XCTest)
import Foundation
import XCTest
@testable import KM16ControlCore

final class KM16ControlCoreTests: XCTestCase {
    func testSixteenFactoryPresetsCoverAllFourHundredInputs() throws {
        let profiles = Presets.all
        XCTAssertEqual(profiles.map(\.name), [
            "Desktop", "Window Management", "Personal Automations", "Agent Deck",
            "Developer", "Git Review", "Terminal", "Research & Writing", "Meetings",
            "Presentations", "Photo Editing", "Video Editing", "3D Modelling",
            "Music Production", "Recording & Streaming", "Creative"
        ])
        XCTAssertEqual(Set(profiles.compactMap(\.presetID)).count, 16)
        XCTAssertEqual(Set(profiles.map(\.id)).count, 16)
        XCTAssertEqual(ControlID.all.count, 25)
        XCTAssertEqual(profiles.flatMap(\.bindings).count, 400)

        for profile in profiles {
            XCTAssertEqual(profile.bindings.count, 25, profile.name)
            XCTAssertEqual(Set(profile.bindings.map(\.controlID)), Set(ControlID.all), profile.name)
            XCTAssertFalse(profile.summary.isEmpty, profile.name)
            for binding in profile.bindings {
                XCTAssertTrue(ActionValidator.issues(for: binding.action).isEmpty, "\(profile.name) \(binding.controlID): \(ActionValidator.issues(for: binding.action))")
                XCTAssertFalse(binding.action.detail.isEmpty, "\(profile.name) \(binding.controlID)")
                XCTAssertNotEqual(binding.action.parameter, "dictation", "Factory profiles must not promise unsupported dictation dispatch")
            }
        }
        try ProfileValidator.validate(Presets.factoryDocument())
    }

    func testPresetTargetsAndAgentCommandsAreExplicit() {
        XCTAssertEqual(Presets.developer().matchingBundleIDs, ["com.microsoft.VSCode"])
        XCTAssertEqual(Presets.meetings().matchingBundleIDs, ["us.zoom.xos"])
        XCTAssertEqual(Presets.creative().matchingBundleIDs, ["com.apple.Preview"])
        XCTAssertTrue(Presets.developer().bindings.filter { $0.action.kind == .shortcut }.allSatisfy {
            $0.action.targetBundleID == "com.microsoft.VSCode"
        })

        let agentParameters = Presets.agentDeck().bindings
            .filter { $0.action.kind == .agentAction }
            .map(\.action.parameter)
        XCTAssertTrue(agentParameters.contains("run-tests"))
        XCTAssertTrue(ActionValidator.supportedAgentParameters.isSubset(of: Set(agentParameters)))
        XCTAssertTrue(agentParameters.allSatisfy {
            ActionValidator.supportedAgentParameters.contains($0) || $0.hasPrefix("prompt:")
        })
    }

    func testPresetsAreDeterministicAndLookupSupportsPresetAndUUID() {
        XCTAssertEqual(Presets.all, Presets.all)
        let developer = Presets.developer()
        XCTAssertEqual(Presets.preset(id: "developer"), developer)
        XCTAssertEqual(Presets.preset(id: developer.id.uuidString.uppercased()), developer)
        XCTAssertNil(Presets.preset(id: "missing"))
    }

    func testBlankPresetIsCompleteAndValid() throws {
        let blank = Presets.blank(name: "Custom")
        XCTAssertEqual(blank.bindings.count, 25)
        XCTAssertTrue(blank.bindings.allSatisfy { $0.action.kind == .disabled })
        try ProfileValidator.validate(ProfileDocument(activeProfileID: blank.id, profiles: [blank]))
    }

    func testShortcutParserCanonicalizesAliasesAndRejectsMalformedInput() throws {
        XCTAssertEqual(
            try ShortcutSpec.parse(" Control + Option + Shift + Command + P "),
            ShortcutSpec(key: "p", modifiers: ["cmd", "shift", "alt", "ctrl"])
        )
        XCTAssertEqual(try ShortcutSpec.parse("⌘+⇧+F12").key, "f12")
        XCTAssertEqual(try ShortcutSpec.parse("ctrl+`").key, "backtick")
        XCTAssertThrowsError(try ShortcutSpec.parse("cmd+cmd+p"))
        XCTAssertThrowsError(try ShortcutSpec.parse("hyper+p"))
        XCTAssertThrowsError(try ShortcutSpec.parse("cmd+"))
    }

    func testProcessSpecRoundTripRequiresStructuredAbsoluteExecution() throws {
        let original = ProcessSpec(
            executable: "/usr/bin/xcrun",
            args: ["swift", "test", "--filter", "Parser Tests"],
            workingDirectory: "/tmp/project with spaces",
            timeoutSeconds: 30
        )
        let encoded = original.encoded()
        XCTAssertEqual(try ProcessSpec.parse(encoded), original)
        XCTAssertFalse(encoded.contains("sh -c"))
        XCTAssertThrowsError(try ProcessSpec.parse("swift test"))
        XCTAssertThrowsError(try ProcessSpec.parse(#"{"executable":"swift","args":["test"],"timeoutSeconds":30}"#))
        XCTAssertThrowsError(try ProcessSpec.parse(#"{"executable":"/usr/bin/swift","args":[],"timeoutSeconds":0}"#))
        XCTAssertThrowsError(try ProcessSpec.parse(#"{"executable":"/usr/bin/swift","args":[],"timeoutSeconds":30,"extra":true}"#))
        XCTAssertThrowsError(try ProcessSpec.parse(#"{"executable":"/usr/bin/swift","args":["bad\u0000argument"],"timeoutSeconds":30}"#)) { error in
            XCTAssertEqual(error as? ActionSpecificationError, .invalidProcessJSON)
        }
    }

    func testActionValidatorChecksEveryActionFamily() {
        XCTAssertFalse(ActionValidator.issues(for: ControlAction(kind: .shortcut, label: "", parameter: "cmd+q")).isEmpty)
        XCTAssertFalse(ActionValidator.issues(for: ControlAction(kind: .system, label: "Power", parameter: "shutdown")).isEmpty)
        XCTAssertFalse(ActionValidator.issues(for: ControlAction(kind: .agentAction, label: "Toggle", parameter: "toggle-terminal")).isEmpty)
        XCTAssertFalse(ActionValidator.issues(for: ControlAction(kind: .launchApp, label: "App", parameter: "not a bundle")).isEmpty)
        XCTAssertFalse(ActionValidator.issues(for: ControlAction(kind: .disabled, label: "Off", parameter: "value")).isEmpty)
        XCTAssertFalse(ActionValidator.issues(for: ControlAction(kind: .shell, label: "Tests", parameter: "swift test")).isEmpty)
        XCTAssertTrue(ActionValidator.issues(for: ControlAction(kind: .agentAction, label: "Prompt", parameter: "prompt:Explain this")).isEmpty)
        XCTAssertTrue(ActionValidator.issues(for: ControlAction(kind: .system, label: "Mute", parameter: "mute")).isEmpty)
        XCTAssertTrue(ActionValidator.issues(for: ControlAction(
            kind: .shell,
            label: "Tests",
            parameter: ProcessSpec(executable: "/usr/bin/xcrun", args: ["swift", "test"], timeoutSeconds: 30).encoded()
        )).isEmpty)
    }

    func testSchemaOneLoadMigratesWithBackwardDefaultsWithoutRewritingFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "schema-one.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Presets.factoryDocument())) as? [String: Any])
        object["schemaVersion"] = 1
        var profiles = try XCTUnwrap(object["profiles"] as? [[String: Any]])
        profiles[0].removeValue(forKey: "summary")
        profiles[0].removeValue(forKey: "matchingBundleIDs")
        profiles[0].removeValue(forKey: "presetID")
        var bindings = try XCTUnwrap(profiles[0]["bindings"] as? [[String: Any]])
        var action = try XCTUnwrap(bindings[0]["action"] as? [String: Any])
        action.removeValue(forKey: "targetBundleID")
        action.removeValue(forKey: "detail")
        action["kind"] = "shell"
        action["parameter"] = "swift test"
        bindings[0]["action"] = action
        profiles[0]["bindings"] = bindings
        object["profiles"] = profiles
        let schemaOneData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try schemaOneData.write(to: url)

        let loaded = try ProfilePersistence(url: url).load()
        XCTAssertEqual(loaded.schemaVersion, 2)
        XCTAssertEqual(loaded.profiles[0].summary, "")
        XCTAssertEqual(loaded.profiles[0].matchingBundleIDs, [])
        XCTAssertNil(loaded.profiles[0].presetID)
        XCTAssertNil(loaded.profiles[0].bindings[0].action.targetBundleID)
        XCTAssertEqual(loaded.profiles[0].bindings[0].action.detail, "")
        XCTAssertFalse(ActionValidator.issues(for: loaded.profiles[0].bindings[0].action).isEmpty, "Legacy incomplete actions stay editable")
        XCTAssertTrue(SimulationDispatcher().dispatch(binding: loaded.profiles[0].bindings[0], profile: loaded.profiles[0]).message.contains("Refused"))
        XCTAssertEqual(try Data(contentsOf: url), schemaOneData, "Migration must not silently rewrite the source")
    }

    func testAtomicOverwritePreservesExactOriginalAndInvalidRecoveryBytes() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        let original = Presets.factoryDocument()
        try persistence.save(original)
        let originalBytes = try Data(contentsOf: persistence.url)

        var edited = original
        edited.profiles[0].name = "Desktop edited"
        try persistence.save(edited)
        XCTAssertEqual(try Data(contentsOf: persistence.backupURL), originalBytes)
        XCTAssertEqual(try persistence.load(), edited)

        let invalidBytes = Data("{invalid user data".utf8)
        try invalidBytes.write(to: persistence.url, options: [.atomic])
        XCTAssertThrowsError(try persistence.load())
        XCTAssertEqual(try Data(contentsOf: persistence.url), invalidBytes, "A failed load must preserve the invalid file")
        try persistence.save(original)
        let recoveryURL = try XCTUnwrap(persistence.latestRecoveryURL())
        XCTAssertEqual(try persistence.recoveryURLs(), [recoveryURL])
        XCTAssertEqual(try Data(contentsOf: recoveryURL), invalidBytes, "Explicit recovery must preserve the invalid source")
        XCTAssertEqual(try persistence.load(), original)

        try persistence.save(edited)
        XCTAssertEqual(try Data(contentsOf: recoveryURL), invalidBytes, "Normal backup rotation must not erase durable recovery data")
        XCTAssertEqual(try persistence.recoveryURLs(), [recoveryURL])
        XCTAssertEqual(try ProfilePersistence(url: persistence.backupURL).load(), original)
        XCTAssertEqual(try persistence.load(), edited)
    }

    func testPersistenceRejectsOversizedFilesBeforeLoadingOrImporting() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let oversizedURL = directory.appending(path: "oversized.json")
        try Data(count: ProfilePersistence.maximumDocumentBytes + 1).write(to: oversizedURL)

        let persistence = ProfilePersistence(url: oversizedURL)
        XCTAssertThrowsError(try persistence.load()) { error in
            XCTAssertTrue(error.localizedDescription.contains("cannot exceed"))
        }
        let destination = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        XCTAssertThrowsError(try destination.importDocument(from: oversizedURL))
    }

    func testPersistenceRejectsMoreThanMaximumProfilesWithoutWriting() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        let profiles = (0...ProfilePersistence.maximumProfileCount).map { Presets.blank(name: "Profile \($0)") }
        let document = ProfileDocument(activeProfileID: profiles[0].id, profiles: profiles)
        XCTAssertThrowsError(try persistence.save(document)) { error in
            XCTAssertTrue(error.localizedDescription.contains("at most \(ProfilePersistence.maximumProfileCount)"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: persistence.url.path))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(document).write(to: persistence.url)
        XCTAssertThrowsError(try persistence.load()) { error in
            XCTAssertTrue(error.localizedDescription.contains("at most \(ProfilePersistence.maximumProfileCount)"))
        }
    }

    func testInvalidImportDoesNotChangeSavedDocument() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        let invalidURL = directory.appending(path: "invalid.json")
        let original = Presets.factoryDocument()
        try persistence.save(original)
        let savedBytes = try Data(contentsOf: persistence.url)
        var invalid = original
        invalid.profiles[0].bindings[0].action.parameter = "cmd+"
        try JSONEncoder().encode(invalid).write(to: invalidURL)
        XCTAssertThrowsError(try persistence.importDocument(from: invalidURL))
        XCTAssertEqual(try Data(contentsOf: persistence.url), savedBytes)
    }

    func testPersistenceRejectsSymbolicLinkSourcesAndDestinations() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let targetURL = directory.appending(path: "target.json")
        let linkURL = directory.appending(path: "profiles.json")
        let original = Presets.factoryDocument()
        try ProfilePersistence(url: targetURL).save(original)
        let originalBytes = try Data(contentsOf: targetURL)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        let linkedPersistence = ProfilePersistence(url: linkURL)
        XCTAssertThrowsError(try linkedPersistence.load()) { error in
            XCTAssertEqual(error as? ProfilePersistenceError, .invalidPath)
        }
        XCTAssertThrowsError(try linkedPersistence.save(original)) { error in
            XCTAssertEqual(error as? ProfilePersistenceError, .invalidPath)
        }
        XCTAssertThrowsError(try ProfilePersistence(url: targetURL).importDocument(from: linkURL)) { error in
            XCTAssertEqual(error as? ProfilePersistenceError, .invalidPath)
        }
        XCTAssertThrowsError(try ProfilePersistence(url: targetURL).exportDocument(original, to: linkURL)) { error in
            XCTAssertEqual(error as? ProfilePersistenceError, .invalidPath)
        }
        XCTAssertEqual(try Data(contentsOf: targetURL), originalBytes)
    }

    func testSimulationDoesNotExposeParametersAndRefusesInvalidActions() {
        let secret = "prompt:private customer data"
        let valid = Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .agentAction, label: "Private prompt", parameter: secret))
        let validEvent = SimulationDispatcher().dispatch(binding: valid, profile: Presets.agentDeck())
        XCTAssertTrue(validEvent.message.contains("Would run"))
        XCTAssertFalse(validEvent.message.contains(secret))

        let invalid = Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .agentAction, label: "Unknown", parameter: "fictional-toggle"))
        let invalidEvent = SimulationDispatcher().dispatch(binding: invalid, profile: Presets.agentDeck())
        XCTAssertTrue(invalidEvent.message.contains("Refused"))
        XCTAssertFalse(invalidEvent.message.contains("fictional-toggle"))
    }

    func testProfileEditorKeepsDocumentsValidAcrossCRUD() throws {
        var editor = ProfileEditor(document: Presets.factoryDocument())
        let blank = Presets.blank(name: "Custom")
        try editor.add(blank)
        XCTAssertEqual(editor.activeProfile?.id, blank.id)
        let copyID = try editor.duplicateProfile(id: blank.id, name: "Custom copy")
        XCTAssertNil(editor.activeProfile?.presetID)
        try editor.updateProfile(id: copyID) { $0.summary = "Edited independently" }
        XCTAssertNotEqual(editor.document.profiles.first { $0.id == blank.id }?.summary, "Edited independently")
        try editor.removeProfile(id: copyID)
        try ProfileValidator.validate(editor.document)
    }

    func testUnknownControlsCannotBeConstructedOrDecoded() throws {
        XCTAssertNil(ControlID.key(4, 0))
        XCTAssertNil(ControlID.encoder(3, .press))
        let encoded = try JSONEncoder().encode(Presets.factoryDocument())
        let source = String(decoding: encoded, as: UTF8.self)
        let corrupt = source.replacingOccurrences(of: "key-0-0", with: "key-9-9", options: [], range: source.range(of: "key-0-0"))
        XCTAssertThrowsError(try JSONDecoder().decode(ProfileDocument.self, from: Data(corrupt.utf8)))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }
}
#endif
