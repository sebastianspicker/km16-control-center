import Foundation
import Testing
@testable import KM16ControlCore
import KM16Presets

@Suite struct ActionSpecificationTests {
    @Test func shortcutParserCanonicalizesAliasesAndRejectsMalformedInput() throws {
        #expect(
            try ShortcutSpec.parse(" Control + Option + Shift + Command + P ") ==
            ShortcutSpec(key: "p", modifiers: ["cmd", "shift", "alt", "ctrl"])
        )
        #expect(try ShortcutSpec.parse("⌘+⇧+F12").key == "f12")
        #expect(try ShortcutSpec.parse("ctrl+`").key == "backtick")
        #expect(throws: (any Error).self) { try ShortcutSpec.parse("cmd+cmd+p") }
        #expect(throws: (any Error).self) { try ShortcutSpec.parse("hyper+p") }
        #expect(throws: (any Error).self) { try ShortcutSpec.parse("cmd+") }
    }

    @Test func processSpecRoundTripRequiresStructuredAbsoluteExecution() throws {
        let original = ProcessSpec(
            executable: "/usr/bin/xcrun",
            args: ["swift", "test", "--filter", "Parser Tests"],
            workingDirectory: "/tmp/project with spaces",
            timeoutSeconds: 30
        )
        let encoded = original.encoded()
        #expect(try ProcessSpec.parse(encoded) == original)
        #expect(!encoded.contains("sh -c"))
        #expect(throws: (any Error).self) { try ProcessSpec.parse("swift test") }
        #expect(throws: (any Error).self) { try ProcessSpec.parse(#"{"executable":"swift","args":["test"],"timeoutSeconds":30}"#) }
        #expect(throws: (any Error).self) { try ProcessSpec.parse(#"{"executable":"/usr/bin/swift","args":[],"timeoutSeconds":0}"#) }
        #expect(throws: (any Error).self) { try ProcessSpec.parse(#"{"executable":"/usr/bin/swift","args":[],"timeoutSeconds":30,"extra":true}"#) }
        #expect(throws: ActionSpecificationError.invalidProcessJSON) {
            try ProcessSpec.parse(#"{"executable":"/usr/bin/swift","args":["bad\u0000argument"],"timeoutSeconds":30}"#)
        }
    }

    @Test func actionValidatorChecksEveryActionFamily() {
        #expect(!ActionValidator.issues(for: ControlAction(kind: .shortcut, label: "", parameter: "cmd+q")).isEmpty)
        #expect(!ActionValidator.issues(for: ControlAction(kind: .system, label: "Power", parameter: "shutdown")).isEmpty)
        #expect(!ActionValidator.issues(for: ControlAction(kind: .agentAction, label: "Toggle", parameter: "toggle-terminal")).isEmpty)
        #expect(!ActionValidator.issues(for: ControlAction(kind: .launchApp, label: "App", parameter: "not a bundle")).isEmpty)
        #expect(!ActionValidator.issues(for: ControlAction(kind: .disabled, label: "Off", parameter: "value")).isEmpty)
        #expect(!ActionValidator.issues(for: ControlAction(kind: .shell, label: "Tests", parameter: "swift test")).isEmpty)
        #expect(ActionValidator.issues(for: ControlAction(kind: .agentAction, label: "Prompt", parameter: "prompt:Explain this")).isEmpty)
        #expect(ActionValidator.issues(for: ControlAction(kind: .system, label: "Mute", parameter: "mute")).isEmpty)
        #expect(ActionValidator.issues(for: ControlAction(
            kind: .shell,
            label: "Tests",
            parameter: ProcessSpec(executable: "/usr/bin/xcrun", args: ["swift", "test"], timeoutSeconds: 30).encoded()
        )).isEmpty)
    }

    @Test func unknownControlsCannotBeConstructedOrDecoded() throws {
        #expect(ControlID.key(4, 0) == nil)
        #expect(ControlID.encoder(3, .press) == nil)
        let encoded = try JSONEncoder().encode(Presets.factoryDocument())
        let source = String(decoding: encoded, as: UTF8.self)
        let corrupt = source.replacingOccurrences(of: "key-0-0", with: "key-9-9", options: [], range: source.range(of: "key-0-0"))
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ProfileDocument.self, from: Data(corrupt.utf8)) }
    }
}

@Suite struct SimulationTests {
    @Test func simulationDoesNotExposeParametersAndRefusesInvalidActions() {
        let secret = "prompt:private customer data"
        let valid = Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .agentAction, label: "Private prompt", parameter: secret))
        let validEvent = SimulationDispatcher().dispatch(binding: valid, profile: Presets.agentDeck())
        #expect(validEvent.message.contains("Would run"))
        #expect(!validEvent.message.contains(secret))

        let invalid = Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .agentAction, label: "Unknown", parameter: "fictional-toggle"))
        let invalidEvent = SimulationDispatcher().dispatch(binding: invalid, profile: Presets.agentDeck())
        #expect(invalidEvent.message.contains("Refused"))
        #expect(!invalidEvent.message.contains("fictional-toggle"))
    }

}

@Suite struct ProfileLibraryTests {
    @Test func createDuplicateAndDeleteKeepDocumentsValidAndIsolated() throws {
        var library = ProfileLibrary(document: Presets.factoryDocument())
        let created = library.createProfile(named: "Custom")
        #expect(library.document.activeProfileID == created.id)

        let duplicateResult = library.duplicateActiveProfile()
        let duplicate = try #require(duplicateResult)
        #expect(library.document.activeProfileID == duplicate.id)
        #expect(duplicate.presetID == nil)

        library.document.profiles[library.document.profiles.firstIndex(where: { $0.id == duplicate.id })!].summary = "Edited independently"
        #expect(library.document.profiles.first { $0.id == created.id }?.summary != "Edited independently", "editing the duplicate must not affect the original")

        let deletedResult = library.deleteActiveProfile()
        let deleted = try #require(deletedResult)
        #expect(deleted.id == duplicate.id)
        try ProfileValidator.validate(library.document)
    }

    @Test func deleteActiveProfileSelectsThePreviousProfile() {
        var library = ProfileLibrary(document: Presets.factoryDocument())
        let first = library.createProfile(named: "A")
        let middle = library.createProfile(named: "B")
        library.createProfile(named: "C")
        library.document.activeProfileID = middle.id
        let deleted = library.deleteActiveProfile()
        let previousID = first.id
        #expect(deleted?.id == middle.id)
        #expect(library.document.activeProfileID == previousID)
    }

    @Test func deleteActiveProfileRefusesToRemoveTheLastProfile() {
        let solo = Profile.blank(name: "Solo")
        var library = ProfileLibrary(document: ProfileDocument(activeProfileID: solo.id, profiles: [solo]))
        #expect(library.deleteActiveProfile() == nil)
        #expect(library.document.profiles.count == 1)
    }

    @Test func uniqueNameAppendsCaseInsensitiveSequentialSuffixes() {
        let document = ProfileDocument(activeProfileID: UUID(), profiles: [
            Profile.blank(name: "X"), Profile.blank(name: "x 2")
        ])
        let library = ProfileLibrary(document: document)
        #expect(library.uniqueName("Unused") == "Unused")
        #expect(library.uniqueName("X") == "X 3")
    }

    @Test func resolveProfileSwitchRecognizesCyclePresetAndUUIDInPrecedenceOrder() {
        let byName = Profile.blank(name: "AAAA")
        let byUUID = Profile.blank(name: byName.id.uuidString)
        let document = ProfileDocument(activeProfileID: byName.id, profiles: [byName, byUUID])
        let library = ProfileLibrary(document: document)
        #expect(library.resolveProfileSwitch(parameter: "cycle-profile") == .cycle)
        // The switch parameter matches byUUID's name AND byName's id; name/presetID wins.
        #expect(library.resolveProfileSwitch(parameter: byName.id.uuidString) == .profile(byUUID.id))
        #expect(library.resolveProfileSwitch(parameter: "missing") == .unavailable)
    }

    @Test func mergedRemapsForwardReferencesAndReassignsCollidingIDs() throws {
        let local = Profile.blank(name: "Local")
        let library = ProfileLibrary(document: ProfileDocument(activeProfileID: local.id, profiles: [local]))

        var source = Profile.blank(name: "Source")
        let destination = Profile.blank(name: "Destination")
        source.bindings[0].action = ControlAction(kind: .profileSwitch, label: "go", parameter: destination.id.uuidString)
        let merged = library.merged(with: ProfileDocument(activeProfileID: source.id, profiles: [source, destination]), replaceNameConflicts: false)

        let mergedSource = try #require(merged.profiles.first { $0.name == "Source" })
        let mergedDestination = try #require(merged.profiles.first { $0.name == "Destination" })
        #expect(UUID(uuidString: mergedSource.bindings[0].action.parameter) == mergedDestination.id)
        #expect(merged.activeProfileID == local.id, "merged keeps the base document's active profile")

        var colliding = Profile.blank(name: "Colliding Name")
        colliding.id = local.id
        let withCollision = library.merged(with: ProfileDocument(activeProfileID: colliding.id, profiles: [colliding]), replaceNameConflicts: false)
        let mergedColliding = try #require(withCollision.profiles.first { $0.name == "Colliding Name" })
        #expect(mergedColliding.id != local.id, "an id collision with an existing profile must get a fresh UUID")
    }
}

@Suite struct PersistenceTests {
    @Test func schemaOneLoadMigratesWithBackwardDefaultsWithoutRewritingFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "schema-one.json")
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(Presets.factoryDocument())) as? [String: Any])
        object["schemaVersion"] = 1
        var profiles = try #require(object["profiles"] as? [[String: Any]])
        profiles[0].removeValue(forKey: "summary")
        profiles[0].removeValue(forKey: "matchingBundleIDs")
        profiles[0].removeValue(forKey: "presetID")
        var bindings = try #require(profiles[0]["bindings"] as? [[String: Any]])
        var action = try #require(bindings[0]["action"] as? [String: Any])
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
        #expect(loaded.schemaVersion == 2)
        #expect(loaded.profiles[0].summary == "")
        #expect(loaded.profiles[0].matchingBundleIDs == [])
        #expect(loaded.profiles[0].presetID == nil)
        #expect(loaded.profiles[0].bindings[0].action.targetBundleID == nil)
        #expect(loaded.profiles[0].bindings[0].action.detail == "")
        #expect(!ActionValidator.issues(for: loaded.profiles[0].bindings[0].action).isEmpty, "Legacy incomplete actions stay editable")
        #expect(SimulationDispatcher().dispatch(binding: loaded.profiles[0].bindings[0], profile: loaded.profiles[0]).message.contains("Refused"))
        #expect(try Data(contentsOf: url) == schemaOneData, "Migration must not silently rewrite the source")
    }

    @Test func atomicOverwritePreservesExactOriginalAndInvalidRecoveryBytes() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        let original = Presets.factoryDocument()
        try persistence.save(original)
        let originalBytes = try Data(contentsOf: persistence.url)

        var edited = original
        edited.profiles[0].name = "Desktop edited"
        try persistence.save(edited)
        #expect(try Data(contentsOf: persistence.backupURL) == originalBytes)
        #expect(try persistence.load() == edited)

        let invalidBytes = Data("{invalid user data".utf8)
        try invalidBytes.write(to: persistence.url, options: [.atomic])
        #expect(throws: (any Error).self) { try persistence.load() }
        #expect(try Data(contentsOf: persistence.url) == invalidBytes, "A failed load must preserve the invalid file")
        try persistence.save(original)
        let recoveryURL = try #require(try persistence.latestRecoveryURL())
        #expect(try persistence.recoveryURLs() == [recoveryURL])
        #expect(try Data(contentsOf: recoveryURL) == invalidBytes, "Explicit recovery must preserve the invalid source")
        #expect(try persistence.load() == original)

        try persistence.save(edited)
        #expect(try Data(contentsOf: recoveryURL) == invalidBytes, "Normal backup rotation must not erase durable recovery data")
        #expect(try persistence.recoveryURLs() == [recoveryURL])
        #expect(try ProfilePersistence(url: persistence.backupURL).load() == original)
        #expect(try persistence.load() == edited)
    }

    @Test func persistenceRejectsOversizedFilesBeforeLoadingOrImporting() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let oversizedURL = directory.appending(path: "oversized.json")
        try Data(count: ProfilePersistence.maximumDocumentBytes + 1).write(to: oversizedURL)

        let persistence = ProfilePersistence(url: oversizedURL)
        #expect(performing: { try persistence.load() }, throws: { error in
            error.localizedDescription.contains("cannot exceed")
        })
        let destination = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        #expect(throws: (any Error).self) { try destination.importDocument(from: oversizedURL) }
    }

    @Test func persistenceRejectsMoreThanMaximumProfilesWithoutWriting() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        let profiles = (0...ProfilePersistence.maximumProfileCount).map { Profile.blank(name: "Profile \($0)") }
        let document = ProfileDocument(activeProfileID: profiles[0].id, profiles: profiles)
        #expect(performing: { try persistence.save(document) }, throws: { error in
            error.localizedDescription.contains("at most \(ProfilePersistence.maximumProfileCount)")
        })
        #expect(!FileManager.default.fileExists(atPath: persistence.url.path))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(document).write(to: persistence.url)
        #expect(performing: { try persistence.load() }, throws: { error in
            error.localizedDescription.contains("at most \(ProfilePersistence.maximumProfileCount)")
        })
    }

    @Test func invalidImportDoesNotChangeSavedDocument() throws {
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
        #expect(throws: (any Error).self) { try persistence.importDocument(from: invalidURL) }
        #expect(try Data(contentsOf: persistence.url) == savedBytes)
    }

    @Test func persistenceRejectsSymbolicLinkSourcesAndDestinations() throws {
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
        #expect(throws: ProfilePersistenceError.invalidPath) { try linkedPersistence.load() }
        #expect(throws: ProfilePersistenceError.invalidPath) { try linkedPersistence.save(original) }
        #expect(throws: ProfilePersistenceError.invalidPath) { try ProfilePersistence(url: targetURL).importDocument(from: linkURL) }
        #expect(throws: ProfilePersistenceError.invalidPath) { try ProfilePersistence(url: targetURL).exportDocument(original, to: linkURL) }
        #expect(try Data(contentsOf: targetURL) == originalBytes)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }
}
