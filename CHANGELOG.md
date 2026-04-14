# Changelog

All notable changes to Simple Icon Catalog will be documented in this file.

## [1.3.0] - 2026-04-14

### Added
- Unified logging via `os.Logger` — subsystem = bundle id, categories: `app`, `indexing`, `watcher`, `store`, `migration`
- Launch, legacy migration, index load, full/incremental reindex (with delta counts and duration), and directory watch events are now logged
- View live logs in **Console.app** (filter by subsystem `com.simpleiconcatalog.app`) or via `log stream --predicate 'subsystem == "com.simpleiconcatalog.app"'`

## [1.2.0] - 2026-04-14

### Added
- **Multi-select** — select multiple icons for bulk operations
- `⌘+Click` to toggle individual icons into a selection
- `⇧+Click` to select a range of icons
- `⌘+A` to select all visible icons
- Selection mode button in toolbar — enables checkboxes on each cell for tap-to-select
- Right-click on multi-selection shows bulk context menu (favorites, collections)
- Drag multiple selected icons to sidebar collections or external apps (Keynote, Finder, etc.)
- Selection auto-clears after bulk actions, filter changes, or pressing `Esc`
- Footer shows selection count when icons are selected
- `MARKETING_VERSION` in project.yml — About view now shows correct app version
- Last indexing date/duration now persisted across launches, updated after every incremental sync
- Legacy bundle ID migration for caches and index database (handles historical `com.simpleicocatalog.app` typo and `IconViewer` paths)

## [1.1.1] - 2026-04-10

### Added
- Background preview strip in icon detail view — see how icons look on 7 different backgrounds (white, light, gray, dark, black, blue, red)
- `⌘F` as global keyboard shortcut to focus search (works from anywhere in the app)
- Settings gear icon in window toolbar, visible even with sidebar collapsed

### Fixed
- Search field focus (`/` and `⌘F`) now works reliably — moved from toolbar to inline bar
- Collections section "+" button size and alignment
- Search bar cleaned up — only search-related elements

## [1.1.0] - 2026-04-10

### Added
- **Collections** — organize icons into virtual folders without moving files
- Sidebar with "All Icons", "Favorites", and user-created collections
- Each collection has a custom name, SF Symbol icon, and color
- Create, edit, and delete collections from the sidebar
- Add icons to collections via right-click > "Add to Collection" submenu (with checkmarks)
- Drag & drop icons from the grid onto sidebar collections
- Remove icons from a collection when viewing it
- Badge counts showing number of icons per collection
- Collections and memberships persisted in SQLite

## [1.0.3] - 2026-04-09

### Changed
- Index persistence migrated from JSON to SQLite (`~/Library/Application Support/{BundleID}/index.db`)
- Favorites now stored in SQLite (single source of truth)
- Thumbnail cache path uses bundle identifier (`~/Library/Caches/{BundleID}/`)
- App launches instantly — loads persisted index from SQLite, then runs incremental sync in background
- Removed all legacy "IconViewer" references from internal paths and names
- Styled DMG installer with Applications shortcut, background message, and 128px icons

### Fixed
- Crash on launch when appearance mode was set (NSApp nil during init)
- DMG styling now persists correctly (icon size, positions, background)

## [1.0.2] - 2026-04-09

### Added
- Drag & drop icons directly from the grid into Keynote, PowerPoint, or any other app
- Sort icons by name, modification date, or file size (toolbar menu)
- Quick Look preview — click to select an icon, press Space to preview
- Icon selection with accent color border
- Press `/` to focus the search field
- Press `Esc` to clear search text or remove focus
- Filtered count in footer ("42 of 791 icons") when filters are active
- Appearance mode toggle in Settings (System / Light / Dark)

## [1.0.1] - 2026-04-09

### Added
- Favorites — right-click > Add to Favorites, star badge, sorted to top, persisted across sessions
- Quarantine preview panel — click a quarantined item to see a large preview with metadata
- Quarantine and Statistics sections in Settings with descriptions and quick-open buttons
- SVG inline style color detection (`style="fill: #color"`)
- GitHub link in About view

### Fixed
- Progress bar now shows correct total file count during indexing
- Filter pickers widened to prevent segment overlap

## [1.0.0] - 2026-04-08

### Added
- Visual grid with continuous scroll and adjustable thumbnail size
- Filter by filename, style (Color / Mono), and format (SVG / PNG)
- Right-click > Copy Image (high-res PNG to clipboard)
- Right-click > Details with format, dimensions, file size, style, and path
- Right-click > Show in Finder
- Smart quarantine for non-icon files (too large, too small, bad aspect ratio)
- Quarantine view with restore functionality
- Statistics view (icon counts, format breakdown, cache size, last indexation)
- Auto-indexing with file watcher and incremental delta updates
- Monochrome SVG detection and theme-adaptive rendering (light/dark)
- Settings with directory management and cache controls
- About window
- Settings gear icon in footer
- App icon
