import XCTest
@testable import IconViewer

final class SVGAnalyzerTests: XCTestCase {
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

    func testExtractsDimensionsFromViewBox() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path d="M0 0h24v24H0z"/>
        </svg>
        """
        let url = tempDir.appendingPathComponent("test.svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)

        let analyzer = SVGAnalyzer()
        let result = try analyzer.analyze(fileURL: url)

        XCTAssertEqual(result.width, 24)
        XCTAssertEqual(result.height, 24)
    }

    func testExtractsDimensionsFromWidthHeight() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48">
          <rect width="48" height="48"/>
        </svg>
        """
        let url = tempDir.appendingPathComponent("test.svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)

        let analyzer = SVGAnalyzer()
        let result = try analyzer.analyze(fileURL: url)

        XCTAssertEqual(result.width, 48)
        XCTAssertEqual(result.height, 48)
    }

    func testDetectsMonochromeSVG() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path fill="#000000" d="M0 0h24v24H0z"/>
          <path fill="black" d="M5 5h14v14H5z"/>
        </svg>
        """
        let url = tempDir.appendingPathComponent("mono.svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)

        let analyzer = SVGAnalyzer()
        let result = try analyzer.analyze(fileURL: url)

        XCTAssertTrue(result.isMonochrome)
    }

    func testDetectsColorSVG() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <circle fill="#FF0000" cx="12" cy="12" r="10"/>
          <rect fill="#00FF00" x="0" y="0" width="24" height="24"/>
        </svg>
        """
        let url = tempDir.appendingPathComponent("color.svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)

        let analyzer = SVGAnalyzer()
        let result = try analyzer.analyze(fileURL: url)

        XCTAssertFalse(result.isMonochrome)
    }

    func testDetectsColorFromInlineStyle() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path style="fill: #FF5733; stroke: #333333" d="M0 0h24v24H0z"/>
        </svg>
        """
        let url = tempDir.appendingPathComponent("style-color.svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)

        let analyzer = SVGAnalyzer()
        let result = try analyzer.analyze(fileURL: url)

        XCTAssertFalse(result.isMonochrome)
    }

    func testDetectsMonoFromInlineStyle() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path style="fill: #000000; stroke: none" d="M0 0h24v24H0z"/>
        </svg>
        """
        let url = tempDir.appendingPathComponent("style-mono.svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)

        let analyzer = SVGAnalyzer()
        let result = try analyzer.analyze(fileURL: url)

        XCTAssertTrue(result.isMonochrome)
    }

    func testHandlesCorruptedSVG() throws {
        let url = tempDir.appendingPathComponent("bad.svg")
        try "not xml at all <<<>>>".write(to: url, atomically: true, encoding: .utf8)

        let analyzer = SVGAnalyzer()

        XCTAssertThrowsError(try analyzer.analyze(fileURL: url))
    }
}
