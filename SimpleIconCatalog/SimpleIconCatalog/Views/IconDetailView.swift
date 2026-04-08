import SwiftUI

struct IconDetailView: View {
    let item: IconItem
    let cache: ThumbnailCache

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.08)
                          : Color.black.opacity(0.03))

                preview
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            }
            .frame(width: 180, height: 180)

            // Info
            VStack(alignment: .leading, spacing: 12) {
                Text(item.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textSelection(.enabled)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        detailLabel("Format")
                        detailValue(item.fileExtension.uppercased())
                    }
                    GridRow {
                        detailLabel("Dimensions")
                        detailValue(item.dimensions + " px")
                    }
                    GridRow {
                        detailLabel("File size")
                        detailValue(fileSize)
                    }
                    GridRow {
                        detailLabel("Style")
                        detailValue(styleDescription)
                    }
                    GridRow {
                        detailLabel("Path")
                        detailValue(item.fileURL.path)
                    }
                    GridRow {
                        detailLabel("Directory")
                        detailValue(item.fileURL.deletingLastPathComponent().path)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Copy Image") {
                        PasteboardHelper.copyIcon(item, cache: cache)
                    }

                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
                    }

                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.fileURL.path, forType: .string)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 520, height: 260)
    }

    private func detailLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 80, alignment: .trailing)
    }

    private func detailValue(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .textSelection(.enabled)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var preview: Image {
        if let nsImage = cache.retrieve(forHash: item.contentHash) {
            return Image(nsImage: nsImage)
        }
        if let nsImage = NSImage(contentsOf: item.fileURL) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.square.dashed")
    }

    private var fileSize: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: item.fileURL.path),
              let bytes = attrs[.size] as? Int64 else {
            return "—"
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var styleDescription: String {
        if item.isMonochrome {
            return "Monochrome"
        } else {
            return "Color"
        }
    }
}
