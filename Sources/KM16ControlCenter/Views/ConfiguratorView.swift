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

/// The pad drawn as a legend card over the real 4×4 + three-knob arrangement.
/// Every key and knob input shows its name, in its legend ink, and the code it sends.
struct PadSurface: View {
    let availableWidth: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("KM16 PRO").font(.system(size: 10, weight: .semibold).width(.condensed)).tracking(1.2)
                Spacer()
                Text("16 keys · 3 knobs").font(.system(size: 10, weight: .medium).width(.condensed)).tracking(0.6)
            }.foregroundStyle(.secondary)
            // Base the arrangement on the allocated width, never the active
            // profile's label lengths, so selecting a profile cannot move the dials.
            if availableWidth >= 640 {
                HStack(alignment: .top, spacing: 24) {
                    keyGrid.frame(width: availableWidth - 44 - 24 - 220)
                    VStack(alignment: .leading, spacing: 18) {
                        StudioDial(index: 0); StudioDial(index: 1)
                        Divider()
                        StudioDial(index: 2, large: true)
                    }.frame(width: 220)
                }
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    keyGrid
                    Divider()
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(0..<3) { StudioDial(index: $0, stacked: true) }
                    }
                }
            }
            Divider()
            InkKey()
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(contrast == .increased ? 0.6 : 0.35)))
        }
    }
    private var keyGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 60), spacing: 10), count: 4), spacing: 10) {
            ForEach(ControlID.keys) { StudioKeycap(controlID: $0) }
        }
    }
}

/// The legend for the four inks, printed at the foot of the card.
private struct InkKey: View {
    var body: some View {
        HStack(spacing: 18) {
            ForEach(LegendInk.allCases, id: \.self) { ink in
                HStack(spacing: 6) {
                    Rectangle().fill(ink.color).frame(width: 8, height: 8)
                    Text(ink.title).foregroundStyle(ink.color)
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
        .lineLimit(1).minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }
}

/// Crop marks around the selected control, instead of a tinted glow.
private struct RegistrationMarks: Shape {
    var length: CGFloat = 8
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x + dx * length, y: corner.y)); path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * length))
        }
        return path
    }
}

struct StudioKeycap: View {
    @Environment(ControlCenterStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovered = false
    let controlID: ControlID
    private var action: ControlAction { store.activeProfile.binding(for: controlID)!.action }
    private var selected: Bool { store.selectedControlID == controlID }
    private var ink: LegendInk { LegendInk(action.kind) }
    var body: some View {
        Button { store.selectedControlID = controlID } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(format: "%02d", controlID.keyNumber ?? 0)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if action.kind != .shortcut {
                        Text(StudioStyle.legendTag(action.kind).uppercased()).font(.system(size: 10, weight: .semibold).width(.condensed)).tracking(0.6)
                            .foregroundStyle(ink.color).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Text(action.label).font(.system(size: 14, weight: .semibold).width(.condensed)).foregroundStyle(ink.color)
                    .lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.leading)
                Text(StudioStyle.legendCode(action)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail)
            }
            .padding(.horizontal, 10).padding(.vertical, 9).frame(maxWidth: .infinity, alignment: .leading).frame(height: 96)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovered ? Color.primary.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
                    .overlay(alignment: .top) { if ink == .runs { Rectangle().fill(ink.color.opacity(0.18)).frame(height: 3).clipShape(RoundedRectangle(cornerRadius: 6)) } }
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Color.primary : .primary.opacity(contrast == .increased ? 0.6 : 0.3), lineWidth: selected ? 2 : 1))
            }
            .overlay { if selected { RegistrationMarks().stroke(Color.primary, lineWidth: 1.5).padding(-6) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
        .help("\(controlID.gridTitle): \(action.label)")
        .accessibilityLabel("\(controlID.gridTitle), \(action.label), \(action.kind.displayName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu { Button("Preview Action", systemImage: "play") { store.simulate(controlID) } }
    }
}

/// A knob drawn as a solid cap through the card, with its scale printed around it
/// and its three legends (counterclockwise, press, clockwise) set beside it.
struct StudioDial: View {
    @Environment(ControlCenterStore.self) private var store
    let index: Int
    var large = false
    var stacked = false
    private var size: CGFloat { large && !stacked ? 76 : 52 }
    private var pressID: ControlID { ControlID.encoder(index, .press)! }
    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            Button { store.selectedControlID = pressID } label: {
                ZStack {
                    ForEach(0..<12, id: \.self) { tick in
                        Capsule().fill(.secondary).frame(width: 1.5, height: 4)
                            .offset(y: -size / 2 + 2).rotationEffect(.degrees(Double(tick) * 30))
                    }
                    Circle().fill(Color.primary).padding(8)
                    Capsule().fill(Color(nsColor: .windowBackgroundColor)).frame(width: 2.5, height: size * 0.16).offset(y: -size * 0.24)
                }
                .frame(width: size, height: size)
                .overlay { if store.selectedControlID == pressID { RegistrationMarks(length: 7).stroke(Color.primary, lineWidth: 1.5).padding(-3) } }
                .contentShape(Circle())
            }.buttonStyle(.plain)
                .help("Edit \(index.encoderName.lowercased()) press")
                .accessibilityAddTraits(store.selectedControlID == pressID ? .isSelected : [])
                .contextMenu { Button("Preview Action") { store.simulate(pressID) } }
                .accessibilityLabel("\(index.encoderName) press, \(store.activeProfile.binding(for: pressID)!.action.label)")
            VStack(alignment: .leading, spacing: 2) {
                Text(index.encoderName.uppercased()).font(.system(size: 10, weight: .semibold).width(.condensed)).tracking(0.8).foregroundStyle(.secondary)
                    .padding(.leading, 6).padding(.bottom, 2)
                legend(.counterClockwise, glyph: "◂")
                legend(.press, glyph: "●")
                legend(.clockwise, glyph: "▸")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func legend(_ input: EncoderInput, glyph: String) -> some View {
        let id = ControlID.encoder(index, input)!
        let action = store.activeProfile.binding(for: id)!.action
        let selected = store.selectedControlID == id
        return Button { store.selectedControlID = id } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(glyph).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 12)
                VStack(alignment: .leading, spacing: 1) {
                    Text(action.label).font(.system(size: 12, weight: .semibold).width(.condensed)).foregroundStyle(LegendInk(action.kind).color).lineLimit(1)
                    Text(StudioStyle.legendCode(action)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).strokeBorder(selected ? Color.primary : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .help(action.label)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityLabel("\(index.encoderName), \(input.displayName), \(action.label)")
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
