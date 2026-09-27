import Foundation
import KM16ControlCore

@MainActor
func profileMergeChecks(directory: URL) throws {
    // Duplicate imported names are valid documents. Both IDs must resolve to the
    // one retained destination, including forward references from other profiles.
    for mode in [ProfileImportMode.mergeKeepingExisting, .mergeReplacingNameConflicts] {
        let local = Presets.blank(name: "Local")
        let persistence = ProfilePersistence(url: directory.appendingPathComponent("merge-\(mode.rawValue).json"))
        let original = ProfileDocument(activeProfileID: local.id, profiles: [local])
        try persistence.save(original)
        let store = ControlCenterStore(persistence: persistence)
        var source = Presets.blank(name: "Source")
        let first = Presets.blank(name: "Destination")
        var second = Presets.blank(name: "destination")
        second.summary = "Replacement"
        source.bindings[0].action = ControlAction(kind: .profileSwitch, label: "First", parameter: first.id.uuidString)
        source.bindings[1].action = ControlAction(kind: .profileSwitch, label: "Second", parameter: second.id.uuidString)
        let imported = ProfileDocument(activeProfileID: source.id, profiles: [source, first, second])
        let input = directory.appendingPathComponent("duplicate-names.json")
        try persistence.exportDocument(imported, to: input)
        store.importProfiles(from: input, mode: mode)
        guard store.document.profiles.count == 3,
              let destination = store.document.profiles.first(where: { $0.name.lowercased() == "destination" }),
              let mergedSource = store.document.profiles.first(where: { $0.id == source.id }),
              mergedSource.bindings.prefix(2).allSatisfy({ UUID(uuidString: $0.action.parameter) == destination.id }),
              destination.summary == (mode == .mergeKeepingExisting ? first.summary : "Replacement") else {
            throw StoreSelfTestError.assertion("Duplicate-name merge lost a profile-switch destination in \(mode.rawValue)")
        }
        try ProfileValidator.validate(store.document)
        let merged = store.document
        store.undo()
        guard store.document == original else { throw StoreSelfTestError.assertion("Merge undo changed the original library") }
        store.redo()
        guard store.document == merged else { throw StoreSelfTestError.assertion("Merge redo changed profile identities") }
    }
}
