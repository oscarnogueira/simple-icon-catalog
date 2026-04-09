import Foundation
import AppKit
import CryptoKit

struct IndexDelta {
    var added: [IconItem] = []
    var removed: Set<UUID> = []
    var modified: [IconItem] = []
}

class IconIndexer {
    private let scanner = DirectoryScanner()
    private let svgAnalyzer = SVGAnalyzer()
    private let classifier = QuarantineClassifier()
    private let thumbnailGenerator = ThumbnailGenerator()
    private let cache: ThumbnailCache

    init(cache: ThumbnailCache = ThumbnailCache()) {
        self.cache = cache
    }

    /// Full index — scans everything from scratch.
    /// onTotalCount is called with the total file count before processing begins.
    func index(directories: [URL], onTotalCount: (@Sendable (Int) -> Void)? = nil) -> AsyncStream<IconItem> {
        AsyncStream { continuation in
            Task {
                do {
                    let files = try await scanner.scan(directories: directories)
                    onTotalCount?(files.count)

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

    /// Incremental index — compares current files on disk against existing icons.
    /// Returns only the delta: new files, removed files, and modified files.
    func incrementalIndex(directories: [URL], existing: [IconItem]) async -> IndexDelta {
        var delta = IndexDelta()

        guard let currentFiles = try? await scanner.scan(directories: directories) else {
            return delta
        }

        let currentPaths = Set(currentFiles.map(\.path))
        let existingByPath = Dictionary(uniqueKeysWithValues: existing.map { ($0.fileURL.path, $0) })
        let existingPaths = Set(existingByPath.keys)

        // Removed: in existing but no longer on disk
        for path in existingPaths.subtracting(currentPaths) {
            if let item = existingByPath[path] {
                delta.removed.insert(item.id)
            }
        }

        // New or modified
        for fileURL in currentFiles {
            let path = fileURL.path
            if let existingItem = existingByPath[path] {
                // Check if file was modified by comparing content hash
                let currentHash = hashFile(fileURL)
                if currentHash != existingItem.contentHash {
                    let item = await processFile(fileURL)
                    delta.modified.append(item)
                }
            } else {
                // New file
                let item = await processFile(fileURL)
                delta.added.append(item)
            }
        }

        return delta
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
