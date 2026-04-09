import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            Text("Simple Icon Catalog")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("A lightweight catalog for your icon collections.\nBrowse, filter, and copy — all in one place.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .frame(width: 200)

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("Built with")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("SwiftUI")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text("for macOS")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    Text("Made with")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("and")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption2)
                        .foregroundStyle(.brown)
                }

                Text("Winter Garden, FL 🍊")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(32)
        .frame(width: 400, height: 400)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
