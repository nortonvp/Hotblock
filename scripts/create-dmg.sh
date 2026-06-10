#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hotblock.app"
DMG_PATH="${1:-$ROOT_DIR/Hotblock.dmg}"
STAGING_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
    echo "Build Hotblock before creating the disk image."
    exit 1
fi

cp -R "$APP_PATH" "$STAGING_DIR/Hotblock.app"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "Hotblock" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Created disk image at:"
echo "$DMG_PATH"
