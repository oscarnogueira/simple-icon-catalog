import AppKit

struct PasteboardHelper {
    /// Copies the icon as a high-resolution PNG to the system pasteboard.
    /// For SVGs, reads the cached rasterized version. For PNGs, uses the original.
    static func copyIcon(_ item: IconItem, cache: ThumbnailCache) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Try to get a high-quality version: original PNG or cached rasterized SVG
        if item.fileExtension == "png",
           let image = NSImage(contentsOf: item.fileURL) {
            pasteboard.writeObjects([image])
        } else if let cached = cache.retrieve(forHash: item.contentHash) {
            pasteboard.writeObjects([cached])
        }
    }
}
