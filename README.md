<p align="center">
  <img src="docs/screenshots/app-icon.png" alt="Simple Icon Catalog icon" width="128" height="128">
</p>

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
- **Instant filter** — Search by filename (`/` to focus), filter by style (color/monochrome) or format (SVG/PNG). `Esc` clears the search
- **Drag & drop** — Drag icons directly from the grid into Keynote, PowerPoint, or any other app
- **Copy & paste** — Right-click any icon, copy as high-res PNG, paste directly into your presentation
- **Collections** — Organize icons into virtual folders (sidebar) with custom name, SF Symbol, and color. Add via right-click or drag & drop
- **Multi-select** — `⌘+Click` to toggle individual icons, `⇧+Click` to select a range, `⌘A` to select all filtered; drag a selection onto a collection or into Keynote/Finder, or use the right-click menu to favorite or add to collections in bulk
- **Favorites** — Mark icons as favorites (right-click > Add to Favorites) — they appear first in the grid with a star badge and persist across sessions
- **Sort** — Sort by name, modification date, or file size. Favorites always stay on top
- **Quick Look** — Click an icon to select it, press `Space` for native macOS Quick Look preview
- **Auto-indexing** — Watches your directories for changes, updates incrementally (no manual refresh needed)
- **Smart quarantine** — Automatically hides files that don't look like icons (too large, too small, bad aspect ratio) — review and restore them in a dedicated view with preview panel
- **Duplicate detection** — Dedicated Duplicates window (`⌘D`) groups byte-identical copies so you can reclaim disk space. Move unwanted copies to Trash one at a time; favorite status and collection memberships migrate automatically to the survivors
- **Dark mode** — Fully adapts to macOS light and dark themes; monochrome icons auto-adjust for visibility. Or choose Light/Dark manually in Settings
- **Detail view** — Right-click > Details to see format, dimensions, file size, path, and style
- **Statistics** — Overview of your catalog: icon counts, format breakdown, cache size, last index date and duration (persists across launches)
- **Zero dependencies** — Pure Swift, SwiftUI, and system frameworks (SQLite3, `os.Logger`). No Electron, no embedded browser, no bloat

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

## Getting Started

On first launch, open **Settings** (gear icon in the bottom-left corner or `⌘,`) and add the directories where your icons live. The app will index them in the background and watch for future changes.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `/` or `⌘F` | Focus the search field |
| `Esc` | Clear search or cancel selection |
| `Space` | Quick Look preview of the selected icon |
| `⌘A` | Select all filtered icons |
| `⌘+Click` | Toggle a single icon in the selection |
| `⇧+Click` | Select a range |
| `⌘I` | Open Statistics |
| `⌘D` | Open Duplicates |
| `⌘⇧Q` | Open Quarantine |
| `⌘,` | Open Settings |

## How It Works

1. **Scan** — Recursively finds all `.svg` and `.png` files in your configured directories
2. **Analyze** — Extracts dimensions, detects if an SVG is monochrome or color (including inline CSS styles)
3. **Classify** — Files that don't look like icons (oversized, tiny, wrong aspect ratio) go to quarantine
4. **Cache** — Generates and caches thumbnails for fast browsing (`~/Library/Caches/com.simpleiconcatalog.app/`)
5. **Persist** — Icon metadata, favorites, and collections are stored in a SQLite index at `~/Library/Application Support/com.simpleiconcatalog.app/index.db`
6. **Watch** — Monitors directories for changes, only reprocesses what's new or modified

## Debugging & Logs

The app emits structured logs via `os.Logger` (subsystem `com.simpleiconcatalog.app`), categorized as `app`, `indexing`, `watcher`, `store`, and `migration`. Stream them live with:

```bash
log stream --predicate 'subsystem == "com.simpleiconcatalog.app"' --level debug
```

Or open **Console.app** and filter by the subsystem to inspect launch events, indexing deltas and durations, directory watch activity, and DB load status.

## Architecture

```
SimpleIconCatalog/
├── Models/          → IconItem, IconCollection, DuplicateGroup,
│                      QuarantineReason, IndexingProgress
├── Services/        → DirectoryScanner, SVGAnalyzer, QuarantineClassifier,
│                      ThumbnailCache, ThumbnailGenerator, IconIndexer,
│                      DirectoryWatcher, IndexStore
├── ViewModels/      → IconCatalogViewModel, StatisticsViewModel
├── Views/           → ContentView, IconGridView, IconCellView, IconDetailView,
│                      CollectionsSidebarView, DuplicatesView, PreferencesView,
│                      QuarantineView, StatisticsView, AboutView
└── Utilities/       → PasteboardHelper, AppLog, LegacyMigration
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
