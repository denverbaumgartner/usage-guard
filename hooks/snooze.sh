#!/usr/bin/env bash
# Snooze the usage-guard halt for a configurable duration.
# Usage: snooze.sh [seconds]   (default: 1800 = 30 min)

DATA_DIR="$HOME/.claude/usage-guard"
CONFIG="$DATA_DIR/config.json"
RESUME_FLAG="$DATA_DIR/resume.flag"

DURATION="${1:-}"
if [[ -z "$DURATION" ]]; then
  DURATION=$(jq -r '.snooze_seconds // 1800' "$CONFIG" 2>/dev/null || echo "1800")
fi

# Compute expiry — macOS date vs GNU date compatible
if date -v+1S +%s &>/dev/null 2>&1; then
  EXPIRES=$(date -v+"${DURATION}S" +%s)   # macOS
else
  EXPIRES=$(date -d "+${DURATION} seconds" +%s)  # GNU/Linux
fi

echo "$EXPIRES" > "$RESUME_FLAG"

# Human-readable expiry
EXPIRY_STR=$(date -r "$EXPIRES" 2>/dev/null || date -d "@$EXPIRES" 2>/dev/null || echo "in ${DURATION}s")
echo "usage-guard: snoozed for ${DURATION}s — halts suppressed until ${EXPIRY_STR}"
echo "usage-guard: run this again to extend, or: rm $RESUME_FLAG to cancel"
