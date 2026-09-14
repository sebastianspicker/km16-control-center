import Foundation

public struct ControlID: RawRepresentable, Hashable, Codable, Sendable, Comparable, Identifiable {
    public let rawValue: String
    public var id: String { rawValue }

    public init?(rawValue: String) {
        guard Self.all.contains(where: { $0.rawValue == rawValue }) else { return nil }
        self.rawValue = rawValue
    }

    private init(unchecked rawValue: String) { self.rawValue = rawValue }

    public static func key(_ row: Int, _ column: Int) -> ControlID? {
        guard (0..<4).contains(row), (0..<4).contains(column) else { return nil }
        return ControlID(unchecked: "key-\(row)-\(column)")
    }

    public static func encoder(_ index: Int, _ input: EncoderInput) -> ControlID? {
        guard (0..<3).contains(index) else { return nil }
        return ControlID(unchecked: "encoder-\(index)-\(input.rawValue)")
    }

    public static let keys: [ControlID] = (0..<4).flatMap { row in
        (0..<4).map { key(row, $0)! }
    }
    public static let encoders: [ControlID] = (0..<3).flatMap { index in
        EncoderInput.allCases.map { encoder(index, $0)! }
    }
    public static let all = keys + encoders

    public static func < (lhs: ControlID, rhs: ControlID) -> Bool { lhs.rawValue < rhs.rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let controlID = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown control ID: \(rawValue)")
        }
        self = controlID
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum EncoderInput: String, Codable, CaseIterable, Sendable {
    case counterClockwise = "ccw"
    case clockwise = "cw"
    case press

    public var displayName: String {
        switch self {
        case .counterClockwise: "Counter-clockwise"
        case .clockwise: "Clockwise"
        case .press: "Press"
        }
    }
}

public enum ActionKind: String, Codable, CaseIterable, Sendable {
    case shortcut
    case launchApp
    case snippet
    case shell
    case agentAction
    case obsAction
    case profileSwitch
    case system
    case disabled

    public var displayName: String {
        switch self {
        case .shortcut: "Shortcut"
        case .launchApp: "Launch app"
        case .snippet: "Snippet"
        case .shell: "Shell"
        case .agentAction: "Agent action"
        case .obsAction: "OBS action"
        case .profileSwitch: "Profile switch"
        case .system: "System action"
        case .disabled: "Disabled"
        }
    }
}

public struct ControlAction: Codable, Equatable, Sendable {
    public var kind: ActionKind
    public var label: String
    public var parameter: String
    public var targetBundleID: String?
    public var detail: String

    public init(
        kind: ActionKind,
        label: String,
        parameter: String,
        targetBundleID: String? = nil,
        detail: String = ""
    ) {
        self.kind = kind
        self.label = label
        self.parameter = parameter
        self.targetBundleID = targetBundleID
        self.detail = detail
    }

    private enum CodingKeys: String, CodingKey {
        case kind, label, parameter, targetBundleID, detail
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(ActionKind.self, forKey: .kind)
        label = try container.decode(String.self, forKey: .label)
        parameter = try container.decode(String.self, forKey: .parameter)
        targetBundleID = try container.decodeIfPresent(String.self, forKey: .targetBundleID)
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
    }
}

public struct Binding: Codable, Equatable, Sendable, Identifiable {
    public let controlID: ControlID
    public var action: ControlAction
    public var id: ControlID { controlID }

    public init(controlID: ControlID, action: ControlAction) {
        self.controlID = controlID
        self.action = action
    }
}

public struct Profile: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var bindings: [Binding]
    public var summary: String
    public var matchingBundleIDs: [String]
    public var presetID: String?

    public init(
        id: UUID = UUID(),
        name: String,
        bindings: [Binding],
        summary: String = "",
        matchingBundleIDs: [String] = [],
        presetID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bindings = bindings
        self.summary = summary
        self.matchingBundleIDs = matchingBundleIDs
        self.presetID = presetID
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, bindings, summary, matchingBundleIDs, presetID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        bindings = try container.decode([Binding].self, forKey: .bindings)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        matchingBundleIDs = try container.decodeIfPresent([String].self, forKey: .matchingBundleIDs) ?? []
        presetID = try container.decodeIfPresent(String.self, forKey: .presetID)
    }

    public func binding(for controlID: ControlID) -> Binding? {
        bindings.first { $0.controlID == controlID }
    }

    public mutating func replace(_ binding: Binding) {
        guard let index = bindings.firstIndex(where: { $0.controlID == binding.controlID }) else { return }
        bindings[index] = binding
    }
}

public struct ProfileDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2
    public var schemaVersion: Int
    public var activeProfileID: UUID
    public var profiles: [Profile]

    public init(schemaVersion: Int = Self.currentSchemaVersion, activeProfileID: UUID, profiles: [Profile]) {
        self.schemaVersion = schemaVersion
        self.activeProfileID = activeProfileID
        self.profiles = profiles
    }
}

public enum ProfileValidationError: Error, LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case noProfiles
    case duplicateProfileID(UUID)
    case missingActiveProfile(UUID)
    case duplicateControlID(profile: String, controlID: ControlID)
    case unknownControlID(profile: String, controlID: ControlID)
    case missingControlIDs(profile: String, controlIDs: [ControlID])
    case blankName
    case invalidMatchingBundleID(profile: String, bundleID: String)
    case invalidAction(profile: String, controlID: ControlID, issues: [String])

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): "Unsupported profile schema \(version)."
        case .noProfiles: "A profile document must contain at least one profile."
        case .duplicateProfileID: "Profile IDs must be unique."
        case .missingActiveProfile: "The active profile is missing from the document."
        case .duplicateControlID(let profile, let controlID): "\(profile) assigns \(controlID.rawValue) more than once."
        case .unknownControlID(let profile, let controlID): "\(profile) assigns unknown control \(controlID.rawValue)."
        case .missingControlIDs(let profile, let controlIDs): "\(profile) is missing: \(controlIDs.map(\.rawValue).joined(separator: ", "))."
        case .blankName: "Profile names cannot be blank."
        case .invalidMatchingBundleID(let profile, _): "\(profile) has an invalid matching bundle identifier."
        case .invalidAction(let profile, let controlID, let issues):
            "\(profile) has an invalid action for \(controlID.rawValue): \(issues.joined(separator: " "))"
        }
    }
}

public enum ProfileValidator {
    public static func validate(_ document: ProfileDocument) throws {
        try validateStructure(document)
        for profile in document.profiles {
            for binding in profile.bindings {
                let issues = ActionValidator.issues(for: binding.action)
                guard issues.isEmpty else {
                    throw ProfileValidationError.invalidAction(profile: profile.name, controlID: binding.controlID, issues: issues)
                }
            }
        }
    }

    /// Validates document identity and control coverage while permitting actions that are
    /// temporarily incomplete in an editor. Dispatchers must still use `ActionValidator`.
    public static func validateStructure(_ document: ProfileDocument) throws {
        guard document.schemaVersion == ProfileDocument.currentSchemaVersion else {
            throw ProfileValidationError.unsupportedSchema(document.schemaVersion)
        }
        guard !document.profiles.isEmpty else { throw ProfileValidationError.noProfiles }
        var seenProfiles = Set<UUID>()
        for profile in document.profiles {
            guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProfileValidationError.blankName
            }
            guard seenProfiles.insert(profile.id).inserted else {
                throw ProfileValidationError.duplicateProfileID(profile.id)
            }
            if let bundleID = profile.matchingBundleIDs.first(where: { !ActionValidator.isValidBundleID($0) }) {
                throw ProfileValidationError.invalidMatchingBundleID(profile: profile.name, bundleID: bundleID)
            }
            var seenControls = Set<ControlID>()
            for binding in profile.bindings {
                guard ControlID.all.contains(binding.controlID) else {
                    throw ProfileValidationError.unknownControlID(profile: profile.name, controlID: binding.controlID)
                }
                guard seenControls.insert(binding.controlID).inserted else {
                    throw ProfileValidationError.duplicateControlID(profile: profile.name, controlID: binding.controlID)
                }
            }
            let missing = ControlID.all.filter { !seenControls.contains($0) }
            guard missing.isEmpty else {
                throw ProfileValidationError.missingControlIDs(profile: profile.name, controlIDs: missing)
            }
        }
        guard seenProfiles.contains(document.activeProfileID) else {
            throw ProfileValidationError.missingActiveProfile(document.activeProfileID)
        }
    }
}
