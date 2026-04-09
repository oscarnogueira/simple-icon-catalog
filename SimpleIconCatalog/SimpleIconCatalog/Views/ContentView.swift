import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: IconCatalogViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Grid
            if viewModel.filteredIcons.isEmpty && !viewModel.progress.isIndexing {
                emptyState
            } else {
                IconGridView(
                    icons: viewModel.filteredIcons,
                    thumbnailSize: viewModel.thumbnailSize,
                    cache: viewModel.cache,
                    viewModel: viewModel
                )
            }

            Divider()

            // Footer
            HStack(spacing: 8) {
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Settings")

                Text(viewModel.iconCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.progress.isIndexing {
                    ProgressView(value: viewModel.progress.fraction)
                        .frame(width: 120)
                    Text(viewModel.progress.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    // Search
                    TextField("Filter (/)", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .focused($isSearchFocused)

                    // Style filter
                    Picker("", selection: $viewModel.styleFilter) {
                        ForEach(StyleFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)

                    // Format filter
                    Picker("", selection: $viewModel.formatFilter) {
                        ForEach(FormatFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)

                    // Size slider
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $viewModel.thumbnailSize, in: 48...256)
                            .frame(width: 100)
                        Image(systemName: "square.grid.2x2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Reindex
                    Button {
                        viewModel.startIndexing()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Reindex")
                    .disabled(viewModel.progress.isIndexing)
                }
            }
        }
        .onAppear {
            viewModel.startIndexing()
            viewModel.startWatching()
        }
        .onKeyPress("/") {
            isSearchFocused = true
            return .handled
        }
        .onKeyPress(.escape) {
            if !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
                return .handled
            }
            if isSearchFocused {
                isSearchFocused = false
                return .handled
            }
            return .ignored
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No icons found")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add a directory in Preferences to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
