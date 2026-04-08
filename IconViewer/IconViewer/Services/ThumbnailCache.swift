import Foundation
import AppKit

struct ThumbnailCache {
    let cacheDirectory: URL

    init(cacheDirectory: URL? = nil) {
        if let dir = cacheDirectory {
            self.cacheDirectory = dir
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = caches.appendingPathComponent("IconViewer")
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory,
                                                   withIntermediateDirectories: true)
    }

    private func fileURL(forHash hash: String) -> URL {
        cacheDirectory.appendingPathComponent("\(hash).png")
    }

    func store(image: NSImage, forHash hash: String) throws {
        let size = image.size
        let width = max(1, Int(size.width))
        let height = max(1, Int(size.height))

        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let rep = bitmapRep else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = rep.representation(using: .png, properties: [:]) else { return }
        try pngData.write(to: fileURL(forHash: hash))
    }

    func retrieve(forHash hash: String) -> NSImage? {
        let url = fileURL(forHash: hash)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    func clear() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: cacheDirectory.path) {
            try fm.removeItem(at: cacheDirectory)
            try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    func sizeOnDisk() throws -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: cacheDirectory,
                                              includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(values.fileSize ?? 0)
        }
        return totalSize
    }
}
