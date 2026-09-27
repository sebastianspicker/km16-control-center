import Foundation

/// Conflict policy for importing a profile library. `title`/`detail` are UI-facing and
/// live in the app target.
public enum ProfileImportMode: String, CaseIterable, Identifiable, Sendable {
    case replace
    case mergeReplacingNameConflicts
    case mergeKeepingExisting

    public var id: String { rawValue }
}

/// The profile-library editing rules: unique naming, create/duplicate/rename/delete/reset,
/// import merge with UUID remapping, and profile-switch and foreground-app match resolution.
/// A pure value type over `ProfileDocument`; it does not depend on the preset catalog.
public struct ProfileLibrary: Equatable, Sendable {
    public var document: ProfileDocument

    public init(document: ProfileDocument) {
        self.document = document
    }

    public var activeProfile: Profile? {
        document.profiles.first { $0.id == document.activeProfileID }
    }

    // MARK: Naming

    public func uniqueName(_ proposed: String) -> String {
        guard document.profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare(proposed) == .orderedSame }) else { return proposed }
        var number = 2
        while document.profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare("\(proposed) \(number)") == .orderedSame }) { number += 1 }
        return "\(proposed) \(number)"
    }

    // MARK: Capacity

    public func canAddProfiles(_ count: Int = 1) -> Bool {
        document.profiles.count + count <= ProfilePersistence.maximumProfileCount
    }

    // MARK: Create / duplicate / rename / delete / reset

    @discardableResult
    public mutating func createProfile(named name: String) -> Profile {
        let profile = Profile.blank(name: uniqueName(name))
        document.profiles.append(profile)
        document.activeProfileID = profile.id
        return profile
    }

    @discardableResult
    public mutating func duplicateActiveProfile() -> Profile? {
        guard let active = activeProfile else { return nil }
        var duplicate = active
        duplicate.id = UUID()
        duplicate.name = uniqueName("\(active.name) Copy")
        duplicate.presetID = nil
        document.profiles.append(duplicate)
        document.activeProfileID = duplicate.id
        return duplicate
    }

    public enum RenameError: Error, Equatable, Sendable {
        case blank
        case duplicate(String)
    }

    /// Validates and cleans a rename of the active profile without mutating the document.
    public func validateRename(to name: String) -> Result<String, RenameError> {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return .failure(.blank) }
        if let active = activeProfile, cleaned != active.name,
           document.profiles.contains(where: { $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) {
            return .failure(.duplicate(cleaned))
        }
        return .success(cleaned)
    }

    public mutating func renameActiveProfile(to cleanedName: String) {
        guard let index = document.profiles.firstIndex(where: { $0.id == document.activeProfileID }) else { return }
        document.profiles[index].name = cleanedName
    }

    @discardableResult
    public mutating func deleteActiveProfile() -> Profile? {
        guard document.profiles.count > 1, let deleting = activeProfile,
              let index = document.profiles.firstIndex(where: { $0.id == deleting.id }) else { return nil }
        document.profiles.remove(at: index)
        document.activeProfileID = document.profiles[max(0, index - 1)].id
        return deleting
    }

    @discardableResult
    public mutating func resetActiveProfile(preset: Profile) -> Bool {
        guard let index = document.profiles.firstIndex(where: { $0.id == document.activeProfileID }) else { return false }
        var replacement = preset
        replacement.id = document.profiles[index].id
        replacement.name = document.profiles[index].name
        document.profiles[index] = replacement
        return true
    }

    @discardableResult
    public mutating func addPreset(_ preset: Profile) -> Profile {
        var copy = preset
        copy.id = UUID()
        copy.name = uniqueName(preset.name)
        document.profiles.append(copy)
        document.activeProfileID = copy.id
        return copy
    }

    public func missingPresets(from all: [Profile]) -> [Profile] {
        let installed = Set(document.profiles.compactMap(\.presetID))
        return all.filter { !installed.contains($0.presetID ?? "") }
    }

    public mutating func addPresets(_ missing: [Profile]) {
        for preset in missing {
            var copy = preset
            copy.id = UUID()
            copy.name = uniqueName(preset.name)
            document.profiles.append(copy)
        }
    }

    // MARK: Import merge

    /// Merges `imported` into the current document. Imported profiles whose name matches an
    /// existing profile (case-insensitively) share that profile's identity; `replaceNameConflicts`
    /// controls whether the existing or the imported profile wins. Profile-switch parameters
    /// that reference another imported profile's original id are remapped to the retained
    /// destination id, including forward references.
    public func merged(with imported: ProfileDocument, replaceNameConflicts: Bool) -> ProfileDocument {
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

    // MARK: Profile-switch resolution

    public enum ProfileSwitchTarget: Equatable, Sendable {
        case cycle
        case profile(UUID)
        case unavailable
    }

    public func resolveProfileSwitch(parameter: String) -> ProfileSwitchTarget {
        if parameter == "cycle-profile" { return .cycle }
        if let target = document.profiles.first(where: { $0.presetID == parameter || $0.name == parameter }) { return .profile(target.id) }
        if let target = document.profiles.first(where: { $0.id.uuidString.caseInsensitiveCompare(parameter) == .orderedSame }) { return .profile(target.id) }
        return .unavailable
    }

    // MARK: Foreground-app matching

    public enum ForegroundMatch: Equatable, Sendable {
        case matched(bundleID: String, profile: Profile)
        case fallback(Profile)
        case unchanged
    }

    public func resolveForegroundMatch(bundleID: String?, fallback: Profile) -> ForegroundMatch {
        if let bundleID, let match = document.profiles.first(where: { $0.matchingBundleIDs.contains(bundleID) }) {
            guard match.id != document.activeProfileID else { return .unchanged }
            return .matched(bundleID: bundleID, profile: match)
        } else if fallback.id != document.activeProfileID {
            return .fallback(fallback)
        }
        return .unchanged
    }
}
