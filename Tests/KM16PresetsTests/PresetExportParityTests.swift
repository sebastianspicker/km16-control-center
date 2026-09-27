import Foundation
import Testing
import KM16ControlCore
import KM16Presets

@Suite struct PresetExportParityTests {
    @Test func factoryPresetExportsMatchCommittedPresetFiles() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presetsDirectory = repositoryRoot.appending(path: "presets", directoryHint: .isDirectory)

        if ProcessInfo.processInfo.environment["KM16_WRITE_PRESET_EXPORTS"] == "1" {
            try Self.exportPresets(to: presetsDirectory)
            return
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        try Self.exportPresets(to: temporaryDirectory)

        for profile in Presets.all {
            let presetID = try #require(profile.presetID)
            let exported = try Data(contentsOf: temporaryDirectory.appending(path: "\(presetID).json"))
            let committed = try Data(contentsOf: presetsDirectory.appending(path: "\(presetID).json"))
            #expect(exported == committed, "\(presetID).json export drifted from the committed preset")
        }
        let exportedAll = try Data(contentsOf: temporaryDirectory.appending(path: "all.json"))
        let committedAll = try Data(contentsOf: presetsDirectory.appending(path: "all.json"))
        #expect(exportedAll == committedAll, "all.json export drifted from the committed preset")
    }

    private static func exportPresets(to directory: URL) throws {
        let profiles = Presets.all
        for profile in profiles {
            let presetID = try #require(profile.presetID)
            let outputURL = directory.appending(path: "\(presetID).json")
            let document = ProfileDocument(activeProfileID: profile.id, profiles: [profile])
            try ProfilePersistence(url: outputURL).exportDocument(document, to: outputURL)
        }
        let allURL = directory.appending(path: "all.json")
        let document = ProfileDocument(activeProfileID: profiles[0].id, profiles: profiles)
        try ProfilePersistence(url: allURL).exportDocument(document, to: allURL)
    }
}
