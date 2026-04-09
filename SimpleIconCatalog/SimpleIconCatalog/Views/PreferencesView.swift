import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: IconCatalogViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
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

            Section {
                HStack {
                    Button {
                        openWindow(id: "quarantine")
                    } label: {
                        Label("Quarantine", systemImage: "exclamationmark.triangle")
                    }

                    Spacer()

                    Button {
                        openWindow(id: "statistics")
                    } label: {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 350)
    }
}
