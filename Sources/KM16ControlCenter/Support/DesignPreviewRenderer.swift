import AppKit
import SwiftUI
import KM16ControlCore
import KM16Integrations

/// In-process, offscreen design exports. These do not inspect or interact with another
/// application and are not a replacement for live window/accessibility verification.
/// Export individual panels: offscreen native split-view hosts do not paint reliably.
/// Verify column allocation, titlebar and window resizing in the running app.
@MainActor enum DesignPreviewRenderer {
    static func render(to directory: URL) throws {
        _ = NSApplication.shared
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ControlCenterStore(persistence: ProfilePersistence(url: directory.appendingPathComponent("preview-unused-profiles.json")))
        let runner = DesktopActionRunner(), client = CodexDeckClient()
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .light ? "light" : "dark"
            try write(ConfiguratorView().environment(store),
                      size: CGSize(width: 820, height: 820), scheme: scheme,
                      to: directory.appendingPathComponent("pad-\(suffix).png"))
            try write(SidebarView().environment(store), size: CGSize(width: 200, height: 740), scheme: scheme,
                      to: directory.appendingPathComponent("sidebar-\(suffix).png"))
            try write(ControlInspectorView().environment(store), size: CGSize(width: 280, height: 740), scheme: scheme,
                      to: directory.appendingPathComponent("inspector-\(suffix).png"))
            try write(OverlayView().environment(store), size: CGSize(width: 640, height: 650), scheme: scheme,
                      to: directory.appendingPathComponent("overlay-\(suffix).png"))
            try write(IntegrationsView().environment(runner).environment(client).environment(OBSController()), size: CGSize(width: 840, height: 760), scheme: scheme,
                      to: directory.appendingPathComponent("connections-\(suffix).png"))
            try write(ApprovalDesignFixture(), size: CGSize(width: 840, height: 900), scheme: scheme,
                      to: directory.appendingPathComponent("approval-cards-\(suffix).png"))
            try write(SettingsView().environment(store), size: CGSize(width: 760, height: 780), scheme: scheme,
                      to: directory.appendingPathComponent("settings-\(suffix).png"))
        }
        try write(ConfiguratorView().environment(store),
                  size: CGSize(width: 500, height: 760), scheme: .light,
                  to: directory.appendingPathComponent("pad-compact.png"))
        try write(ApprovalDesignFixture(), size: CGSize(width: 560, height: 900), scheme: .light,
                  to: directory.appendingPathComponent("approval-cards-compact.png"))
        if let agent = store.document.profiles.first(where: { $0.presetID == "agent-deck" }) {
            store.select(profileID: agent.id)
            try write(ConfiguratorView().environment(store),
                      size: CGSize(width: 820, height: 820), scheme: .dark,
                      to: directory.appendingPathComponent("pad-agent.png"))
        }
        print("Exported offscreen design previews. No live window interaction was tested.")
    }
    private static func write<Content: View>(_ content: Content, size: CGSize, scheme: ColorScheme, to url: URL) throws {
        let view = NSHostingView(rootView: content.frame(width: size.width, height: size.height).background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, scheme))
        view.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
        window.contentView = view
        // The host window is intentionally never ordered on screen.
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        view.layoutSubtreeIfNeeded()
        view.needsDisplay = true
        view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw RenderError.bitmap }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw RenderError.bitmap }
        try png.write(to: url, options: .atomic)
        window.contentView = nil
    }
    enum RenderError: Error { case bitmap }
}
