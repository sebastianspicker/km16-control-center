import OSLog

import Foundation

/// Unified-log channels for the integrations. Messages carry outcomes and error categories,
/// never passwords, prompts, commands, or other action parameters.
public enum IntegrationLog {
    /// Matches the app bundle identifier, which `script/build_and_run.sh --telemetry` streams.
    public static let subsystem = "org.local.KM16ControlCenter"

    /// A loggable category for an error, such as `KM16ControlCore.ProfilePersistenceError 1`.
    /// Log the error's description only as `.private`: it can contain profile names, action labels,
    /// OBS request comments, or text sent by the Codex process.
    public static func category(of error: Error) -> String {
        let bridged = error as NSError
        return "\(bridged.domain) \(bridged.code)"
    }
    static let obs = Logger(subsystem: subsystem, category: "obs")
    static let codex = Logger(subsystem: subsystem, category: "codex")
}
