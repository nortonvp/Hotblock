#!/bin/zsh

set -u

APP_BUNDLE_PATH="${1:-}"
APP_EXECUTABLE_PATH="${2:-}"
DEFAULTS_DOMAIN="${3:-com.nortonvp.hotblock}"

if [[ -z "$APP_BUNDLE_PATH" || -z "$APP_EXECUTABLE_PATH" ]]; then
    exit 1
fi

while true; do
    BLOCKING_ACTIVE="$(defaults read "$DEFAULTS_DOMAIN" hotblock.isBlocking 2>/dev/null || echo 0)"

    if [[ "$BLOCKING_ACTIVE" == "1" ]]; then
        if ! pgrep -f "/Hotblock.app/Contents/MacOS/Hotblock( |$)" >/dev/null 2>&1; then
            "$APP_EXECUTABLE_PATH" --background >/dev/null 2>&1 &
        fi
    fi

    sleep 2
done
