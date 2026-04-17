#!/usr/bin/env bash
# Notifier dispatcher — factory pattern. Add new notifiers to notifiers/ and list them in config.json.

DATA_DIR="$HOME/.claude/usage-guard"
CONFIG="$DATA_DIR/config.json"
NOTIFIERS_DIR="$DATA_DIR/notifiers"

PCT="${1:?usage: notify.sh <pct> <threshold> <window>}"
THRESHOLD="${2:?}"
WINDOW="${3:?}"

mapfile -t NOTIFIERS < <(jq -r '.notifiers // ["macos"] | .[]' "$CONFIG" 2>/dev/null || echo "macos")

for NOTIFIER in "${NOTIFIERS[@]}"; do
  SCRIPT="$NOTIFIERS_DIR/${NOTIFIER}.sh"
  if [[ -x "$SCRIPT" ]]; then
    bash "$SCRIPT" "$PCT" "$THRESHOLD" "$WINDOW" "$CONFIG" || true
  else
    echo "usage-guard: notifier '$NOTIFIER' not found at $SCRIPT" >&2
  fi
done
