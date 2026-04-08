# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Simple Icon Catalog is a lightweight native macOS app (SwiftUI) for browsing and cataloging SVG/PNG icon collections. Users point it at directories, it indexes the images, and displays them in a scrollable grid for visual browsing and copy-to-clipboard.

## Build & Test Commands

```bash
# Regenerate Xcode project (required after adding/removing files)
cd SimpleIconCatalog && xcodegen generate

# Build
cd SimpleIconCatalog && xcodebuild -scheme SimpleIconCatalog -destination 'platform=macOS' build

# Run all tests
cd SimpleIconCatalog && xcodebuild test -scheme SimpleIconCatalog -destination 'platform=macOS'

# Run a single test class
cd SimpleIconCatalog && xcodebuild test -scheme SimpleIconCatalog -destination 'platform=macOS' -only-testing:SimpleIconCatalogTests/DirectoryScannerTests

# Run a single test method
cd SimpleIconCatalog && xcodebuild test -scheme SimpleIconCatalog -destination 'platform=macOS' -only-testing:SimpleIconCatalogTests/DirectoryScannerTests/testFindsIconFiles
```

## Architecture

Three-layer architecture inside `SimpleIconCatalog/SimpleIconCatalog/`:

- **Models/** — `IconItem`, `QuarantineReason`, `IndexingProgress`. Pure value types.
- **Services/** — Business logic. `DirectoryScanner` finds files, `SVGAnalyzer` parses SVG XML for dimensions/monochrome detection, `QuarantineClassifier` validates dimensions, `ThumbnailCache` stores PNG thumbnails on disk (`~/Library/Caches/IconViewer/`), `ThumbnailGenerator` rasterizes SVG/PNG via NSImage, `IconIndexer` orchestrates the full scan-classify-cache pipeline as an `AsyncStream<IconItem>`, `DirectoryWatcher` monitors directories for changes via GCD DispatchSource.
- **ViewModels/** — `IconCatalogViewModel` is the shared `@MainActor ObservableObject` (injected via `@EnvironmentObject`). `StatisticsViewModel` is a plain struct computed from catalog state.
- **Views/** — `ContentView` (main window with toolbar/grid/footer), `IconGridView` (LazyVGrid), `IconCellView` (single cell with hover/context menu), `IconDetailView` (detail sheet), `PreferencesView`, `QuarantineView`, `StatisticsView`, `AboutView`.
- **Utilities/** — `PasteboardHelper` copies icons to NSPasteboard as PNG.

## Key Patterns

- **XcodeGen**: Project uses `project.yml` — always run `xcodegen generate` after adding/removing Swift files.
- **Module name**: `PRODUCT_MODULE_NAME = IconViewer`. Tests use `@testable import IconViewer`. The module name differs from the project name for historical reasons.
- **Thumbnail cache**: File-based in `~/Library/Caches/IconViewer/`, keyed by SHA256 hash of file contents. Designed to be swappable to SQLite/Core Data later.
- **SVG rendering**: Primary path uses `NSImage(contentsOf:)` (macOS 14+ native SVG support). WebKit fallback is a skeleton for edge cases.
- **Monochrome SVGs**: Detected by parsing fill/stroke attributes. Rendered with theme-adaptive foregroundStyle (black in light mode, white in dark mode).
- **Quarantine**: Files with dimensions >1024px, <16px, aspect ratio >2:1, or corrupted are quarantined (hidden from main grid, visible in Quarantine window, user can restore).
- **Incremental indexing**: File watcher uses delta-based reindexing (compares paths + content hashes). Full reindex only on app launch or manual trigger.

## Tech Stack

- Swift 5.9, SwiftUI, macOS 14+
- XcodeGen for project generation
- CryptoKit for content hashing
- No third-party dependencies
