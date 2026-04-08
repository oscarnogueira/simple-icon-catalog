import Foundation
import SwiftUI
import Combine

enum StyleFilter: String, CaseIterable {
    case all = "All"
    case color = "Color"
    case monochrome = "Mono"
}

@MainActor
class IconCatalogViewModel: ObservableObject {
    @Published var allIcons: [IconItem] = []
    @Published var searchText: String = ""
    @Published var styleFilter: StyleFilter = .all
    @Published var thumbnailSize: CGFloat = 64
    @Published var progress = IndexingProgress()
    @Published var lastIndexedAt: Date?
    @Published var lastIndexDuration: TimeInterval?

    @AppStorage("sourceDirectories") private var sourceDirectoriesData: Data = Data()

    private let indexer: IconIndexer
    let cache: ThumbnailCache
    private var directoryWatcher: DirectoryWatcher?
    private var debounceTask: Task<Void, Never>?

    var filteredIcons: [IconItem] {
        var result = allIcons.filter { !$0.isQuarantined }
        switch styleFilter {
        case .all: break
        case .color: result = result.filter { !$0.isMonochrome }
        case .monochrome: result = result.filter { $0.isMonochrome }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
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
        startWatching()
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

    func startWatching() {
        directoryWatcher = DirectoryWatcher { [weak self] in
            self?.debouncedReindex()
        }
        directoryWatcher?.watch(directories: sourceDirectories)
    }

    private func debouncedReindex() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await incrementalReindex()
        }
    }

    private func incrementalReindex() async {
        guard !sourceDirectories.isEmpty else { return }

        let delta = await indexer.incrementalIndex(
            directories: sourceDirectories,
            existing: allIcons
        )

        // Remove deleted
        if !delta.removed.isEmpty {
            allIcons.removeAll { delta.removed.contains($0.id) }
        }

        // Update modified (replace in place)
        for item in delta.modified {
            if let idx = allIcons.firstIndex(where: { $0.fileURL == item.fileURL }) {
                allIcons[idx] = item
            }
        }

        // Add new
        allIcons.append(contentsOf: delta.added)
    }
}
