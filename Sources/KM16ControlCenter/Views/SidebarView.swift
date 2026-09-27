import SwiftUI
import KM16ControlCore

struct SidebarView: View {
    @Environment(ControlCenterStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var showingNameEditor = false
    @State private var showingPresets = false
    @State private var editingName = false
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.3x3.square").font(.system(size: 23, weight: .light))
                VStack(alignment: .leading, spacing: 2) {
                    Text("KM16").font(.system(size: 19, weight: .semibold, design: .rounded))
                    Text("Control Center").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 22)

            List(selection: selection) {
                ForEach(ProfileOrganization.sections(store.document.profiles)) { section in
                    Section(section.group.title) {
                        ForEach(section.profiles) { profile in
                            Label(profile.name, systemImage: StudioStyle.profileSymbol(profile))
                                .font(.system(size: 13, weight: profile.id == store.document.activeProfileID ? .medium : .regular))
                                .lineLimit(1)
                                .help(profile.name)
                                .padding(.vertical, 3)
                                .tag(profile.id)
                                .contextMenu {
                                    Button("Rename…") { store.select(profileID: profile.id); name = profile.name; editingName = true; showingNameEditor = true }
                                    Button("Duplicate", systemImage: "plus.square.on.square") { store.select(profileID: profile.id); store.duplicateActiveProfile() }
                                    if profile.presetID != nil { Button("Restore Preset", systemImage: "arrow.counterclockwise") { store.select(profileID: profile.id); store.resetActiveProfile() } }
                                    Divider()
                                    Button("Delete", role: .destructive) { store.select(profileID: profile.id); store.deleteActiveProfile() }.disabled(store.document.profiles.count <= 1)
                                }
                        }
                    }
                }
            }.listStyle(.sidebar).scrollContentBackground(.hidden)

            HStack {
                Menu {
                    Button("New Profile…", systemImage: "plus") { name = ""; editingName = false; showingNameEditor = true }
                    Divider()
                    Button("Browse Presets…", systemImage: "square.grid.2x2") { showingPresets = true }
                } label: { Label("New profile", systemImage: "plus").font(.system(size: 11, weight: .medium)) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).help("Create a profile or add a preset").accessibilityLabel("New profile or preset")
                Spacer()
                Menu {
                    Button("Rename…") { name = store.activeProfile.name; editingName = true; showingNameEditor = true }
                    Button("Duplicate") { store.duplicateActiveProfile() }
                    if store.activeProfile.presetID != nil { Button("Restore Preset") { store.resetActiveProfile() } }
                    Divider()
                    Button("Delete", role: .destructive) { store.deleteActiveProfile() }.disabled(store.document.profiles.count <= 1)
                } label: { Image(systemName: "ellipsis").frame(width: 20, height: 20) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Profile options").accessibilityLabel("Profile options")
            }.padding(.horizontal, 18).padding(.vertical, 14)
            Button("Preset Library", systemImage: "square.grid.2x2") { showingPresets = true }
                .buttonStyle(.plain).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.bottom, 16)
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 14) {
                Button { openWindow(id: "integrations") } label: { Label("Connections", systemImage: "point.3.connected.trianglepath.dotted").font(.system(size: 12)) }.buttonStyle(.plain)
                SettingsLink { Label("Settings", systemImage: "gearshape").font(.system(size: 12)) }.buttonStyle(.plain)
                StudioStatus("Device offline", symbol: "cable.connector")
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
        }
        .sheet(isPresented: $showingPresets) { PresetLibraryView() }
        .alert(editingName ? "Rename Profile" : "New Profile", isPresented: $showingNameEditor) {
            TextField("Name", text: $name)
            Button(editingName ? "Rename" : "Create") {
                if editingName { store.renameActiveProfile(to: name) } else { store.createProfile(named: name.isEmpty ? "Untitled Profile" : name) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    private var selection: SwiftUI.Binding<UUID?> {
        SwiftUI.Binding(get: { store.document.activeProfileID }, set: { if let id = $0 { store.select(profileID: id) } })
    }
}
