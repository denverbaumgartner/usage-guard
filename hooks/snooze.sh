#!/usr/bin/env bash
# Snooze the usage-guard halt. Called by /usage-guard:resume skill or directly.
# Usage: snooze.sh [seconds|30m|1h]   (default: snooze_seconds from config, or 1800)

DATA_DIR="$HOME/.claude/usage-guard"
CONFIG="$DATA_DIR/config.json"
RESUME_FLAG="$DATA_DIR/resume.flag"

RAW="${1:-}"

# Parse human-readable durations
if [[ "$RAW" =~ ^([0-9]+)m$ ]]; then
  DURATION=$(( ${BASH_REMATCH[1]} * 60 ))
elif [[ "$RAW" =~ ^([0-9]+)h$ ]]; then
  DURATION=$(( ${BASH_REMATCH[1]} * 3600 ))
elif [[ "$RAW" =~ ^[0-9]+$ ]]; then
  DURATION="$RAW"
else
  DURATION=$(jq -r '.snooze_seconds // 1800' "$CONFIG" 2>/dev/null || echo "1800")
fi

# Compute expiry — macOS date vs GNU date compatible
if date -v+1S +%s &>/dev/null 2>&1; then
  EXPIRES=$(date -v+"${DURATION}S" +%s)
else
  EXPIRES=$(date -d "+${DURATION} seconds" +%s)
fi

mkdir -p "$DATA_DIR"
echo "$EXPIRES" > "$RESUME_FLAG"

EXPIRY_STR=$(date -r "$EXPIRES" 2>/dev/null || date -d "@$EXPIRES" 2>/dev/null || echo "in ${DURATION}s")
echo "usage-guard: snoozed for ${DURATION}s — halts suppressed until ${EXPIRY_STR}"
echo "usage-guard: /usage-guard:cancel or rm $RESUME_FLAG to cancel early"
