import KM16Integrations

@MainActor
func obsProtocolChecks() async throws {
    try await OBSProtocolSelfTest.run()
    print("PASS: OBS WebSocket v5 authentication, request correlation, scene navigation and volume clamping fixtures.")
}
