import XCTest
import AppKit
@testable import IconViewer

final class ThumbnailCacheTests: XCTestCase {
    var cache: ThumbnailCache!
    var tempCacheDir: URL!

    override func setUp() {
        super.setUp()
        tempCacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SICTestCache-\(UUID().uuidString)")
        cache = ThumbnailCache(cacheDirectory: tempCacheDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempCacheDir)
        super.tearDown()
    }

    func testStoreAndRetrieve() throws {
        let image = NSImage(size: NSSize(width: 64, height: 64))
        let hash = "abc123"

        try cache.store(image: image, forHash: hash)
        let retrieved = cache.retrieve(forHash: hash)

        XCTAssertNotNil(retrieved)
    }

    func testReturnNilForMissingHash() {
        let retrieved = cache.retrieve(forHash: "nonexistent")
        XCTAssertNil(retrieved)
    }

    func testClearRemovesAllEntries() throws {
        let image = NSImage(size: NSSize(width: 64, height: 64))
        try cache.store(image: image, forHash: "hash1")
        try cache.store(image: image, forHash: "hash2")

        try cache.clear()

        XCTAssertNil(cache.retrieve(forHash: "hash1"))
        XCTAssertNil(cache.retrieve(forHash: "hash2"))
    }

    func testCacheSizeOnDisk() throws {
        let image = NSImage(size: NSSize(width: 64, height: 64))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 64).fill()
        image.unlockFocus()

        try cache.store(image: image, forHash: "hash1")

        let size = try cache.sizeOnDisk()
        XCTAssertGreaterThan(size, 0)
    }
}
