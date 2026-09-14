import Foundation

/// Presentation order is derived from preset identity, so renamed and edited profiles stay intact.
public enum ProfileGroup: String, CaseIterable, Identifiable, Sendable {
    case everyday, development, work, media, custom
    public var id: Self { self }
    public var title: String {
        switch self {
        case .everyday: "Everyday"
        case .development: "Development"
        case .work: "Work & Writing"
        case .media: "Media & Design"
        case .custom: "Custom"
        }
    }
    public var presetIDs: [String] {
        switch self {
        case .everyday: ["desktop", "window-management", "personal-automations"]
        case .development: ["agent-deck", "developer", "git-review", "terminal"]
        case .work: ["research-writing", "meetings", "presentations"]
        case .media: ["photo-editing", "video-editing", "3d-modelling", "music-production", "recording-streaming", "creative"]
        case .custom: []
        }
    }
}

public struct ProfileSection: Identifiable, Sendable {
    public let group: ProfileGroup
    public let profiles: [Profile]
    public var id: ProfileGroup { group }
}

public enum ProfileOrganization {
    public static func group(for profile: Profile) -> ProfileGroup {
        guard let id = profile.presetID else { return .custom }
        return ProfileGroup.allCases.first { $0.presetIDs.contains(id) } ?? .custom
    }
    public static func sections(_ profiles: [Profile]) -> [ProfileSection] {
        ProfileGroup.allCases.compactMap { group in
            let members = profiles.filter { Self.group(for: $0) == group }.sorted { lhs, rhs in
                let left = group.presetIDs.firstIndex(of: lhs.presetID ?? "") ?? Int.max
                let right = group.presetIDs.firstIndex(of: rhs.presetID ?? "") ?? Int.max
                if left != right { return left < right }
                let names = lhs.name.localizedStandardCompare(rhs.name)
                if names != .orderedSame { return names == .orderedAscending }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return members.isEmpty ? nil : ProfileSection(group: group, profiles: members)
        }
    }
    public static func ordered(_ profiles: [Profile]) -> [Profile] { sections(profiles).flatMap(\.profiles) }
}
