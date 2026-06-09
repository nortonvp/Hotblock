#!/bin/zsh

set -u

APP_EXECUTABLE_PATH="${1:-}"
DEFAULTS_DOMAIN="${2:-com.nortonvp.hotblock}"

if [[ -z "$APP_EXECUTABLE_PATH" ]]; then
    exit 1
fi

while true; do
    BLOCKING_ACTIVE="$(defaults read "$DEFAULTS_DOMAIN" hotblock.isBlocking 2>/dev/null || echo 0)"

    if [[ "$BLOCKING_ACTIVE" == "1" ]]; then
        if ! pgrep -f "/Hotblock.app/Contents/MacOS/Hotblock( |$)" >/dev/null 2>&1; then
            "$APP_EXECUTABLE_PATH" >/dev/null 2>&1 &
        fi
    fi

    sleep 2
done
