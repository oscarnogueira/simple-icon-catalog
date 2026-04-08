import XCTest
@testable import IconViewer

final class DirectoryScannerTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testFindsIconFiles() async throws {
        try "svg content".write(to: tempDir.appendingPathComponent("icon1.svg"), atomically: true, encoding: .utf8)
        try Data([0x89, 0x50]).write(to: tempDir.appendingPathComponent("icon2.png"))
        try "not an icon".write(to: tempDir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)

        let scanner = DirectoryScanner()
        let files = try await scanner.scan(directories: [tempDir])

        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.allSatisfy { ["svg", "png"].contains($0.pathExtension.lowercased()) })
    }

    func testScansSubdirectories() async throws {
        let subDir = tempDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "svg".write(to: tempDir.appendingPathComponent("a.svg"), atomically: true, encoding: .utf8)
        try "svg".write(to: subDir.appendingPathComponent("b.svg"), atomically: true, encoding: .utf8)

        let scanner = DirectoryScanner()
        let files = try await scanner.scan(directories: [tempDir])

        XCTAssertEqual(files.count, 2)
    }

    func testHandlesEmptyDirectory() async throws {
        let scanner = DirectoryScanner()
        let files = try await scanner.scan(directories: [tempDir])

        XCTAssertTrue(files.isEmpty)
    }

    func testDeduplicatesAcrossDirectories() async throws {
        let dir2 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir2) }

        try "svg".write(to: tempDir.appendingPathComponent("icon.svg"), atomically: true, encoding: .utf8)
        try "svg".write(to: dir2.appendingPathComponent("icon.svg"), atomically: true, encoding: .utf8)

        let scanner = DirectoryScanner()
        let files = try await scanner.scan(directories: [tempDir, dir2])

        XCTAssertEqual(files.count, 2)
    }
}
