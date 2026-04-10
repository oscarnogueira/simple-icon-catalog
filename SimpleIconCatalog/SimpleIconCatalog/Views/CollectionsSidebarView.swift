import SwiftUI

struct CollectionsSidebarView: View {
    @ObservedObject var viewModel: IconCatalogViewModel
    @State private var showNewCollection = false
    @State private var editingCollection: IconCollection?

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

            if !viewModel.collections.isEmpty {
                Section("Collections") {
                    ForEach(viewModel.collections) { collection in
                        collectionRow(collection)
                            .tag(collection.id as UUID?)
                            .onTapGesture {
                                viewModel.selectedCollectionID = collection.id
                            }
                            .dropDestination(for: URL.self) { urls, _ in
                                for url in urls {
                                    viewModel.addToCollection(iconPath: url.path, collectionID: collection.id)
                                }
                                return true
                            }
                            .contextMenu {
                                Button("Edit...") {
                                    editingCollection = collection
                                }
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteCollection(id: collection.id)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                showNewCollection = true
            } label: {
                Label("New Collection", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
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
