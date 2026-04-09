#!/bin/bash
set -euo pipefail

# ============================================================
# Simple Icon Catalog — Build & Release Script
# ============================================================
# Usage:
#   ./scripts/build-release.sh              # Build DMG only
#   ./scripts/build-release.sh --release    # Build DMG + create GitHub release
#
# Prerequisites:
#   - Xcode command line tools
#   - XcodeGen (brew install xcodegen)
#   - gh CLI (brew install gh) — only for --release
# ============================================================

VERSION="${VERSION:-1.0.0}"
APP_NAME="Simple Icon Catalog"
SCHEME="SimpleIconCatalog"
PROJECT_DIR="$(cd "$(dirname "$0")/../SimpleIconCatalog" && pwd)"
BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/SimpleIconCatalog-$VERSION.dmg"

echo "==> Building $APP_NAME v$VERSION"
echo "    Project: $PROJECT_DIR"
echo "    Output:  $BUILD_DIR"
echo ""

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Regenerate Xcode project
echo "==> Regenerating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

# Archive (Release build)
echo "==> Archiving (Release)..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  | tail -5

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "ERROR: Archive failed."
  exit 1
fi

# Extract .app from archive
echo "==> Extracting .app..."
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$APP_PATH"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: .app not found in archive."
  exit 1
fi

# Create DMG with Applications symlink and styled layout
echo "==> Creating DMG..."
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Create temporary read-write DMG (empty, then copy contents preserving symlinks)
DMG_TEMP="$BUILD_DIR/temp.dmg"
hdiutil create \
  -volname "$APP_NAME" \
  -size 20m \
  -ov \
  -type UDIF \
  -fs HFS+ \
  "$DMG_TEMP"

# Generate background image with install instructions
DMG_BG="$BUILD_DIR/dmg-background.png"
magick -size 540x300 xc:none \
  -font "/System/Library/Fonts/Supplemental/Arial.ttf" -pointsize 15 \
  -fill "rgba(160,160,160,0.9)" -gravity north \
  -annotate +0+20 "Drag the app to your Applications folder to install" \
  "$DMG_BG"

# Mount and copy contents (preserving symlinks)
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP" -readwrite -noverify | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')
if [ -n "$MOUNT_DIR" ]; then
  cp -R "$DMG_STAGING/." "$MOUNT_DIR/"
  mkdir -p "$MOUNT_DIR/.background"
  cp "$DMG_BG" "$MOUNT_DIR/.background/background.png"
  hdiutil detach "$MOUNT_DIR" -quiet
fi

# Re-mount for styling
MOUNT_DIR=$(hdiutil attach "$DMG_TEMP" -readwrite -noverify | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')
if [ -n "$MOUNT_DIR" ]; then
  # Set icon size and view options via .DS_Store-free approach
  # Use Finder AppleScript with retry for positioning
  osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 640, 400}
    set opts to icon view options of container window
    set icon size of opts to 128
    set arrangement of opts to not arranged
    set background picture of opts to file ".background:background.png"
    try
      set position of item "$APP_NAME.app" of container window to {140, 150}
    end try
    try
      set position of item "Applications" of container window to {400, 150}
    end try
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
  # Set volume icon if app icon exists
  if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
  fi
  sync
  hdiutil detach "$MOUNT_DIR" -quiet
fi

# Convert to compressed read-only DMG
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_PATH" -ov
rm -f "$DMG_TEMP"
rm -rf "$DMG_STAGING"

if [ ! -f "$DMG_PATH" ]; then
  echo "ERROR: DMG creation failed."
  exit 1
fi

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "==> DMG created: $DMG_PATH ($DMG_SIZE)"

# Create GitHub release if --release flag is passed
if [[ "${1:-}" == "--release" ]]; then
  echo ""
  echo "==> Creating GitHub release v$VERSION..."

  if ! command -v gh &> /dev/null; then
    echo "ERROR: gh CLI not found. Install with: brew install gh"
    exit 1
  fi

  gh release create "v$VERSION" \
    "$DMG_PATH" \
    --title "$APP_NAME v$VERSION" \
    --notes "$(cat <<EOF
## $APP_NAME v$VERSION

### Download
Download **SimpleIconCatalog-$VERSION.dmg**, open it, and drag the app to your Applications folder.

### Note
This app is not notarized. On first launch, right-click the app and select "Open", then confirm in the dialog. After that it will open normally.
EOF
)"

  echo "==> Release created: https://github.com/oscarnogueira/simple-icon-catalog/releases/tag/v$VERSION"
else
  echo ""
  echo "To create a GitHub release, run:"
  echo "  VERSION=$VERSION ./scripts/build-release.sh --release"
fi

echo ""
echo "Done."
