import Foundation
import Testing
@testable import KM16Integrations
import KM16ControlCore

@MainActor
@Suite struct OBSProtocolTests {
    @Test func obsWebSocketV5UrlValidationRequiresLocalOrEncryptedEndpoints() throws {
        for endpoint in ["ws://localhost:4455", "ws://LOCALHOST.:4455", "ws://127.0.0.1:4455", "ws://127.2.3.4:4455", "ws://[::1]:4455", "ws://[0:0:0:0:0:0:0:1]:4455", "wss://obs.example:4455"] {
            _ = try OBSController.validatedURL(endpoint)
        }
        for endpoint in ["ws://obs.example:4455", "ws://localhost.example:4455", "ws://192.168.1.2:4455", "ws://[::2]:4455", "ws://[::ffff:192.168.1.2]:4455", "ws://127.0.0.1@obs.example:4455"] {
            #expect(performing: {
                try OBSController.validatedURL(endpoint)
            }, throws: { error in
                guard case IntegrationError.message(let message) = error else { return false }
                return message.contains("require wss") || message.contains("without credentials")
            })
        }
    }

    @Test func obsAuthenticationChallengeResponseMatchesTheFixture() {
        let expectedAuthentication = "1Ct943GAT+6YQUUX47Ia/ncufilbe6+oD6lY+5kaCu4="
        #expect(OBSProtocolSession.authentication(
            password: "supersecretpassword",
            salt: "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI=",
            challenge: "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY="
        ) == expectedAuthentication, "OBS authentication fixture failed.")
    }

    @Test func obsAuthenticationSceneNavigationVolumeAndStudioModeFixturesRoundTrip() async throws {
        let expectedAuthentication = "1Ct943GAT+6YQUUX47Ia/ncufilbe6+oD6lY+5kaCu4="
        let fixture = OBSFixtureTransport(incoming: [
            #"{"op":0,"d":{"rpcVersion":1,"authentication":{"challenge":"+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=","salt":"lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI="}}}"#,
            #"{"op":2,"d":{"negotiatedRpcVersion":1}}"#,
            #"{"op":7,"d":{"requestType":"GetSceneList","requestId":"fixture-1","requestStatus":{"result":true,"code":100},"responseData":{"currentProgramSceneName":"Second","scenes":[{"sceneName":"Third"},{"sceneName":"Second"},{"sceneName":"First"}]}}}"#,
            #"{"op":7,"d":{"requestType":"SetCurrentProgramScene","requestId":"fixture-2","requestStatus":{"result":true,"code":100}}}"#,
            #"{"op":7,"d":{"requestType":"GetInputVolume","requestId":"fixture-3","requestStatus":{"result":true,"code":100},"responseData":{"inputVolumeMul":0.98}}}"#,
            #"{"op":7,"d":{"requestType":"SetInputVolume","requestId":"fixture-4","requestStatus":{"result":true,"code":100}}}"#,
            #"{"op":7,"d":{"requestType":"GetStudioModeEnabled","requestId":"fixture-5","requestStatus":{"result":true,"code":100},"responseData":{"studioModeEnabled":false}}}"#,
            #"{"op":7,"d":{"requestType":"SetStudioModeEnabled","requestId":"fixture-6","requestStatus":{"result":true,"code":100}}}"#
        ])
        var nextID = 0
        let session = OBSProtocolSession(transport: fixture) {
            nextID += 1
            return "fixture-\(nextID)"
        }
        fixture.start()
        try await session.identify(password: "supersecretpassword")
        let executor = OBSActionExecutor(session: session, microphoneSource: "Mic/Aux", playbackSource: "Desktop Audio")
        #expect(try await executor.perform(.previousScene) == "Switched OBS to First.", "OBS scene navigation fixture failed.")
        #expect(try await executor.perform(.microphoneUp) == "Set OBS microphone volume to 100%.", "OBS volume fixture failed.")
        #expect(try await executor.perform(.toggleStudioMode) == "Enabled OBS Studio Mode.", "OBS Studio Mode fixture failed.")
        #expect(fixture.sent.count == 7)
        #expect(try decoded(fixture.sent[0])["d"]["authentication"].string == expectedAuthentication, "OBS request encoding fixture failed.")
        #expect(try decoded(fixture.sent[2])["d"]["requestData"]["sceneName"].string == "First", "OBS request encoding fixture failed.")
        #expect(try decoded(fixture.sent[4])["d"]["requestData"]["inputVolumeMul"].number == 1, "OBS request encoding fixture failed.")
        #expect(try decoded(fixture.sent[6])["d"]["requestData"]["studioModeEnabled"].bool == true, "OBS request encoding fixture failed.")
    }

    @Test func obsRequestCorrelationAndFailedRequestStatusAreRejected() async throws {
        for (id, response, expectedError) in [
            ("expected", #"{"op":7,"d":{"requestType":"StartRecord","requestId":"wrong","requestStatus":{"result":true,"code":100}}}"#, ["different request"]),
            ("failed", #"{"op":7,"d":{"requestType":"StartRecord","requestId":"failed","requestStatus":{"result":false,"code":501,"comment":"Output is already running."}}}"#, ["501", "already running"])
        ] {
            let transport = OBSFixtureTransport(incoming: [
                #"{"op":0,"d":{"rpcVersion":1}}"#,
                #"{"op":2,"d":{"negotiatedRpcVersion":1}}"#,
                response
            ])
            let session = OBSProtocolSession(transport: transport, requestID: { id })
            transport.start()
            try await session.identify(password: "")
            await #expect(performing: {
                try await session.request("StartRecord")
            }, throws: { error in
                guard case IntegrationError.message(let message) = error else { return false }
                return expectedError.allSatisfy(message.contains)
            })
        }
    }

    private func decoded(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }
}

@MainActor
final class OBSFixtureTransport: OBSWebSocketTransport {
    private var incoming: [String]
    private(set) var sent: [String] = []
    private var started = false

    init(incoming: [String]) { self.incoming = incoming }
    func start() { started = true }
    func send(_ text: String) async throws {
        guard started else { throw IntegrationError.message("OBS fixture was not started.") }
        sent.append(text)
    }
    func receive() async throws -> String {
        guard started, !incoming.isEmpty else { throw IntegrationError.message("OBS fixture has no response.") }
        return incoming.removeFirst()
    }
    func close() { started = false }
}
