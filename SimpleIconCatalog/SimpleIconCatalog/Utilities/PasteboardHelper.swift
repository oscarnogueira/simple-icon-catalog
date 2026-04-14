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

    /// Copies a monochrome SVG to the clipboard after rewriting every fill/stroke to
    /// the requested color and rasterizing at the given longest-side size.
    /// Non-SVG or non-monochrome icons are copied via the normal `copyIcon` path.
    @discardableResult
    static func copyRecoloredIcon(_ item: IconItem, color: NSColor, cache: ThumbnailCache) -> Bool {
        guard item.fileExtension == "svg", item.isMonochrome,
              let image = SVGRecolorer.recoloredImage(from: item.fileURL, color: color) else {
            copyIcon(item, cache: cache)
            return false
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        return true
    }
}
