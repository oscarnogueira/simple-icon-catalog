import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: IconCatalogViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationSplitView {
            CollectionsSidebarView(viewModel: viewModel)
                .frame(minWidth: 180)
        } detail: {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter (/ or \u{2318}F)", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

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
                Text(viewModel.iconCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !viewModel.selectedPaths.isEmpty {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(viewModel.selectionCount)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
        .navigationTitle("Simple Icon Catalog")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    // Selection mode toggle
                    Button {
                        if viewModel.isSelectionMode {
                            viewModel.clearSelection()
                        } else {
                            viewModel.isSelectionMode = true
                        }
                    } label: {
                        Image(systemName: viewModel.isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .help(viewModel.isSelectionMode ? "Exit Selection Mode" : "Selection Mode")

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

                    // Sort order
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                viewModel.sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if viewModel.sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .frame(width: 30)
                    .help("Sort by")

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
        } // NavigationSplitView
        .toolbar {
            ToolbarItem(placement: .navigation) {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .onAppear {
            viewModel.loadAndSync()
            viewModel.startWatching()
        }
        .onKeyPress("/") {
            isSearchFocused = true
            return .handled
        }
        .onChange(of: viewModel.focusSearch) {
            if viewModel.focusSearch {
                isSearchFocused = true
                viewModel.focusSearch = false
            }
        }
        .onKeyPress(.space) {
            if let icon = viewModel.selectedIcon {
                QuickLookHelper.shared.preview(url: icon.fileURL)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if !viewModel.selectedPaths.isEmpty || viewModel.isSelectionMode {
                viewModel.clearSelection()
                return .handled
            }
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
        .background {
            // Cmd+A: Select all
            Button("") { viewModel.selectAll() }
                .keyboardShortcut("a", modifiers: .command)
                .hidden()
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
