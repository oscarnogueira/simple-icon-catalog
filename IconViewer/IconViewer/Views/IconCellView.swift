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
                          ? Color.white.opacity(0.05)
                          : Color.black.opacity(0.03))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                thumbnailImage
                    .resizable()
                    .scaledToFit()
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
        }
    }

    @State private var isHovering = false

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
