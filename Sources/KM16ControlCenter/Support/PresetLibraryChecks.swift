import Foundation
import KM16ControlCore

@MainActor func presetLibraryChecks(directory: URL) throws {
    for id in ["git-review", "terminal", "research-writing", "window-management", "recording-streaming", "video-editing", "personal-automations", "photo-editing", "3d-modelling", "music-production", "presentations"] {
        guard PresetSetupResources.guide(for: id)?.isEmpty == false else { throw StoreSelfTestError.assertion("Bundled setup guide missing: \(id)") }
    }
    if Bundle.main.bundleURL.pathExtension == "app" {
        guard PresetSetupResources.directory.path.hasPrefix(Bundle.main.bundleURL.path + "/") else {
            throw StoreSelfTestError.assertion("Packaged guides resolved outside the app bundle")
        }
    }
    let exportFolder = directory.appendingPathComponent("setup-export")
    try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
    try PresetSetupResources.export(to: exportFolder)
    let exported = try FileManager.default.contentsOfDirectory(at: exportFolder, includingPropertiesForKeys: nil)
    guard exported.count == 1,
          FileManager.default.fileExists(atPath: exported[0].appendingPathComponent("keybindings/git-review.code-keybindings.json").path) else {
        throw StoreSelfTestError.assertion("Setup export omitted keybindings")
    }
    var edited = Presets.desktop()
    edited.name = "My Desktop"
    edited.bindings[0].action.label = "My edited copy"
    let persistence = ProfilePersistence(url: directory.appendingPathComponent("older-library.json"))
    let previous = ProfileDocument(activeProfileID: edited.id, profiles: [edited])
    try persistence.save(previous)
    let store = ControlCenterStore(persistence: persistence)
    store.addMissingPresets()
    guard store.document.profiles.count == 16,
          store.document.profiles[0] == edited,
          store.document.activeProfileID == edited.id,
          try persistence.load() == previous else {
        throw StoreSelfTestError.assertion("adding presets changed existing edits, selection, or saved data")
    }
    let expanded = store.document
    store.addMissingPresets()
    guard store.document == expanded else { throw StoreSelfTestError.assertion("adding missing presets must be idempotent") }
    store.undo()
    guard store.document == previous else { throw StoreSelfTestError.assertion("preset expansion must undo as one change") }
    store.redo()
    guard store.document == expanded else { throw StoreSelfTestError.assertion("preset expansion must redo as one change") }
    let newIDs: Set<String> = ["photo-editing", "3d-modelling", "music-production", "presentations"]
    var oldLibrary = Presets.all.filter { !newIDs.contains($0.presetID ?? "") }
    oldLibrary[0] = edited
    let oldDocument = ProfileDocument(activeProfileID: edited.id, profiles: oldLibrary)
    try persistence.save(oldDocument)
    let upgraded = ControlCenterStore(persistence: persistence)
    guard upgraded.missingPresets.count == 4 else { throw StoreSelfTestError.assertion("existing twelve-profile library must offer exactly four additions") }
    upgraded.addMissingPresets()
    guard Array(upgraded.document.profiles.prefix(12)) == oldLibrary, upgraded.document.profiles.count == 16 else {
        throw StoreSelfTestError.assertion("four-preset expansion changed an existing profile")
    }
    // A nearly-full existing library must reject the whole expansion atomically.
    let profiles = [edited] + (1..<125).map { Presets.blank(name: "Custom \($0)") }
    let capacityDocument = ProfileDocument(activeProfileID: edited.id, profiles: profiles)
    try persistence.save(capacityDocument)
    let capped = ControlCenterStore(persistence: persistence)
    capped.addMissingPresets()
    guard capped.document == capacityDocument, !capped.canUndo else { throw StoreSelfTestError.assertion("capacity rejection partially added presets") }
}
