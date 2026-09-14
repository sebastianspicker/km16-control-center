import Foundation
import CoreGraphics
import KM16ControlCore

func presetExpansionChecks() throws {
    let profiles = Presets.all
    try expect(Set(profiles.map(\.id)).count == 16 && Set(profiles.compactMap(\.presetID)).count == 16, "preset IDs must be unique")
    try expect(profiles == Presets.all, "factory identifiers must be stable")
    let creativeIDs = Set(["photo-editing", "3d-modelling", "music-production", "presentations"])
    let additions = profiles.filter { creativeIDs.contains($0.presetID ?? "") }
    try expect(additions.count == 4, "the four requested creative workflows must be present")
    try expect(additions.allSatisfy { profile in profile.matchingBundleIDs.count == 1 && profile.bindings.allSatisfy { $0.action.targetBundleID == profile.matchingBundleIDs.first } }, "creative actions must target their specific app")
    let matches = profiles.flatMap(\.matchingBundleIDs)
    try expect(Set(matches).count == matches.count, "factory automatic matching must be unambiguous")
    let bytes = try JSONEncoder().encode(Presets.factoryDocument())
    try expect(try JSONDecoder().decode(ProfileDocument.self, from: bytes) == Presets.factoryDocument(), "new actions must survive JSON round trip")
    try expect(profiles.flatMap(\.bindings).allSatisfy { $0.action.kind != .disabled }, "factory assignments must be usable")
    try expect(Presets.gitReview().matchingBundleIDs.isEmpty, "Git Review must not override Developer automatic matching")
    try expect(!ActionValidator.issues(for: ControlAction(kind: .obsAction, label: "Invalid", parameter: "unknown")).isEmpty, "unknown OBS operation accepted")
    let terminalSnippets = Presets.terminal().bindings.filter { $0.action.kind == .snippet }
    try expect(terminalSnippets.allSatisfy { !$0.action.parameter.contains("\n") && !$0.action.parameter.contains("\r") }, "Terminal templates must not execute by sending Return")
    for binding in Presets.personalAutomations().bindings where binding.action.kind == .shell {
        let spec = try ProcessSpec.parse(binding.action.parameter)
        try expect(spec.executable == "/usr/bin/shortcuts" && spec.args.count == 2 && spec.args[0] == "run", "routine must use a literal Shortcuts invocation")
    }
    let screen = CGRect(x: -1600, y: -400, width: 1600, height: 900)
    let current = CGRect(x: -1000, y: 0, width: 700, height: 500)
    try expect(WindowGeometry.placement(.topRight, current: current, visible: screen) == CGRect(x: -800, y: -400, width: 800, height: 450), "quarter placement must respect negative screen origins")
    try expect(WindowGeometry.placement(.bottomHalf, current: current, visible: screen) == CGRect(x: -1600, y: 50, width: 1600, height: 450), "bottom placement is inverted")
    try expect(WindowGeometry.centered(CGSize(width: 2000, height: 1000), in: screen) == screen, "centering must fit oversized windows")
    try expect(WindowGeometry.accessibilityFrame(CGRect(x: -1600, y: 200, width: 1600, height: 900), primaryTop: 1000) == CGRect(x: -1600, y: -100, width: 1600, height: 900), "screen coordinate conversion failed")
    try expect(WindowGeometry.displayIndex(for: current, displays: [CGRect(x: 0, y: 0, width: 1000, height: 800), screen]) == 1, "display selection must use intersection area")
    try expect(WindowGeometry.displayIndex(for: current, displays: []) == nil, "empty display inventory must be handled")
}
