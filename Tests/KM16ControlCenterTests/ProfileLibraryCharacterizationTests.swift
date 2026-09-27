import Foundation
import Testing
@testable import KM16ControlCenter
import KM16ControlCore
import KM16Presets

/// Pins the observable behaviour of `ControlCenterStore`'s profile-library editing rules
/// before those rules move into `KM16ControlCore.ProfileLibrary`. Every expectation here
/// was captured by running the current implementation; none is aspirational.
@MainActor
@Suite struct ProfileLibraryCharacterizationTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "KM16ProfileLibraryCharacterization-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private func makeStore() -> ControlCenterStore {
        ControlCenterStore(persistence: ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json")))
    }

    // MARK: select() and mutate()

    @Test func selectingTheActiveProfileIsANoOpThatAddsNoUndoEntry() {
        let store = makeStore()
        let currentID = store.document.activeProfileID
        store.select(profileID: currentID)
        #expect(!store.canUndo)
        #expect(!store.isDirty)
    }

    @Test func selectingADifferentProfileAddsUndoAndDirtiesTheDocument() {
        let store = makeStore()
        let other = store.document.profiles.first { $0.id != store.document.activeProfileID }!
        store.select(profileID: other.id)
        #expect(store.canUndo)
        #expect(store.isDirty)
        #expect(store.statusMessage == "Software profile switched to \(other.name). Select Save to persist this local change.")
        #expect(store.manualProfileOverrideID == other.id, "select(isManual: true) is the default")
    }

    @Test func automaticSelectionAlsoGoesThroughMutateButOverwritesTheMutateStatusMessage() {
        let store = makeStore()
        let target = store.document.profiles.first { $0.matchingBundleIDs.contains("com.microsoft.VSCode") }!
        store.recordForegroundApplication(bundleID: "com.microsoft.VSCode")
        #expect(store.canUndo, "automatic foreground matching still records an undo entry")
        #expect(store.isDirty)
        #expect(store.activeProfile.id == target.id)
        #expect(store.manualProfileOverrideID == nil, "automatic selection must not set a manual override")
        // matchForegroundApplication overwrites mutate's "... Select Save ..." suffix.
        #expect(store.statusMessage == "Matched foreground app com.microsoft.VSCode to \(target.name).")
    }

    // MARK: create / duplicate / rename / delete / reset messages

    @Test func createRecordsExactStatusMessage() {
        let store = makeStore()
        store.createProfile(named: "Self Test")
        #expect(store.statusMessage == "Created Self Test. Select Save to persist this local change.")
    }

    @Test func duplicateUsesTheOriginalNameInItsMessageAndClearsPresetID() {
        let store = makeStore()
        let desktop = store.document.profiles.first { $0.presetID == "desktop" }!
        store.select(profileID: desktop.id, isManual: false)
        store.duplicateActiveProfile()
        #expect(store.statusMessage == "Duplicated Desktop. Select Save to persist this local change.")
        #expect(store.activeProfile.name == "Desktop Copy")
        #expect(store.activeProfile.presetID == nil)
    }

    @Test func renameRecordsExactStatusMessage() {
        let store = makeStore()
        store.createProfile(named: "Renamable")
        store.renameActiveProfile(to: "Renamed")
        #expect(store.statusMessage == "Renamed profile to Renamed. Select Save to persist this local change.")
    }

    @Test func blankRenameIsRejectedWithoutMutating() {
        let store = makeStore()
        let before = store.document
        store.renameActiveProfile(to: "   ")
        #expect(store.statusMessage == "A profile name cannot be blank.")
        #expect(store.document == before)
        #expect(!store.canUndo)
    }

    @Test func renameOntoAnotherProfilesNameIsRejected() {
        let store = makeStore()
        let desktop = store.document.profiles.first { $0.presetID == "desktop" }!
        let other = store.document.profiles.first { $0.presetID == "agent-deck" }!
        store.select(profileID: other.id, isManual: false)
        store.renameActiveProfile(to: desktop.name)
        #expect(store.statusMessage == "A profile named \(desktop.name) already exists.")
        #expect(store.activeProfile.name == other.name)
    }

    /// Characterized as-is: the active profile's own current name always matches the
    /// case-insensitive lookup (it is a member of `document.profiles`), so a rename that
    /// changes only the case of the active profile's own name is rejected as a duplicate,
    /// not accepted. This is the observed behaviour of the current implementation.
    @Test func caseOnlyRenameOfTheActiveProfileItselfIsRejectedAsADuplicate() {
        let store = makeStore()
        let desktop = store.document.profiles.first { $0.presetID == "desktop" }!
        store.select(profileID: desktop.id, isManual: false)
        store.renameActiveProfile(to: "DESKTOP")
        #expect(store.statusMessage == "A profile named DESKTOP already exists.")
        #expect(store.activeProfile.name == "Desktop")
    }

    @Test func exactCaseRenameIsANoOpAllowedByTheEqualityShortCircuit() {
        let store = makeStore()
        let desktop = store.document.profiles.first { $0.presetID == "desktop" }!
        store.select(profileID: desktop.id, isManual: false)
        let before = store.document
        store.renameActiveProfile(to: "Desktop")
        #expect(store.document == before, "renaming to the identical name changes nothing")
        #expect(!store.canUndo)
    }

    @Test func deleteSelectsThePreviousProfileAndClearsAMatchingOverride() {
        let store = makeStore()
        store.createProfile(named: "A")
        store.createProfile(named: "B")
        store.createProfile(named: "C")
        // Delete a middle profile so "previous" and "next" select different profiles.
        let count = store.document.profiles.count
        let deletingID = store.document.profiles[count - 2].id // "B"
        let expectedPreviousID = store.document.profiles[count - 3].id // "A"
        store.select(profileID: deletingID)
        store.deleteActiveProfile()
        #expect(store.statusMessage == "Deleted B. Select Save to persist this local change.")
        #expect(store.activeProfile.id == expectedPreviousID)
        #expect(store.manualProfileOverrideID == nil)
    }

    @Test func deletingTheLastRemainingProfileIsRefused() {
        let store = makeStore()
        var library = store.document
        library.profiles = [library.profiles[0]]
        library.activeProfileID = library.profiles[0].id
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try? persistence.save(library)
        let soloStore = ControlCenterStore(persistence: persistence)
        #expect(soloStore.document.profiles.count == 1)
        let before = soloStore.document
        soloStore.deleteActiveProfile()
        #expect(soloStore.statusMessage == "Keep at least one profile in the library.")
        #expect(soloStore.document == before)
        #expect(!soloStore.canUndo)
    }

    @Test func resetFromPresetKeepsIDAndNameAndRestoresOtherFields() {
        let store = makeStore()
        let desktop = store.document.profiles.first { $0.presetID == "desktop" }!
        store.select(profileID: desktop.id, isManual: false)
        store.renameActiveProfile(to: "My Desktop")
        store.updateActiveProfile(summary: "edited")
        let idBefore = store.activeProfile.id
        store.resetActiveProfile()
        #expect(store.statusMessage == "Restored the Desktop preset. Select Save to persist this local change.")
        #expect(store.activeProfile.id == idBefore)
        #expect(store.activeProfile.name == "My Desktop")
        #expect(store.activeProfile.summary == Presets.desktop().summary)
    }

    @Test func resetOfACustomProfileGivesItsOwnMessage() {
        let store = makeStore()
        store.createProfile(named: "Custom")
        let before = store.document
        let undoCountBefore = store.undoHistory.count
        store.resetActiveProfile()
        #expect(store.statusMessage == "This custom profile has no factory preset to restore.")
        #expect(store.document == before)
        #expect(store.undoHistory.count == undoCountBefore, "the refused reset must not add an undo entry")
    }

    // MARK: uniqueName

    @Test func uniqueNameGeneratesCaseInsensitiveSequentialSuffixes() {
        let store = makeStore()
        store.createProfile(named: "X")
        #expect(store.activeProfile.name == "X")
        store.createProfile(named: "x")
        #expect(store.activeProfile.name == "x 2")
        store.createProfile(named: "X")
        #expect(store.activeProfile.name == "X 3")
    }

    @Test func addMissingPresetsReEvaluatesNamesAgainstTheGrowingDocument() throws {
        let directory = temporaryDirectory()
        var profiles = [Presets.desktop()]
        profiles.append(Profile.blank(name: "Agent Deck"))
        profiles.append(Profile.blank(name: "Agent Deck 2"))
        let persistence = ProfilePersistence(url: directory.appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: profiles[0].id, profiles: profiles))
        let store = ControlCenterStore(persistence: persistence)
        store.addMissingPresets()
        let added = try #require(store.document.profiles.first { $0.presetID == "agent-deck" })
        #expect(added.name == "Agent Deck 3")
    }

    // MARK: capacity

    @Test func capacityLimitBlocksCreationWithItsExactMessage() {
        let store = makeStore()
        while store.document.profiles.count < ProfilePersistence.maximumProfileCount {
            store.createProfile(named: "Cap \(store.document.profiles.count)")
        }
        let before = store.document
        store.createProfile(named: "Over")
        #expect(store.document == before)
        #expect(store.statusMessage == "A profile library can contain at most \(ProfilePersistence.maximumProfileCount) profiles.")
    }

    // MARK: profile-switch resolution

    @Test func cycleProfileParameterCyclesInProfileOrganizationOrder() throws {
        var alpha = Profile.blank(name: "Alpha")
        var mid = Profile.blank(name: "Mid")
        let zeta = Profile.blank(name: "Zeta")
        alpha.bindings[0].action = ControlAction(kind: .profileSwitch, label: "cycle", parameter: "cycle-profile")
        mid.bindings[0].action = ControlAction(kind: .profileSwitch, label: "cycle", parameter: "cycle-profile")
        // Array order deliberately differs from ProfileOrganization's alphabetical .custom order.
        let doc = ProfileDocument(activeProfileID: alpha.id, profiles: [zeta, alpha, mid])
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(doc)
        let store = ControlCenterStore(persistence: persistence)
        #expect(store.orderedProfiles.map(\.name) == ["Alpha", "Mid", "Zeta"])
        store.selectedControlID = .keys[0]
        store.simulate(.keys[0])
        #expect(store.activeProfile.name == "Mid")
    }

    @Test func presetIDOrNameMatchTakesPrecedenceOverUUIDMatch() throws {
        var profileA = Profile.blank(name: "AAAA")
        let profileB = Profile.blank(name: profileA.id.uuidString)
        profileA.bindings[0].action = ControlAction(kind: .profileSwitch, label: "switch", parameter: profileA.id.uuidString)
        let doc = ProfileDocument(activeProfileID: profileA.id, profiles: [profileA, profileB])
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(doc)
        let store = ControlCenterStore(persistence: persistence)
        store.selectedControlID = .keys[0]
        store.simulate(.keys[0])
        // profileB's NAME equals the switch parameter, and profileA's UUID also equals it;
        // the name/presetID lookup runs first, so profileB (the name match) wins.
        #expect(store.activeProfile.id == profileB.id)
        #expect(store.manualProfileOverrideID == profileB.id, "a resolved profile switch is a manual selection")
    }

    @Test func unknownSwitchTargetRecordsItsUnavailableMessage() throws {
        var profile = Profile.blank(name: "Solo")
        profile.bindings[0].action = ControlAction(kind: .profileSwitch, label: "switch", parameter: "does-not-exist")
        let doc = ProfileDocument(activeProfileID: profile.id, profiles: [profile])
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(doc)
        let store = ControlCenterStore(persistence: persistence)
        store.selectedControlID = .keys[0]
        store.simulate(.keys[0])
        #expect(store.statusMessage == "Profile switch target does-not-exist is unavailable.")
        #expect(store.events[0].message == "Profile switch target does-not-exist is unavailable.")
    }

    // MARK: merge

    @Test func mergeKeepsTheCurrentActiveProfileID() throws {
        let local = Profile.blank(name: "Local")
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)
        let imported = Profile.blank(name: "Imported")
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: imported.id, profiles: [imported]), to: importURL)
        store.importProfiles(from: importURL, mode: .mergeKeepingExisting)
        #expect(store.document.activeProfileID == local.id)
    }

    @Test func replaceModeNormalizesActiveProfileIDAndClearsAStaleOverride() throws {
        let local = Profile.blank(name: "Local")
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)
        store.manualProfileOverrideID = local.id
        let imported = Profile.blank(name: "Imported")
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: imported.id, profiles: [imported]), to: importURL)
        store.importProfiles(from: importURL, mode: .replace)
        #expect(store.document.activeProfileID == imported.id)
        #expect(store.manualProfileOverrideID == nil, "the override pointed at a profile the replace removed")
    }

    @Test func mergeKeepingExistingKeepsLocalOnNameConflict() throws {
        var local = Profile.blank(name: "Shared")
        local.summary = "local summary"
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)
        var imported = Profile.blank(name: "shared")
        imported.summary = "imported summary"
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: imported.id, profiles: [imported]), to: importURL)
        store.importProfiles(from: importURL, mode: .mergeKeepingExisting)
        #expect(store.document.profiles.count == 1)
        #expect(store.document.profiles[0].summary == "local summary")
    }

    @Test func mergeReplacingNameConflictsReplacesLocalOnNameConflict() throws {
        var local = Profile.blank(name: "Shared")
        local.summary = "local summary"
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)
        var imported = Profile.blank(name: "shared")
        imported.summary = "imported summary"
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: imported.id, profiles: [imported]), to: importURL)
        store.importProfiles(from: importURL, mode: .mergeReplacingNameConflicts)
        #expect(store.document.profiles.count == 1)
        #expect(store.document.profiles[0].summary == "imported summary")
        #expect(store.document.profiles[0].id == local.id, "the retained destination keeps the local profile's identity")
    }

    @Test func mergeRemapsForwardProfileSwitchReferences() throws {
        let local = Profile.blank(name: "Local")
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)

        var source = Profile.blank(name: "Source")
        let destination = Profile.blank(name: "Destination")
        source.bindings[0].action = ControlAction(kind: .profileSwitch, label: "go", parameter: destination.id.uuidString)
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: source.id, profiles: [source, destination]), to: importURL)
        store.importProfiles(from: importURL, mode: .mergeKeepingExisting)

        let mergedSource = try #require(store.document.profiles.first { $0.name == "Source" })
        let mergedDestination = try #require(store.document.profiles.first { $0.name == "Destination" })
        #expect(UUID(uuidString: mergedSource.bindings[0].action.parameter) == mergedDestination.id)
    }

    @Test func mergeGivesAnIDCollisionWithAnExistingProfileAFreshUUID() throws {
        let local = Profile.blank(name: "Local")
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)

        var collidingImport = Profile.blank(name: "Imported Name")
        collidingImport.id = local.id // same identity, different name: not treated as the same profile by name
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: collidingImport.id, profiles: [collidingImport]), to: importURL)
        store.importProfiles(from: importURL, mode: .mergeKeepingExisting)

        #expect(store.document.profiles.count == 2)
        let importedProfile = try #require(store.document.profiles.first { $0.name == "Imported Name" })
        #expect(importedProfile.id != local.id, "an id collision with an existing profile must be assigned a fresh UUID")
    }

    @Test func importExceedingTheProfileLimitIsRejectedAtomically() throws {
        let local = Profile.blank(name: "Local")
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)

        let overflow = (0..<ProfilePersistence.maximumProfileCount).map { Profile.blank(name: "Overflow \($0)") }
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: overflow[0].id, profiles: overflow), to: importURL)
        let before = store.document
        store.importProfiles(from: importURL, mode: .mergeKeepingExisting)

        #expect(store.document == before, "an import that would exceed the profile limit must change nothing")
        #expect(store.statusMessage == "Import would exceed the \(ProfilePersistence.maximumProfileCount)-profile limit; the current library is unchanged.")
        #expect(!store.canUndo)
    }

    // MARK: foreground matching

    @Test func matchForegroundApplicationDoesNothingWhenAutomaticMatchingIsDisabled() {
        let store = makeStore()
        store.automaticProfileMatchingEnabled = false
        let before = store.document
        store.matchForegroundApplication(bundleID: "com.microsoft.VSCode")
        #expect(store.document == before)
    }

    @Test func matchForegroundApplicationDoesNothingWhenAManualOverrideIsSet() {
        let store = makeStore()
        store.manualProfileOverrideID = store.document.profiles.first { $0.presetID != "desktop" }!.id
        let before = store.document
        store.matchForegroundApplication(bundleID: "com.microsoft.VSCode")
        #expect(store.document == before)
    }

    @Test func unmatchedForegroundApplicationFallsBackToDesktop() {
        let store = makeStore()
        let desktop = store.document.profiles.first { $0.presetID == "desktop" }!
        store.select(profileID: store.document.profiles.first { $0.presetID == "agent-deck" }!.id, isManual: false)
        store.matchForegroundApplication(bundleID: "com.example.unmatched")
        #expect(store.activeProfile.id == desktop.id)
        #expect(store.statusMessage == "No foreground-app profile matched; using Desktop.")
    }

    // MARK: undo / redo / events capacity

    @Test func undoHistoryIsCappedAtOneHundredEntries() {
        let store = makeStore()
        for index in 0..<150 { store.createProfile(named: "U \(index)") }
        #expect(store.undoHistory.count == 100)
    }

    @Test func eventsAreCappedAtEightyNewestFirst() {
        let store = makeStore()
        for _ in 0..<100 {
            store.selectedControlID = .keys[0]
            store.simulate(.keys[0])
        }
        #expect(store.events.count == 80)
    }

    @Test func discardUnsavedChangesClearsBothUndoAndRedoStacks() {
        let store = makeStore()
        store.createProfile(named: "A")
        store.undo()
        #expect(store.canRedo)
        store.createProfile(named: "B")
        store.discardUnsavedChanges()
        #expect(!store.canUndo)
        #expect(!store.canRedo)
        #expect(store.statusMessage == "Discarded unsaved edits.")
    }

    // MARK: import status messages (replace and merge)

    @Test func importReplaceRecordsItsExactStatusMessage() throws {
        let local = Profile.blank(name: "Local")
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)
        let imported = Profile.blank(name: "Imported")
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: imported.id, profiles: [imported]), to: importURL)
        store.importProfiles(from: importURL, mode: .replace)
        #expect(store.statusMessage == "Imported 1 profiles using replace current library. Save to persist the working copy.")
    }

    @Test func importMergeRecordsItsExactStatusMessage() throws {
        let local = Profile.blank(name: "Local")
        let persistence = ProfilePersistence(url: temporaryDirectory().appending(path: "profiles.json"))
        try persistence.save(ProfileDocument(activeProfileID: local.id, profiles: [local]))
        let store = ControlCenterStore(persistence: persistence)
        let imported = Profile.blank(name: "Imported")
        let importURL = persistence.url.deletingLastPathComponent().appendingPathComponent("import.json")
        try persistence.exportDocument(ProfileDocument(activeProfileID: imported.id, profiles: [imported]), to: importURL)
        store.importProfiles(from: importURL, mode: .mergeKeepingExisting)
        #expect(store.statusMessage == "Imported 1 profiles using merge, keep current same-name profiles. Save to persist the working copy.")
    }
}
