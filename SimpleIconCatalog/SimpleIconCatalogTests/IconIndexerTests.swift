import XCTest
import AppKit
@testable import IconViewer

final class IconIndexerTests: XCTestCase {
    var tempDir: URL!
    var tempCacheDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconViewerTest-\(UUID().uuidString)")
        tempCacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconViewerTestCache-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: tempCacheDir)
        super.tearDown()
    }

    func testIndexesSVGFile() async throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
          <rect fill="#FF0000" width="64" height="64"/>
        </svg>
        """
        try svg.write(to: tempDir.appendingPathComponent("test.svg"),
                      atomically: true, encoding: .utf8)

        let cache = ThumbnailCache(cacheDirectory: tempCacheDir)
        let indexer = IconIndexer(cache: cache)

        var icons: [IconItem] = []
        for await item in indexer.index(directories: [tempDir]) {
            icons.append(item)
        }

        XCTAssertEqual(icons.count, 1)
        XCTAssertEqual(icons.first?.fileName, "test.svg")
        XCTAssertFalse(icons.first?.isQuarantined ?? true)
    }

    func testQuarantinesOversizedFile() async throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4096 4096">
          <rect width="4096" height="4096"/>
        </svg>
        """
        try svg.write(to: tempDir.appendingPathComponent("huge.svg"),
                      atomically: true, encoding: .utf8)

        let cache = ThumbnailCache(cacheDirectory: tempCacheDir)
        let indexer = IconIndexer(cache: cache)

        var icons: [IconItem] = []
        for await item in indexer.index(directories: [tempDir]) {
            icons.append(item)
        }

        XCTAssertEqual(icons.count, 1)
        XCTAssertTrue(icons.first?.isQuarantined ?? false)
        XCTAssertEqual(icons.first?.quarantineReason, .tooLarge)
    }
}
