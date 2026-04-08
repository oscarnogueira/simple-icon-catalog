# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Icon Viewer is a lightweight native macOS app (SwiftUI) for browsing and cataloging SVG/PNG icon collections. Users point it at directories, it indexes the images, and displays them in a scrollable grid for visual browsing and copy-to-clipboard.

## Build & Test Commands

```bash
# Regenerate Xcode project (required after adding/removing files)
cd IconViewer && xcodegen generate

# Build
cd IconViewer && xcodebuild -scheme IconViewer -destination 'platform=macOS' build

# Run all tests
cd IconViewer && xcodebuild test -scheme IconViewer -destination 'platform=macOS'

# Run a single test class
cd IconViewer && xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/DirectoryScannerTests

# Run a single test method
cd IconViewer && xcodebuild test -scheme IconViewer -destination 'platform=macOS' -only-testing:IconViewerTests/DirectoryScannerTests/testFindsIconFiles
```

## Architecture

Three-layer architecture inside `IconViewer/IconViewer/`:

- **Models/** — `IconItem`, `QuarantineReason`, `IndexingProgress`. Pure value types.
- **Services/** — Business logic. `DirectoryScanner` finds files, `SVGAnalyzer` parses SVG XML for dimensions/monochrome detection, `QuarantineClassifier` validates dimensions, `ThumbnailCache` stores PNG thumbnails on disk (`~/Library/Caches/IconViewer/`), `ThumbnailGenerator` rasterizes SVG/PNG via NSImage, `IconIndexer` orchestrates the full scan-classify-cache pipeline as an `AsyncStream<IconItem>`.
- **ViewModels/** — `IconCatalogViewModel` is the shared `@MainActor ObservableObject` (injected via `@EnvironmentObject`). `StatisticsViewModel` is a plain struct computed from catalog state.
- **Views/** — `ContentView` (main window with toolbar/grid/footer), `IconGridView` (LazyVGrid), `IconCellView` (single cell with hover/context menu), `PreferencesView`, `QuarantineView`, `StatisticsView`.
- **Utilities/** — `PasteboardHelper` copies icons to NSPasteboard as PNG.

## Key Patterns

- **XcodeGen**: Project uses `project.yml` — always run `xcodegen generate` after adding/removing Swift files.
- **Module name**: `PRODUCT_MODULE_NAME = IconViewer` (not "Icon_Viewer"). Tests use `@testable import IconViewer`.
- **Thumbnail cache**: File-based in `~/Library/Caches/IconViewer/`, keyed by SHA256 hash of file contents. Designed to be swappable to SQLite/Core Data later.
- **SVG rendering**: Primary path uses `NSImage(contentsOf:)` (macOS 14+ native SVG support). WebKit fallback is a skeleton for edge cases.
- **Monochrome SVGs**: Detected by parsing fill/stroke attributes. Rendered with theme-adaptive foregroundStyle (black in light mode, white in dark mode).
- **Quarantine**: Files with dimensions >1024px, <16px, aspect ratio >2:1, or corrupted are quarantined (hidden from main grid, visible in Quarantine window, user can restore).

## Tech Stack

- Swift 5.9, SwiftUI, macOS 14+
- XcodeGen for project generation
- CryptoKit for content hashing
- No third-party dependencies
