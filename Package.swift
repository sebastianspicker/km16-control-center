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
        .executableTarget(name: "KM16ControlCenter", dependencies: ["KM16ControlCore", "KM16Integrations"], resources: [.copy("Resources/PresetSetup")]),
        .testTarget(name: "KM16ControlCoreTests", dependencies: ["KM16ControlCore"]),
        .testTarget(name: "KM16IntegrationsTests", dependencies: ["KM16Integrations", "KM16ControlCore"]),
        .testTarget(name: "KM16ControlCenterTests", dependencies: ["KM16ControlCenter", "KM16ControlCore", "KM16Integrations"])
    ]
)
