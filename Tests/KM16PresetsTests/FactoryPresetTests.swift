import Foundation
import CoreGraphics
import Testing
import KM16ControlCore
import KM16Presets

@Suite struct FactoryPresetTests {
    @Test func sixteenFactoryPresetsCoverAllFourHundredInputs() throws {
        let profiles = Presets.all
        #expect(profiles.map(\.name) == [
            "Desktop", "Window Management", "Personal Automations", "Agent Deck",
            "Developer", "Git Review", "Terminal", "Research & Writing", "Meetings",
            "Presentations", "Photo Editing", "Video Editing", "3D Modelling",
            "Music Production", "Recording & Streaming", "Creative"
        ])
        #expect(Set(profiles.compactMap(\.presetID)).count == 16)
        #expect(Set(profiles.map(\.id)).count == 16)
        #expect(ControlID.all.count == 25)
        #expect(profiles.flatMap(\.bindings).count == 400)

        for profile in profiles {
            #expect(profile.bindings.count == 25, "\(profile.name)")
            #expect(Set(profile.bindings.map(\.controlID)) == Set(ControlID.all), "\(profile.name)")
            #expect(!profile.summary.isEmpty, "\(profile.name)")
            for binding in profile.bindings {
                #expect(ActionValidator.issues(for: binding.action).isEmpty, "\(profile.name) \(binding.controlID): \(ActionValidator.issues(for: binding.action))")
                #expect(!binding.action.detail.isEmpty, "\(profile.name) \(binding.controlID)")
                #expect(binding.action.parameter != "dictation", "Factory profiles must not promise unsupported dictation dispatch")
            }
        }
        try ProfileValidator.validate(Presets.factoryDocument())
    }

    @Test func presetTargetsAndAgentCommandsAreExplicit() {
        #expect(Presets.developer().matchingBundleIDs == ["com.microsoft.VSCode"])
        #expect(Presets.meetings().matchingBundleIDs == ["us.zoom.xos"])
        #expect(Presets.creative().matchingBundleIDs == ["com.apple.Preview"])
        #expect(Presets.developer().bindings.filter { $0.action.kind == .shortcut }.allSatisfy {
            $0.action.targetBundleID == "com.microsoft.VSCode"
        })

        let agentParameters = Presets.agentDeck().bindings
            .filter { $0.action.kind == .agentAction }
            .map(\.action.parameter)
        #expect(agentParameters.contains("run-tests"))
        #expect(ActionValidator.supportedAgentParameters.isSubset(of: Set(agentParameters)))
        #expect(agentParameters.allSatisfy {
            ActionValidator.supportedAgentParameters.contains($0) || $0.hasPrefix("prompt:")
        })
    }

    @Test func presetsAreDeterministicAndLookupSupportsPresetAndUUID() {
        #expect(Presets.all == Presets.all)
        let developer = Presets.developer()
        #expect(Presets.preset(id: "developer") == developer)
        #expect(Presets.preset(id: developer.id.uuidString.uppercased()) == developer)
        #expect(Presets.preset(id: "missing") == nil)
    }

    @Test func blankPresetIsCompleteAndValid() throws {
        let blank = Profile.blank(name: "Custom")
        #expect(blank.bindings.count == 25)
        #expect(blank.bindings.allSatisfy { $0.action.kind == .disabled })
        try ProfileValidator.validate(ProfileDocument(activeProfileID: blank.id, profiles: [blank]))
    }

    @Test func mutatingOneProfileDoesNotAffectAnother() {
        var isolated = Presets.factoryDocument()
        isolated.profiles[1].replace(Binding(controlID: ControlID.keys[0], action: ControlAction(kind: .snippet, label: "Changed", parameter: "value")))
        #expect(isolated.profiles[0].binding(for: ControlID.keys[0])!.action != isolated.profiles[1].binding(for: ControlID.keys[0])!.action, "profiles are not isolated")
    }
}

@Suite struct PresetExpansionTests {
    @Test func creativeWorkflowPresetsTargetASingleApp() {
        let profiles = Presets.all
        let creativeIDs = Set(["photo-editing", "3d-modelling", "music-production", "presentations"])
        let additions = profiles.filter { creativeIDs.contains($0.presetID ?? "") }
        #expect(additions.count == 4, "the four requested creative workflows must be present")
        #expect(additions.allSatisfy { profile in profile.matchingBundleIDs.count == 1 && profile.bindings.allSatisfy { $0.action.targetBundleID == profile.matchingBundleIDs.first } }, "creative actions must target their specific app")
    }

    @Test func factoryBundleIDMatchingIsUnambiguous() {
        let matches = Presets.all.flatMap(\.matchingBundleIDs)
        #expect(Set(matches).count == matches.count, "factory automatic matching must be unambiguous")
    }

    @Test func factoryDocumentSurvivesJSONRoundTripAndUsesOnlyLiveActions() throws {
        let bytes = try JSONEncoder().encode(Presets.factoryDocument())
        #expect(try JSONDecoder().decode(ProfileDocument.self, from: bytes) == Presets.factoryDocument(), "new actions must survive JSON round trip")
        #expect(Presets.all.flatMap(\.bindings).allSatisfy { $0.action.kind != .disabled }, "factory assignments must be usable")
    }

    @Test func gitReviewDoesNotOverrideDeveloperMatching() {
        #expect(Presets.gitReview().matchingBundleIDs.isEmpty, "Git Review must not override Developer automatic matching")
    }

    @Test func obsActionValidatorRejectsUnknownOperation() {
        #expect(!ActionValidator.issues(for: ControlAction(kind: .obsAction, label: "Invalid", parameter: "unknown")).isEmpty, "unknown OBS operation accepted")
    }

    @Test func terminalSnippetsNeverSendReturn() throws {
        let terminalSnippets = Presets.terminal().bindings.filter { $0.action.kind == .snippet }
        #expect(terminalSnippets.allSatisfy { !$0.action.parameter.contains("\n") && !$0.action.parameter.contains("\r") }, "Terminal templates must not execute by sending Return")
    }

    @Test func personalAutomationsRoutinesUseALiteralShortcutsInvocation() throws {
        for binding in Presets.personalAutomations().bindings where binding.action.kind == .shell {
            let spec = try ProcessSpec.parse(binding.action.parameter)
            #expect(spec.executable == "/usr/bin/shortcuts" && spec.args.count == 2 && spec.args[0] == "run", "routine must use a literal Shortcuts invocation")
        }
    }

    @Test func windowGeometryHandlesNegativeOriginsAndMultipleDisplays() {
        let screen = CGRect(x: -1600, y: -400, width: 1600, height: 900)
        let current = CGRect(x: -1000, y: 0, width: 700, height: 500)
        #expect(WindowGeometry.placement(.topRight, current: current, visible: screen) == CGRect(x: -800, y: -400, width: 800, height: 450), "quarter placement must respect negative screen origins")
        #expect(WindowGeometry.placement(.bottomHalf, current: current, visible: screen) == CGRect(x: -1600, y: 50, width: 1600, height: 450), "bottom placement is inverted")
        #expect(WindowGeometry.centered(CGSize(width: 2000, height: 1000), in: screen) == screen, "centering must fit oversized windows")
        #expect(WindowGeometry.accessibilityFrame(CGRect(x: -1600, y: 200, width: 1600, height: 900), primaryTop: 1000) == CGRect(x: -1600, y: -100, width: 1600, height: 900), "screen coordinate conversion failed")
        #expect(WindowGeometry.displayIndex(for: current, displays: [CGRect(x: 0, y: 0, width: 1000, height: 800), screen]) == 1, "display selection must use intersection area")
        #expect(WindowGeometry.displayIndex(for: current, displays: []) == nil, "empty display inventory must be handled")
    }
}
