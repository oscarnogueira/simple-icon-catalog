import Foundation

/// Migrates cache and database from legacy bundle ID paths to the current one.
/// Legacy paths: "IconViewer", "com.simpleicocatalog.app"
/// Current path uses Bundle.main.bundleIdentifier ?? "com.simpleiconcatalog.app"
enum LegacyMigration {
    private static let legacyIdentifiers = ["IconViewer", "com.simpleicocatalog.app"]

    static func migrateIfNeeded() {
        let currentID = Bundle.main.bundleIdentifier ?? "com.simpleiconcatalog.app"
        let fm = FileManager.default

        // Migrate caches
        let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let currentCacheDir = cachesDir.appendingPathComponent(currentID)
        migrateDirectory(label: "cache", from: legacyIdentifiers, base: cachesDir, to: currentCacheDir, fm: fm)

        // Migrate application support (database)
        let appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let currentAppSupportDir = appSupportDir.appendingPathComponent(currentID)
        migrateDirectory(label: "appSupport", from: legacyIdentifiers, base: appSupportDir, to: currentAppSupportDir, fm: fm)
    }

    private static func migrateDirectory(label: String, from legacyIDs: [String], base: URL, to destination: URL, fm: FileManager) {
        // If destination already has files, skip migration
        if fm.fileExists(atPath: destination.path),
           let contents = try? fm.contentsOfDirectory(atPath: destination.path),
           !contents.isEmpty {
            // Still clean up empty legacy dirs
            for id in legacyIDs {
                let legacyDir = base.appendingPathComponent(id)
                if legacyDir != destination {
                    try? removeDirIfEmpty(legacyDir, fm: fm)
                }
            }
            return
        }

        // Find first legacy directory with content
        for id in legacyIDs {
            let legacyDir = base.appendingPathComponent(id)
            guard legacyDir != destination else { continue }
            guard fm.fileExists(atPath: legacyDir.path),
                  let contents = try? fm.contentsOfDirectory(atPath: legacyDir.path),
                  !contents.isEmpty else { continue }

            // Move legacy to current
            do {
                // Remove empty destination if it exists
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.moveItem(at: legacyDir, to: destination)
                AppLog.migration.notice("Migrated \(label, privacy: .public) from \(id, privacy: .public) (\(contents.count) items)")
            } catch {
                // Fallback: copy files individually
                try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
                for file in contents {
                    let src = legacyDir.appendingPathComponent(file)
                    let dst = destination.appendingPathComponent(file)
                    try? fm.moveItem(at: src, to: dst)
                }
                try? removeDirIfEmpty(legacyDir, fm: fm)
                AppLog.migration.error("Migrated \(label, privacy: .public) from \(id, privacy: .public) via fallback: \(error.localizedDescription, privacy: .public)")
            }
            break
        }
    }

    private static func removeDirIfEmpty(_ dir: URL, fm: FileManager) throws {
        if let contents = try? fm.contentsOfDirectory(atPath: dir.path), contents.isEmpty {
            try fm.removeItem(at: dir)
        }
    }
}
