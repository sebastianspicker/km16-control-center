import SwiftUI
import KM16ControlCore

/// Shared visual language. Materials belong to navigation and floating controls;
/// content uses quiet, opaque-enough surfaces that remain legible in both appearances.
enum StudioStyle {
    static let accent = Color.accentColor
    private static let profileSymbols = [
        "desktop": "macwindow",
        "agent-deck": "sparkle",
        "developer": "curlybraces",
        "meetings": "video",
        "creative": "slider.horizontal.3",
        "git-review": "arrow.triangle.branch",
        "terminal": "terminal",
        "research-writing": "doc.text",
        "window-management": "rectangle.split.2x2",
        "recording-streaming": "record.circle",
        "video-editing": "film",
        "photo-editing": "camera.aperture",
        "3d-modelling": "cube",
        "music-production": "pianokeys",
        "presentations": "rectangle.on.rectangle",
        "personal-automations": "bolt",
    ]
    static func profileSymbol(_ profile: Profile) -> String {
        profile.presetID.flatMap { profileSymbols[$0] } ?? "square.grid.2x2"
    }
    static func actionSymbol(_ kind: ActionKind) -> String {
        switch kind {
        case .shortcut: "command"
        case .launchApp: "app"
        case .snippet: "text.alignleft"
        case .shell: "terminal"
        case .agentAction: "sparkle"
        case .obsAction: "record.circle"
        case .profileSwitch: "square.stack"
        case .system: "slider.horizontal.3"
        case .disabled: "minus"
        }
    }
    static func shortcutLabel(_ parameter: String) -> String {
        guard let shortcut = try? ShortcutSpec.parse(parameter) else { return parameter }
        let modifiers = shortcut.modifiers.map { ["cmd":"⌘", "shift":"⇧", "alt":"⌥", "ctrl":"⌃"][$0] ?? $0 }.joined()
        let key = ["enter":"↩", "esc":"⎋", "tab":"⇥", "delete":"⌫", "space":"Space", "up":"↑", "down":"↓", "left":"←", "right":"→", "plus":"+", "minus":"−", "backtick":"`", "pageup":"⇞", "pagedown":"⇟"][shortcut.key] ?? shortcut.key.uppercased()
        return modifiers + key
    }
}

struct StudioSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content
    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StudioStatus: View {
    let title: String
    var symbol: String
    var tint: Color
    init(_ title: String, symbol: String = "circle.fill", tint: Color = .secondary) {
        self.title = title; self.symbol = symbol; self.tint = tint
    }
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: symbol == "circle.fill" ? 5 : 10, weight: .medium)).foregroundStyle(tint)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct StudioSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    var cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(scheme == .dark ? 0.035 : 0.018), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.primary.opacity(contrast == .increased ? 0.3 : 0.075), lineWidth: 1))
    }
}
extension View {
    func studioSurface(cornerRadius: CGFloat = 16) -> some View { modifier(StudioSurface(cornerRadius: cornerRadius)) }
}

extension ControlID {
    var gridTitle: String {
        let parts = rawValue.split(separator: "-")
        guard parts.count == 3, let index = Int(parts[1]) else { return rawValue }
        if rawValue.hasPrefix("encoder"), let input = EncoderInput(rawValue: String(parts[2])) { return "\(index.encoderName) · \(input.displayName)" }
        guard let column = Int(parts[2]) else { return rawValue }
        return "Key \(index * 4 + column + 1)"
    }
    var keyNumber: Int? { ControlID.keys.firstIndex(of: self).map { $0 + 1 } }
}
extension Int {
    var encoderName: String { switch self { case 0: "Upper left"; case 1: "Upper right"; default: "Main dial" } }
}
