import Foundation

public enum ProfileEditorError: Error, LocalizedError, Equatable {
    case unknownProfile(UUID)
    case duplicateProfileID(UUID)
    case cannotRemoveLastProfile

    public var errorDescription: String? {
        switch self {
        case .unknownProfile: "The profile does not exist."
        case .duplicateProfileID: "A profile with that identifier already exists."
        case .cannotRemoveLastProfile: "A profile document must keep at least one profile."
        }
    }
}

/// A reusable value-type editing surface. Callers own undo history and persistence.
public struct ProfileEditor: Equatable, Sendable {
    public var document: ProfileDocument

    public init(document: ProfileDocument) {
        self.document = document
    }

    public var activeProfile: Profile? {
        document.profiles.first { $0.id == document.activeProfileID }
    }

    public mutating func selectProfile(id: UUID) throws {
        _ = try profileIndex(id: id)
        document.activeProfileID = id
    }

    public mutating func add(_ profile: Profile, makeActive: Bool = true) throws {
        guard !document.profiles.contains(where: { $0.id == profile.id }) else {
            throw ProfileEditorError.duplicateProfileID(profile.id)
        }
        document.profiles.append(profile)
        if makeActive { document.activeProfileID = profile.id }
    }

    @discardableResult
    public mutating func duplicateProfile(id: UUID, name: String? = nil) throws -> UUID {
        let source = document.profiles[try profileIndex(id: id)]
        let newID = UUID()
        let copy = Profile(
            id: newID,
            name: name ?? "\(source.name) Copy",
            bindings: source.bindings,
            summary: source.summary,
            matchingBundleIDs: source.matchingBundleIDs,
            presetID: nil
        )
        document.profiles.append(copy)
        document.activeProfileID = newID
        return newID
    }

    public mutating func removeProfile(id: UUID) throws {
        guard document.profiles.count > 1 else { throw ProfileEditorError.cannotRemoveLastProfile }
        let index = try profileIndex(id: id)
        document.profiles.remove(at: index)
        if document.activeProfileID == id {
            document.activeProfileID = document.profiles[min(index, document.profiles.count - 1)].id
        }
    }

    public mutating func updateProfile(id: UUID, _ change: (inout Profile) -> Void) throws {
        let index = try profileIndex(id: id)
        change(&document.profiles[index])
    }

    private func profileIndex(id: UUID) throws -> Int {
        guard let index = document.profiles.firstIndex(where: { $0.id == id }) else { throw ProfileEditorError.unknownProfile(id) }
        return index
    }
}
