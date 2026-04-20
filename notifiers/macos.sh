#!/usr/bin/env bash

PCT="$1"
THRESHOLD="$2"
WINDOW="$3"
CONFIG="$4"

SOUND=$(jq -r '.notifier_config.macos.sound // "Basso"' "$CONFIG" 2>/dev/null || echo "Basso")
WINDOW_LABEL="${WINDOW//_/ }"

osascript -e "display notification \"${WINDOW_LABEL} usage at ${PCT}%. Agent paused to preserve budget.\" with title \"Claude Code Usage Guard\" sound name \"${SOUND}\""
