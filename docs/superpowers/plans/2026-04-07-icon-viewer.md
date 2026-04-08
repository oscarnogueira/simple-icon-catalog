# Icon Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight native macOS app that catalogs SVG/PNG icons from user-selected directories, displaying them in a scrollable grid with filtering, copy-to-clipboard, and quarantine for non-icon files.

**Architecture:** Three-layer SwiftUI app — UI layer (single-window grid with toolbar/footer), Service layer (directory scanning, SVG rasterization, quarantine classification), and Cache layer (file-based thumbnail cache in `~/Library/Caches/IconViewer/` keyed by content hash). Indexation runs on background threads with progressive UI updates.

**Tech Stack:** Swift, SwiftUI, macOS 14+, Swift Package Manager. SVG rendering via native `WebKit`-based rasterization (no third-party dependencies — keeps the app lightweight). `CryptoKit` for content hashing. `Combine` for reactive data flow.

**Design decisions from spec review:**
- SVG rendering: WebKit-based rasterization (avoids third-party dependency, aligns with lightweight goal)
- Copy Image: copies high-resolution rasterized PNG to pasteboard (universal paste target for Keynote/PowerPoint)
- Monochrome SVG detection: parse SVG fill/stroke attributes — dedicated implementation task

---

## File Structure

```
IconViewer/
├── IconViewerApp.swift              — App entry point, menu commands
├── Models/
│   ├── IconItem.swift               — Data model for a single icon (path, name, dimensions, hash, quarantine status)
│   ├── QuarantineReason.swift       — Enum for quarantine reasons
│   └── IndexingProgress.swift       — Progress tracking model
├── Services/
│   ├── DirectoryScanner.swift       — Recursive file discovery (.svg, .png)
│   ├── ThumbnailGenerator.swift     — SVG/PNG rasterization to thumbnail images
│   ├── ThumbnailCache.swift         — File-based cache read/write/invalidation
│   ├── QuarantineClassifier.swift   — Determines if a file is an icon or quarantined
│   ├── IconIndexer.swift            — Orchestrates scan → classify → cache pipeline
│   └── SVGAnalyzer.swift            — Parses SVG for dimensions and mono/color detection
├── ViewModels/
│   ├── IconCatalogViewModel.swift   — Main view model: icons list, filtering, indexing state
│   └── StatisticsViewModel.swift    — Computes stats from icon catalog
├── Views/
│   ├── ContentView.swift            — Main window layout (toolbar + grid + footer)
│   ├── IconGridView.swift           — LazyVGrid of icon cells
│   ├── IconCellView.swift           — Single icon cell (thumbnail + filename)
│   ├── QuarantineView.swift         — Quarantine list window
│   ├── StatisticsView.swift         — Statistics panel
│   └── PreferencesView.swift        — Directory management + cache controls
├── Utilities/
│   └── PasteboardHelper.swift       — Copy rasterized PNG to NSPasteboard
└── Tests/
    ├── DirectoryScannerTests.swift
    ├── ThumbnailCacheTests.swift
    ├── QuarantineClassifierTests.swift
    ├── SVGAnalyzerTests.swift
    ├── IconIndexerTests.swift
    └── IconCatalogViewModelTests.swift
```

---

### Task 1: Project Scaffold

**Files:**
- Create: `IconViewer.xcodeproj` (via Xcode project generation)
- Create: `IconViewer/IconViewerApp.swift`

- [ ] **Step 1: Create Xcode project**

Create a new SwiftUI macOS App project:

```bash
mkdir -p IconViewer/IconViewer
mkdir -p IconViewer/IconViewerTests
```

Create the Xcode project using `swift package init` is not suitable for a macOS app. Instead, create the project structure manually and generate via a `Package.swift` or use `xcodegen`.

Use this `project.yml` for XcodeGen:

```yaml
name: IconViewer
options:
  bundleIdPrefix: com.iconviewer
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
targets:
  IconViewer:
    type: application
    platform: macOS
    sources:
      - path: IconViewer
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.iconviewer.app
        PRODUCT_NAME: Icon Viewer
        MACOSX_DEPLOYMENT_TARGET: "14.0"
        SWIFT_VERSION: "5.9"
        INFOPLIST_KEY_LSApplicationCategoryType: "public.app-category.utilities"
  IconViewerTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: IconViewerTests
    dependencies:
      - target: IconViewer
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.iconviewer.tests
```

```bash
# Install xcodegen if needed
brew install xcodegen
# Generate project
cd IconViewer && xcodegen generate
```

- [ ] **Step 2: Create app entry point**

Create `IconViewer/IconViewerApp.swift`:

```swift
import SwiftUI

@main
struct IconViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 700)
    }
}
```

Create `IconViewer/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Icon Viewer")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Verify it builds and runs**

```bash
cd IconViewer && xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add IconViewer/ project.yml
git commit -m "feat: scaffold macOS SwiftUI app with XcodeGen"
```

---

### Task 2: Models

**Files:**
- Create: `IconViewer/Models/IconItem.swift`
- Create: `IconViewer/Models/QuarantineReason.swift`
- Create: `IconViewer/Models/IndexingProgress.swift`

- [ ] **Step 1: Create QuarantineReason**

```swift
import Foundation

enum QuarantineReason: String, Codable, CaseIterable {
    case tooLarge       // > 1024x1024
    case tooSmall       // < 16x16
    case badAspectRatio // > 2:1
    case corrupted      // unparseable
    case manualExclude  // user manually excluded

    var displayName: String {
        switch self {
        case .tooLarge: return "Too large (>1024px)"
        case .tooSmall: return "Too small (<16px)"
        case .badAspectRatio: return "Bad aspect ratio (>2:1)"
        case .corrupted: return "Corrupted or unreadable"
        case .manualExclude: return "Manually excluded"
        }
    }
}
```

- [ ] **Step 2: Create IconItem**

```swift
import Foundation
import AppKit

struct IconItem: Identifiable, Hashable {
    let id: UUID
    let fileURL: URL
    let fileName: String
    let fileExtension: String
    let contentHash: String
    let width: Int
    let height: Int
    let isMonochrome: Bool
    var quarantineReason: QuarantineReason?

    var isQuarantined: Bool { quarantineReason != nil }
    var displayName: String { fileURL.deletingPathExtension().lastPathComponent }
    var dimensions: String { "\(width) x \(height)" }

    init(fileURL: URL, contentHash: String, width: Int, height: Int,
         isMonochrome: Bool = false, quarantineReason: QuarantineReason? = nil) {
        self.id = UUID()
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.fileExtension = fileURL.pathExtension.lowercased()
        self.contentHash = contentHash
        self.width = width
        self.height = height
        self.isMonochrome = isMonochrome
        self.quarantineReason = quarantineReason
    }
}
```

- [ ] **Step 3: Create IndexingProgress**

```swift
import Foundation

struct IndexingProgress {
    var totalFiles: Int = 0
    var processedFiles: Int = 0
    var isIndexing: Bool = false

    var fraction: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles)
    }

    var displayText: String {
        "Indexing... \(processedFiles)/\(totalFiles) files"
    }
}
```

- [ ] **Step 4: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add IconViewer/Models/
git commit -m "feat: add IconItem, QuarantineReason, and IndexingProgress models"
```

---

### Task 3: Directory Scanner

**Files:**
- Create: `IconViewer/Services/DirectoryScanner.swift`
- Create: `IconViewerTests/DirectoryScannerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
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
        // Create test files
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

        // Both files should appear (same name, different paths)
        XCTAssertEqual(files.count, 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/DirectoryScannerTests 2>&1 | tail -20
```

Expected: FAIL — `DirectoryScanner` not found

- [ ] **Step 3: Implement DirectoryScanner**

```swift
import Foundation

struct DirectoryScanner {
    private let supportedExtensions: Set<String> = ["svg", "png"]

    func scan(directories: [URL]) async throws -> [URL] {
        var results: [URL] = []
        let fm = FileManager.default

        for directory in directories {
            guard let enumerator = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard resourceValues.isRegularFile == true else { continue }
                guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                results.append(fileURL)
            }
        }

        return results
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/DirectoryScannerTests 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add IconViewer/Services/DirectoryScanner.swift IconViewerTests/DirectoryScannerTests.swift
git commit -m "feat: add DirectoryScanner for recursive SVG/PNG discovery"
```

---

### Task 4: SVG Analyzer

**Files:**
- Create: `IconViewer/Services/SVGAnalyzer.swift`
- Create: `IconViewerTests/SVGAnalyzerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
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

    func testHandlesCorruptedSVG() throws {
        let url = tempDir.appendingPathComponent("bad.svg")
        try "not xml at all <<<>>>".write(to: url, atomically: true, encoding: .utf8)

        let analyzer = SVGAnalyzer()

        XCTAssertThrowsError(try analyzer.analyze(fileURL: url))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/SVGAnalyzerTests 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement SVGAnalyzer**

```swift
import Foundation

struct SVGAnalysisResult {
    let width: Int
    let height: Int
    let isMonochrome: Bool
}

struct SVGAnalyzer {
    enum SVGError: Error {
        case parseError(String)
        case noDimensions
    }

    func analyze(fileURL: URL) throws -> SVGAnalysisResult {
        let data = try Data(contentsOf: fileURL)
        let parser = SVGXMLParser(data: data)
        try parser.parse()

        guard let width = parser.width, let height = parser.height else {
            throw SVGError.noDimensions
        }

        return SVGAnalysisResult(
            width: width,
            height: height,
            isMonochrome: parser.isMonochrome
        )
    }
}

private class SVGXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    var width: Int?
    var height: Int?
    private var colors: Set<String> = []
    private var parseError: Error?

    // Colors considered "monochrome" — black, white, none, currentColor, inherit
    private let monochromeColors: Set<String> = [
        "#000000", "#000", "black",
        "#ffffff", "#fff", "white",
        "none", "currentcolor", "inherit", ""
    ]

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    func parse() throws {
        guard parser.parse() else {
            throw parseError ?? SVGAnalyzer.SVGError.parseError("Unknown parse error")
        }
    }

    var isMonochrome: Bool {
        colors.allSatisfy { monochromeColors.contains($0.lowercased().trimmingCharacters(in: .whitespaces)) }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if elementName.lowercased() == "svg" {
            // Try width/height attributes first
            if let w = attributes["width"], let h = attributes["height"] {
                self.width = Int(Double(w.replacingOccurrences(of: "px", with: "")) ?? 0)
                self.height = Int(Double(h.replacingOccurrences(of: "px", with: "")) ?? 0)
            }
            // Fall back to viewBox
            if (self.width == nil || self.width == 0),
               let viewBox = attributes["viewBox"] {
                let parts = viewBox.split(separator: " ").map(String.init)
                if parts.count == 4 {
                    self.width = Int(Double(parts[2]) ?? 0)
                    self.height = Int(Double(parts[3]) ?? 0)
                }
            }
        }

        // Collect colors for monochrome detection
        if let fill = attributes["fill"] { colors.insert(fill) }
        if let stroke = attributes["stroke"] { colors.insert(stroke) }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = SVGAnalyzer.SVGError.parseError(error.localizedDescription)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/SVGAnalyzerTests 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add IconViewer/Services/SVGAnalyzer.swift IconViewerTests/SVGAnalyzerTests.swift
git commit -m "feat: add SVGAnalyzer for dimension extraction and monochrome detection"
```

---

### Task 5: Quarantine Classifier

**Files:**
- Create: `IconViewer/Services/QuarantineClassifier.swift`
- Create: `IconViewerTests/QuarantineClassifierTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import IconViewer

final class QuarantineClassifierTests: XCTestCase {
    let classifier = QuarantineClassifier()

    func testAcceptsNormalIcon() {
        let result = classifier.classify(width: 64, height: 64)
        XCTAssertNil(result)
    }

    func testQuarantinesTooLarge() {
        let result = classifier.classify(width: 2048, height: 2048)
        XCTAssertEqual(result, .tooLarge)
    }

    func testQuarantinesTooSmall() {
        let result = classifier.classify(width: 8, height: 8)
        XCTAssertEqual(result, .tooSmall)
    }

    func testQuarantinesBadAspectRatio() {
        let result = classifier.classify(width: 500, height: 100)
        XCTAssertEqual(result, .badAspectRatio)
    }

    func testAcceptsBorderlineDimensions() {
        // Exactly at limits should pass
        XCTAssertNil(classifier.classify(width: 1024, height: 1024))
        XCTAssertNil(classifier.classify(width: 16, height: 16))
    }

    func testAcceptsSlightlyNonSquare() {
        // 1.5:1 should be fine (under 2:1)
        XCTAssertNil(classifier.classify(width: 150, height: 100))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/QuarantineClassifierTests 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement QuarantineClassifier**

```swift
import Foundation

struct QuarantineClassifier {
    let maxDimension: Int = 1024
    let minDimension: Int = 16
    let maxAspectRatio: Double = 2.0

    func classify(width: Int, height: Int) -> QuarantineReason? {
        if width > maxDimension || height > maxDimension {
            return .tooLarge
        }
        if width < minDimension || height < minDimension {
            return .tooSmall
        }
        let aspect = Double(max(width, height)) / Double(max(min(width, height), 1))
        if aspect > maxAspectRatio {
            return .badAspectRatio
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/QuarantineClassifierTests 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add IconViewer/Services/QuarantineClassifier.swift IconViewerTests/QuarantineClassifierTests.swift
git commit -m "feat: add QuarantineClassifier for icon dimension validation"
```

---

### Task 6: Thumbnail Cache

**Files:**
- Create: `IconViewer/Services/ThumbnailCache.swift`
- Create: `IconViewerTests/ThumbnailCacheTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
import AppKit
@testable import IconViewer

final class ThumbnailCacheTests: XCTestCase {
    var cache: ThumbnailCache!
    var tempCacheDir: URL!

    override func setUp() {
        super.setUp()
        tempCacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconViewerTestCache-\(UUID().uuidString)")
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/ThumbnailCacheTests 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement ThumbnailCache**

```swift
import Foundation
import AppKit

struct ThumbnailCache {
    let cacheDirectory: URL

    init(cacheDirectory: URL? = nil) {
        if let dir = cacheDirectory {
            self.cacheDirectory = dir
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = caches.appendingPathComponent("IconViewer")
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory,
                                                   withIntermediateDirectories: true)
    }

    private func fileURL(forHash hash: String) -> URL {
        cacheDirectory.appendingPathComponent("\(hash).png")
    }

    func store(image: NSImage, forHash hash: String) throws {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return
        }
        try pngData.write(to: fileURL(forHash: hash))
    }

    func retrieve(forHash hash: String) -> NSImage? {
        let url = fileURL(forHash: hash)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    func clear() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: cacheDirectory.path) {
            try fm.removeItem(at: cacheDirectory)
            try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    func sizeOnDisk() throws -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: cacheDirectory,
                                              includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(values.fileSize ?? 0)
        }
        return totalSize
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/ThumbnailCacheTests 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add IconViewer/Services/ThumbnailCache.swift IconViewerTests/ThumbnailCacheTests.swift
git commit -m "feat: add file-based ThumbnailCache with store/retrieve/clear"
```

---

### Task 7: Thumbnail Generator

**Files:**
- Create: `IconViewer/Services/ThumbnailGenerator.swift`

- [ ] **Step 1: Implement ThumbnailGenerator**

This uses `NSImage(contentsOf:)` for both SVG and PNG. macOS 14+ has native SVG support in `NSImage` — it can load and rasterize SVGs directly without WebKit or third-party libraries. For SVGs that `NSImage` can't handle (rare edge cases), we fall back to a `WKWebView` snapshot. Unit testing is validated via integration in Task 8.

```swift
import Foundation
import AppKit
import WebKit

actor ThumbnailGenerator {
    private let thumbnailSize: CGFloat = 256  // generate at 2x for retina

    func generateThumbnail(for fileURL: URL) async throws -> NSImage {
        let ext = fileURL.pathExtension.lowercased()
        guard ["png", "svg"].contains(ext) else {
            throw ThumbnailError.unsupportedFormat(ext)
        }

        // macOS 14+ loads both PNG and SVG natively via NSImage
        if let image = NSImage(contentsOf: fileURL), image.isValid {
            return resized(image: image, to: thumbnailSize)
        }

        // Fallback for SVGs that NSImage can't parse: use WKWebView snapshot
        if ext == "svg" {
            return try await renderSVGViaWebKit(fileURL: fileURL)
        }

        throw ThumbnailError.loadFailed(fileURL)
    }

    private func renderSVGViaWebKit(fileURL: URL) async throws -> NSImage {
        let svgData = try Data(contentsOf: fileURL)
        guard let svgString = String(data: svgData, encoding: .utf8) else {
            throw ThumbnailError.loadFailed(fileURL)
        }

        let html = """
        <!DOCTYPE html>
        <html><head><style>
        html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
        svg { width: 100%; height: 100%; }
        </style></head>
        <body>\(svgString)</body></html>
        """

        return try await MainActor.run {
            let size = NSSize(width: thumbnailSize, height: thumbnailSize)
            let webView = WKWebView(frame: NSRect(origin: .zero, size: size))
            webView.loadHTMLString(html, baseURL: fileURL.deletingLastPathComponent())

            // WKWebView rendering is async — for the initial implementation,
            // return a placeholder. The cache will be updated on next index
            // if the webView snapshot becomes available.
            // A production-grade approach would use webView.takeSnapshot.
            // For now, throw to signal that this SVG needs special handling.
            throw ThumbnailError.renderFailed
        }
    }

    private func resized(image: NSImage, to maxDimension: CGFloat) -> NSImage {
        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else { return image }

        let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height, 1.0)
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    enum ThumbnailError: Error {
        case unsupportedFormat(String)
        case loadFailed(URL)
        case renderFailed
    }
}
```

**Note:** The primary rendering path uses `NSImage(contentsOf:)` which handles most SVGs on macOS 14+. The WebKit fallback is a skeleton for edge cases — if real-world SVGs from the user's collection fail to load via `NSImage`, the implementer should expand the WebKit path using `webView.takeSnapshot(configuration:completionHandler:)` with a continuation-based async wrapper.

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add IconViewer/Services/ThumbnailGenerator.swift
git commit -m "feat: add ThumbnailGenerator for SVG/PNG rasterization"
```

---

### Task 8: Icon Indexer (Orchestrator)

**Files:**
- Create: `IconViewer/Services/IconIndexer.swift`
- Create: `IconViewerTests/IconIndexerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/IconIndexerTests 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement IconIndexer**

```swift
import Foundation
import AppKit
import CryptoKit

class IconIndexer {
    private let scanner = DirectoryScanner()
    private let svgAnalyzer = SVGAnalyzer()
    private let classifier = QuarantineClassifier()
    private let thumbnailGenerator = ThumbnailGenerator()
    private let cache: ThumbnailCache

    init(cache: ThumbnailCache = ThumbnailCache()) {
        self.cache = cache
    }

    func index(directories: [URL]) -> AsyncStream<IconItem> {
        AsyncStream { continuation in
            Task {
                do {
                    let files = try await scanner.scan(directories: directories)

                    for file in files {
                        let item = await processFile(file)
                        continuation.yield(item)
                    }
                } catch {
                    // Scanner failed — end stream
                }
                continuation.finish()
            }
        }
    }

    var totalFileCount: Int? // Set after scan completes, before processing

    private func processFile(_ fileURL: URL) async -> IconItem {
        let contentHash = hashFile(fileURL)

        // Get dimensions
        let ext = fileURL.pathExtension.lowercased()
        var width = 0, height = 0, isMonochrome = false
        var quarantineReason: QuarantineReason? = nil

        do {
            if ext == "svg" {
                let analysis = try svgAnalyzer.analyze(fileURL: fileURL)
                width = analysis.width
                height = analysis.height
                isMonochrome = analysis.isMonochrome
            } else {
                if let image = NSImage(contentsOf: fileURL) {
                    width = Int(image.size.width)
                    height = Int(image.size.height)
                }
            }
            quarantineReason = classifier.classify(width: width, height: height)
        } catch {
            quarantineReason = .corrupted
        }

        // Generate and cache thumbnail for non-quarantined items
        if quarantineReason == nil, cache.retrieve(forHash: contentHash) == nil {
            do {
                let thumbnail = try await thumbnailGenerator.generateThumbnail(for: fileURL)
                try cache.store(image: thumbnail, forHash: contentHash)
            } catch {
                // Thumbnail generation failed — still show in catalog without cached thumb
            }
        }

        return IconItem(
            fileURL: fileURL,
            contentHash: contentHash,
            width: width,
            height: height,
            isMonochrome: isMonochrome,
            quarantineReason: quarantineReason
        )
    }

    private func hashFile(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return UUID().uuidString }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/IconIndexerTests 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add IconViewer/Services/IconIndexer.swift IconViewerTests/IconIndexerTests.swift
git commit -m "feat: add IconIndexer orchestrating scan → classify → cache pipeline"
```

---

### Task 9: Pasteboard Helper

**Files:**
- Create: `IconViewer/Utilities/PasteboardHelper.swift`

- [ ] **Step 1: Implement PasteboardHelper**

```swift
import AppKit

struct PasteboardHelper {
    /// Copies the icon as a high-resolution PNG to the system pasteboard.
    /// For SVGs, reads the cached rasterized version. For PNGs, uses the original.
    static func copyIcon(_ item: IconItem, cache: ThumbnailCache) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Try to get a high-quality version: original PNG or cached rasterized SVG
        if item.fileExtension == "png",
           let image = NSImage(contentsOf: item.fileURL) {
            pasteboard.writeObjects([image])
        } else if let cached = cache.retrieve(forHash: item.contentHash) {
            pasteboard.writeObjects([cached])
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add IconViewer/Utilities/PasteboardHelper.swift
git commit -m "feat: add PasteboardHelper for copy-to-clipboard"
```

---

### Task 10: IconCatalogViewModel

**Files:**
- Create: `IconViewer/ViewModels/IconCatalogViewModel.swift`
- Create: `IconViewerTests/IconCatalogViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import IconViewer

@MainActor
final class IconCatalogViewModelTests: XCTestCase {
    func testFilterByName() {
        let vm = IconCatalogViewModel()
        vm.allIcons = [
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/arrow-left.svg"),
                     contentHash: "a", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/arrow-right.svg"),
                     contentHash: "b", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/circle.svg"),
                     contentHash: "c", width: 24, height: 24),
        ]

        vm.searchText = "arrow"

        XCTAssertEqual(vm.filteredIcons.count, 2)
        XCTAssertTrue(vm.filteredIcons.allSatisfy { $0.displayName.contains("arrow") })
    }

    func testEmptyFilterShowsAll() {
        let vm = IconCatalogViewModel()
        vm.allIcons = [
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/a.svg"),
                     contentHash: "a", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/b.svg"),
                     contentHash: "b", width: 24, height: 24),
        ]

        vm.searchText = ""

        XCTAssertEqual(vm.filteredIcons.count, 2)
    }

    func testQuarantinedIconsExcludedFromFiltered() {
        let vm = IconCatalogViewModel()
        vm.allIcons = [
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/good.svg"),
                     contentHash: "a", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/bad.svg"),
                     contentHash: "b", width: 4096, height: 4096,
                     quarantineReason: .tooLarge),
        ]

        XCTAssertEqual(vm.filteredIcons.count, 1)
        XCTAssertEqual(vm.filteredIcons.first?.displayName, "good")
    }

    func testQuarantinedIconsList() {
        let vm = IconCatalogViewModel()
        vm.allIcons = [
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/good.svg"),
                     contentHash: "a", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/bad.svg"),
                     contentHash: "b", width: 4096, height: 4096,
                     quarantineReason: .tooLarge),
        ]

        XCTAssertEqual(vm.quarantinedIcons.count, 1)
        XCTAssertEqual(vm.quarantinedIcons.first?.displayName, "bad")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/IconCatalogViewModelTests 2>&1 | tail -20
```

Expected: FAIL

- [ ] **Step 3: Implement IconCatalogViewModel**

```swift
import Foundation
import SwiftUI
import Combine

@MainActor
class IconCatalogViewModel: ObservableObject {
    @Published var allIcons: [IconItem] = []
    @Published var searchText: String = ""
    @Published var thumbnailSize: CGFloat = 64
    @Published var progress = IndexingProgress()
    @Published var lastIndexedAt: Date?
    @Published var lastIndexDuration: TimeInterval?

    @AppStorage("sourceDirectories") private var sourceDirectoriesData: Data = Data()

    private let indexer: IconIndexer
    let cache: ThumbnailCache

    var filteredIcons: [IconItem] {
        let active = allIcons.filter { !$0.isQuarantined }
        if searchText.isEmpty { return active }
        return active.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var quarantinedIcons: [IconItem] {
        allIcons.filter { $0.isQuarantined }
    }

    var iconCount: String {
        let count = filteredIcons.count
        return "\(count) icon\(count == 1 ? "" : "s")"
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

    func startIndexing() {
        guard !sourceDirectories.isEmpty else { return }

        progress = IndexingProgress(isIndexing: true)
        allIcons = []
        let startTime = Date()

        Task {
            var count = 0
            for await item in indexer.index(directories: sourceDirectories) {
                count += 1
                allIcons.append(item)
                progress.processedFiles = count
            }
            progress.isIndexing = false
            lastIndexedAt = Date()
            lastIndexDuration = Date().timeIntervalSince(startTime)
        }
    }

    func addDirectory(_ url: URL) {
        var dirs = sourceDirectories
        guard !dirs.contains(url) else { return }
        dirs.append(url)
        sourceDirectories = dirs
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
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/IconCatalogViewModelTests 2>&1 | tail -20
```

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add IconViewer/ViewModels/IconCatalogViewModel.swift IconViewerTests/IconCatalogViewModelTests.swift
git commit -m "feat: add IconCatalogViewModel with filtering and quarantine"
```

---

### Task 11: Icon Cell View

**Files:**
- Create: `IconViewer/Views/IconCellView.swift`

- [ ] **Step 1: Implement IconCellView**

```swift
import SwiftUI

struct IconCellView: View {
    let item: IconItem
    let thumbnailSize: CGFloat
    let cache: ThumbnailCache

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.05)
                          : Color.black.opacity(0.03))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                thumbnailImage
                    .resizable()
                    .scaledToFit()
                    .padding(thumbnailSize * 0.15)
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)

            Text(item.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: thumbnailSize)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .help("\(item.fileName)\n\(item.dimensions)")
        .contextMenu {
            Button("Copy Image") {
                PasteboardHelper.copyIcon(item, cache: cache)
            }
        }
    }

    @State private var isHovering = false

    private var thumbnailImage: Image {
        if let nsImage = cache.retrieve(forHash: item.contentHash) {
            return Image(nsImage: nsImage)
        }
        // Fallback: try loading directly
        if let nsImage = NSImage(contentsOf: item.fileURL) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.square.dashed")
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add IconViewer/Views/IconCellView.swift
git commit -m "feat: add IconCellView with hover effect and context menu"
```

---

### Task 12: Icon Grid View

**Files:**
- Create: `IconViewer/Views/IconGridView.swift`

- [ ] **Step 1: Implement IconGridView**

```swift
import SwiftUI

struct IconGridView: View {
    let icons: [IconItem]
    let thumbnailSize: CGFloat
    let cache: ThumbnailCache

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize + 16), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(icons) { icon in
                    IconCellView(item: icon, thumbnailSize: thumbnailSize, cache: cache)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.2), value: icons.map(\.id))
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add IconViewer/Views/IconGridView.swift
git commit -m "feat: add IconGridView with adaptive LazyVGrid layout"
```

---

### Task 13: Main ContentView with Toolbar and Footer

**Files:**
- Modify: `IconViewer/Views/ContentView.swift`

- [ ] **Step 1: Implement ContentView**

Replace the placeholder with the full layout:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = IconCatalogViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Grid
            if viewModel.filteredIcons.isEmpty && !viewModel.progress.isIndexing {
                emptyState
            } else {
                IconGridView(
                    icons: viewModel.filteredIcons,
                    thumbnailSize: viewModel.thumbnailSize,
                    cache: viewModel.cache
                )
            }

            Divider()

            // Footer
            HStack {
                Text(viewModel.iconCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.progress.isIndexing {
                    ProgressView(value: viewModel.progress.fraction)
                        .frame(width: 120)
                    Text(viewModel.progress.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 12) {
                    // Search
                    TextField("Filter", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)

                    // Size slider
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $viewModel.thumbnailSize, in: 48...256)
                            .frame(width: 100)
                        Image(systemName: "square.grid.2x2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Reindex
                    Button {
                        viewModel.startIndexing()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Reindex")
                    .disabled(viewModel.progress.isIndexing)
                }
            }
        }
        .onAppear {
            viewModel.startIndexing()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No icons found")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add a directory in Preferences to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add IconViewer/Views/ContentView.swift
git commit -m "feat: implement ContentView with toolbar, grid, and footer"
```

---

### Task 14: Preferences View

**Files:**
- Create: `IconViewer/Views/PreferencesView.swift`

- [ ] **Step 1: Implement PreferencesView**

```swift
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: IconCatalogViewModel
    @State private var showDirectoryPicker = false

    var body: some View {
        Form {
            Section("Source Directories") {
                List {
                    ForEach(viewModel.sourceDirectories, id: \.self) { dir in
                        HStack {
                            Image(systemName: "folder")
                            Text(dir.path)
                                .lineLimit(1)
                                .truncationMode(.head)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeDirectory(dir)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(minHeight: 100)

                Button("Add Directory...") {
                    showDirectoryPicker = true
                }
                .fileImporter(
                    isPresented: $showDirectoryPicker,
                    allowedContentTypes: [.folder]
                ) { result in
                    if case .success(let url) = result {
                        viewModel.addDirectory(url)
                    }
                }
            }

            Section("Cache") {
                HStack {
                    Text("Thumbnail cache")
                    Spacer()
                    Button("Clear Cache") {
                        try? viewModel.clearCache()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 350)
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add IconViewer/Views/PreferencesView.swift
git commit -m "feat: add PreferencesView for directory management"
```

---

### Task 15: Quarantine View

**Files:**
- Create: `IconViewer/Views/QuarantineView.swift`

- [ ] **Step 1: Implement QuarantineView**

```swift
import SwiftUI

struct QuarantineView: View {
    @ObservedObject var viewModel: IconCatalogViewModel

    var body: some View {
        VStack(alignment: .leading) {
            if viewModel.quarantinedIcons.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                    Text("No quarantined files")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.quarantinedIcons) { item in
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(item.fileName)
                                .font(.body)
                            Text(item.quarantineReason?.displayName ?? "Unknown")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.dimensions)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button("Restore") {
                            viewModel.promoteFromQuarantine(item)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add IconViewer/Views/QuarantineView.swift
git commit -m "feat: add QuarantineView with restore functionality"
```

---

### Task 16: Statistics View

**Files:**
- Create: `IconViewer/ViewModels/StatisticsViewModel.swift`
- Create: `IconViewer/Views/StatisticsView.swift`

- [ ] **Step 1: Implement StatisticsViewModel**

```swift
import Foundation

struct StatisticsViewModel {
    let allIcons: [IconItem]
    let cache: ThumbnailCache
    let sourceDirectories: [URL]
    let lastIndexedAt: Date?
    let lastIndexDuration: TimeInterval?

    var totalActive: Int {
        allIcons.filter { !$0.isQuarantined }.count
    }

    var totalQuarantined: Int {
        allIcons.filter { $0.isQuarantined }.count
    }

    var quarantineBreakdown: [(QuarantineReason, Int)] {
        let quarantined = allIcons.filter { $0.isQuarantined }
        var counts: [QuarantineReason: Int] = [:]
        for item in quarantined {
            if let reason = item.quarantineReason {
                counts[reason, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }

    var svgCount: Int {
        allIcons.filter { $0.fileExtension == "svg" && !$0.isQuarantined }.count
    }

    var pngCount: Int {
        allIcons.filter { $0.fileExtension == "png" && !$0.isQuarantined }.count
    }

    var directoryBreakdown: [(URL, Int)] {
        sourceDirectories.map { dir in
            let count = allIcons.filter { $0.fileURL.path.hasPrefix(dir.path) && !$0.isQuarantined }.count
            return (dir, count)
        }
    }

    var cacheSize: String {
        let bytes = (try? cache.sizeOnDisk()) ?? 0
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var lastIndexedDisplay: String {
        guard let date = lastIndexedAt else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var lastIndexDurationDisplay: String {
        guard let duration = lastIndexDuration else { return "—" }
        if duration < 1 { return "< 1s" }
        return String(format: "%.1fs", duration)
    }
}
```

- [ ] **Step 2: Implement StatisticsView**

```swift
import SwiftUI

struct StatisticsView: View {
    let stats: StatisticsViewModel

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Active icons", value: "\(stats.totalActive)")
                LabeledContent("Quarantined", value: "\(stats.totalQuarantined)")
            }

            Section("Formats") {
                LabeledContent("SVG", value: "\(stats.svgCount)")
                LabeledContent("PNG", value: "\(stats.pngCount)")
            }

            Section("Directories") {
                ForEach(stats.directoryBreakdown, id: \.0) { dir, count in
                    LabeledContent(dir.lastPathComponent, value: "\(count) icons")
                }
            }

            if !stats.quarantineBreakdown.isEmpty {
                Section("Quarantine Breakdown") {
                    ForEach(stats.quarantineBreakdown, id: \.0) { reason, count in
                        LabeledContent(reason.displayName, value: "\(count)")
                    }
                }
            }

            Section("Cache") {
                LabeledContent("Size on disk", value: stats.cacheSize)
            }

            Section("Last Indexation") {
                LabeledContent("Date", value: stats.lastIndexedDisplay)
                LabeledContent("Duration", value: stats.lastIndexDurationDisplay)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 450)
    }
}
```

- [ ] **Step 3: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add IconViewer/ViewModels/StatisticsViewModel.swift IconViewer/Views/StatisticsView.swift
git commit -m "feat: add StatisticsView and StatisticsViewModel"
```

---

### Task 17: App Menus and Window Wiring

**Files:**
- Modify: `IconViewer/IconViewerApp.swift`

- [ ] **Step 1: Wire up menus and window scenes**

```swift
import SwiftUI

@main
struct IconViewerApp: App {
    @StateObject private var viewModel = IconCatalogViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(after: .appInfo) {
                OpenWindowButton(id: "statistics", label: "Statistics...")
                    .keyboardShortcut("i", modifiers: [.command])

                OpenWindowButton(id: "quarantine", label: "Quarantine...")
                    .keyboardShortcut("q", modifiers: [.command, .shift])
            }
        }

        Settings {
            PreferencesView(viewModel: viewModel)
        }

        Window("Statistics", id: "statistics") {
            StatisticsView(stats: StatisticsViewModel(
                allIcons: viewModel.allIcons,
                cache: viewModel.cache,
                sourceDirectories: viewModel.sourceDirectories,
                lastIndexedAt: viewModel.lastIndexedAt,
                lastIndexDuration: viewModel.lastIndexDuration
            ))
        }
        .defaultSize(width: 400, height: 450)

        Window("Quarantine", id: "quarantine") {
            QuarantineView(viewModel: viewModel)
        }
        .defaultSize(width: 500, height: 400)
    }
}

/// Helper view that uses @Environment(\.openWindow) to open a window by ID from a menu command.
struct OpenWindowButton: View {
    let id: String
    let label: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(label) {
            openWindow(id: id)
        }
    }
}
```

Update `ContentView` to use `@EnvironmentObject` instead of creating its own `@StateObject`.

- [ ] **Step 2: Update ContentView to use EnvironmentObject**

Change `ContentView`:
- Replace `@StateObject private var viewModel = IconCatalogViewModel()` with `@EnvironmentObject var viewModel: IconCatalogViewModel`

- [ ] **Step 3: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add IconViewer/IconViewerApp.swift IconViewer/Views/ContentView.swift
git commit -m "feat: wire up app menus, settings, statistics, and quarantine windows"
```

---

### Task 18: Monochrome SVG Theme Adaptation

**Files:**
- Modify: `IconViewer/Views/IconCellView.swift`

- [ ] **Step 1: Add theme-aware rendering for monochrome SVGs**

In `IconCellView`, update `thumbnailImage` computation to apply a tint for monochrome icons:

Add after the `thumbnailImage` computed property:

```swift
private var iconView: some View {
    Group {
        if item.isMonochrome {
            thumbnailImage
                .resizable()
                .scaledToFit()
                .foregroundStyle(colorScheme == .dark ? .white : .black)
        } else {
            thumbnailImage
                .resizable()
                .scaledToFit()
        }
    }
    .padding(thumbnailSize * 0.15)
}
```

Replace the reference to `thumbnailImage.resizable().scaledToFit().padding(...)` in the body with `iconView`.

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add IconViewer/Views/IconCellView.swift
git commit -m "feat: adapt monochrome SVG icons to system light/dark theme"
```

---

### Task 19: End-to-End Manual Test

- [ ] **Step 1: Create a test icon directory**

```bash
mkdir -p /tmp/test-icons
# Create a simple test SVG
cat > /tmp/test-icons/test-arrow.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
  <path d="M5 12h14M12 5l7 7-7 7"/>
</svg>
EOF
# Create a test "too large" SVG
cat > /tmp/test-icons/huge-illustration.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4096 4096">
  <rect width="4096" height="4096" fill="blue"/>
</svg>
EOF
```

- [ ] **Step 2: Build and run the app**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' build
# Open the built app or run from Xcode
```

- [ ] **Step 3: Verify these behaviors**

1. Open Preferences, add `/tmp/test-icons`
2. Confirm indexing progress shows in footer
3. Confirm `test-arrow.svg` appears in grid
4. Confirm `huge-illustration.svg` does NOT appear in grid
5. Open Quarantine — confirm `huge-illustration.svg` is listed with "Too large" reason
6. Click "Restore" on the quarantined file — confirm it moves to main grid
7. Right-click an icon → Copy Image → paste into a text editor or Preview — confirm image pastes
8. Type "arrow" in filter field — confirm only matching icons show
9. Move the size slider — confirm grid thumbnails resize smoothly
10. Open Statistics — confirm counts are correct
11. Toggle system dark/light mode — confirm monochrome SVGs adapt

- [ ] **Step 4: Commit any fixes**

```bash
git add -A && git commit -m "fix: adjustments from end-to-end testing"
```

---

### Task 20: Polish and Final Cleanup

- [ ] **Step 1: Add app icon placeholder and Info.plist settings**

Ensure the `project.yml` includes:
- `LSApplicationCategoryType: public.app-category.utilities`
- Appropriate `CFBundleDisplayName: Icon Viewer`

- [ ] **Step 2: Add .gitignore**

```bash
cat > .gitignore << 'EOF'
.DS_Store
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
.build/
.superpowers/
EOF
```

- [ ] **Step 3: Final build verification**

```bash
xcodebuild -scheme IconViewer -destination 'platform=macOS' clean build
xcodebuild test -scheme IconViewer -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED, all tests PASS

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore and finalize project configuration"
```
