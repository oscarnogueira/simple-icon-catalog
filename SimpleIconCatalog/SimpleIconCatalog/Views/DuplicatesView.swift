import SwiftUI

struct DuplicatesView: View {
    @ObservedObject var viewModel: IconCatalogViewModel
    @State private var pendingDelete: (item: IconItem, group: DuplicateGroup)?

    private var groups: [DuplicateGroup] { viewModel.duplicateGroups }

    private var totalWastedBytes: Int64 { groups.reduce(0) { $0 + $1.wastedBytes } }
    private var totalDuplicatedFiles: Int { groups.reduce(0) { $0 + ($1.count - 1) } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(groups) { group in
                            groupCard(group)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 720, height: 520)
        .alert(
            "Move to Trash?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Move to Trash", role: .destructive) {
                if let pending = pendingDelete {
                    viewModel.deleteDuplicate(pending.item, in: pending.group)
                    pendingDelete = nil
                }
            }
        } message: {
            if let pending = pendingDelete {
                Text("Move \(pending.item.fileName) to the Trash. Favorite and collection memberships will transfer to the remaining copies.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "square.on.square.dashed")
                .font(.title)
                .foregroundStyle(groups.isEmpty ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(groups.isEmpty ? "No duplicates found" : "\(groups.count) group\(groups.count == 1 ? "" : "s") · \(totalDuplicatedFiles) duplicated file\(totalDuplicatedFiles == 1 ? "" : "s")")
                    .font(.headline)
                if !groups.isEmpty {
                    Text("\(ByteCountFormatter.string(fromByteCount: totalWastedBytes, countStyle: .file)) reclaimable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("Your catalog is clean")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func groupCard(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(group.count) copies")
                    .font(.subheadline.bold())
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(ByteCountFormatter.string(fromByteCount: group.wastedBytes, countStyle: .file)) reclaimable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(group.id.prefix(8)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            ForEach(group.icons) { item in
                duplicateRow(item: item, in: group)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func duplicateRow(item: IconItem, in group: DuplicateGroup) -> some View {
        HStack(spacing: 10) {
            Group {
                if let nsImage = NSImage(contentsOf: item.fileURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image(systemName: "questionmark.square.dashed")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.tertiary)
                        .padding(4)
                }
            }
            .frame(width: 40, height: 40)
            .background(Color(white: 0.88))
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.body)
                    .lineLimit(1)
                Text(item.fileURL.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")

            Button(role: .destructive) {
                pendingDelete = (item, group)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("Move to Trash")
            .disabled(group.count <= 1)
        }
        .padding(.vertical, 4)
    }
}
