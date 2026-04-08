import Foundation
import SwiftUI
import Combine

@MainActor
class IconCatalogViewModel: ObservableObject {
    @Published var allIcons: [IconItem] = []
    @Published var searchText: String = ""
    @Published var thumbnailSize: CGFloat = 64
    @Published var progress = IndexingProgress()
    @Published var lastIndexedAt: Date?
    @Published var lastIndexDuration: TimeInterval?

    @AppStorage("sourceDirectories") private var sourceDirectoriesData: Data = Data()

    private let indexer: IconIndexer
    let cache: ThumbnailCache

    var filteredIcons: [IconItem] {
        let active = allIcons.filter { !$0.isQuarantined }
        if searchText.isEmpty { return active }
        return active.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var quarantinedIcons: [IconItem] {
        allIcons.filter { $0.isQuarantined }
    }

    var iconCount: String {
        let count = filteredIcons.count
        return "\(count) icon\(count == 1 ? "" : "s")"
    }

    var sourceDirectories: [URL] {
        get {
            (try? JSONDecoder().decode([URL].self, from: sourceDirectoriesData)) ?? []
        }
        set {
            sourceDirectoriesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(cache: ThumbnailCache = ThumbnailCache()) {
        self.cache = cache
        self.indexer = IconIndexer(cache: cache)
    }

    func startIndexing() {
        guard !sourceDirectories.isEmpty else { return }

        progress = IndexingProgress(isIndexing: true)
        allIcons = []
        let startTime = Date()

        Task {
            var count = 0
            for await item in indexer.index(directories: sourceDirectories) {
                count += 1
                allIcons.append(item)
                progress.processedFiles = count
            }
            progress.isIndexing = false
            lastIndexedAt = Date()
            lastIndexDuration = Date().timeIntervalSince(startTime)
        }
    }

    func addDirectory(_ url: URL) {
        var dirs = sourceDirectories
        guard !dirs.contains(url) else { return }
        dirs.append(url)
        sourceDirectories = dirs
        startIndexing()
    }

    func removeDirectory(_ url: URL) {
        var dirs = sourceDirectories
        dirs.removeAll { $0 == url }
        sourceDirectories = dirs
    }

    func promoteFromQuarantine(_ item: IconItem) {
        if let index = allIcons.firstIndex(where: { $0.id == item.id }) {
            allIcons[index].quarantineReason = nil
        }
    }

    func clearCache() throws {
        try cache.clear()
    }
}
