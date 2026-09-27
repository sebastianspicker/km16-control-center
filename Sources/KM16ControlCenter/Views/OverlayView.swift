import SwiftUI
import KM16ControlCore

struct OverlayView: View {
    @Environment(ControlCenterStore.self) private var store
    @AppStorage("KM16.overlayFloating") private var overlayFloating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                VStack(alignment: .leading, spacing: 10) {
                    Text("Keys").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(ControlID.keys) { controlID in OverlayKey(controlID: controlID) }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Dials").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 10) { ForEach(0..<3, id: \.self) { index in OverlayDial(index: index) } }
                }
                Text("Preview actions are recorded locally.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(22)
        }
        .background(OverlayWindowConfigurator(floating: overlayFloating).frame(width: 0, height: 0))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: StudioStyle.profileSymbol(store.activeProfile))
                .font(.title2).foregroundStyle(StudioStyle.accent).frame(width: 34, height: 34).studioSurface(cornerRadius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeProfile.name).font(.headline)
                Text(store.activeProfile.summary.isEmpty ? "Active software profile" : store.activeProfile.summary)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
    }
}

private struct OverlayKey: View {
    @Environment(ControlCenterStore.self) private var store
    let controlID: ControlID

    var body: some View {
        let binding = store.activeProfile.binding(for: controlID)!
        Button { store.simulate(controlID) } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(keyTitle).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: StudioStyle.actionSymbol(binding.action.kind)).font(.caption2).foregroundStyle(.secondary)
                }
                Text(binding.action.label).font(.caption.weight(.medium)).lineLimit(2).frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
            }
            .padding(9).frame(maxWidth: .infinity, alignment: .leading).studioSurface(cornerRadius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(keyTitle): \(binding.action.label)")
    }

    private var keyTitle: String { controlID.gridTitle }
}

private struct OverlayDial: View {
    @Environment(ControlCenterStore.self) private var store
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(index.encoderName).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(EncoderInput.allCases, id: \.self) { input in
                if let controlID = ControlID.encoder(index, input), let binding = store.activeProfile.binding(for: controlID) {
                    Button { store.simulate(controlID) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: symbol(for: input)).frame(width: 13)
                            Text(binding.action.label).lineLimit(1)
                        }
                        .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(index.encoderName), \(input.displayName): \(binding.action.label)")
                }
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading).studioSurface(cornerRadius: 12)
    }

    private func symbol(for input: EncoderInput) -> String {
        switch input {
        case .counterClockwise: "arrow.counterclockwise"
        case .clockwise: "arrow.clockwise"
        case .press: "circle.fill"
        }
    }
}
