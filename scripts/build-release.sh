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

# Create DMG
echo "==> Creating DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

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
