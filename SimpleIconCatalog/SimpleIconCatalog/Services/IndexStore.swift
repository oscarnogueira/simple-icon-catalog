import Foundation
import SQLite3

/// Persists the icon index and favorites in a SQLite database.
/// Location: ~/Library/Application Support/{BundleID}/index.db
/// If the database is deleted, the app performs a full rescan on next launch.
final class IndexStore {
    private var db: OpaquePointer?

    init() {
        let dir = IndexStore.storeDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbPath = dir.appendingPathComponent("index.db").path

        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            createTables()
        }
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Location

    private static func storeDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.simpleicocatalog.app"
        return appSupport.appendingPathComponent(bundleID)
    }

    // MARK: - Schema

    private func createTables() {
        execute("""
            CREATE TABLE IF NOT EXISTS icons (
                path TEXT PRIMARY KEY,
                content_hash TEXT NOT NULL,
                width INTEGER NOT NULL,
                height INTEGER NOT NULL,
                is_monochrome INTEGER NOT NULL DEFAULT 0,
                file_size INTEGER NOT NULL DEFAULT 0,
                modification_date REAL NOT NULL,
                quarantine_reason TEXT,
                is_favorite INTEGER NOT NULL DEFAULT 0
            );
        """)
        // Migration: add is_favorite column if missing (for upgrades)
        execute("ALTER TABLE icons ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0;", ignoreError: true)
    }

    // MARK: - Icons

    func saveAll(_ icons: [IconItem], favorites: Set<String>) {
        execute("BEGIN TRANSACTION;")
        execute("DELETE FROM icons;")

        let sql = """
            INSERT INTO icons (path, content_hash, width, height, is_monochrome,
                               file_size, modification_date, quarantine_reason, is_favorite)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            execute("ROLLBACK;")
            return
        }

        for icon in icons {
            sqlite3_reset(stmt)
            sqlite3_bind_text(stmt, 1, icon.fileURL.path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, icon.contentHash, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int(stmt, 3, Int32(icon.width))
            sqlite3_bind_int(stmt, 4, Int32(icon.height))
            sqlite3_bind_int(stmt, 5, icon.isMonochrome ? 1 : 0)
            sqlite3_bind_int64(stmt, 6, icon.fileSize)
            sqlite3_bind_double(stmt, 7, icon.modificationDate.timeIntervalSince1970)
            if let reason = icon.quarantineReason {
                sqlite3_bind_text(stmt, 8, reason.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            sqlite3_bind_int(stmt, 9, favorites.contains(icon.fileURL.path) ? 1 : 0)
            sqlite3_step(stmt)
        }

        sqlite3_finalize(stmt)
        execute("COMMIT;")
    }

    func loadAll() -> (icons: [IconItem], favorites: Set<String>)? {
        let sql = "SELECT path, content_hash, width, height, is_monochrome, file_size, modification_date, quarantine_reason, is_favorite FROM icons;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        var icons: [IconItem] = []
        var favorites: Set<String> = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let path = String(cString: sqlite3_column_text(stmt, 0))
            let hash = String(cString: sqlite3_column_text(stmt, 1))
            let width = Int(sqlite3_column_int(stmt, 2))
            let height = Int(sqlite3_column_int(stmt, 3))
            let isMono = sqlite3_column_int(stmt, 4) != 0
            let fileSize = sqlite3_column_int64(stmt, 5)
            let modDate = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
            let quarantine: QuarantineReason? = {
                guard sqlite3_column_type(stmt, 7) != SQLITE_NULL else { return nil }
                return QuarantineReason(rawValue: String(cString: sqlite3_column_text(stmt, 7)))
            }()
            let isFavorite = sqlite3_column_int(stmt, 8) != 0

            let url = URL(fileURLWithPath: path)
            let item = IconItem(
                fileURL: url,
                contentHash: hash,
                width: width,
                height: height,
                isMonochrome: isMono,
                fileSize: fileSize,
                modificationDate: modDate,
                quarantineReason: quarantine
            )
            icons.append(item)
            if isFavorite { favorites.insert(path) }
        }

        return icons.isEmpty ? nil : (icons, favorites)
    }

    // MARK: - Favorites

    func setFavorite(path: String, isFavorite: Bool) {
        let sql = "UPDATE icons SET is_favorite = ? WHERE path = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_int(stmt, 1, isFavorite ? 1 : 0)
        sqlite3_bind_text(stmt, 2, path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    // MARK: - Maintenance

    func clear() {
        execute("DELETE FROM icons;")
    }

    var iconCount: Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM icons;", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    // MARK: - Helpers

    @discardableResult
    private func execute(_ sql: String, ignoreError: Bool = false) -> Bool {
        var err: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &err)
        if let err { sqlite3_free(err) }
        return result == SQLITE_OK || ignoreError
    }
}
