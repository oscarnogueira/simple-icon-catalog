import Foundation
import AppKit
import WebKit

actor ThumbnailGenerator {
    private let thumbnailSize: CGFloat = 256  // generate at 2x for retina

    func generateThumbnail(for fileURL: URL) async throws -> NSImage {
        let ext = fileURL.pathExtension.lowercased()
        guard ["png", "svg"].contains(ext) else {
            throw ThumbnailError.unsupportedFormat(ext)
        }

        // macOS 14+ loads both PNG and SVG natively via NSImage
        if let image = NSImage(contentsOf: fileURL), image.isValid {
            return resized(image: image, to: thumbnailSize)
        }

        // Fallback for SVGs that NSImage can't parse: use WKWebView snapshot
        if ext == "svg" {
            return try await renderSVGViaWebKit(fileURL: fileURL)
        }

        throw ThumbnailError.loadFailed(fileURL)
    }

    private func renderSVGViaWebKit(fileURL: URL) async throws -> NSImage {
        let svgData = try Data(contentsOf: fileURL)
        guard let svgString = String(data: svgData, encoding: .utf8) else {
            throw ThumbnailError.loadFailed(fileURL)
        }

        let html = """
        <!DOCTYPE html>
        <html><head><style>
        html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
        svg { width: 100%; height: 100%; }
        </style></head>
        <body>\(svgString)</body></html>
        """

        return try await MainActor.run {
            let size = NSSize(width: thumbnailSize, height: thumbnailSize)
            let webView = WKWebView(frame: NSRect(origin: .zero, size: size))
            webView.loadHTMLString(html, baseURL: fileURL.deletingLastPathComponent())

            // WKWebView rendering is async — for the initial implementation,
            // throw to signal that this SVG needs special handling.
            // Most SVGs work via NSImage on macOS 14+.
            throw ThumbnailError.renderFailed
        }
    }

    private func resized(image: NSImage, to maxDimension: CGFloat) -> NSImage {
        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else { return image }

        let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height, 1.0)
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    enum ThumbnailError: Error {
        case unsupportedFormat(String)
        case loadFailed(URL)
        case renderFailed
    }
}
