import Foundation
import SwiftUI
import Combine

enum StyleFilter: String, CaseIterable {
    case all = "All"
    case color = "Color"
    case monochrome = "Mono"
}

enum FormatFilter: String, CaseIterable {
    case all = "All"
    case svg = "SVG"
    case png = "PNG"
}

enum SortOrder: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
}

@MainActor
class IconCatalogViewModel: ObservableObject {
    @Published var allIcons: [IconItem] = []
    @Published var searchText: String = ""
    @Published var styleFilter: StyleFilter = .all
    @Published var formatFilter: FormatFilter = .all
    @Published var sortOrder: SortOrder = .name
    @Published var selectedIcon: IconItem?
    @Published var thumbnailSize: CGFloat = 64
    @Published var progress = IndexingProgress()
    @Published var lastIndexedAt: Date?
    @Published var lastIndexDuration: TimeInterval?

    @AppStorage("sourceDirectories") private var sourceDirectoriesData: Data = Data()
    @AppStorage("favoritePaths") private var favoritePathsData: Data = Data()

    private let indexer: IconIndexer
    private let indexStore = IndexStore()
    let cache: ThumbnailCache
    private var directoryWatcher: DirectoryWatcher?
    private var debounceTask: Task<Void, Never>?

    private var favoritePaths: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: favoritePathsData)) ?? []
        }
        set {
            favoritePathsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    func isFavorite(_ item: IconItem) -> Bool {
        favoritePaths.contains(item.fileURL.path)
    }

    func toggleFavorite(_ item: IconItem) {
        var paths = favoritePaths
        if paths.contains(item.fileURL.path) {
            paths.remove(item.fileURL.path)
        } else {
            paths.insert(item.fileURL.path)
        }
        favoritePaths = paths
        objectWillChange.send()
    }

    var filteredIcons: [IconItem] {
        var result = allIcons.filter { !$0.isQuarantined }
        switch styleFilter {
        case .all: break
        case .color: result = result.filter { !$0.isMonochrome }
        case .monochrome: result = result.filter { $0.isMonochrome }
        }
        switch formatFilter {
        case .all: break
        case .svg: result = result.filter { $0.fileExtension == "svg" }
        case .png: result = result.filter { $0.fileExtension == "png" }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        // Sort
        switch sortOrder {
        case .name: result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .date: result.sort { $0.modificationDate > $1.modificationDate }
        case .size: result.sort { $0.fileSize > $1.fileSize }
        }
        // Favorites first (stable, preserves sort within each group)
        let favs = favoritePaths
        result.sort { a, b in
            let aFav = favs.contains(a.fileURL.path)
            let bFav = favs.contains(b.fileURL.path)
            if aFav == bFav { return false }
            return aFav
        }
        return result
    }

    var quarantinedIcons: [IconItem] {
        allIcons.filter { $0.isQuarantined }
    }

    private var hasActiveFilter: Bool {
        !searchText.isEmpty || styleFilter != .all || formatFilter != .all
    }

    var iconCount: String {
        let filtered = filteredIcons.count
        let total = allIcons.filter { !$0.isQuarantined }.count
        if hasActiveFilter {
            return "\(filtered) of \(total) icons"
        }
        return "\(total) icon\(total == 1 ? "" : "s")"
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

    /// Called on app launch. Loads persisted index instantly, then runs incremental sync.
    func loadAndSync() {
        guard !sourceDirectories.isEmpty else { return }

        // Load persisted index immediately (instant UI)
        if let saved = indexStore.load() {
            allIcons = saved
        }

        // Then run incremental sync in background
        Task {
            await incrementalReindex()
            indexStore.save(allIcons)
        }
    }

    /// Full reindex from scratch. Used by reindex button and addDirectory.
    func startIndexing() {
        guard !sourceDirectories.isEmpty else { return }

        progress = IndexingProgress(isIndexing: true)
        allIcons = []
        let startTime = Date()

        Task { [weak self] in
            guard let self else { return }
            var count = 0
            let stream = indexer.index(directories: sourceDirectories) { total in
                Task { @MainActor in
                    self.progress.totalFiles = total
                }
            }
            for await item in stream {
                count += 1
                allIcons.append(item)
                progress.processedFiles = count
            }
            progress.isIndexing = false
            lastIndexedAt = Date()
            lastIndexDuration = Date().timeIntervalSince(startTime)
            indexStore.save(allIcons)
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
            indexStore.save(allIcons)
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
