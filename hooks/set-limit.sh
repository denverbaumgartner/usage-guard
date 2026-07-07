#!/usr/bin/env bash
# Set the usage-guard threshold percentage. Called by /usage-guard:set-limit skill or directly.
# Usage: set-limit.sh <percentage>   (percentage must be 0-100)

DATA_DIR="$HOME/.claude/usage-guard"
CONFIG="$DATA_DIR/config.json"

RAW="${1:-}"

# Validate input is an integer
if ! [[ "$RAW" =~ ^[0-9]+$ ]]; then
  echo "usage-guard: error — threshold must be an integer between 0 and 100" >&2
  exit 1
fi

THRESHOLD="$RAW"

# Validate range (0-100)
if (( THRESHOLD < 0 || THRESHOLD > 100 )); then
  echo "usage-guard: error — threshold must be between 0 and 100 (got $THRESHOLD)" >&2
  exit 1
fi

# Create config with defaults if missing
if [[ ! -f "$CONFIG" ]]; then
  mkdir -p "$DATA_DIR"
  cat > "$CONFIG" <<'EOF'
{
  "threshold": 90,
  "snooze_seconds": 1800,
  "windows": ["seven_day", "five_hour"],
  "chain_statusline": "",
  "notifiers": ["macos"],
  "notifier_config": {
    "macos": {
      "sound": "Basso"
    },
    "slack": {
      "webhook_url": ""
    },
    "webhook": {
      "url": "",
      "headers": {}
    }
  }
}
EOF
fi

# Update threshold using jq
jq --argjson th "$THRESHOLD" '.threshold = $th' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

echo "usage-guard: threshold set to ${THRESHOLD}%"
