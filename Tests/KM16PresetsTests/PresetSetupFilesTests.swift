import Foundation
import Testing
@testable import KM16Presets

private let setupGuideIDs = [
    "git-review", "terminal", "research-writing", "window-management", "recording-streaming",
    "video-editing", "personal-automations", "photo-editing", "3d-modelling", "music-production", "presentations"
]

/// Repository root, three levels above this file (`Tests/KM16PresetsTests/<file>.swift`).
private func repositoryRoot() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

@Suite struct KeybindingFragmentTests {
    private struct Entry: Decodable { let key: String }

    @Test func keybindingFragmentKeysAreUnique() throws {
        let fragmentURL = repositoryRoot().appending(path: "presets/setup/keybindings/git-review.code-keybindings.json")
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: fragmentURL))
        #expect(Set(entries.map(\.key)).count == entries.count, "keybindings fragment must not reuse a chord")
    }
}

@Suite struct PresetSetupFilesTests {
    @Test func everyListedPresetHasANonEmptyGuide() {
        for id in setupGuideIDs {
            #expect(PresetSetupFiles.guide(for: id)?.isEmpty == false, "Bundled setup guide missing: \(id)")
        }
    }

    @Test func exportYieldsOneFolderMatchingTheCommittedSetupLayout() throws {
        let destination = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        try PresetSetupFiles.export(to: destination)
        let exported = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
        #expect(exported.count == 1)
        let exportedFolder = try #require(exported.first)

        let committedSetup = repositoryRoot().appending(path: "presets/setup", directoryHint: .isDirectory)
        #expect(try filesRecursively(in: exportedFolder) == filesRecursively(in: committedSetup))
        for relativePath in try filesRecursively(in: committedSetup) {
            let exportedBytes = try Data(contentsOf: exportedFolder.appending(path: relativePath))
            let committedBytes = try Data(contentsOf: committedSetup.appending(path: relativePath))
            #expect(exportedBytes == committedBytes, "\(relativePath) drifted from presets/setup")
        }
    }

    @Test func locatorFindsAPackagedBundleInASyntheticAppLayoutAndIsNilWhenAbsent() throws {
        // Mirrors the `X.app/Contents/Resources/KM16ControlCenter_KM16Presets.bundle` layout
        // that script/build_and_run.sh assembles from swift build's Contents/Resources bundle.
        let appResources = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: appResources) }
        let bundleContents = appResources.appending(path: "KM16ControlCenter_KM16Presets.bundle/Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bundleContents.appending(path: "Resources/setup", directoryHint: .isDirectory), withIntermediateDirectories: true)
        let info = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>org.local.KM16Presets</string></dict></plist>"
        try Data(info.utf8).write(to: bundleContents.appending(path: "Info.plist"))
        try Data("guide".utf8).write(to: bundleContents.appending(path: "Resources/setup/git-review.md"))

        let found = PresetSetupFiles.directory(resourcesURL: appResources, moduleBundle: nil)
        #expect(found?.path.hasSuffix("Contents/Resources/setup") == true)

        let empty = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        #expect(PresetSetupFiles.directory(resourcesURL: empty, moduleBundle: nil) == nil)
    }
}

private func filesRecursively(in directory: URL) throws -> Set<String> {
    guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
    var paths: Set<String> = []
    for case let url as URL in enumerator {
        let isRegularFile = try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile ?? false
        guard isRegularFile else { continue }
        paths.insert(url.path.replacingOccurrences(of: directory.path + "/", with: ""))
    }
    return paths
}
