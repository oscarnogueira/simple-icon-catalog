import Foundation
import AppKit
import CryptoKit

class IconIndexer {
    private let scanner = DirectoryScanner()
    private let svgAnalyzer = SVGAnalyzer()
    private let classifier = QuarantineClassifier()
    private let thumbnailGenerator = ThumbnailGenerator()
    private let cache: ThumbnailCache

    init(cache: ThumbnailCache = ThumbnailCache()) {
        self.cache = cache
    }

    func index(directories: [URL]) -> AsyncStream<IconItem> {
        AsyncStream { continuation in
            Task {
                do {
                    let files = try await scanner.scan(directories: directories)

                    for file in files {
                        let item = await processFile(file)
                        continuation.yield(item)
                    }
                } catch {
                    // Scanner failed — end stream
                }
                continuation.finish()
            }
        }
    }

    private func processFile(_ fileURL: URL) async -> IconItem {
        let contentHash = hashFile(fileURL)

        let ext = fileURL.pathExtension.lowercased()
        var width = 0, height = 0, isMonochrome = false
        var quarantineReason: QuarantineReason? = nil

        do {
            if ext == "svg" {
                let analysis = try svgAnalyzer.analyze(fileURL: fileURL)
                width = analysis.width
                height = analysis.height
                isMonochrome = analysis.isMonochrome
            } else {
                if let image = NSImage(contentsOf: fileURL) {
                    width = Int(image.size.width)
                    height = Int(image.size.height)
                }
            }
            quarantineReason = classifier.classify(width: width, height: height)
        } catch {
            quarantineReason = .corrupted
        }

        // Generate and cache thumbnail for non-quarantined items
        if quarantineReason == nil, cache.retrieve(forHash: contentHash) == nil {
            do {
                let thumbnail = try await thumbnailGenerator.generateThumbnail(for: fileURL)
                try cache.store(image: thumbnail, forHash: contentHash)
            } catch {
                // Thumbnail generation failed — still show in catalog without cached thumb
            }
        }

        return IconItem(
            fileURL: fileURL,
            contentHash: contentHash,
            width: width,
            height: height,
            isMonochrome: isMonochrome,
            quarantineReason: quarantineReason
        )
    }

    private func hashFile(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return UUID().uuidString }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
