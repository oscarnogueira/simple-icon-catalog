import SwiftUI

struct RecolorSheetView: View {
    let item: IconItem
    let cache: ThumbnailCache
    let onCopied: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("recolorRecentHexColors") private var recentsBlob: String = ""
    @AppStorage("recolorPreviewBackgroundHex") private var backgroundHex: String = "#E0E0E0"
    @State private var color: Color = .black
    @State private var background: Color = Color(white: 0.88)

    private var recents: [String] {
        recentsBlob.split(separator: ",").map(String.init).filter { $0.hasPrefix("#") }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Copy Colored")
                .font(.headline)

            preview

            LabeledContent("Icon color") {
                ColorPicker("", selection: $color, supportsOpacity: false)
                    .labelsHidden()
            }
            LabeledContent("Preview background") {
                ColorPicker("", selection: $background, supportsOpacity: false)
                    .labelsHidden()
            }

            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(recents, id: \.self) { hex in
                            Button {
                                color = Color(hex: hex)
                            } label: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: hex))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(hex)
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Cancel") {
                    if NSColorPanel.shared.isVisible {
                        NSColorPanel.shared.close()
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Copy") {
                    copyAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .help("Copy to clipboard (⏎)")
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            background = Color(hex: backgroundHex)
        }
        .onChange(of: background) { _, newValue in
            backgroundHex = newValue.toHex()
        }
        .onExitCommand {
            if NSColorPanel.shared.isVisible {
                NSColorPanel.shared.close()
            } else {
                dismiss()
            }
        }
        .onDisappear {
            if NSColorPanel.shared.isVisible {
                NSColorPanel.shared.close()
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(background)
                .frame(width: 140, height: 140)
            if let nsImage = SVGRecolorer.recoloredImage(from: item.fileURL, color: NSColor(color), size: 256) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108, height: 108)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func copyAndDismiss() {
        let nsColor = NSColor(color)
        PasteboardHelper.copyRecoloredIcon(item, color: nsColor, cache: cache)
        saveRecent(hex: nsColor.hexString)
        AppLog.app.notice("Recolor copy \(item.fileName, privacy: .public) -> \(nsColor.hexString, privacy: .public)")
        onCopied()
        dismiss()
    }

    private func saveRecent(hex: String) {
        var list = recents.filter { $0.lowercased() != hex.lowercased() }
        list.insert(hex, at: 0)
        if list.count > 5 { list = Array(list.prefix(5)) }
        recentsBlob = list.joined(separator: ",")
    }
}

private extension NSColor {
    var hexString: String {
        let rgb = usingColorSpace(.sRGB) ?? self
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
