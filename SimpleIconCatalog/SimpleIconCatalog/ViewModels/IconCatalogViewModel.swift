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
    @Published var focusSearch: Bool = false
    @Published var thumbnailSize: CGFloat = 64
    @Published var progress = IndexingProgress()
    @Published var lastIndexedAt: Date? {
        didSet {
            if let lastIndexedAt {
                UserDefaults.standard.set(lastIndexedAt, forKey: "lastIndexedAt")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastIndexedAt")
            }
        }
    }
    @Published var lastIndexDuration: TimeInterval? {
        didSet {
            if let lastIndexDuration {
                UserDefaults.standard.set(lastIndexDuration, forKey: "lastIndexDuration")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastIndexDuration")
            }
        }
    }
    @Published var collections: [IconCollection] = []
    @Published var selectedCollectionID: UUID? = nil
    @Published var collectionMemberships: [UUID: Set<String>] = [:]
    @Published var selectedPaths: Set<String> = []
    @Published var isSelectionMode: Bool = false
    var lastSelectedPath: String?

    @AppStorage("sourceDirectories") private var sourceDirectoriesData: Data = Data()

    private let indexer: IconIndexer
    let indexStore = IndexStore()
    let cache: ThumbnailCache
    private var directoryWatcher: DirectoryWatcher?
    private var debounceTask: Task<Void, Never>?
    private var _favoritePaths: Set<String> = []

    func isFavorite(_ item: IconItem) -> Bool {
        _favoritePaths.contains(item.fileURL.path)
    }

    func _isFavoritePath(_ path: String) -> Bool {
        _favoritePaths.contains(path)
    }

    func toggleFavorite(_ item: IconItem) {
        let path = item.fileURL.path
        if _favoritePaths.contains(path) {
            _favoritePaths.remove(path)
            indexStore.setFavorite(path: path, isFavorite: false)
        } else {
            _favoritePaths.insert(path)
            indexStore.setFavorite(path: path, isFavorite: true)
        }
        objectWillChange.send()
    }

    var filteredIcons: [IconItem] {
        var result = allIcons.filter { !$0.isQuarantined }
        // Collection filter
        if let collectionID = selectedCollectionID {
            if collectionID == UUID(uuidString: "00000000-0000-0000-0000-000000000000")! {
                // Favorites pseudo-collection
                result = result.filter { _favoritePaths.contains($0.fileURL.path) }
            } else if let members = collectionMemberships[collectionID] {
                result = result.filter { members.contains($0.fileURL.path) }
            } else {
                result = []
            }
        }
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
        let favs = _favoritePaths
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

    private var filterObservers: Set<AnyCancellable> = []

    init(cache: ThumbnailCache = ThumbnailCache()) {
        self.cache = cache
        self.indexer = IconIndexer(cache: cache)
        self.lastIndexedAt = UserDefaults.standard.object(forKey: "lastIndexedAt") as? Date
        self.lastIndexDuration = UserDefaults.standard.object(forKey: "lastIndexDuration") as? TimeInterval
        observeFilterChanges()
    }

    private func observeFilterChanges() {
        $searchText.dropFirst().sink { [weak self] _ in self?.clearSelection() }.store(in: &filterObservers)
        $styleFilter.dropFirst().sink { [weak self] _ in self?.clearSelection() }.store(in: &filterObservers)
        $formatFilter.dropFirst().sink { [weak self] _ in self?.clearSelection() }.store(in: &filterObservers)
        $selectedCollectionID.dropFirst().sink { [weak self] _ in self?.clearSelection() }.store(in: &filterObservers)
    }

    /// Called on app launch. Loads persisted index instantly, then runs incremental sync.
    func loadAndSync() {
        // Load collections regardless of directories
        collections = indexStore.loadCollections()
        collectionMemberships = indexStore.loadAllMemberships()

        guard !sourceDirectories.isEmpty else { return }

        // Load persisted index from SQLite (instant UI)
        if let saved = indexStore.loadAll() {
            allIcons = saved.icons
            _favoritePaths = saved.favorites
        }

        // Then run incremental sync in background
        Task {
            await incrementalReindex()
            persistIndex()
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
            persistIndex()
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
            persistIndex()
        }
    }

    // MARK: - Multi-Select

    func toggleSelection(_ item: IconItem) {
        let path = item.fileURL.path
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.insert(path)
        }
        lastSelectedPath = path
        syncSelectedIcon()
    }

    func selectRange(to item: IconItem) {
        let icons = filteredIcons
        guard let anchorPath = lastSelectedPath,
              let anchorIndex = icons.firstIndex(where: { $0.fileURL.path == anchorPath }),
              let targetIndex = icons.firstIndex(where: { $0.id == item.id }) else {
            toggleSelection(item)
            return
        }
        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        for i in range {
            selectedPaths.insert(icons[i].fileURL.path)
        }
        syncSelectedIcon()
    }

    func selectAll() {
        for icon in filteredIcons {
            selectedPaths.insert(icon.fileURL.path)
        }
        syncSelectedIcon()
    }

    func clearSelection() {
        selectedPaths.removeAll()
        isSelectionMode = false
        lastSelectedPath = nil
        selectedIcon = nil
    }

    func handleClick(_ item: IconItem, commandDown: Bool, shiftDown: Bool) {
        if shiftDown {
            selectRange(to: item)
        } else if commandDown {
            if selectedPaths.isEmpty, let current = selectedIcon {
                selectedPaths.insert(current.fileURL.path)
            }
            toggleSelection(item)
        } else if isSelectionMode {
            toggleSelection(item)
        } else {
            selectedPaths.removeAll()
            lastSelectedPath = item.fileURL.path
            selectedIcon = item
        }
    }

    var hasMultiSelection: Bool {
        selectedPaths.count > 1
    }

    var selectionCount: String {
        "\(selectedPaths.count) selected"
    }

    func toggleFavorites(for paths: Set<String>) {
        let allAreFavorites = paths.allSatisfy { _favoritePaths.contains($0) }
        if allAreFavorites {
            for path in paths {
                _favoritePaths.remove(path)
            }
            indexStore.setFavorite(paths: paths, isFavorite: false)
        } else {
            for path in paths {
                _favoritePaths.insert(path)
            }
            indexStore.setFavorite(paths: paths, isFavorite: true)
        }
        objectWillChange.send()
        clearSelection()
    }

    func addToCollection(paths: Set<String>, collectionID: UUID) {
        indexStore.addIcons(paths: paths, toCollection: collectionID)
        for path in paths {
            collectionMemberships[collectionID, default: []].insert(path)
        }
        clearSelection()
    }

    func removeFromCollection(paths: Set<String>, collectionID: UUID) {
        indexStore.removeIcons(paths: paths, fromCollection: collectionID)
        for path in paths {
            collectionMemberships[collectionID]?.remove(path)
        }
        clearSelection()
    }

    func isPathSelected(_ path: String) -> Bool {
        selectedPaths.contains(path)
    }

    private func syncSelectedIcon() {
        if selectedPaths.count == 1, let path = selectedPaths.first {
            selectedIcon = allIcons.first { $0.fileURL.path == path }
        } else if selectedPaths.count > 1 {
            selectedIcon = nil
        }
    }

    // MARK: - Collections

    func createCollection(name: String, symbol: String, colorHex: String) {
        let collection = IconCollection(name: name, symbol: symbol, colorHex: colorHex, sortOrder: collections.count)
        indexStore.saveCollection(collection)
        collections.append(collection)
    }

    func updateCollection(_ collection: IconCollection) {
        indexStore.saveCollection(collection)
        if let idx = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[idx] = collection
        }
    }

    func deleteCollection(id: UUID) {
        indexStore.deleteCollection(id: id)
        collections.removeAll { $0.id == id }
        collectionMemberships.removeValue(forKey: id)
        if selectedCollectionID == id {
            selectedCollectionID = nil
        }
    }

    func addToCollection(iconPath: String, collectionID: UUID) {
        indexStore.addIcon(path: iconPath, toCollection: collectionID)
        collectionMemberships[collectionID, default: []].insert(iconPath)
    }

    func removeFromCollection(iconPath: String, collectionID: UUID) {
        indexStore.removeIcon(path: iconPath, fromCollection: collectionID)
        collectionMemberships[collectionID]?.remove(iconPath)
    }

    func collectionsContaining(iconPath: String) -> [IconCollection] {
        collections.filter { collectionMemberships[$0.id]?.contains(iconPath) == true }
    }

    func memberCount(for collectionID: UUID) -> Int {
        collectionMemberships[collectionID]?.count ?? 0
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
            persistIndex()
        }
    }

    private func incrementalReindex() async {
        guard !sourceDirectories.isEmpty else { return }

        let startTime = Date()
        let delta = await indexer.incrementalIndex(
            directories: sourceDirectories,
            existing: allIcons
        )
        defer {
            lastIndexedAt = Date()
            lastIndexDuration = Date().timeIntervalSince(startTime)
        }

        if !delta.removed.isEmpty {
            let removedPaths = Set(allIcons.filter { delta.removed.contains($0.id) }.map { $0.fileURL.path })
            selectedPaths.subtract(removedPaths)
            allIcons.removeAll { delta.removed.contains($0.id) }
        }
        for item in delta.modified {
            if let idx = allIcons.firstIndex(where: { $0.fileURL == item.fileURL }) {
                allIcons[idx] = item
            }
        }
        allIcons.append(contentsOf: delta.added)
    }

    private func persistIndex() {
        indexStore.saveAll(allIcons, favorites: _favoritePaths)
    }
}
