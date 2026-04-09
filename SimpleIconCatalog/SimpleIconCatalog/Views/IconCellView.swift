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
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.22)
                          : Color.black.opacity(0.03))
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
            viewModel.selectedIcon = item
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .help("\(item.fileName)\n\(item.dimensions)")
        .contextMenu {
            Button("Copy Image") {
                PasteboardHelper.copyIcon(item, cache: cache)
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
            }
            Divider()
            Button(viewModel.isFavorite(item) ? "Remove from Favorites" : "Add to Favorites") {
                viewModel.toggleFavorite(item)
            }
            Divider()
            Button("Details...") {
                showDetail = true
            }
        }
        .sheet(isPresented: $showDetail) {
            IconDetailView(item: item, cache: cache)
        }
        .draggable(item.fileURL) {
            // Drag preview
            ZStack {
                iconView
                    .frame(width: 48, height: 48)
            }
        }
    }

    @State private var isHovering = false
    @State private var showDetail = false

    private var isSelected: Bool {
        viewModel.selectedIcon?.id == item.id
    }

    @ViewBuilder
    private var iconView: some View {
        if item.isMonochrome {
            thumbnailImage
                .resizable()
                .scaledToFit()
                .foregroundStyle(colorScheme == .dark ? .white : .black)
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
