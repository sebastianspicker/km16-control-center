import AppKit
import ApplicationServices
import Observation
import KM16ControlCore

@MainActor @Observable
public final class DesktopActionRunner {
    public private(set) var isRunning = false
    public var accessibilityGranted: Bool { AXIsProcessTrusted() }
    @ObservationIgnored private let processRunner = BoundedProcessRunner()
    @ObservationIgnored private let windowController = WindowController()
    public init() {}
    public func cancel() { processRunner.cancel() }

    public func perform(_ action: ControlAction, fallbackTargetBundleID: String? = nil) async throws -> String {
        guard !isRunning else { throw IntegrationError.message("An action is already running.") }
        let issues = ActionValidator.issues(for: action)
        guard issues.isEmpty else { throw IntegrationError.message(issues.joined(separator: " ")) }
        isRunning = true; defer { isRunning = false }
        switch action.kind {
        case .disabled: return "Disabled control; no action performed."
        case .launchApp:
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: action.parameter) else { throw IntegrationError.message("The selected application is not installed.") }
            let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = true
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            return "Opened \(action.label)."
        case .shell:
            let spec = try ProcessSpec.parse(action.parameter)
            let result = try await processRunner.run(executable: spec.executable, arguments: spec.args, directory: spec.workingDirectory, timeout: spec.timeoutSeconds)
            guard result.status == 0 else { throw IntegrationError.message("\(action.label) exited with status \(result.status).") }
            // Raw command output and arguments deliberately do not enter the routine activity log.
            return "\(action.label) finished successfully."
        case .shortcut:
            try requireAccessibility()
            let target = try await focus(action.targetBundleID ?? fallbackTargetBundleID)
            try DesktopEvents.shortcut(ShortcutSpec.parse(action.parameter), targetPID: target.processIdentifier)
            return "Sent \(action.label) to \(target.localizedName ?? "selected app")."
        case .snippet:
            try requireAccessibility()
            let target = try await focus(action.targetBundleID ?? fallbackTargetBundleID)
            try DesktopEvents.text(action.parameter, targetPID: target.processIdentifier)
            return "Inserted \(action.label) into \(target.localizedName ?? "selected app")."
        case .system:
            if let operation = WindowOperation(rawValue: action.parameter) {
                try requireAccessibility()
                let target = try await focus(action.targetBundleID ?? fallbackTargetBundleID)
                try windowController.perform(operation, application: target)
                return "Performed \(operation.title)."
            }
            switch action.parameter {
            case "volumeUp", "volumeDown", "mute": try SystemAudio.perform(action.parameter)
            case "playPause", "previousTrack", "nextTrack": try requireAccessibility(); try DesktopEvents.media(action.parameter)
            case "scrollUp", "scrollDown":
                try requireAccessibility()
                let target = try await focus(action.targetBundleID ?? fallbackTargetBundleID)
                guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: action.parameter == "scrollUp" ? 3 : -3, wheel2: 0, wheel3: 0) else { throw IntegrationError.message("Could not create a scroll event.") }
                event.postToPid(target.processIdentifier)
            case "dictation": throw IntegrationError.message("Set this action to the Dictation shortcut configured in macOS Keyboard settings. The app does not assume the system shortcut.")
            default: throw IntegrationError.message("Unsupported system action.")
            }
            return "Sent \(action.label)."
        case .profileSwitch: throw IntegrationError.message("Profile actions are handled by the profile editor.")
        case .obsAction: throw IntegrationError.message("Use the configured OBS provider for this action.")
        case .agentAction: throw IntegrationError.message("Use the connected Agent Deck provider for this action.")
        }
    }
    private func requireAccessibility() throws {
        guard accessibilityGranted else { throw IntegrationError.message("Allow KM16 Control Center in System Settings → Privacy & Security → Accessibility to send input.") }
    }
    private func focus(_ bundle: String?) async throws -> NSRunningApplication {
        guard let bundle, !bundle.isEmpty, bundle != Bundle.main.bundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first,
              !app.isTerminated else { throw IntegrationError.message("Select a running target app or focus another app before using Run.") }
        app.activate()
        for _ in 0..<10 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { return app }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw IntegrationError.message("The target app could not be focused; no input was sent.")
    }
}
