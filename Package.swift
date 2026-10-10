// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KM16ControlCenter",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KM16ControlCenter", targets: ["KM16ControlCenter"])
    ],
    targets: [
        .target(name: "KM16ControlCore"),
        .target(name: "KM16ProcessSupport"),
        .target(name: "KM16Integrations", dependencies: ["KM16ControlCore", "KM16ProcessSupport"]),
        .target(
            name: "KM16Presets",
            dependencies: ["KM16ControlCore"],
            path: "presets",
            // The per-preset and combined JSON files are generated exports of the Catalog sources
            // below (regenerate with `swift run KM16PresetExport`), not build inputs.
            exclude: [
                "README.md", "all.json",
                "3d-modelling.json", "agent-deck.json", "creative.json", "desktop.json",
                "developer.json", "git-review.json", "meetings.json", "music-production.json",
                "personal-automations.json", "photo-editing.json", "presentations.json",
                "recording-streaming.json", "research-writing.json", "terminal.json",
                "video-editing.json", "window-management.json"
            ],
            sources: ["Catalog"],
            resources: [.copy("setup")]
        ),
        .executableTarget(name: "KM16ControlCenter", dependencies: ["KM16ControlCore", "KM16Integrations", "KM16Presets"]),
        .executableTarget(name: "KM16PresetExport", dependencies: ["KM16ControlCore", "KM16Presets"])
    ]
)
