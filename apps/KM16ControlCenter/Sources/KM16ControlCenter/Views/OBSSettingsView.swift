import SwiftUI
import KM16Integrations

struct OBSSettingsView: View {
    @Environment(OBSController.self) private var controller

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 7) {
                Text("OBS Studio")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("Configure the OBS WebSocket endpoint and audio source names.")
                    .foregroundStyle(.secondary)
                StudioStatus(
                    controller.isRunning ? "Running" : controller.status,
                    symbol: controller.isRunning ? "arrow.triangle.2.circlepath" : "circle",
                    tint: controller.isRunning ? StudioStyle.accent : .secondary
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            StudioSection("WebSocket", subtitle: "The app opens a short-lived OBS WebSocket v5 connection only when an OBS action runs.") {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        Text("Host URL").foregroundStyle(.secondary)
                        TextField("ws://localhost:4455", text: Bindable(controller).hostURL)
                            .textContentType(.URL)
                    }
                    GridRow {
                        Text("Password").foregroundStyle(.secondary)
                        SecureField("OBS WebSocket password", text: Bindable(controller).password)
                    }
                }
                .controlSize(.small)
                Text("Use ws:// for localhost. Remote OBS connections require wss:// with TLS; redirects are not followed.")
                    .font(.caption).foregroundStyle(.secondary)
                Label("The password remains in memory and is not saved to preferences.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            StudioSection("Audio sources", subtitle: "Use the exact input names shown in the OBS Audio Mixer.") {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        Text("Microphone").foregroundStyle(.secondary)
                        TextField("Microphone source name", text: Bindable(controller).microphoneSource)
                    }
                    GridRow {
                        Text("Playback").foregroundStyle(.secondary)
                        TextField("Playback source name", text: Bindable(controller).playbackSource)
                    }
                }
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
