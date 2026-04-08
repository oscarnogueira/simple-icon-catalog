import SwiftUI

struct IconCellView: View {
    let item: IconItem
    let thumbnailSize: CGFloat
    let cache: ThumbnailCache

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.12)
                          : Color.black.opacity(0.03))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

                iconView
                    .padding(thumbnailSize * 0.15)
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)

            Text(item.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: thumbnailSize)
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
            Button("Details...") {
                showDetail = true
            }
        }
        .sheet(isPresented: $showDetail) {
            IconDetailView(item: item, cache: cache)
        }
    }

    @State private var isHovering = false
    @State private var showDetail = false

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
