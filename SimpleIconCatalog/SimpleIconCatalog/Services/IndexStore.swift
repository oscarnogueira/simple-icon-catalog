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
        let bundleID = Bundle.main.bundleIdentifier ?? "com.simpleiconcatalog.app"
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

        execute("""
            CREATE TABLE IF NOT EXISTS collections (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                symbol TEXT NOT NULL,
                color_hex TEXT NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0
            );
        """)

        execute("""
            CREATE TABLE IF NOT EXISTS collection_members (
                collection_id TEXT NOT NULL,
                icon_path TEXT NOT NULL,
                PRIMARY KEY (collection_id, icon_path)
            );
        """)
        execute("CREATE INDEX IF NOT EXISTS idx_cm_collection ON collection_members(collection_id);", ignoreError: true)
        execute("CREATE INDEX IF NOT EXISTS idx_cm_path ON collection_members(icon_path);", ignoreError: true)
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

    func setFavorite(paths: Set<String>, isFavorite: Bool) {
        guard !paths.isEmpty else { return }
        execute("BEGIN TRANSACTION;")
        let sql = "UPDATE icons SET is_favorite = ? WHERE path = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            execute("ROLLBACK;")
            return
        }
        let val: Int32 = isFavorite ? 1 : 0
        for path in paths {
            sqlite3_reset(stmt)
            sqlite3_bind_int(stmt, 1, val)
            sqlite3_bind_text(stmt, 2, path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        execute("COMMIT;")
    }

    // MARK: - Collections

    func saveCollection(_ c: IconCollection) {
        let sql = "INSERT OR REPLACE INTO collections (id, name, symbol, color_hex, sort_order) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        let idStr = c.id.uuidString
        sqlite3_bind_text(stmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, c.name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 3, c.symbol, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 4, c.colorHex, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(stmt, 5, Int32(c.sortOrder))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    func deleteCollection(id: UUID) {
        let idStr = id.uuidString
        execute("DELETE FROM collection_members WHERE collection_id = '\(idStr)';")
        execute("DELETE FROM collections WHERE id = '\(idStr)';")
    }

    func loadCollections() -> [IconCollection] {
        let sql = "SELECT id, name, symbol, color_hex, sort_order FROM collections ORDER BY sort_order;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var result: [IconCollection] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            guard let id = UUID(uuidString: idStr) else { continue }
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let symbol = String(cString: sqlite3_column_text(stmt, 2))
            let colorHex = String(cString: sqlite3_column_text(stmt, 3))
            let sortOrder = Int(sqlite3_column_int(stmt, 4))
            result.append(IconCollection(id: id, name: name, symbol: symbol, colorHex: colorHex, sortOrder: sortOrder))
        }
        return result
    }

    // MARK: - Collection Membership

    func addIcon(path: String, toCollection collectionID: UUID) {
        let sql = "INSERT OR IGNORE INTO collection_members (collection_id, icon_path) VALUES (?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        let idStr = collectionID.uuidString
        sqlite3_bind_text(stmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    func removeIcon(path: String, fromCollection collectionID: UUID) {
        let sql = "DELETE FROM collection_members WHERE collection_id = ? AND icon_path = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        let idStr = collectionID.uuidString
        sqlite3_bind_text(stmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    func iconPaths(inCollection collectionID: UUID) -> Set<String> {
        let sql = "SELECT icon_path FROM collection_members WHERE collection_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        let idStr = collectionID.uuidString
        sqlite3_bind_text(stmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        defer { sqlite3_finalize(stmt) }

        var paths: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            paths.insert(String(cString: sqlite3_column_text(stmt, 0)))
        }
        return paths
    }

    func addIcons(paths: Set<String>, toCollection collectionID: UUID) {
        guard !paths.isEmpty else { return }
        execute("BEGIN TRANSACTION;")
        let sql = "INSERT OR IGNORE INTO collection_members (collection_id, icon_path) VALUES (?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            execute("ROLLBACK;")
            return
        }
        let idStr = collectionID.uuidString
        for path in paths {
            sqlite3_reset(stmt)
            sqlite3_bind_text(stmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        execute("COMMIT;")
    }

    func removeIcons(paths: Set<String>, fromCollection collectionID: UUID) {
        guard !paths.isEmpty else { return }
        execute("BEGIN TRANSACTION;")
        let sql = "DELETE FROM collection_members WHERE collection_id = ? AND icon_path = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            execute("ROLLBACK;")
            return
        }
        let idStr = collectionID.uuidString
        for path in paths {
            sqlite3_reset(stmt)
            sqlite3_bind_text(stmt, 1, idStr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, path, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        execute("COMMIT;")
    }

    func loadAllMemberships() -> [UUID: Set<String>] {
        let sql = "SELECT collection_id, icon_path FROM collection_members;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }

        var result: [UUID: Set<String>] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            let path = String(cString: sqlite3_column_text(stmt, 1))
            guard let id = UUID(uuidString: idStr) else { continue }
            result[id, default: []].insert(path)
        }
        return result
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

    var databaseSize: Int64 {
        let dir = IndexStore.storeDirectory()
        let dbPath = dir.appendingPathComponent("index.db").path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
              let bytes = attrs[.size] as? Int64 else { return 0 }
        return bytes
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
