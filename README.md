# Simple Icon Catalog

A lightweight native macOS app for browsing, filtering, and copying icons from your local SVG and PNG collections.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![SwiftUI](https://img.shields.io/badge/SwiftUI-native-green) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

![Simple Icon Catalog](docs/screenshots/main-grid.png)

---

## Why?

If you work with icon collections for presentations, design, or development, you know the pain: hundreds of SVG/PNG files in a folder, no easy way to browse them visually, and no quick way to copy one into your slide deck.

Simple Icon Catalog solves this. Point it at your icon directories and get an instant visual catalog. Find what you need, right-click, copy, paste into Keynote or PowerPoint. Done.

## Features

- **Visual grid** — Browse all your icons at a glance with continuous scroll
- **Instant filter** — Search by filename, filter by style (color/monochrome) or format (SVG/PNG)
- **Copy & paste** — Right-click any icon, copy as high-res PNG, paste directly into your presentation
- **Favorites** — Mark icons as favorites (right-click > Add to Favorites) — they appear first in the grid with a star badge and persist across sessions
- **Auto-indexing** — Watches your directories for changes, updates incrementally (no manual refresh needed)
- **Smart quarantine** — Automatically hides files that don't look like icons (too large, too small, bad aspect ratio) — review and restore them in a dedicated view with preview panel
- **Dark mode** — Fully adapts to macOS light and dark themes; monochrome icons auto-adjust for visibility
- **Detail view** — Right-click > Details to see format, dimensions, file size, path, and style
- **Statistics** — Overview of your catalog: icon counts, format breakdown, cache size, last index time
- **Zero dependencies** — Pure Swift and SwiftUI. No Electron, no embedded browser, no bloat

## Download

Grab the latest `.dmg` from the [Releases](https://github.com/oscarnogueira/simple-icon-catalog/releases) page.

> **Note:** This app is not notarized. On first launch, right-click the app and select "Open", then confirm in the dialog. After that it will open normally.

## Building from Source

### Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build & Run

```bash
git clone https://github.com/oscarnogueira/simple-icon-catalog.git
cd simple-icon-catalog

cd SimpleIconCatalog && xcodegen generate

open SimpleIconCatalog.xcodeproj
# Press Cmd+R in Xcode
```

### Build DMG

```bash
./scripts/build-release.sh
```

On first launch, open **Settings** (gear icon in the bottom-left corner or `Cmd+,`) and add the directories where your icons live.

## How It Works

1. **Scan** — Recursively finds all `.svg` and `.png` files in your configured directories
2. **Analyze** — Extracts dimensions, detects if an SVG is monochrome or color (including inline CSS styles)
3. **Classify** — Files that don't look like icons (oversized, tiny, wrong aspect ratio) go to quarantine
4. **Cache** — Generates and caches thumbnails for fast browsing (`~/Library/Caches/IconViewer/`)
5. **Watch** — Monitors directories for changes, only reprocesses what's new or modified

## Architecture

```
SimpleIconCatalog/
├── Models/          → IconItem, QuarantineReason, IndexingProgress
├── Services/        → DirectoryScanner, SVGAnalyzer, QuarantineClassifier,
│                      ThumbnailCache, ThumbnailGenerator, IconIndexer,
│                      DirectoryWatcher
├── ViewModels/      → IconCatalogViewModel, StatisticsViewModel
├── Views/           → ContentView, IconGridView, IconCellView, IconDetailView,
│                      PreferencesView, QuarantineView, StatisticsView, AboutView
└── Utilities/       → PasteboardHelper
```

Three clean layers: **UI** (SwiftUI views) → **ViewModel** (state management) → **Services** (business logic + caching). No third-party dependencies.

## Running Tests

```bash
cd SimpleIconCatalog
xcodebuild test -scheme SimpleIconCatalog -destination 'platform=macOS'
```

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT
