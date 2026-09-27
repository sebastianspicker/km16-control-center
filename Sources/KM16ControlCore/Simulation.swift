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

public struct SimulationDispatcher: Sendable {
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
