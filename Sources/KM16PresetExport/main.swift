import Foundation
import KM16ControlCore
import KM16Presets

// Regenerates the files derived from the Swift preset catalog: presets/<id>.json,
// presets/all.json, and the `groups` list in site/app.js. Run from the repository
// root. With --check, nothing is written and the exit status is 1 if any file is stale.

struct GeneratedFile {
    let path: String
    let contents: Data
}

enum ExportError: Error, CustomStringConvertible {
    case notRepositoryRoot(String)
    case missingPresetID(String)
    case groupsBlockNotFound
    case usage

    var description: String {
        switch self {
        case .notRepositoryRoot(let path): "Run from the repository root; \(path) has no presets/Catalog."
        case .missingPresetID(let name): "Factory profile \"\(name)\" has no preset ID."
        case .groupsBlockNotFound: "site/app.js has no `const groups = [ ... ];` block."
        case .usage: "Usage: swift run KM16PresetExport [--check]"
        }
    }
}

func presetExports() throws -> [GeneratedFile] {
    let profiles = Presets.all
    var files = try profiles.map { profile in
        guard let presetID = profile.presetID else { throw ExportError.missingPresetID(profile.name) }
        let document = ProfileDocument(activeProfileID: profile.id, profiles: [profile])
        return GeneratedFile(path: "presets/\(presetID).json", contents: try ProfilePersistence.exportData(document))
    }
    let library = ProfileDocument(activeProfileID: profiles[0].id, profiles: profiles)
    files.append(GeneratedFile(path: "presets/all.json", contents: try ProfilePersistence.exportData(library)))
    return files
}

func javaScriptString(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'"
}

func siteScript(from current: String) throws -> GeneratedFile {
    let rows = ProfileGroup.allCases.filter { $0 != .custom }.map { group in
        "  [\(javaScriptString(group.title)), [\(group.presetIDs.map(javaScriptString).joined(separator: ", "))]],"
    }
    let block = "const groups = [\n" + rows.joined(separator: "\n") + "\n];"
    guard let range = current.range(of: #"const groups = \[\n[\s\S]*?\n\];"#, options: .regularExpression) else {
        throw ExportError.groupsBlockNotFound
    }
    return GeneratedFile(path: "site/app.js", contents: Data(current.replacingCharacters(in: range, with: block).utf8))
}

func run(arguments: [String]) throws -> Int32 {
    guard arguments.count <= 1, arguments.allSatisfy({ $0 == "--check" }) else { throw ExportError.usage }
    let check = arguments == ["--check"]

    let root = URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
    guard FileManager.default.fileExists(atPath: root.appending(path: "presets/Catalog").path) else {
        throw ExportError.notRepositoryRoot(root.path)
    }

    let appScript = try String(contentsOf: root.appending(path: "site/app.js"), encoding: .utf8)
    let files = try presetExports() + [siteScript(from: appScript)]

    var stale: [String] = []
    for file in files {
        let url = root.appending(path: file.path)
        if (try? Data(contentsOf: url)) == file.contents { continue }
        stale.append(file.path)
        if !check { try file.contents.write(to: url, options: [.atomic]) }
    }

    if check {
        for path in stale { print("Stale: \(path)") }
        if !stale.isEmpty {
            print("Run `swift run KM16PresetExport` and commit the result.")
            return 1
        }
        print("Preset exports and site groups match the catalog (\(files.count) files).")
    } else {
        print(stale.isEmpty ? "Already up to date (\(files.count) files)." : "Updated \(stale.count) of \(files.count) files.")
    }
    return 0
}

do {
    exit(try run(arguments: Array(CommandLine.arguments.dropFirst())))
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(2)
}
