import SwiftUI

struct QuarantineView: View {
    @ObservedObject var viewModel: IconCatalogViewModel

    var body: some View {
        VStack(alignment: .leading) {
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
                List(viewModel.quarantinedIcons) { item in
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(item.fileName)
                                .font(.body)
                            Text(item.quarantineReason?.displayName ?? "Unknown")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.dimensions)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button("Restore") {
                            viewModel.promoteFromQuarantine(item)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
