import SwiftUI

struct CollectionsSidebarView: View {
    @ObservedObject var viewModel: IconCatalogViewModel
    @State private var showNewCollection = false
    @State private var editingCollection: IconCollection?
    @State private var collectionToDelete: IconCollection?

    var body: some View {
        List(selection: $viewModel.selectedCollectionID) {
            // All Icons
            Label("All Icons", systemImage: "square.grid.2x2")
                .tag(nil as UUID?)
                .onTapGesture { viewModel.selectedCollectionID = nil }

            // Favorites
            Label {
                Text("Favorites")
            } icon: {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
            .badge(favoriteCount)
            .tag(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
            .onTapGesture {
                viewModel.selectedCollectionID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
            }

            Section {
                ForEach(viewModel.collections) { collection in
                        collectionRow(collection)
                            .tag(collection.id as UUID?)
                            .onTapGesture {
                                viewModel.selectedCollectionID = collection.id
                            }
                            .dropDestination(for: URL.self) { urls, _ in
                                let droppedPaths = Set(urls.map(\.path))
                                // If the dragged icon is part of a multi-selection, use all selected paths
                                if !viewModel.selectedPaths.isEmpty && !viewModel.selectedPaths.isDisjoint(with: droppedPaths) {
                                    viewModel.addToCollection(paths: viewModel.selectedPaths, collectionID: collection.id)
                                } else {
                                    for url in urls {
                                        viewModel.addToCollection(iconPath: url.path, collectionID: collection.id)
                                    }
                                }
                                return true
                            }
                            .contextMenu {
                                Button("Edit...") {
                                    editingCollection = collection
                                }
                                Button("Delete", role: .destructive) {
                                    if viewModel.memberCount(for: collection.id) > 0 {
                                        collectionToDelete = collection
                                    } else {
                                        viewModel.deleteCollection(id: collection.id)
                                    }
                                }
                            }
                    }
            } header: {
                HStack(alignment: .center) {
                    Text("Collections")
                    Spacer()
                    Button {
                        showNewCollection = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("New Collection")
                    .padding(.trailing, 4)
                }
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(title: "New Collection") { name, symbol, colorHex in
                viewModel.createCollection(name: name, symbol: symbol, colorHex: colorHex)
            }
        }
        .sheet(item: $editingCollection) { collection in
            CollectionEditorView(
                title: "Edit Collection",
                name: collection.name,
                symbol: collection.symbol,
                colorHex: collection.colorHex
            ) { name, symbol, colorHex in
                var updated = collection
                updated.name = name
                updated.symbol = symbol
                updated.colorHex = colorHex
                viewModel.updateCollection(updated)
            }
        }
        .alert(
            "Delete \"\(collectionToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { collectionToDelete != nil },
                set: { if !$0 { collectionToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                collectionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let collection = collectionToDelete {
                    viewModel.deleteCollection(id: collection.id)
                    collectionToDelete = nil
                }
            }
        } message: {
            let count = viewModel.memberCount(for: collectionToDelete?.id ?? UUID())
            Text("This collection contains \(count) icon\(count == 1 ? "" : "s"). The icons won't be deleted from disk.")
        }
    }

    private func collectionRow(_ collection: IconCollection) -> some View {
        Label {
            Text(collection.name)
        } icon: {
            Image(systemName: collection.symbol)
                .foregroundStyle(collection.color)
        }
        .badge(viewModel.memberCount(for: collection.id))
    }

    private var favoriteCount: Int {
        viewModel.allIcons.filter { !$0.isQuarantined && viewModel.isFavorite($0) }.count
    }
}
