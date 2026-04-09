import Foundation

/// Persists the icon index to disk so the app doesn't need to full-scan on every launch.
struct IndexStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("IconViewer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("index.json")
    }

    func save(_ icons: [IconItem]) {
        do {
            let data = try JSONEncoder().encode(icons)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silent fail — index will be rebuilt next launch
        }
    }

    func load() -> [IconItem]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([IconItem].self, from: data)
        } catch {
            return nil
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
