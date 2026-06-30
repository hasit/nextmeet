#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NextMeet"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
SHA_PATH="$ZIP_PATH.sha256"
VERSION_FILE="$ROOT_DIR/VERSION"
APP_VERSION="${APP_VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"

if [[ -z "$APP_VERSION" && -f "$VERSION_FILE" ]]; then
  APP_VERSION="$(tr -d '[:space:]' <"$VERSION_FILE")"
fi

if [[ -z "$APP_VERSION" ]]; then
  echo "Missing app version. Set APP_VERSION or add VERSION." >&2
  exit 1
fi

APP_VERSION="$APP_VERSION" BUILD_NUMBER="$BUILD_NUMBER" "$ROOT_DIR/script/build_app.sh" --release

rm -f "$ZIP_PATH" "$SHA_PATH"

(
  cd "$DIST_DIR"
  zip -qry -X "$APP_NAME.zip" "$APP_NAME.app"
  shasum -a 256 "$APP_NAME.zip" >"$APP_NAME.zip.sha256"
)

echo "Packaged $ZIP_PATH"
echo "Checksum $SHA_PATH"
