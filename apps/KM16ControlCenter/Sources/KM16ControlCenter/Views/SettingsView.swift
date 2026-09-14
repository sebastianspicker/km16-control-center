import SwiftUI

struct SettingsView: View {
    @Environment(ControlCenterStore.self) private var store
    @AppStorage("KM16.overlayFloating") private var overlayFloating = false
    @AppStorage("KM16.overlayPosition") private var overlayPosition = "Remembered"
    @State private var bundleIDs = ""
    @State private var summary = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Settings").font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("Profile matching, the overlay, and local storage.").foregroundStyle(.secondary)
                }
                matching
                overlay
                storage
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .onAppear(perform: syncFields)
        .onChange(of: store.document.activeProfileID) { _, _ in syncFields() }
    }

    private var matching: some View {
        StudioSection("Profile matching", subtitle: "Switch profiles when the foreground app changes.") {
            Toggle("Match the foreground app automatically", isOn: Bindable(store).automaticProfileMatchingEnabled)
            if let override = store.manualProfileOverrideID,
               let profile = store.document.profiles.first(where: { $0.id == override }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manual selection")
                        Text(profile.name).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Resume automatic matching") { store.clearManualOverride() }.controlSize(.small)
                }
            }
            HStack {
                Text("Current foreground app").foregroundStyle(.secondary)
                Spacer()
                Text(store.lastForegroundBundleID ?? "Not checked").textSelection(.enabled)
            }
            .font(.caption)
            Button("Match foreground app now") { store.matchForegroundApplication() }.controlSize(.small)
            Divider()
            TextField("Profile summary", text: $summary, axis: .vertical).lineLimit(2...4)
            TextField("Bundle identifiers", text: $bundleIDs, axis: .vertical).lineLimit(2...5)
            HStack {
                Text("Separate identifiers with commas or new lines.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Apply") {
                    store.updateActiveProfile(
                        summary: summary,
                        matchingBundleIDs: bundleIDs.split(whereSeparator: { $0 == "," || $0 == "\n" })
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    )
                }
                .buttonStyle(.borderedProminent).tint(StudioStyle.accent)
            }
        }
    }

    private var overlay: some View {
        StudioSection("Overlay", subtitle: "A compact reference window for the active profile.") {
            Toggle("Keep overlay above normal windows", isOn: $overlayFloating)
            Picker("Opening position", selection: $overlayPosition) {
                Text("Remembered by macOS").tag("Remembered")
                Text("Centered on open").tag("Center")
            }
            .pickerStyle(.radioGroup)
            .controlSize(.small)
        }
    }

    private var storage: some View {
        StudioSection("Storage", subtitle: "Save changes to your local profile library.") {
            Text(store.persistence.url.path)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .studioSurface(cornerRadius: 10)
            if let recovery = store.recoveryMessage {
                Label(recovery, systemImage: "arrow.counterclockwise.circle").font(.caption).foregroundStyle(.secondary)
            }
            Button("Show recovery files") { store.revealRecoveryFiles() }.controlSize(.small)
        }
    }

    private func syncFields() {
        summary = store.activeProfile.summary
        bundleIDs = store.activeProfile.matchingBundleIDs.joined(separator: ", ")
    }
}
