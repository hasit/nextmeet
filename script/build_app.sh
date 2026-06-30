#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="release"

case "${1:-}" in
  "")
    ;;
  --debug|debug)
    CONFIGURATION="debug"
    ;;
  --release|release)
    CONFIGURATION="release"
    ;;
  *)
    echo "usage: $0 [--debug|--release]" >&2
    exit 2
    ;;
esac

APP_NAME="NextMeet"
BUNDLE_ID="com.hasit.NextMeet"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MODULE_CACHE_DIR="$ROOT_DIR/.build/module-cache"
APP_ICON="$ROOT_DIR/Assets/AppIcon.icns"
ICON_GENERATOR="$ROOT_DIR/script/generate_app_icon.sh"
ICON_SOURCE="$ROOT_DIR/script/generate_app_icon.swift"
APP_VERSION="${APP_VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
CODE_SIGN_RUNTIME="${CODE_SIGN_RUNTIME:-0}"
CODE_SIGN_TIMESTAMP="${CODE_SIGN_TIMESTAMP:-0}"

if [[ -z "$APP_VERSION" && -f "$VERSION_FILE" ]]; then
  APP_VERSION="$(tr -d '[:space:]' <"$VERSION_FILE")"
fi

if [[ -z "$APP_VERSION" ]]; then
  APP_VERSION="0.1.0"
fi

mkdir -p "$MODULE_CACHE_DIR"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR"

# The local Command Line Tools install currently points MacOSX.sdk at a newer
# SDK than its Swift compiler supports. Prefer the bundled stable SDK when present.
if [[ -z "${SDKROOT:-}" && -d "/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk" ]]; then
  export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
fi

if [[ -f "$ICON_GENERATOR" && ( ! -f "$APP_ICON" || "$ICON_SOURCE" -nt "$APP_ICON" ) ]]; then
  bash "$ICON_GENERATOR"
fi

swift_build() {
  if [[ "$CONFIGURATION" == "release" ]]; then
    swift build -c release "$@"
  else
    swift build "$@"
  fi
}

swift_build
BUILD_BINARY="$(swift_build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSMultipleInstancesProhibited</key>
  <true/>
  <key>LSUIElement</key>
  <true/>
  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>NextMeet reads upcoming calendar events to show meeting links in the menu bar.</string>
  <key>NSCalendarsUsageDescription</key>
  <string>NextMeet reads upcoming calendar events to show meeting links in the menu bar.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$INFO_PLIST" >/dev/null

if [[ -n "$CODE_SIGN_IDENTITY" ]] && command -v codesign >/dev/null 2>&1; then
  CODESIGN_ARGS=(--force --sign "$CODE_SIGN_IDENTITY")

  if [[ "$CODE_SIGN_RUNTIME" == "1" ]]; then
    CODESIGN_ARGS+=(--options runtime)
  fi

  if [[ "$CODE_SIGN_TIMESTAMP" == "1" ]]; then
    CODESIGN_ARGS+=(--timestamp)
  fi

  codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE" >/dev/null
  codesign --verify --deep --strict "$APP_BUNDLE"
fi

echo "Built $APP_BUNDLE"
