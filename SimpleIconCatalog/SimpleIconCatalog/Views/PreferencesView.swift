import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: IconCatalogViewModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appearanceMode) {
                    appearanceMode.apply()
                }
            }

            Section("Source Directories") {
                List {
                    ForEach(viewModel.sourceDirectories, id: \.self) { dir in
                        HStack {
                            Image(systemName: "folder")
                            Text(dir.path)
                                .lineLimit(1)
                                .truncationMode(.head)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeDirectory(dir)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(minHeight: 100)

                Button("Add Directory...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        viewModel.addDirectory(url)
                    }
                }
            }

            Section("Cache") {
                HStack {
                    Text("Thumbnail cache")
                    Spacer()
                    Button("Clear Cache") {
                        try? viewModel.clearCache()
                    }
                }
            }

            Section("Quarantine") {
                Text("Files that don't look like icons are automatically quarantined — images that are too large, too small, or have unusual aspect ratios. You can review and restore them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button {
                        openWindow(id: "quarantine")
                    } label: {
                        Label("Open Quarantine", systemImage: "exclamationmark.triangle")
                    }
                }
            }

            Section("Statistics") {
                Text("Overview of your catalog: total icons, format breakdown, directory counts, cache size, and indexing history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button {
                        openWindow(id: "statistics")
                    } label: {
                        Label("Open Statistics", systemImage: "chart.bar")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 540)
    }
}

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    func apply() {
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
