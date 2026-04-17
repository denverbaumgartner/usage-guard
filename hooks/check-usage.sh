#!/usr/bin/env bash

DATA_DIR="$HOME/.claude/usage-guard"
CONFIG="$DATA_DIR/config.json"
RATE_LIMITS="$DATA_DIR/rate_limits.json"
HOOKS_DIR="$DATA_DIR/hooks"

# No data yet — allow
[[ -f "$RATE_LIMITS" ]] || exit 0
[[ -f "$CONFIG" ]] || exit 0

THRESHOLD=$(jq -r '.threshold // 90' "$CONFIG")
WINDOWS=()
while IFS= read -r win; do WINDOWS+=("$win"); done \
  < <(jq -r '.windows // ["seven_day"] | .[]' "$CONFIG")

EXCEEDED_WINDOW=""
EXCEEDED_PCT=""

for WINDOW in "${WINDOWS[@]}"; do
  case "$WINDOW" in
    seven_day) FIELD=".seven_day.used_percentage" ;;
    five_hour) FIELD=".five_hour.used_percentage" ;;
    *)         continue ;;
  esac

  PCT=$(jq -r "$FIELD // 0" "$RATE_LIMITS" 2>/dev/null || echo "0")

  if (( $(echo "$PCT >= $THRESHOLD" | bc -l) )); then
    EXCEEDED_WINDOW="$WINDOW"
    EXCEEDED_PCT="$PCT"
    break
  fi
done

if [[ -n "$EXCEEDED_WINDOW" ]]; then
  bash "$HOOKS_DIR/notify.sh" "$EXCEEDED_PCT" "$THRESHOLD" "$EXCEEDED_WINDOW" || true
  printf '{"continue": false, "stopReason": "Usage Guard: %s window at %s%% (threshold: %s%%). Paused to preserve budget — resume when ready."}\n' \
    "$EXCEEDED_WINDOW" "$EXCEEDED_PCT" "$THRESHOLD"
  exit 0
fi

exit 0
