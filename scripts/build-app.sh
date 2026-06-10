#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Hotblock"
BUILD_CONFIGURATION="release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VERSION="${HOTBLOCK_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/App/Info.plist")}"
BUILD_NUMBER="${HOTBLOCK_BUILD_NUMBER:-1}"
ARCH_VALUES="${HOTBLOCK_ARCHS:-$(uname -m)}"
ARCHS=("${(@s: :)ARCH_VALUES}")
BUILT_BINARIES=()

for ARCH in "${ARCHS[@]}"; do
    SCRATCH_DIR="$ROOT_DIR/.build/hotblock-$ARCH"
    echo "Building $APP_NAME $VERSION for $ARCH..."
    swift build \
        -c "$BUILD_CONFIGURATION" \
        --package-path "$ROOT_DIR" \
        --scratch-path "$SCRATCH_DIR" \
        --triple "$ARCH-apple-macosx14.0"
    BUILT_BINARIES+=("$SCRATCH_DIR/$ARCH-apple-macosx/$BUILD_CONFIGURATION/$APP_NAME")
done

echo "Bundling $APP_NAME.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if (( ${#BUILT_BINARIES[@]} > 1 )); then
    lipo -create "${BUILT_BINARIES[@]}" -output "$MACOS_DIR/$APP_NAME"
else
    cp "$BUILT_BINARIES[1]" "$MACOS_DIR/$APP_NAME"
fi

cp "$ROOT_DIR/App/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/scripts/hotblock-watchdog.sh" "$RESOURCES_DIR/hotblock-watchdog.sh"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/$APP_NAME"
chmod +x "$RESOURCES_DIR/hotblock-watchdog.sh"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "Built app bundle at:"
echo "$APP_DIR"
lipo -archs "$MACOS_DIR/$APP_NAME"
