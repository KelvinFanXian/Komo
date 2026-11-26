#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/.build/module-cache"
SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache" \
CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/module-cache" \
swift build -c release --disable-sandbox -debug-info-format none

ICONSET_DIR="$PROJECT_DIR/.build/KMonitor.iconset"
APP_DIR="$PROJECT_DIR/.build/app/KMonitor.app"
SWIFT_MODULECACHE_PATH="$PROJECT_DIR/.build/module-cache" \
swift -module-cache-path "$PROJECT_DIR/.build/module-cache" \
    Scripts/generate-icon.swift Resources/AppIcon.png "$ICONSET_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
cp .build/release/KMonitor "$APP_DIR/Contents/MacOS/KMonitor"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "$APP_DIR"
