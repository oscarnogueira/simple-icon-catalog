import SwiftUI

struct QuarantineView: View {
    @ObservedObject var viewModel: IconCatalogViewModel
    @State private var selectedItem: IconItem?

    var body: some View {
        HSplitView {
            // List
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.quarantinedIcons.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(.green)
                        Text("No quarantined files")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.quarantinedIcons, selection: $selectedItem) { item in
                        HStack(spacing: 10) {
                            // Thumbnail
                            Group {
                                if let nsImage = NSImage(contentsOf: item.fileURL) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "questionmark.square.dashed")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.fileName)
                                    .font(.body)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text(item.quarantineReason?.displayName ?? "Unknown")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(item.dimensions)
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Button("Restore") {
                                viewModel.promoteFromQuarantine(item)
                                if selectedItem?.id == item.id {
                                    selectedItem = nil
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                        }
                    }
                }
            }
            .frame(minWidth: 350)

            // Preview panel
            VStack {
                if let item = selectedItem {
                    quarantinePreview(item)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("Select an item to preview")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(minWidth: 250, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 450)
    }

    @ViewBuilder
    private func quarantinePreview(_ item: IconItem) -> some View {
        VStack(spacing: 12) {
            // Large preview
            Group {
                if let nsImage = NSImage(contentsOf: item.fileURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "questionmark.square.dashed")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: 200, maxHeight: 200)
            .padding()

            Text(item.displayName)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Format:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.fileExtension.uppercased())
                        .font(.caption)
                }
                HStack {
                    Text("Dimensions:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.dimensions + " px")
                        .font(.caption)
                }
                HStack {
                    Text("Reason:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.quarantineReason?.displayName ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                HStack {
                    Text("Path:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.fileURL.path)
                        .font(.caption)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            Button("Restore to Catalog") {
                viewModel.promoteFromQuarantine(item)
                selectedItem = nil
            }
            .padding(.bottom, 16)
        }
        .padding()
    }
}
