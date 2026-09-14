import KM16ControlCore

/// The KM16 hardware path remains disconnected. Desktop and Codex providers live in
/// `KM16Integrations` and are reached only through the explicit live-action opt-in.
struct DisconnectedDeviceCapability: HIDCapabilityProviding {
    let deviceDescription = "Simulation • device disconnected"
}
