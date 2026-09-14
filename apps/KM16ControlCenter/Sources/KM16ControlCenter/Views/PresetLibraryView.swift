import SwiftUI
import AppKit
import KM16ControlCore

struct PresetLibraryView: View {
    @Environment(ControlCenterStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selectedID = "desktop"
    @State private var exportError: String?
    private var filtered: [Profile] {
        Presets.all.filter { search.isEmpty || "\($0.name) \($0.summary)".localizedCaseInsensitiveContains(search) }
    }
    private var selected: Profile { Presets.all.first { $0.presetID == selectedID } ?? Presets.desktop() }
    private var installed: Profile? { store.document.profiles.first { $0.presetID == selectedID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preset Library").font(.title2.weight(.semibold))
                    Text("\(Presets.all.count) workspaces. Every key and dial assigned.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(24)
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 12) {
                    TextField("Search presets", text: $search).textFieldStyle(.roundedBorder).padding(.horizontal, 16).padding(.top, 16)
                    List(selection: $selectedID) {
                        ForEach(ProfileOrganization.sections(filtered)) { section in
                            Section(section.group.title) {
                                ForEach(section.profiles) { preset in
                                    Label(preset.name, systemImage: StudioStyle.profileSymbol(preset))
                                        .font(.callout).padding(.vertical, 3).tag(preset.presetID ?? "")
                                }
                            }
                        }
                    }.listStyle(.sidebar)
                    if filtered.isEmpty { Text("No matching presets").font(.caption).foregroundStyle(.secondary) }
                }.frame(width: 238)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: StudioStyle.profileSymbol(selected)).font(.system(size: 28, weight: .light)).foregroundStyle(Color.accentColor)
                        Text(selected.name).font(.system(size: 28, weight: .semibold))
                        Text(selected.summary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            if let installed {
                                Button("Open Profile") { store.select(profileID: installed.id); dismiss() }.buttonStyle(.borderedProminent)
                                Label("In your library", systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button("Add Preset") { store.addPreset(selected) }.buttonStyle(.borderedProminent)
                            }
                            Menu("More") {
                                Button("Add a Fresh Copy") { store.addPreset(selected) }
                                Button("Export Setup Files…") { exportSetup() }
                            }.fixedSize()
                        }
                        Divider()
                        Text("Setup & controls").font(.headline)
                        if let guide = PresetSetupResources.guide(for: selectedID) {
                            PresetGuideText(markdown: guide)
                        } else {
                            Text("This preset uses the actions shown on the pad. Select a control to inspect its destination and description. Preview is local; Run Selected requires live actions to be enabled in Connections.").font(.callout).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(26)
                }
            }
            Divider()
            HStack {
                Text("Adding presets preserves your existing profiles and edits.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Add Missing Presets (\(store.missingPresets.count))") { store.addMissingPresets() }.disabled(store.missingPresets.isEmpty)
            }.padding(18)
        }
        .frame(width: 850, height: 650)
        .onAppear { selectedID = store.activeProfile.presetID ?? "desktop" }
        .alert("Setup Export Failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(exportError ?? "") }
    }

    private func exportSetup() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for the setup files"
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            do { try PresetSetupResources.export(to: destination) }
            catch { exportError = error.localizedDescription }
        }
    }
}

/// Keep code blocks literal; render inline links and emphasis in ordinary paragraphs.
private struct PresetGuideText: View {
    let markdown: String
    private var blocks: [(text: String, code: Bool)] {
        markdown.components(separatedBy: "```").enumerated().map { index, part in
            if index % 2 == 1 { return (part.components(separatedBy: "\n").dropFirst().joined(separator: "\n"), true) }
            return (part, false)
        }
    }
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks.indices, id: \.self) { index in
                let block = blocks[index]
                if block.code {
                    ScrollView(.horizontal) { Text(block.text.trimmingCharacters(in: .newlines)).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).padding(12) }.studioSurface(cornerRadius: 8)
                } else {
                    ForEach(Array(block.text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                        if !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            if paragraph.hasPrefix("|") {
                                let rows = paragraph.components(separatedBy: "\n").filter { !$0.contains("| ---") }
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                                        let cells = row.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                                        HStack(alignment: .top, spacing: 14) {
                                            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                                                Text(inline(cell)).font(rowIndex == 0 ? .caption.weight(.semibold) : .caption)
                                                    .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        Divider()
                                    }
                                }
                            } else {
                                let heading = paragraph.hasPrefix("#")
                                Text(inline(paragraph.replacingOccurrences(of: "^#+ ", with: "", options: .regularExpression)))
                                    .font(heading ? .headline : .callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}

enum PresetSetupResources {
    static var directory: URL {
        let packaged = Bundle.main.resourceURL?.appendingPathComponent("KM16ControlCenter_KM16ControlCenter.bundle")
        let bundle = packaged.flatMap { Bundle(url: $0) } ?? Bundle.module
        return bundle.resourceURL!.appendingPathComponent("PresetSetup", isDirectory: true)
    }
    static func guide(for presetID: String) -> String? {
        try? String(contentsOf: directory.appendingPathComponent("\(presetID).md"), encoding: .utf8)
    }
    static func export(to directory: URL) throws {
        // A fresh subfolder avoids replacing any user-owned editor configuration.
        let destination = directory.appendingPathComponent("KM16-Preset-Setup-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.copyItem(at: Self.directory, to: destination)
    }
}
