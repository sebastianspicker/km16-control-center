import Foundation

public struct SimulationEvent: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let controlID: ControlID
    public let message: String
    public let date: Date

    public init(controlID: ControlID, message: String, date: Date = Date()) {
        self.id = UUID()
        self.controlID = controlID
        self.message = message
        self.date = date
    }
}

public protocol ActionDispatching {
    func dispatch(binding: Binding, profile: Profile) -> SimulationEvent
}

public struct SimulationDispatcher: ActionDispatching, Sendable {
    public init() {}

    public func dispatch(binding: Binding, profile: Profile) -> SimulationEvent {
        let action = binding.action
        let issues = ActionValidator.issues(for: action)
        if !issues.isEmpty {
            return SimulationEvent(
                controlID: binding.controlID,
                message: "Refused invalid \(action.kind.displayName.lowercased()) \"\(action.label)\" in \(profile.name). Fix validation issues before dispatch."
            )
        }
        return SimulationEvent(
            controlID: binding.controlID,
            message: "Would run \(action.kind.displayName.lowercased()) \"\(action.label)\" in \(profile.name)."
        )
    }
}

/// Boundaries for future integrations. This scaffold deliberately has no live providers.
public protocol HIDCapabilityProviding: Sendable {
    var deviceDescription: String { get }
}

public protocol DesktopActionProviding: Sendable {
    func perform(_ action: ControlAction) async throws
}

public protocol AgentActionProviding: Sendable {
    func request(_ action: ControlAction) async throws
}
