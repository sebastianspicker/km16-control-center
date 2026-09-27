import Foundation
import Testing
@testable import KM16ControlCenter
import KM16ControlCore
import KM16Presets

@MainActor
@Suite struct ControlCenterStoreTests {
    @Test func firstLaunchLoadsFactoryPresetsWithoutRecoveryWarningsOrCreatingStorage() {
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        let store = ControlCenterStore(persistence: persistence)
        #expect(store.recoveryMessage == nil)
        #expect(store.document.profiles.count == Presets.all.count)
        #expect(!FileManager.default.fileExists(atPath: persistence.url.path))
    }

    @Test func presetLibraryAdditionsPreserveExistingEditsSelectionAndSavedDataAndUndoAsOneChange() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        var edited = Presets.desktop()
        edited.name = "My Desktop"
        edited.bindings[0].action.label = "My edited copy"
        let persistence = ProfilePersistence(url: directory.appendingPathComponent("older-library.json"))
        let previous = ProfileDocument(activeProfileID: edited.id, profiles: [edited])
        try persistence.save(previous)
        let store = ControlCenterStore(persistence: persistence)
        store.addMissingPresets()
        #expect(store.document.profiles.count == 16)
        #expect(store.document.profiles[0] == edited)
        #expect(store.document.activeProfileID == edited.id)
        #expect(try persistence.load() == previous, "adding presets changed existing edits, selection, or saved data")

        let expanded = store.document
        store.addMissingPresets()
        #expect(store.document == expanded, "adding missing presets must be idempotent")
        store.undo()
        #expect(store.document == previous, "preset expansion must undo as one change")
        store.redo()
        #expect(store.document == expanded, "preset expansion must redo as one change")

        let newIDs: Set<String> = ["photo-editing", "3d-modelling", "music-production", "presentations"]
        var oldLibrary = Presets.all.filter { !newIDs.contains($0.presetID ?? "") }
        oldLibrary[0] = edited
        let oldDocument = ProfileDocument(activeProfileID: edited.id, profiles: oldLibrary)
        try persistence.save(oldDocument)
        let upgraded = ControlCenterStore(persistence: persistence)
        #expect(upgraded.missingPresets.count == 4, "existing twelve-profile library must offer exactly four additions")
        upgraded.addMissingPresets()
        #expect(Array(upgraded.document.profiles.prefix(12)) == oldLibrary, "four-preset expansion changed an existing profile")
        #expect(upgraded.document.profiles.count == 16)

        // A nearly-full existing library must reject the whole expansion atomically.
        let profiles = [edited] + (1..<125).map { Profile.blank(name: "Custom \($0)") }
        let capacityDocument = ProfileDocument(activeProfileID: edited.id, profiles: profiles)
        try persistence.save(capacityDocument)
        let capped = ControlCenterStore(persistence: persistence)
        capped.addMissingPresets()
        #expect(capped.document == capacityDocument, "capacity rejection partially added presets")
        #expect(!capped.canUndo)
    }

    @Test func duplicateNameImportMergesToOneRetainedDestinationForBothMergeModes() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // Duplicate imported names are valid documents. Both IDs must resolve to the
        // one retained destination, including forward references from other profiles.
        for mode in [ProfileImportMode.mergeKeepingExisting, .mergeReplacingNameConflicts] {
            let local = Profile.blank(name: "Local")
            let persistence = ProfilePersistence(url: directory.appendingPathComponent("merge-\(mode.rawValue).json"))
            let original = ProfileDocument(activeProfileID: local.id, profiles: [local])
            try persistence.save(original)
            let store = ControlCenterStore(persistence: persistence)
            var source = Profile.blank(name: "Source")
            let first = Profile.blank(name: "Destination")
            var second = Profile.blank(name: "destination")
            second.summary = "Replacement"
            source.bindings[0].action = ControlAction(kind: .profileSwitch, label: "First", parameter: first.id.uuidString)
            source.bindings[1].action = ControlAction(kind: .profileSwitch, label: "Second", parameter: second.id.uuidString)
            let imported = ProfileDocument(activeProfileID: source.id, profiles: [source, first, second])
            let input = directory.appendingPathComponent("duplicate-names-\(mode.rawValue).json")
            try persistence.exportDocument(imported, to: input)
            store.importProfiles(from: input, mode: mode)

            #expect(store.document.profiles.count == 3, "Duplicate-name merge lost a profile-switch destination in \(mode.rawValue)")
            let destination = try #require(store.document.profiles.first(where: { $0.name.lowercased() == "destination" }), "Duplicate-name merge lost a profile-switch destination in \(mode.rawValue)")
            let mergedSource = try #require(store.document.profiles.first(where: { $0.id == source.id }), "Duplicate-name merge lost a profile-switch destination in \(mode.rawValue)")
            #expect(mergedSource.bindings.prefix(2).allSatisfy { UUID(uuidString: $0.action.parameter) == destination.id }, "Duplicate-name merge lost a profile-switch destination in \(mode.rawValue)")
            #expect(destination.summary == (mode == .mergeKeepingExisting ? first.summary : "Replacement"), "Duplicate-name merge lost a profile-switch destination in \(mode.rawValue)")

            try ProfileValidator.validate(store.document)
            let merged = store.document
            store.undo()
            #expect(store.document == original, "Merge undo changed the original library")
            store.redo()
            #expect(store.document == merged, "Merge redo changed profile identities")
        }
    }

    @Test func storeLifecycleCoversSelectionSimulationImportExportAndCapacity() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        let store = ControlCenterStore(persistence: persistence)
        let originalCount = store.document.profiles.count

        let desktop = try #require(store.document.profiles.first(where: { $0.presetID == "desktop" }), "desktop fallback preset is missing")
        store.select(profileID: desktop.id, isManual: false)
        store.selectedControlID = ControlID.all.last!
        store.simulate(store.selectedControlID)
        #expect(store.activeProfile.presetID == "agent-deck", "preset profile switch did not resolve its preset ID")

        store.manualProfileOverrideID = nil
        store.recordForegroundApplication(bundleID: "com.microsoft.VSCode")
        #expect(store.activeProfile.presetID == "developer" && store.lastExternalBundleID == "com.microsoft.VSCode", "foreground app matching did not use the notification bundle")

        store.createProfile(named: "Self Test")
        #expect(store.document.profiles.count == originalCount + 1 && store.isDirty, "create did not mark a dirty profile library")

        store.renameActiveProfile(to: "Renamed Self Test")
        #expect(store.activeProfile.name == "Renamed Self Test", "rename failed")

        store.duplicateActiveProfile()
        #expect(store.document.profiles.count == originalCount + 2, "duplicate failed")

        store.undo()
        #expect(store.document.profiles.count == originalCount + 1, "undo failed")

        store.redo()
        #expect(store.document.profiles.count == originalCount + 2, "redo failed")

        store.save()
        #expect(!store.isDirty, "save did not clear dirty tracking")

        let exportURL = directory.appending(path: "export.json")
        store.exportProfiles(to: exportURL)
        store.importProfiles(from: exportURL, mode: .mergeKeepingExisting)
        #expect(store.document.profiles.count == originalCount + 2, "merge duplicated same-name profiles")

        let existingDesktopID = try #require(store.document.profiles.first(where: { $0.presetID == "desktop" })).id
        var importedSource = Profile.blank(name: "Imported Source")
        importedSource.id = existingDesktopID
        var importedDesktop = Profile.blank(name: "Desktop")
        importedDesktop.id = UUID()
        importedSource.replace(Binding(controlID: .keys[0], action: ControlAction(kind: .profileSwitch, label: "Imported destination", parameter: importedDesktop.id.uuidString)))
        let mergeURL = directory.appending(path: "merge.json")
        try ProfilePersistence(url: mergeURL).exportDocument(ProfileDocument(activeProfileID: importedSource.id, profiles: [importedSource, importedDesktop]), to: mergeURL)
        store.importProfiles(from: mergeURL, mode: .mergeKeepingExisting)
        let mergedSource = try #require(store.document.profiles.first(where: { $0.name == "Imported Source" }), "merged UUID profile switches were not remapped to retained destinations")
        #expect(mergedSource.id != existingDesktopID, "merged UUID profile switches were not remapped to retained destinations")
        #expect(mergedSource.binding(for: .keys[0])?.action.parameter.caseInsensitiveCompare(existingDesktopID.uuidString) == .orderedSame, "merged UUID profile switches were not remapped to retained destinations")

        store.simulate(.keys[0])
        #expect(!store.events.isEmpty && store.events[0].message.contains("Would run"), "simulation escaped the local dispatcher")

        while store.document.profiles.count < ProfilePersistence.maximumProfileCount { store.createProfile(named: "Capacity Test") }
        let cappedCount = store.document.profiles.count
        store.createProfile(named: "Over Capacity")
        #expect(store.document.profiles.count == cappedCount && store.statusMessage?.contains("at most") == true, "profile library cap was not enforced")
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "KM16ControlCenterTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }
}
