import Foundation
import Observation
import AppKit
import KM16ControlCore
import KM16Presets
import KM16Integrations

extension ProfileImportMode {
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

/// A save or export failure that needs the user's attention, not just a status-bar line.
struct LibraryProblem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    /// The file changed on disk; the user may choose to replace it.
    var offersOverwrite = false
}

@MainActor @Observable
final class ControlCenterStore {
    private(set) var document: ProfileDocument
    var selectedControlID: ControlID = .keys[0]
    private(set) var events: [SimulationEvent] = []
    private(set) var statusMessage: String?
    private(set) var recoveryMessage: String?
    private(set) var libraryProblem: LibraryProblem?
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
    private let dispatcher: SimulationDispatcher
    private let ownBundleIdentifier: String?
    /// The profiles file as this store last loaded or saved it (nil: no file).
    @ObservationIgnored private var knownFileData: Data?

    init(persistence: ProfilePersistence, dispatcher: SimulationDispatcher = SimulationDispatcher(), ownBundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        self.persistence = persistence
        self.dispatcher = dispatcher
        self.ownBundleIdentifier = ownBundleIdentifier
        do {
            let loaded = try persistence.load()
            self.document = loaded
            self.savedDocument = loaded
            self.statusMessage = "Loaded saved software profiles."
            self.recoveryMessage = "Profile storage was validated before it was opened."
            Diagnostics.library.info("Loaded \(loaded.profiles.count) profiles.")
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            let factory = Presets.factoryDocument()
            self.document = factory
            self.savedDocument = factory
            self.statusMessage = "Using factory presets. Save to create a local file."
            Diagnostics.library.notice("No profiles file yet; using factory presets.")
        } catch {
            let factory = Presets.factoryDocument()
            self.document = factory
            self.savedDocument = factory
            self.statusMessage = "Saved profiles were not loaded: \(error.localizedDescription). Existing file was left untouched."
            self.recoveryMessage = "Recovery started with factory presets. Review the existing profile file before replacing it."
            Diagnostics.library.error("Saved profiles were not loaded; started with factory presets: [\(IntegrationLog.category(of: error), privacy: .public)] \(error.localizedDescription, privacy: .private)")
        }
        // If the file cannot be read now, the first Save treats it as changed and asks first.
        knownFileData = (try? persistence.currentFileData()) ?? nil
    }

    var orderedProfiles: [Profile] { ProfileOrganization.ordered(document.profiles) }

    var activeProfile: Profile {
        document.profiles.first(where: { $0.id == document.activeProfileID }) ?? fallbackProfile
    }

    private var fallbackProfile: Profile {
        document.profiles.first(where: { $0.presetID == "desktop" }) ?? document.profiles[0]
    }

    var selectedBinding: Binding { activeProfile.binding(for: selectedControlID)! }
    /// The active profile is saved with the library but is a selection, not an edit.
    var isDirty: Bool { document.schemaVersion != savedDocument.schemaVersion || document.profiles != savedDocument.profiles }
    var canUndo: Bool { !undoHistory.isEmpty }
    var canRedo: Bool { !redoHistory.isEmpty }

    func select(profileID: UUID, isManual: Bool = true) {
        guard let profile = document.profiles.first(where: { $0.id == profileID }) else {
            statusMessage = "Ignored an unknown profile selection."
            return
        }
        if isManual { manualProfileOverrideID = profileID }
        // Selection bypasses mutate: it neither enters undo history nor clears redo.
        guard document.activeProfileID != profileID else { return }
        document.activeProfileID = profileID
        statusMessage = "Software profile switched to \(profile.name)."
    }

    func cycleProfile() {
        let profiles = orderedProfiles
        guard let index = profiles.firstIndex(where: { $0.id == document.activeProfileID }) else { return }
        select(profileID: profiles[(index + 1) % profiles.count].id)
    }

    func createProfile(named name: String = "Untitled Profile") {
        var library = ProfileLibrary(document: document)
        guard library.canAddProfiles() else { statusMessage = profileLimitMessage; return }
        let profile = library.createProfile(named: name)
        mutate("Created \(profile.name).") { document = library.document }
    }

    func duplicateActiveProfile() {
        var library = ProfileLibrary(document: document)
        guard library.canAddProfiles() else { statusMessage = profileLimitMessage; return }
        let originalName = activeProfile.name
        guard library.duplicateActiveProfile() != nil else { return }
        mutate("Duplicated \(originalName).") { document = library.document }
    }

    func renameActiveProfile(to name: String) {
        switch ProfileLibrary(document: document).validateRename(to: name) {
        case .failure(.blank):
            statusMessage = "A profile name cannot be blank."
        case .failure(.duplicate(let cleaned)):
            statusMessage = "A profile named \(cleaned) already exists."
        case .success(let cleaned):
            mutate("Renamed profile to \(cleaned).") {
                var library = ProfileLibrary(document: document)
                library.renameActiveProfile(to: cleaned)
                document = library.document
            }
        }
    }

    func deleteActiveProfile() {
        var library = ProfileLibrary(document: document)
        guard let deleted = library.deleteActiveProfile() else {
            statusMessage = "Keep at least one profile in the library."
            return
        }
        mutate("Deleted \(deleted.name).") { document = library.document }
        if manualProfileOverrideID == deleted.id { manualProfileOverrideID = nil }
    }

    func resetActiveProfile() {
        guard let presetID = activeProfile.presetID, let preset = Presets.preset(id: presetID) else {
            statusMessage = "This custom profile has no factory preset to restore."
            return
        }
        var library = ProfileLibrary(document: document)
        guard library.resetActiveProfile(preset: preset) else { return }
        mutate("Restored the \(preset.name) preset.") { document = library.document }
    }

    func addPreset(_ preset: Profile) {
        var library = ProfileLibrary(document: document)
        guard library.canAddProfiles() else { statusMessage = profileLimitMessage; return }
        library.addPreset(preset)
        mutate("Added the \(preset.name) preset.") { document = library.document }
    }

    var missingPresets: [Profile] {
        ProfileLibrary(document: document).missingPresets(from: Presets.all)
    }

    func addMissingPresets() {
        let missing = missingPresets
        guard !missing.isEmpty else { statusMessage = "All presets are already in this library."; return }
        var library = ProfileLibrary(document: document)
        guard library.canAddProfiles(missing.count) else { statusMessage = profileLimitMessage; return }
        library.addPresets(missing)
        mutate("Added \(missing.count) missing presets.") { document = library.document }
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
        let isOwnApplication = bundleID != nil && bundleID == ownBundleIdentifier
        if !isOwnApplication { lastExternalBundleID = bundleID }
        // Activating this app is not a foreground change: keep matching the app the user came from.
        let matchedBundleID = isOwnApplication ? lastExternalBundleID : bundleID
        guard !isOwnApplication || matchedBundleID != nil else { return }
        switch ProfileLibrary(document: document).resolveForegroundMatch(bundleID: matchedBundleID, fallback: fallbackProfile) {
        case .matched(let matchedBundleID, let match):
            select(profileID: match.id, isManual: false)
            statusMessage = "Matched foreground app \(matchedBundleID) to \(match.name)."
        case .fallback(let fallback):
            select(profileID: fallback.id, isManual: false)
            statusMessage = "No foreground-app profile matched; using \(fallback.name)."
        case .unchanged:
            break
        }
    }

    func recordForegroundApplication(bundleID: String?) {
        lastForegroundBundleID = bundleID
        if bundleID != ownBundleIdentifier, let bundleID { lastExternalBundleID = bundleID }
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
        if action.kind == .profileSwitch {
            switch ProfileLibrary(document: document).resolveProfileSwitch(parameter: action.parameter) {
            case .cycle: cycleProfile()
            case .profile(let id): select(profileID: id)
            case .unavailable: recordLiveResult("Profile switch target \(action.parameter) is unavailable.", for: controlID)
            }
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

    @discardableResult
    func save(overwritingExternalChanges: Bool = false) -> Bool {
        guard overwritingExternalChanges || !fileChangedOnDisk() else {
            statusMessage = "Save stopped: the profiles file changed on disk."
            Diagnostics.library.notice("Save stopped: the profiles file changed on disk.")
            libraryProblem = LibraryProblem(
                title: "Profiles Changed on Disk",
                message: "\(persistence.url.lastPathComponent) was changed by another KM16 Control Center window or app since it was opened here. Nothing was written. Overwrite replaces that version with this one and keeps a copy of it next to the file (\(persistence.backupURL.lastPathComponent), or a recovery copy if that version is invalid).",
                offersOverwrite: true
            )
            return false
        }
        do {
            try persistence.save(document)
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
            Diagnostics.library.error("Save failed: [\(IntegrationLog.category(of: error), privacy: .public)] \(error.localizedDescription, privacy: .private)")
            reportLibraryProblem("Profiles Not Saved", error: error, outcome: "Nothing was written and your edits are still open.")
            return false
        }
        savedDocument = document
        // If the new file cannot be read back, the next Save asks before replacing it.
        knownFileData = (try? persistence.currentFileData()) ?? nil
        statusMessage = "Saved profiles to \(persistence.url.path)."
        Diagnostics.library.info("Saved \(self.document.profiles.count) profiles\(overwritingExternalChanges ? " over external changes" : "", privacy: .public).")
        return true
    }

    /// Save from the unsaved-changes dialog. A failed save also cancels a pending quit, so the
    /// dialog does not reappear until the reported problem is fixed.
    func saveForClose() -> Bool {
        guard save() else { cancelCloseRequest(); return false }
        return true
    }

    /// Clears the problem the alert showed; a newer problem (for example a failed Overwrite) stays.
    func dismissLibraryProblem(_ id: UUID) { if libraryProblem?.id == id { libraryProblem = nil } }

    private func fileChangedOnDisk() -> Bool {
        do { return try persistence.currentFileData() != knownFileData }
        catch { return true }
    }

    func importProfiles(from url: URL, mode: ProfileImportMode) {
        do {
            let candidate = try persistence.importDocument(from: url)
            let result = mode == .replace ? candidate : ProfileLibrary(document: document).merged(with: candidate, replaceNameConflicts: mode == .mergeReplacingNameConflicts)
            guard result.profiles.count <= ProfilePersistence.maximumProfileCount else {
                statusMessage = "Import would exceed the \(ProfilePersistence.maximumProfileCount)-profile limit; the current library is unchanged."
                return
            }
            replaceDocument(result, message: "Imported \(candidate.profiles.count) profiles using \(mode.title.lowercased()). Save to persist the working copy.")
            Diagnostics.library.info("Imported \(candidate.profiles.count) profiles (\(mode.rawValue, privacy: .public)).")
        } catch {
            statusMessage = "Import rejected; current profiles are unchanged: \(error.localizedDescription)"
            Diagnostics.library.error("Import rejected: [\(IntegrationLog.category(of: error), privacy: .public)] \(error.localizedDescription, privacy: .private)")
        }
    }

    func exportProfiles(to url: URL) {
        do { try persistence.exportDocument(document, to: url); statusMessage = "Exported profiles to \(url.lastPathComponent)." }
        catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
            Diagnostics.library.error("Export failed: [\(IntegrationLog.category(of: error), privacy: .public)] \(error.localizedDescription, privacy: .private)")
            reportLibraryProblem("Profiles Not Exported", error: error, outcome: "No file was written.")
        }
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
        // Discarding edits is not a selection change: keep the shown profile if it still exists.
        let selection = document.activeProfileID
        document = savedDocument
        if document.profiles.contains(where: { $0.id == selection }) { document.activeProfileID = selection }
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
        } catch {
            statusMessage = "Could not list recovery files: \(error.localizedDescription)"
            Diagnostics.library.error("Could not list recovery files: [\(IntegrationLog.category(of: error), privacy: .public)] \(error.localizedDescription, privacy: .private)")
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

    /// Validation runs over the whole library, so the failing control may be in another profile:
    /// select it so the inspector shows its issues.
    private func reportLibraryProblem(_ title: String, error: Error, outcome: String) {
        var message = "\(error.localizedDescription) \(outcome)"
        if let location = ProfileValidator.firstInvalidAction(in: document) {
            let status = statusMessage
            // Keep a manual pause on the profile actually shown; the failure stays in the status line.
            select(profileID: location.profileID, isManual: manualProfileOverrideID != nil)
            selectedControlID = location.controlID
            statusMessage = status
            message += " The control is now selected: fix its assignment or set its type to Disabled, then try again."
        }
        libraryProblem = LibraryProblem(title: title, message: message)
    }

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
