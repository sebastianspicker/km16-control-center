import Foundation
import CoreGraphics
import Testing
@testable import KM16ControlCore

@Suite struct FactoryPresetTests {
    @Test func sixteenFactoryPresetsCoverAllFourHundredInputs() throws {
        let profiles = Presets.all
        #expect(profiles.map(\.name) == [
            "Desktop", "Window Management", "Personal Automations", "Agent Deck",
            "Developer", "Git Review", "Terminal", "Research & Writing", "Meetings",
            "Presentations", "Photo Editing", "Video Editing", "3D Modelling",
            "Music Production", "Recording & Streaming", "Creative"
        ])
        #expect(Set(profiles.compactMap(\.presetID)).count == 16)
        #expect(Set(profiles.map(\.id)).count == 16)
        #expect(ControlID.all.count == 25)
        #expect(profiles.flatMap(\.bindings).count == 400)

        for profile in profiles {
            #expect(profile.bindings.count == 25, "\(profile.name)")
            #expect(Set(profile.bindings.map(\.controlID)) == Set(ControlID.all), "\(profile.name)")
            #expect(!profile.summary.isEmpty, "\(profile.name)")
            for binding in profile.bindings {
                #expect(ActionValidator.issues(for: binding.action).isEmpty, "\(profile.name) \(binding.controlID): \(ActionValidator.issues(for: binding.action))")
                #expect(!binding.action.detail.isEmpty, "\(profile.name) \(binding.controlID)")
                #expect(binding.action.parameter != "dictation", "Factory profiles must not promise unsupported dictation dispatch")
            }
        }
        try ProfileValidator.validate(Presets.factoryDocument())
    }

    @Test func presetTargetsAndAgentCommandsAreExplicit() {
        #expect(Presets.developer().matchingBundleIDs == ["com.microsoft.VSCode"])
        #expect(Presets.meetings().matchingBundleIDs == ["us.zoom.xos"])
        #expect(Presets.creative().matchingBundleIDs == ["com.apple.Preview"])
        #expect(Presets.developer().bindings.filter { $0.action.kind == .shortcut }.allSatisfy {
            $0.action.targetBundleID == "com.microsoft.VSCode"
        })

        let agentParameters = Presets.agentDeck().bindings
            .filter { $0.action.kind == .agentAction }
            .map(\.action.parameter)
        #expect(agentParameters.contains("run-tests"))
        #expect(ActionValidator.supportedAgentParameters.isSubset(of: Set(agentParameters)))
        #expect(agentParameters.allSatisfy {
            ActionValidator.supportedAgentParameters.contains($0) || $0.hasPrefix("prompt:")
        })
    }

    @Test func presetsAreDeterministicAndLookupSupportsPresetAndUUID() {
        #expect(Presets.all == Presets.all)
        let developer = Presets.developer()
        #expect(Presets.preset(id: "developer") == developer)
        #expect(Presets.preset(id: developer.id.uuidString.uppercased()) == developer)
        #expect(Presets.preset(id: "missing") == nil)
    }

    @Test func blankPresetIsCompleteAndValid() throws {
        let blank = Presets.blank(name: "Custom")
        #expect(blank.bindings.count == 25)
        #expect(blank.bindings.allSatisfy { $0.action.kind == .disabled })
        try ProfileValidator.validate(ProfileDocument(activeProfileID: blank.id, profiles: [blank]))
    }

    @Test func mutatingOneProfileDoesNotAffectAnother() {
        var isolated = Presets.factoryDocument()
        isolated.profiles[1].replace(Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .snippet, label: "Changed", parameter: "value")))
        #expect(isolated.profiles[0].binding(for: ControlID.keys[0])!.action != isolated.profiles[1].binding(for: ControlID.keys[0])!.action, "profiles are not isolated")
    }
}

@Suite struct PresetExpansionTests {
    @Test func creativeWorkflowPresetsTargetASingleApp() {
        let profiles = Presets.all
        let creativeIDs = Set(["photo-editing", "3d-modelling", "music-production", "presentations"])
        let additions = profiles.filter { creativeIDs.contains($0.presetID ?? "") }
        #expect(additions.count == 4, "the four requested creative workflows must be present")
        #expect(additions.allSatisfy { profile in profile.matchingBundleIDs.count == 1 && profile.bindings.allSatisfy { $0.action.targetBundleID == profile.matchingBundleIDs.first } }, "creative actions must target their specific app")
    }

    @Test func factoryBundleIDMatchingIsUnambiguous() {
        let matches = Presets.all.flatMap(\.matchingBundleIDs)
        #expect(Set(matches).count == matches.count, "factory automatic matching must be unambiguous")
    }

    @Test func factoryDocumentSurvivesJSONRoundTripAndUsesOnlyLiveActions() throws {
        let bytes = try JSONEncoder().encode(Presets.factoryDocument())
        #expect(try JSONDecoder().decode(ProfileDocument.self, from: bytes) == Presets.factoryDocument(), "new actions must survive JSON round trip")
        #expect(Presets.all.flatMap(\.bindings).allSatisfy { $0.action.kind != .disabled }, "factory assignments must be usable")
    }

    @Test func gitReviewDoesNotOverrideDeveloperMatching() {
        #expect(Presets.gitReview().matchingBundleIDs.isEmpty, "Git Review must not override Developer automatic matching")
    }

    @Test func obsActionValidatorRejectsUnknownOperation() {
        #expect(!ActionValidator.issues(for: ControlAction(kind: .obsAction, label: "Invalid", parameter: "unknown")).isEmpty, "unknown OBS operation accepted")
    }

    @Test func terminalSnippetsNeverSendReturn() throws {
        let terminalSnippets = Presets.terminal().bindings.filter { $0.action.kind == .snippet }
        #expect(terminalSnippets.allSatisfy { !$0.action.parameter.contains("\n") && !$0.action.parameter.contains("\r") }, "Terminal templates must not execute by sending Return")
    }

    @Test func personalAutomationsRoutinesUseALiteralShortcutsInvocation() throws {
        for binding in Presets.personalAutomations().bindings where binding.action.kind == .shell {
            let spec = try ProcessSpec.parse(binding.action.parameter)
            #expect(spec.executable == "/usr/bin/shortcuts" && spec.args.count == 2 && spec.args[0] == "run", "routine must use a literal Shortcuts invocation")
        }
    }

    @Test func windowGeometryHandlesNegativeOriginsAndMultipleDisplays() {
        let screen = CGRect(x: -1600, y: -400, width: 1600, height: 900)
        let current = CGRect(x: -1000, y: 0, width: 700, height: 500)
        #expect(WindowGeometry.placement(.topRight, current: current, visible: screen) == CGRect(x: -800, y: -400, width: 800, height: 450), "quarter placement must respect negative screen origins")
        #expect(WindowGeometry.placement(.bottomHalf, current: current, visible: screen) == CGRect(x: -1600, y: 50, width: 1600, height: 450), "bottom placement is inverted")
        #expect(WindowGeometry.centered(CGSize(width: 2000, height: 1000), in: screen) == screen, "centering must fit oversized windows")
        #expect(WindowGeometry.accessibilityFrame(CGRect(x: -1600, y: 200, width: 1600, height: 900), primaryTop: 1000) == CGRect(x: -1600, y: -100, width: 1600, height: 900), "screen coordinate conversion failed")
        #expect(WindowGeometry.displayIndex(for: current, displays: [CGRect(x: 0, y: 0, width: 1000, height: 800), screen]) == 1, "display selection must use intersection area")
        #expect(WindowGeometry.displayIndex(for: current, displays: []) == nil, "empty display inventory must be handled")
    }
}

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

    @Test func profileEditorKeepsDocumentsValidAcrossCRUD() throws {
        var editor = ProfileEditor(document: Presets.factoryDocument())
        let blank = Presets.blank(name: "Custom")
        try editor.add(blank)
        #expect(editor.activeProfile?.id == blank.id)
        let copyID = try editor.duplicateProfile(id: blank.id, name: "Custom copy")
        #expect(editor.activeProfile?.presetID == nil)
        try editor.updateProfile(id: copyID) { $0.summary = "Edited independently" }
        #expect(editor.document.profiles.first { $0.id == blank.id }?.summary != "Edited independently")
        try editor.removeProfile(id: copyID)
        try ProfileValidator.validate(editor.document)
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
        let profiles = (0...ProfilePersistence.maximumProfileCount).map { Presets.blank(name: "Profile \($0)") }
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

    @Test func factoryPresetExportsMatchCommittedPresetFiles() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presetsDirectory = repositoryRoot.appending(path: "presets", directoryHint: .isDirectory)

        if ProcessInfo.processInfo.environment["KM16_WRITE_PRESET_EXPORTS"] == "1" {
            try Self.exportPresets(to: presetsDirectory)
            return
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        try Self.exportPresets(to: temporaryDirectory)

        for profile in Presets.all {
            let presetID = try #require(profile.presetID)
            let exported = try Data(contentsOf: temporaryDirectory.appending(path: "\(presetID).json"))
            let committed = try Data(contentsOf: presetsDirectory.appending(path: "\(presetID).json"))
            #expect(exported == committed, "\(presetID).json export drifted from the committed preset")
        }
        let exportedAll = try Data(contentsOf: temporaryDirectory.appending(path: "all.json"))
        let committedAll = try Data(contentsOf: presetsDirectory.appending(path: "all.json"))
        #expect(exportedAll == committedAll, "all.json export drifted from the committed preset")
    }

    private static func exportPresets(to directory: URL) throws {
        let profiles = Presets.all
        for profile in profiles {
            let presetID = try #require(profile.presetID)
            let outputURL = directory.appending(path: "\(presetID).json")
            let document = ProfileDocument(activeProfileID: profile.id, profiles: [profile])
            try ProfilePersistence(url: outputURL).exportDocument(document, to: outputURL)
        }
        let allURL = directory.appending(path: "all.json")
        let document = ProfileDocument(activeProfileID: profiles[0].id, profiles: profiles)
        try ProfilePersistence(url: allURL).exportDocument(document, to: allURL)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }
}
