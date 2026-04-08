# Icon Viewer — Design Spec

## Overview

A lightweight native macOS app (SwiftUI) for browsing and cataloging SVG/PNG icon collections. The user points it at one or more directories, it indexes the images, and presents them in a scrollable grid — like a visual catalog for icons used in presentations.

## Problem

Icons are stored in a single directory, disorganized, some with duplicate names. Finding the right icon means previewing files one by one in Finder. This is slow and frustrating.

## Core Workflow

1. User configures source directories (one or more)
2. App scans directories for `.svg` and `.png` files
3. Thumbnails are generated and cached to disk
4. Icons are displayed in a continuous-scroll grid
5. User filters by name, finds the icon, right-clicks > Copy, pastes into presentation

## Architecture

Three layers:

### UI (SwiftUI)
- Single-window app
- `LazyVGrid` for the icon grid with continuous vertical scroll
- Search field for name filtering
- Slider for thumbnail size adjustment
- Context menu (right-click) with "Copy Image"

### Service
- Directory scanning (recursive, `.svg` and `.png`)
- SVG rasterization for thumbnail generation
- Quarantine classification (non-icon detection)
- Filtering logic (extensible for future filter types like tags)

### Cache
- Thumbnail storage at `~/Library/Caches/IconViewer/`
- Keyed by content hash of source file
- Reindexation compares modification dates to detect changes
- macOS can reclaim this space; app regenerates as needed

## Indexation

### Progress
- Runs on background thread, never blocks UI
- Status bar in the footer: "Indexing... 142/380 files"
- Grid populates progressively as thumbnails become ready (streaming)
- Reindex button in toolbar for manual trigger

### Quarantine

Files that don't look like icons are quarantined instead of shown in the main grid.

**Criteria:**
- Dimensions > 1024x1024 (likely illustration)
- Dimensions < 16x16 (likely favicon/artifact)
- Aspect ratio > 2:1 (likely banner/non-icon)
- Corrupted or unparseable file

**UX:**
- Quarantined files are hidden from the main grid
- Accessible via Menu > Quarantine
- Shows each file with the reason for quarantine
- User can promote a file back to the main catalog (manual override)

## Statistics

Accessible via Menu > Statistics. Shows:

- Total active icons in catalog
- Quarantine breakdown (count per reason)
- Format split (SVG vs PNG count)
- Monitored directories with icon count per directory
- Cache size on disk
- Last indexation date/time and duration

## UI Layout

### Toolbar (top)
- Search field — filters grid by filename
- Thumbnail size slider — compact (48px) to large, compact is default
- Reindex button

### Grid (main area)
- `LazyVGrid`, continuous vertical scroll
- Each cell: thumbnail + filename below (truncated if long)
- Right-click: context menu with "Copy Image"
- Hover: tooltip with full filename and dimensions

### Footer
- Icon count (updates with filter): "248 icons"
- Progress bar during indexation

### Preferences
- Add/remove source directories
- Clear cache

### Menu bar
- Statistics
- Quarantine

## Visual Style

- Follows system theme (dark/light mode automatic)
- Neutral background, thumbnails with subtle shadow and rounded corners
- Hover: slight scale-up and card highlight
- Click: selection border
- Typography: SF Pro (system font), filename in small discrete size
- Generous padding between icons — clean, no visual noise
- Smooth transitions: filter shows/hides icons with fade, slider animates fluidly
- Color SVGs: rendered with original colors
- Monochrome SVGs: adapt to theme (black in light, white in dark)
- Target: Apple-level minimalism and polish

## Technology

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Target:** macOS (native)
- **SVG Rendering:** SVGKit or native WebKit-based rasterization
- **Cache:** File-based in `~/Library/Caches/IconViewer/`, upgradeable to SQLite/Core Data in the future

## Extensibility

The architecture is designed so that:
- Filter system is protocol-based — new filter types (tags, categories) can be added without rewriting existing code
- Cache backend can be swapped from file-based to SQLite/Core Data as a localized change
- Quarantine criteria can be extended with new rules
