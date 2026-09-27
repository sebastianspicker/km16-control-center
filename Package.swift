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
            // below (checked for parity by KM16PresetsTests), not build inputs.
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
        .testTarget(name: "KM16ControlCoreTests", dependencies: ["KM16ControlCore", "KM16Presets"]),
        .testTarget(name: "KM16PresetsTests", dependencies: ["KM16Presets", "KM16ControlCore"]),
        .testTarget(name: "KM16IntegrationsTests", dependencies: ["KM16Integrations", "KM16ControlCore", "KM16Presets"]),
        .testTarget(name: "KM16ControlCenterTests", dependencies: ["KM16ControlCenter", "KM16ControlCore", "KM16Integrations", "KM16Presets"])
    ]
)
