import SwiftUI
import KM16ControlCore

struct ConfiguratorView: View {
    @Environment(ControlCenterStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activityVisible = false

    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                PadSurface(availableWidth: max(0, min(geometry.size.width, 890) - 64))
                HStack(alignment: .top) {
                    Label("Select a control to edit its action", systemImage: "cursorarrow")
                    Spacer()
                    Text("⌘ ↩ to preview").monospaced()
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    Divider()
                    DisclosureGroup(isExpanded: $activityVisible) {
                        ActivityView().padding(.top, 14)
                    } label: {
                        HStack(spacing: 8) {
                            Text("Activity").font(.system(size: 12, weight: .medium))
                            if !store.events.isEmpty { Text("\(store.events.count)").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary) }
                            Spacer()
                            if let event = store.events.first, !activityVisible { Text(event.message).lineLimit(1).font(.system(size: 11)).foregroundStyle(.secondary) }
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 30)
            .frame(maxWidth: 890)
            .frame(maxWidth: .infinity)
        }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: store.document.activeProfileID)
    }
    private var usesAutomaticMatching: Bool { store.automaticProfileMatchingEnabled && store.manualProfileOverrideID == nil }
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                StudioStatus(usesAutomaticMatching ? "Automatic" : "Manual profile", symbol: usesAutomaticMatching ? "arrow.triangle.2.circlepath" : "hand.point.up.left")
                    .contextMenu { Button("Use Automatic Matching") { store.clearManualOverride() } }
            }
            Text(store.activeProfile.name).font(.system(size: 32, weight: .semibold)).tracking(-0.8)
            Text(store.activeProfile.summary.isEmpty ? "Make every control your own." : store.activeProfile.summary)
                .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The hardware-inspired workspace is drawn from the real 4×4 + three-knob arrangement.
struct PadSurface: View {
    let availableWidth: CGFloat
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("KM16 PRO").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2)
                Spacer()
                HStack(spacing: 4) { ForEach(0..<3) { _ in Circle().fill(.secondary.opacity(0.25)).frame(width: 3, height: 3) } }
            }.foregroundStyle(.secondary)
            // Base the arrangement on the allocated width, never the active
            // profile's label lengths, so selecting a profile cannot move the dials.
            if availableWidth >= 544 {
                HStack(alignment: .top, spacing: 18) {
                    keyGrid.frame(width: availableWidth - 44 - 168)
                    dialBank.frame(width: 150)
                }
            } else {
                VStack(spacing: 24) { keyGrid; dialBank }
            }
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color.primary.opacity(scheme == .dark ? 0.06 : 0.018), Color.primary.opacity(scheme == .dark ? 0.025 : 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.primary.opacity(0.08)))
        }
    }
    private var keyGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 60), spacing: 9), count: 4), spacing: 9) {
            ForEach(ControlID.keys) { StudioKeycap(controlID: $0) }
        }
    }
    private var dialBank: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top, spacing: 12) { StudioDial(index: 0); StudioDial(index: 1) }
            StudioDial(index: 2, large: true)
        }.padding(.top, 4)
    }
}

struct StudioKeycap: View {
    @Environment(ControlCenterStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovered = false
    let controlID: ControlID
    private var action: ControlAction { store.activeProfile.binding(for: controlID)!.action }
    private var selected: Bool { store.selectedControlID == controlID }
    var body: some View {
        Button { store.selectedControlID = controlID } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: StudioStyle.actionSymbol(action.kind)).font(.system(size: 15, weight: .regular)).foregroundStyle(selected ? Color.accentColor : .primary.opacity(0.65))
                    Spacer(minLength: 0)
                    Text(String(format: "%02d", controlID.keyNumber ?? 0)).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(action.label).font(.system(size: 11, weight: .medium)).lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.leading).frame(height: 28, alignment: .bottomLeading)
            }
            .padding(9).frame(maxWidth: .infinity).frame(height: 92)
            .background {
                RoundedRectangle(cornerRadius: 11)
                    .fill(scheme == .dark ? Color(nsColor: .controlBackgroundColor).opacity(0.8) : Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(scheme == .dark ? 0.18 : 0.07), radius: hovered ? 5 : 2, y: hovered ? 3 : 2)
                    .overlay(RoundedRectangle(cornerRadius: 11).fill(Color.accentColor.opacity(selected ? 0.065 : 0)))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? Color.accentColor.opacity(0.85) : .primary.opacity(contrast == .increased ? 0.4 : (hovered ? 0.18 : 0.07)), lineWidth: selected ? 1.5 : 1))
            }
            .offset(y: hovered ? -1 : 0)
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
        .help("\(controlID.gridTitle): \(action.label)")
        .accessibilityLabel("\(controlID.gridTitle), \(action.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu { Button("Preview Action", systemImage: "play") { store.simulate(controlID) } }
    }
}

struct StudioDial: View {
    @Environment(ControlCenterStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let index: Int
    var large = false
    private var size: CGFloat { large ? 108 : 64 }
    private var pressID: ControlID { ControlID.encoder(index, .press)! }
    var body: some View {
        VStack(spacing: large ? 11 : 9) {
            Button { store.selectedControlID = pressID } label: {
                ZStack {
                    Circle().fill(.primary.opacity(0.035))
                    ForEach(0..<32, id: \.self) { tick in
                        Capsule().fill(.primary.opacity(0.14)).frame(width: 1, height: large ? 5 : 3)
                            .offset(y: -size / 2 + 5).rotationEffect(.degrees(Double(tick) * 11.25))
                    }
                    Circle().fill(LinearGradient(colors: [Color(nsColor: .controlBackgroundColor), Color.primary.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(9).shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                    Circle().strokeBorder(store.selectedControlID == pressID ? Color.accentColor : .primary.opacity(0.1), lineWidth: store.selectedControlID == pressID ? 1.5 : 1).padding(9)
                    Capsule().fill(Color.accentColor.opacity(0.8)).frame(width: 2, height: large ? 9 : 6).offset(y: -size * 0.23)
                    if large { Image(systemName: "circle.dotted").font(.system(size: 16, weight: .light)).foregroundStyle(.secondary) }
                }.frame(width: size, height: size)
            }.buttonStyle(.plain)
                .help("Edit \(index.encoderName.lowercased()) press")
                .accessibilityAddTraits(store.selectedControlID == pressID ? .isSelected : [])
                .contextMenu { Button("Preview Action") { store.simulate(pressID) } }
                .accessibilityLabel("\(index.encoderName) press, \(store.activeProfile.binding(for: pressID)!.action.label)")
            Text(index.encoderName).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                direction(.counterClockwise, symbol: "arrow.counterclockwise")
                direction(.clockwise, symbol: "arrow.clockwise")
            }
            if large {
                Text("TURN · PRESS").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(.tertiary)
            }
        }.frame(maxWidth: .infinity)
    }
    private func direction(_ input: EncoderInput, symbol: String) -> some View {
        let id = ControlID.encoder(index, input)!
        return Button { store.selectedControlID = id } label: {
            Image(systemName: symbol).font(.system(size: 10, weight: .medium)).frame(width: large ? 36 : 30, height: 26)
                .background(store.selectedControlID == id ? Color.accentColor.opacity(0.1) : .primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(store.selectedControlID == id ? Color.accentColor : .secondary)
        }.buttonStyle(.plain)
            .help(store.activeProfile.binding(for: id)!.action.label)
            .accessibilityAddTraits(store.selectedControlID == id ? .isSelected : [])
            .accessibilityLabel("\(index.encoderName), \(input.displayName), \(store.activeProfile.binding(for: id)!.action.label)")
            .contextMenu { Button("Preview Action") { store.simulate(id) } }
    }
}

private struct ActivityView: View {
    @Environment(ControlCenterStore.self) private var store
    var body: some View {
        if store.events.isEmpty {
            Text("Your previews and action results will appear here.").font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(store.events.prefix(12)) { event in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(event.date, style: .time).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 60, alignment: .leading)
                        Text(event.message).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
