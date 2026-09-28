import Foundation

public enum ActionSpecificationError: Error, LocalizedError, Equatable, Sendable {
    case emptyShortcut
    case malformedShortcut
    case duplicateModifier(String)
    case unsupportedModifier(String)
    case unsupportedKey(String)
    case invalidProcessJSON
    case invalidExecutable
    case invalidWorkingDirectory
    case invalidTimeout

    public var errorDescription: String? {
        switch self {
        case .emptyShortcut: "The shortcut is empty."
        case .malformedShortcut: "Use one key with optional modifiers separated by plus signs."
        case .duplicateModifier(let modifier): "The shortcut repeats the \(modifier) modifier."
        case .unsupportedModifier(let modifier): "The shortcut modifier \(modifier) is unsupported."
        case .unsupportedKey: "The shortcut key is unsupported."
        case .invalidProcessJSON: "The process action must be a JSON object with executable, args, optional workingDirectory, and timeoutSeconds."
        case .invalidExecutable: "The process executable must be an absolute path."
        case .invalidWorkingDirectory: "The process working directory must be an absolute path when provided."
        case .invalidTimeout: "The process timeout must be between 1 and 3600 seconds."
        }
    }
}

public struct ShortcutSpec: Codable, Equatable, Sendable {
    public let key: String
    public let modifiers: [String]

    public init(key: String, modifiers: [String]) {
        self.key = key
        self.modifiers = modifiers
    }

    public static func parse(_ source: String) throws -> ShortcutSpec {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ActionSpecificationError.emptyShortcut }
        let rawParts = value.components(separatedBy: "+")
        guard !rawParts.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              let rawKey = rawParts.last else {
            throw ActionSpecificationError.malformedShortcut
        }

        var modifiers = Set<String>()
        for rawModifier in rawParts.dropLast() {
            let token = rawModifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let canonical = modifierAliases[token] else {
                throw ActionSpecificationError.unsupportedModifier(token)
            }
            guard modifiers.insert(canonical).inserted else {
                throw ActionSpecificationError.duplicateModifier(canonical)
            }
        }

        let key = canonicalKey(rawKey)
        guard supportedKeys.contains(key) || isFunctionKey(key) || isSinglePrintableKey(key) else {
            throw ActionSpecificationError.unsupportedKey(key)
        }
        return ShortcutSpec(key: key, modifiers: modifierOrder.filter(modifiers.contains))
    }

    private static let modifierOrder = ["cmd", "shift", "alt", "ctrl"]
    private static let modifierAliases = [
        "cmd": "cmd", "command": "cmd", "⌘": "cmd",
        "shift": "shift", "⇧": "shift",
        "alt": "alt", "option": "alt", "opt": "alt", "⌥": "alt",
        "ctrl": "ctrl", "control": "ctrl", "⌃": "ctrl", "^": "ctrl"
    ]
    private static let keyAliases = [
        "return": "enter", "escape": "esc", "backspace": "delete",
        "uparrow": "up", "downarrow": "down", "leftarrow": "left", "rightarrow": "right",
        "page up": "pageup", "page down": "pagedown", "pgup": "pageup", "pgdn": "pagedown",
        "`": "backtick", " ": "space"
    ]
    private static let supportedKeys: Set<String> = [
        "enter", "tab", "space", "esc", "delete", "forwarddelete",
        "up", "down", "left", "right", "home", "end", "pageup", "pagedown",
        "backtick", "plus", "minus"
    ]

    private static func canonicalKey(_ rawKey: String) -> String {
        let normalized = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return keyAliases[normalized] ?? normalized
    }

    private static func isFunctionKey(_ key: String) -> Bool {
        guard key.first == "f", let number = Int(key.dropFirst()) else { return false }
        return (1...20).contains(number)
    }

    private static func isSinglePrintableKey(_ key: String) -> Bool {
        key.count == 1 && key.unicodeScalars.allSatisfy {
            !CharacterSet.whitespacesAndNewlines.contains($0) && !CharacterSet.controlCharacters.contains($0)
        }
    }
}

public struct ProcessSpec: Codable, Equatable, Sendable {
    public var executable: String
    public var args: [String]
    public var workingDirectory: String?
    public var timeoutSeconds: Double

    public init(executable: String, args: [String], workingDirectory: String? = nil, timeoutSeconds: Double) {
        self.executable = executable
        self.args = args
        self.workingDirectory = workingDirectory
        self.timeoutSeconds = timeoutSeconds
    }

    public static func parse(_ source: String) throws -> ProcessSpec {
        guard let data = source.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["executable", "args", "workingDirectory", "timeoutSeconds"]),
              object["executable"] != nil, object["args"] != nil, object["timeoutSeconds"] != nil,
              let spec = try? JSONDecoder().decode(ProcessSpec.self, from: data) else {
            throw ActionSpecificationError.invalidProcessJSON
        }
        guard Self.isAbsolute(spec.executable) else { throw ActionSpecificationError.invalidExecutable }
        if let workingDirectory = spec.workingDirectory, !Self.isAbsolute(workingDirectory) {
            throw ActionSpecificationError.invalidWorkingDirectory
        }
        guard (1...3600).contains(spec.timeoutSeconds) else { throw ActionSpecificationError.invalidTimeout }
        guard ([spec.executable] + spec.args + [spec.workingDirectory ?? ""]).allSatisfy({ !$0.utf8.contains(0) }) else {
            throw ActionSpecificationError.invalidProcessJSON
        }
        return spec
    }

    public func encoded() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func isAbsolute(_ path: String) -> Bool {
        !path.isEmpty && URL(fileURLWithPath: path).path == path && path.hasPrefix("/")
    }
}

public enum ActionValidator {
    public static let supportedSystemParameters: Set<String> = Set(WindowOperation.allCases.map(\.rawValue)).union([
        "volumeDown", "volumeUp", "mute", "playPause", "previousTrack", "nextTrack",
        "scrollUp", "scrollDown", "dictation"
    ])
    public static let supportedAgentParameters: Set<String> = [
        "new-task", "review-changes", "run-tests", "explain-selection", "stop-current-task",
        "summarize-context", "draft-commit", "previous-task", "next-task", "open-task",
        "previous-changed-file", "next-changed-file", "open-diff", "scroll-up", "scroll-down"
    ]

    public static func issues(for action: ControlAction) -> [String] {
        var issues = issue(if: action.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "The label is required.")
        issues += issue(
            if: action.targetBundleID.map { !isValidBundleID($0) } ?? false,
            "The target bundle identifier is invalid."
        )
        let parameter = action.parameter.trimmingCharacters(in: .whitespacesAndNewlines)
        issues.append(contentsOf: parameterIssues(for: action, parameter: parameter))
        return issues
    }

    private static func parameterIssues(for action: ControlAction, parameter: String) -> [String] {
        switch action.kind {
        case .shortcut: return parsingIssues { try ShortcutSpec.parse(parameter) }
        case .launchApp: return issue(if: !isValidBundleID(parameter), "The app bundle identifier is invalid.")
        case .snippet: return issue(if: parameter.isEmpty, "Snippet text is required.")
        case .shell: return parsingIssues { try ProcessSpec.parse(parameter) }
        case .obsAction: return issue(if: OBSOperation(rawValue: parameter) == nil, "The OBS action identifier is unsupported.")
        case .agentAction: return agentIssues(parameter)
        case .profileSwitch: return issue(if: parameter.isEmpty, "A destination profile is required.")
        case .system: return issue(if: !supportedSystemParameters.contains(parameter), "The system action identifier is unsupported.")
        case .disabled:
            return issue(if: !parameter.isEmpty, "Disabled actions cannot have a parameter.")
                + issue(if: action.targetBundleID != nil, "Disabled actions cannot target an app.")
        }
    }

    private static func parsingIssues<T>(_ parse: () throws -> T) -> [String] {
        do { _ = try parse(); return [] } catch { return [error.localizedDescription] }
    }

    private static func agentIssues(_ parameter: String) -> [String] {
        let prompt = parameter.hasPrefix("prompt:")
            ? String(parameter.dropFirst("prompt:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        return issue(if: !supportedAgentParameters.contains(parameter) && prompt.isEmpty, "The agent action identifier is unsupported.")
    }

    private static func issue(if condition: Bool, _ message: String) -> [String] { condition ? [message] : [] }

    public static func isValidBundleID(_ value: String) -> Bool {
        guard value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              value.count <= 255 else { return false }
        let segments = value.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return segments.allSatisfy { segment in
            guard let first = segment.unicodeScalars.first, let last = segment.unicodeScalars.last,
                  CharacterSet.alphanumerics.contains(first), CharacterSet.alphanumerics.contains(last) else {
                return false
            }
            return segment.unicodeScalars.allSatisfy(allowed.contains)
        }
    }
}
