#!/usr/bin/env bash
# Notifier dispatcher — factory pattern. Add new notifiers to notifiers/ and list them in config.json.

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFIERS_DIR="$(dirname "$HOOKS_DIR")/notifiers"
DATA_DIR="$HOME/.claude/usage-guard"
CONFIG="$DATA_DIR/config.json"

PCT="${1:?usage: notify.sh <pct> <threshold> <window>}"
THRESHOLD="${2:?}"
WINDOW="${3:?}"

NOTIFIERS=()
while IFS= read -r n; do NOTIFIERS+=("$n"); done \
  < <(jq -r '.notifiers // ["macos"] | .[]' "$CONFIG" 2>/dev/null || echo "macos")

for NOTIFIER in "${NOTIFIERS[@]}"; do
  SCRIPT="$NOTIFIERS_DIR/${NOTIFIER}.sh"
  if [[ -x "$SCRIPT" ]]; then
    bash "$SCRIPT" "$PCT" "$THRESHOLD" "$WINDOW" "$CONFIG" || true
  else
    echo "usage-guard: notifier '$NOTIFIER' not found at $SCRIPT" >&2
  fi
done
