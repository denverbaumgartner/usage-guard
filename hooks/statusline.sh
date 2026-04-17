#!/usr/bin/env bash

DATA_DIR="$HOME/.claude/usage-guard"
CONFIG="$DATA_DIR/config.json"

INPUT=$(cat)

# Atomic write of rate_limits to disk for check-usage.sh to read
mkdir -p "$DATA_DIR"
echo "$INPUT" | jq -c '.rate_limits // {}' > "$DATA_DIR/rate_limits.tmp" \
  && mv "$DATA_DIR/rate_limits.tmp" "$DATA_DIR/rate_limits.json" 2>/dev/null || true

# Chain to configured next statusLine (caveman, etc.) — output goes to Claude Code status bar
CHAIN=$(jq -r '.chain_statusline // ""' "$CONFIG" 2>/dev/null || echo "")
if [[ -n "$CHAIN" ]]; then
  echo "$INPUT" | eval "$CHAIN"
fi
