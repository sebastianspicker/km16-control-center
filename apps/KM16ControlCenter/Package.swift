// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KM16ControlCenter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KM16ControlCore", targets: ["KM16ControlCore"]),
        .library(name: "KM16Integrations", targets: ["KM16Integrations"]),
        .executable(name: "KM16IntegrationSelfTest", targets: ["KM16IntegrationSelfTest"]),
        .executable(name: "KM16ControlCenter", targets: ["KM16ControlCenter"]),
        .executable(name: "KM16ControlCoreSelfTest", targets: ["KM16ControlCoreSelfTest"])
    ],
    targets: [
        .target(name: "KM16ControlCore"),
        .target(name: "KM16ProcessSupport"),
        .target(name: "KM16Integrations", dependencies: ["KM16ControlCore", "KM16ProcessSupport"]),
        .executableTarget(name: "KM16IntegrationSelfTest", dependencies: ["KM16Integrations"]),
        .executableTarget(name: "KM16ControlCenter", dependencies: ["KM16ControlCore", "KM16Integrations"], resources: [.copy("Resources/PresetSetup")]),
        .executableTarget(name: "KM16ControlCoreSelfTest", dependencies: ["KM16ControlCore"]),
        .testTarget(name: "KM16ControlCoreTests", dependencies: ["KM16ControlCore"])
    ]
)
