import OSLog
import KM16ControlCore
import KM16Integrations

/// Unified-log channels for bug reports (`log show --predicate 'subsystem == "org.local.KM16ControlCenter"'`).
/// Messages carry outcomes and public error categories; error descriptions are `.private`
/// (they can contain profile names or action labels), and snippet text, commands, prompts and
/// other action parameters are never logged.
enum Diagnostics {
    static let library = Logger(subsystem: IntegrationLog.subsystem, category: "library")
    static let actions = Logger(subsystem: IntegrationLog.subsystem, category: "actions")

    static func logLiveAction(_ action: ControlAction, controlID: ControlID, result: Result<String, Error>) {
        switch result {
        case .success:
            actions.info("Ran \(action.kind.rawValue, privacy: .public) action on \(controlID.rawValue, privacy: .public).")
        case .failure(let error):
            actions.error("Run of \(action.kind.rawValue, privacy: .public) action on \(controlID.rawValue, privacy: .public) failed: [\(IntegrationLog.category(of: error), privacy: .public)] \(error.localizedDescription, privacy: .private)")
        }
    }
}
