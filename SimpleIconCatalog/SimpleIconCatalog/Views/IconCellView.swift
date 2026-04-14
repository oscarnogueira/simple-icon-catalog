import SwiftUI

struct IconCellView: View {
    let item: IconItem
    let thumbnailSize: CGFloat
    let cache: ThumbnailCache
    @ObservedObject var viewModel: IconCatalogViewModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.88))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

                iconView
                    .padding(thumbnailSize * 0.15)

                if viewModel.isFavorite(item) {
                    Image(systemName: "star.fill")
                        .font(.system(size: max(thumbnailSize * 0.12, 10)))
                        .foregroundStyle(.yellow)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .padding(4)
                }

                // Selection checkbox (visible in selection mode)
                if viewModel.isSelectionMode {
                    ZStack {
                        Circle()
                            .fill(isMultiSelected ? Color.accentColor : Color.clear)
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(isMultiSelected ? Color.accentColor : Color.white.opacity(0.8), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                        if isMultiSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
                }
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)

            Text(item.displayName)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: thumbnailSize)
        }
        .onTapGesture {
            viewModel.handleClick(item, commandDown: NSEvent.modifierFlags.contains(.command),
                                  shiftDown: NSEvent.modifierFlags.contains(.shift))
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .help("\(item.fileName)\n\(item.dimensions)")
        .contextMenu { contextMenuContent }
        .sheet(isPresented: $showDetail) {
            IconDetailView(item: item, cache: cache, viewModel: viewModel)
        }
        .sheet(isPresented: $showRecolor) {
            RecolorSheetView(item: item, cache: cache, onCopied: {})
        }
        .sheet(isPresented: $showNewCollection) {
            let paths = pathsForNewCollection
            CollectionEditorView(title: "New Collection") { name, symbol, colorHex in
                viewModel.createCollection(name: name, symbol: symbol, colorHex: colorHex)
                if let newCollection = viewModel.collections.last {
                    viewModel.addToCollection(paths: paths, collectionID: newCollection.id)
                }
            }
        }
        .draggable(dragPayload) {
            ZStack {
                iconView
                    .frame(width: 48, height: 48)
                if isMultiSelected && viewModel.selectedPaths.count > 1 {
                    Text("\(viewModel.selectedPaths.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
    }

    @State private var isHovering = false
    @State private var showDetail = false
    @State private var showNewCollection = false
    @State private var showRecolor = false
    @State private var pathsForNewCollection: Set<String> = []

    private var isMultiSelected: Bool {
        viewModel.isPathSelected(item.fileURL.path)
    }

    private var isSelected: Bool {
        isMultiSelected || viewModel.selectedIcon?.id == item.id
    }

    private var dragPayload: URL {
        item.fileURL
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if viewModel.hasMultiSelection && isMultiSelected {
            multiSelectContextMenu
        } else {
            singleSelectContextMenu
        }
    }

    @ViewBuilder
    private var singleSelectContextMenu: some View {
        Button("Copy Image") {
            PasteboardHelper.copyIcon(item, cache: cache)
        }
        Button("Copy Colored...") {
            showRecolor = true
        }
        .disabled(!(item.fileExtension == "svg" && item.isMonochrome))
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
        }
        Divider()
        Button {
            viewModel.toggleFavorite(item)
        } label: {
            Label(viewModel.isFavorite(item) ? "Remove from Favorites" : "Add to Favorites", systemImage: "star")
        }
        Menu("Add to Collection") {
            ForEach(viewModel.collections) { collection in
                let isInCollection = viewModel.collectionsContaining(iconPath: item.fileURL.path).contains(where: { $0.id == collection.id })
                Button {
                    if isInCollection {
                        viewModel.removeFromCollection(iconPath: item.fileURL.path, collectionID: collection.id)
                    } else {
                        viewModel.addToCollection(iconPath: item.fileURL.path, collectionID: collection.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: collection.symbol)
                            .foregroundStyle(collection.color)
                        Text(collection.name)
                        if isInCollection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            if !viewModel.collections.isEmpty {
                Divider()
            }
            Button("New Collection...") {
                pathsForNewCollection = viewModel.hasMultiSelection ? viewModel.selectedPaths : [item.fileURL.path]
                showNewCollection = true
            }
        }
        if let collectionID = viewModel.selectedCollectionID,
           collectionID != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
           viewModel.collections.contains(where: { $0.id == collectionID }) {
            Button("Remove from Collection") {
                viewModel.removeFromCollection(iconPath: item.fileURL.path, collectionID: collectionID)
            }
        }
        Divider()
        Button {
            showDetail = true
        } label: {
            Label("Details...", systemImage: "info.circle")
        }
    }

    @ViewBuilder
    private var multiSelectContextMenu: some View {
        let paths = viewModel.selectedPaths
        let allFavorites = paths.allSatisfy { viewModel._isFavoritePath($0) }

        Text("\(paths.count) icons selected")
            .foregroundStyle(.secondary)

        Divider()

        Button {
            viewModel.toggleFavorites(for: paths)
        } label: {
            Label(allFavorites ? "Remove from Favorites" : "Add to Favorites", systemImage: "star")
        }

        Menu("Add to Collection") {
            ForEach(viewModel.collections) { collection in
                Button {
                    viewModel.addToCollection(paths: paths, collectionID: collection.id)
                } label: {
                    HStack {
                        Image(systemName: collection.symbol)
                            .foregroundStyle(collection.color)
                        Text(collection.name)
                    }
                }
            }
            if !viewModel.collections.isEmpty {
                Divider()
            }
            Button("New Collection...") {
                pathsForNewCollection = viewModel.selectedPaths
                showNewCollection = true
            }
        }

        if let collectionID = viewModel.selectedCollectionID,
           collectionID != UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
           viewModel.collections.contains(where: { $0.id == collectionID }) {
            Button("Remove from Collection") {
                viewModel.removeFromCollection(paths: paths, collectionID: collectionID)
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if item.isMonochrome {
            thumbnailImage
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black)
        } else {
            thumbnailImage
                .resizable()
                .scaledToFit()
        }
    }

    private var thumbnailImage: Image {
        if let nsImage = cache.retrieve(forHash: item.contentHash) {
            return Image(nsImage: nsImage)
        }
        // Fallback: try loading directly
        if let nsImage = NSImage(contentsOf: item.fileURL) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.square.dashed")
    }
}
