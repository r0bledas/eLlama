#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="1.2.0"
APP_NAME="eLlama.app"
OUTPUT_DIR="$ROOT_DIR/dist"

echo "=================================================="
echo " Building eLlama for macOS (SwiftUI)"
echo " Version: $VERSION"
echo "=================================================="

cd "$ROOT_DIR"

# Build Release with Swift Package Manager
echo "--> Compiling with Swift Package Manager..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/eLlama"

if [ ! -f "$BIN_PATH" ]; then
    echo "Error: Binary not found at $BIN_PATH"
    exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/$APP_NAME/Contents/MacOS"
mkdir -p "$OUTPUT_DIR/$APP_NAME/Contents/Resources"

# Copy binary
echo "--> Assembling $APP_NAME bundle..."
cp "$BIN_PATH" "$OUTPUT_DIR/$APP_NAME/Contents/MacOS/eLlama"
chmod +x "$OUTPUT_DIR/$APP_NAME/Contents/MacOS/eLlama"

# Copy Info.plist
cp "$ROOT_DIR/Resources/Info.plist" "$OUTPUT_DIR/$APP_NAME/Contents/Info.plist"

# Copy Icon
if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$OUTPUT_DIR/$APP_NAME/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signing for local execution
if command -v codesign &> /dev/null; then
    echo "--> Signing bundle (ad-hoc)..."
    codesign --force --deep --sign - "$OUTPUT_DIR/$APP_NAME"
fi

# Package ZIP
echo "--> Creating ZIP archive..."
cd "$OUTPUT_DIR"
zip -r -y -q "eLlama-v${VERSION}-macos.app.zip" "$APP_NAME"

# Package DMG if hdiutil is available
if command -v hdiutil &> /dev/null; then
    echo "--> Creating DMG disk image..."
    DMG_DIR="$OUTPUT_DIR/dmg_root"
    mkdir -p "$DMG_DIR"
    cp -R "$APP_NAME" "$DMG_DIR/"
    ln -s /Applications "$DMG_DIR/Applications"
    
    hdiutil create -volname "eLlama" \
                   -srcfolder "$DMG_DIR" \
                   -ov -format UDZO \
                   "eLlama-v${VERSION}-macos.dmg"
    rm -rf "$DMG_DIR"
fi

echo "=================================================="
echo " Build Succeeded!"
echo " Artifacts in: $OUTPUT_DIR"
echo " - $APP_NAME"
echo " - eLlama-v${VERSION}-macos.app.zip"
if [ -f "$OUTPUT_DIR/eLlama-v${VERSION}-macos.dmg" ]; then
    echo " - eLlama-v${VERSION}-macos.dmg"
fi
echo "=================================================="
