import Foundation

/// Access to the preset setup guides bundled as a resource of this module: per-preset Markdown
/// guides, a shared README, and the Git Review VS Code keybindings fragment (see `presets/setup/`).
public enum PresetSetupFiles {
    public enum ExportError: Error, LocalizedError {
        case resourcesUnavailable
        public var errorDescription: String? {
            switch self {
            case .resourcesUnavailable: "Preset setup resources are unavailable."
            }
        }
    }

    public static func guide(for presetID: String) -> String? {
        directory().flatMap { try? String(contentsOf: $0.appendingPathComponent("\(presetID).md"), encoding: .utf8) }
    }

    public static func export(to destination: URL) throws {
        guard let source = directory() else { throw ExportError.resourcesUnavailable }
        // A fresh subfolder avoids replacing any user-owned editor configuration.
        let target = destination.appendingPathComponent("KM16-Preset-Setup-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.copyItem(at: source, to: target)
    }

    /// Looks first for the packaged app's `KM16Presets` resource bundle in `resourcesURL`
    /// (`Bundle.main.resourceURL` in the hand-assembled `.app` made by `script/build_and_run.sh`),
    /// then falls back to `moduleBundle` (`Bundle.module` when running unbundled, e.g. under
    /// `swift test`). Returns nil when neither location has the setup resources.
    /// `moduleBundle` is evaluated only as a fallback: some SwiftPM `Bundle.module` accessors trap when
    /// the build directory is gone, which is normal for a packaged app.
    static func directory(resourcesURL: URL? = Bundle.main.resourceURL, moduleBundle: @autoclosure () -> Bundle? = Bundle.module) -> URL? {
        if let resourcesURL,
           let packaged = Bundle(url: resourcesURL.appendingPathComponent("KM16ControlCenter_KM16Presets.bundle")),
           let resourceURL = packaged.resourceURL {
            return resourceURL.appendingPathComponent("setup", isDirectory: true)
        }
        return moduleBundle()?.resourceURL?.appendingPathComponent("setup", isDirectory: true)
    }
}
