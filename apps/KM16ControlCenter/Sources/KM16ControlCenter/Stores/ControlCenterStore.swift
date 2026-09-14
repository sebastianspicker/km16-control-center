import Foundation
import Observation
import AppKit
import KM16ControlCore

enum ProfileImportMode: String, CaseIterable, Identifiable {
    case replace
    case mergeReplacingNameConflicts
    case mergeKeepingExisting

    var id: String { rawValue }
    var title: String {
        switch self {
        case .replace: "Replace current library"
        case .mergeReplacingNameConflicts: "Merge, replace same-name profiles"
        case .mergeKeepingExisting: "Merge, keep current same-name profiles"
        }
    }

    var detail: String {
        switch self {
        case .replace: "The imported library becomes the local working copy."
        case .mergeReplacingNameConflicts: "Imported profiles replace local profiles with the same name; other profiles are retained."
        case .mergeKeepingExisting: "Local profiles win when names conflict; imported unique profiles are added."
        }
    }
}

@MainActor @Observable
final class ControlCenterStore {
    private(set) var document: ProfileDocument
    var selectedControlID: ControlID = .keys[0]
    private(set) var events: [SimulationEvent] = []
    private(set) var statusMessage: String?
    private(set) var recoveryMessage: String?
    private(set) var undoHistory: [ProfileDocument] = []
    private(set) var redoHistory: [ProfileDocument] = []
    private(set) var savedDocument: ProfileDocument
    var automaticProfileMatchingEnabled = true
    var manualProfileOverrideID: UUID?
    var lastForegroundBundleID: String?
    var lastExternalBundleID: String?
    var closeConfirmationRequested = false
    var quitRequested = false
    let persistence: ProfilePersistence
    private let dispatcher: any ActionDispatching

    init(persistence: ProfilePersistence, dispatcher: any ActionDispatching = SimulationDispatcher()) {
        self.persistence = persistence
        self.dispatcher = dispatcher
        do {
            let loaded = try persistence.load()
            self.document = loaded
            self.savedDocument = loaded
            self.statusMessage = "Loaded saved software profiles."
            self.recoveryMessage = "Profile storage was validated before it was opened."
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            let factory = Presets.factoryDocument()
            self.document = factory
            self.savedDocument = factory
            self.statusMessage = "Using factory presets. Save to create a local file."
        } catch {
            let factory = Presets.factoryDocument()
            self.document = factory
            self.savedDocument = factory
            self.statusMessage = "Saved profiles were not loaded: \(error.localizedDescription). Existing file was left untouched."
            self.recoveryMessage = "Recovery started with factory presets. Review the existing profile file before replacing it."
        }
    }

    var orderedProfiles: [Profile] { ProfileOrganization.ordered(document.profiles) }

    var activeProfile: Profile {
        document.profiles.first(where: { $0.id == document.activeProfileID }) ?? fallbackProfile
    }

    private var fallbackProfile: Profile {
        document.profiles.first(where: { $0.presetID == "desktop" }) ?? document.profiles[0]
    }

    var selectedBinding: Binding { activeProfile.binding(for: selectedControlID)! }
    var isDirty: Bool { document != savedDocument }
    var canUndo: Bool { !undoHistory.isEmpty }
    var canRedo: Bool { !redoHistory.isEmpty }

    func select(profileID: UUID, isManual: Bool = true) {
        guard let profile = document.profiles.first(where: { $0.id == profileID }) else {
            statusMessage = "Ignored an unknown profile selection."
            return
        }
        mutate("Software profile switched to \(profile.name).") {
            document.activeProfileID = profileID
        }
        if isManual { manualProfileOverrideID = profileID }
    }

    func cycleProfile() {
        let profiles = orderedProfiles
        guard let index = profiles.firstIndex(where: { $0.id == document.activeProfileID }) else { return }
        select(profileID: profiles[(index + 1) % profiles.count].id)
    }

    func createProfile(named name: String = "Untitled Profile") {
        guard canAddProfile else { statusMessage = profileLimitMessage; return }
        let profile = Presets.blank(name: uniqueName(name))
        appendProfile(profile, message: "Created \(profile.name).")
    }

    func duplicateActiveProfile() {
        guard canAddProfile else { statusMessage = profileLimitMessage; return }
        var duplicate = activeProfile
        duplicate.id = UUID()
        duplicate.name = uniqueName("\(activeProfile.name) Copy")
        duplicate.presetID = nil
        appendProfile(duplicate, message: "Duplicated \(activeProfile.name).")
    }

    func renameActiveProfile(to name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { statusMessage = "A profile name cannot be blank."; return }
        guard cleaned == activeProfile.name || !document.profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) else {
            statusMessage = "A profile named \(cleaned) already exists."
            return
        }
        mutate("Renamed profile to \(cleaned).") {
            guard let index = document.profiles.firstIndex(where: { $0.id == document.activeProfileID }) else { return }
            document.profiles[index].name = cleaned
        }
    }

    func deleteActiveProfile() {
        guard document.profiles.count > 1 else { statusMessage = "Keep at least one profile in the library."; return }
        let deleting = activeProfile
        mutate("Deleted \(deleting.name).") {
            guard let index = document.profiles.firstIndex(where: { $0.id == deleting.id }) else { return }
            document.profiles.remove(at: index)
            document.activeProfileID = document.profiles[max(0, index - 1)].id
        }
        if manualProfileOverrideID == deleting.id { manualProfileOverrideID = nil }
    }

    func resetActiveProfile() {
        guard let presetID = activeProfile.presetID, let preset = Presets.preset(id: presetID) else {
            statusMessage = "This custom profile has no factory preset to restore."
            return
        }
        var replacement = preset
        replacement.id = activeProfile.id
        replacement.name = activeProfile.name
        mutate("Restored the \(preset.name) preset.") {
            guard let index = document.profiles.firstIndex(where: { $0.id == document.activeProfileID }) else { return }
            document.profiles[index] = replacement
        }
    }

    func addPreset(_ preset: Profile) {
        guard canAddProfile else { statusMessage = profileLimitMessage; return }
        var copy = preset
        copy.id = UUID()
        copy.name = uniqueName(preset.name)
        appendProfile(copy, message: "Added the \(preset.name) preset.")
    }

    var missingPresets: [Profile] {
        let installed = Set(document.profiles.compactMap(\.presetID))
        return Presets.all.filter { !installed.contains($0.presetID ?? "") }
    }

    func addMissingPresets() {
        let missing = missingPresets
        guard !missing.isEmpty else { statusMessage = "All presets are already in this library."; return }
        guard document.profiles.count + missing.count <= ProfilePersistence.maximumProfileCount else {
            statusMessage = profileLimitMessage; return
        }
        mutate("Added \(missing.count) missing presets.") {
            for preset in missing {
                var copy = preset
                copy.id = UUID()
                copy.name = uniqueName(preset.name)
                document.profiles.append(copy)
            }
        }
    }

    func updateSelected(action: ControlAction) {
        mutate("Edited \(selectedControlID.rawValue).") {
            guard let profileIndex = document.profiles.firstIndex(where: { $0.id == document.activeProfileID }),
                  let bindingIndex = document.profiles[profileIndex].bindings.firstIndex(where: { $0.controlID == selectedControlID }) else { return }
            document.profiles[profileIndex].bindings[bindingIndex].action = action
        }
    }

    func updateActiveProfile(summary: String? = nil, matchingBundleIDs: [String]? = nil) {
        mutate("Updated profile matching settings.") {
            guard let index = document.profiles.firstIndex(where: { $0.id == document.activeProfileID }) else { return }
            if let summary { document.profiles[index].summary = summary }
            if let matchingBundleIDs { document.profiles[index].matchingBundleIDs = matchingBundleIDs }
        }
    }

    func matchForegroundApplication(bundleID: String? = NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
        guard automaticProfileMatchingEnabled, manualProfileOverrideID == nil else { return }
        lastForegroundBundleID = bundleID
        if bundleID != Bundle.main.bundleIdentifier { lastExternalBundleID = bundleID }
        if let bundleID, let match = document.profiles.first(where: { $0.matchingBundleIDs.contains(bundleID) }) {
            guard match.id != document.activeProfileID else { return }
            select(profileID: match.id, isManual: false)
            statusMessage = "Matched foreground app \(bundleID) to \(match.name)."
        } else if fallbackProfile.id != document.activeProfileID {
            select(profileID: fallbackProfile.id, isManual: false)
            statusMessage = "No foreground-app profile matched; using \(fallbackProfile.name)."
        }
    }

    func recordForegroundApplication(bundleID: String?) {
        lastForegroundBundleID = bundleID
        if bundleID != Bundle.main.bundleIdentifier, let bundleID { lastExternalBundleID = bundleID }
        matchForegroundApplication(bundleID: bundleID)
    }

    func clearManualOverride() {
        manualProfileOverrideID = nil
        statusMessage = "Automatic foreground-app matching is available again."
        matchForegroundApplication()
    }

    func simulate(_ controlID: ControlID) {
        selectedControlID = controlID
        guard let binding = activeProfile.binding(for: controlID) else { return }
        let action = binding.action
        if action.kind.rawValue == "profileSwitch" {
            if action.parameter == "cycle-profile" { cycleProfile(); return }
            if let target = document.profiles.first(where: { $0.presetID == action.parameter || $0.name == action.parameter }) { select(profileID: target.id); return }
            if let target = document.profiles.first(where: { $0.id.uuidString.caseInsensitiveCompare(action.parameter) == .orderedSame }) { select(profileID: target.id); return }
            recordLiveResult("Profile switch target \(action.parameter) is unavailable.", for: controlID)
            return
        }
        record(dispatcher.dispatch(binding: binding, profile: activeProfile))
    }

    func replaySavedCapture(_ controls: [ControlID]) async {
        var replayed = 0
        for batchStart in stride(from: 0, to: controls.count, by: 64) {
            if Task.isCancelled { statusMessage = "Replay stopped after \(replayed) historical controls. No HID device was opened."; return }
            for controlID in controls[batchStart..<min(batchStart + 64, controls.count)] { simulate(controlID); replayed += 1 }
            await Task.yield()
        }
        statusMessage = "Replayed \(replayed) decoded historical controls in simulation only. No HID device was opened."
    }

    func recordLiveResult(_ message: String, for controlID: ControlID) {
        record(SimulationEvent(controlID: controlID, message: message))
        statusMessage = message
    }

    func save() {
        do {
            try persistence.save(document)
            savedDocument = document
            statusMessage = "Saved profiles to \(persistence.url.path)."
        } catch { statusMessage = "Save failed: \(error.localizedDescription)" }
    }

    func importProfiles(from url: URL, mode: ProfileImportMode) {
        do {
            let candidate = try persistence.importDocument(from: url)
            let result = mode == .replace ? candidate : merged(candidate, replaceNameConflicts: mode == .mergeReplacingNameConflicts)
            guard result.profiles.count <= ProfilePersistence.maximumProfileCount else {
                statusMessage = "Import would exceed the \(ProfilePersistence.maximumProfileCount)-profile limit; the current library is unchanged."
                return
            }
            replaceDocument(result, message: "Imported \(candidate.profiles.count) profiles using \(mode.title.lowercased()). Save to persist the working copy.")
        } catch { statusMessage = "Import rejected; current profiles are unchanged: \(error.localizedDescription)" }
    }

    func exportProfiles(to url: URL) {
        do { try persistence.exportDocument(document, to: url); statusMessage = "Exported profiles to \(url.lastPathComponent)." }
        catch { statusMessage = "Export failed: \(error.localizedDescription)" }
    }

    func undo() {
        guard let previous = undoHistory.popLast() else { return }
        redoHistory.append(document)
        document = previous
        normalizeTransientState()
        statusMessage = "Undid the last profile edit."
    }

    func redo() {
        guard let next = redoHistory.popLast() else { return }
        undoHistory.append(document)
        document = next
        normalizeTransientState()
        statusMessage = "Redid the profile edit."
    }

    func discardUnsavedChanges() {
        document = savedDocument
        normalizeTransientState()
        undoHistory.removeAll(); redoHistory.removeAll()
        statusMessage = "Discarded unsaved edits."
    }

    func cancelCloseRequest() {
        closeConfirmationRequested = false
        quitRequested = false
    }

    func revealRecoveryFiles() {
        do {
            let urls = try persistence.recoveryURLs()
            guard !urls.isEmpty else { statusMessage = "No durable recovery files are available."; return }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
            statusMessage = "Opened \(urls.count) recovery file\(urls.count == 1 ? "" : "s") in Finder."
        } catch { statusMessage = "Could not list recovery files: \(error.localizedDescription)" }
    }

    private func appendProfile(_ profile: Profile, message: String) {
        mutate(message) {
            document.profiles.append(profile)
            document.activeProfileID = profile.id
        }
    }

    private func mutate(_ message: String, _ change: () -> Void) {
        let before = document
        change()
        guard document != before else { return }
        appendUndo(before)
        redoHistory.removeAll()
        statusMessage = "\(message) Select Save to persist this local change."
    }

    private func replaceDocument(_ replacement: ProfileDocument, message: String) {
        let before = document
        document = replacement
        normalizeTransientState()
        appendUndo(before); redoHistory.removeAll()
        statusMessage = message
    }

    private func merged(_ imported: ProfileDocument, replaceNameConflicts: Bool) -> ProfileDocument {
        var profiles = document.profiles
        var destinations: [UUID: UUID] = [:]
        // Reserve names and identities before remapping forward references. Multiple
        // imported profiles with the same name share the destination retained by
        // the chosen merge policy, even when that name is new to the library.
        var reservedProfiles = profiles
        for importedProfile in imported.profiles {
            if let existing = reservedProfiles.first(where: { $0.name.localizedCaseInsensitiveCompare(importedProfile.name) == .orderedSame }) {
                destinations[importedProfile.id] = existing.id
            } else {
                var reserved = importedProfile
                if reservedProfiles.contains(where: { $0.id == importedProfile.id }) { reserved.id = UUID() }
                destinations[importedProfile.id] = reserved.id
                reservedProfiles.append(reserved)
            }
        }
        for importedProfile in imported.profiles {
            let sameNameIndex = profiles.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(importedProfile.name) == .orderedSame })
            if sameNameIndex != nil && !replaceNameConflicts { continue }
            var mapped = importedProfile
            mapped.id = destinations[importedProfile.id]!
            mapped.bindings = mapped.bindings.map { binding in
                var binding = binding
                if binding.action.kind == .profileSwitch,
                   let sourceID = UUID(uuidString: binding.action.parameter),
                   let destinationID = destinations[sourceID] {
                    binding.action.parameter = destinationID.uuidString
                }
                return binding
            }
            if let sameNameIndex { profiles[sameNameIndex] = mapped }
            else { profiles.append(mapped) }
        }
        return ProfileDocument(activeProfileID: document.activeProfileID, profiles: profiles)
    }

    private func uniqueName(_ proposed: String) -> String {
        guard document.profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare(proposed) == .orderedSame }) else { return proposed }
        var number = 2
        while document.profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare("\(proposed) \(number)") == .orderedSame }) { number += 1 }
        return "\(proposed) \(number)"
    }

    private var canAddProfile: Bool { document.profiles.count < ProfilePersistence.maximumProfileCount }
    private var profileLimitMessage: String { "A profile library can contain at most \(ProfilePersistence.maximumProfileCount) profiles." }

    private func appendUndo(_ document: ProfileDocument) {
        undoHistory.append(document)
        if undoHistory.count > 100 { undoHistory.removeFirst(undoHistory.count - 100) }
    }

    private func record(_ event: SimulationEvent) {
        events.insert(event, at: 0)
        if events.count > 80 { events.removeLast(events.count - 80) }
    }

    private func normalizeTransientState() {
        if let manualProfileOverrideID, !document.profiles.contains(where: { $0.id == manualProfileOverrideID }) {
            self.manualProfileOverrideID = nil
        }
        if !document.profiles.contains(where: { $0.id == document.activeProfileID }) {
            document.activeProfileID = fallbackProfile.id
        }
    }
}
