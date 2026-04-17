#!/usr/bin/env bash
# Creates ~/.claude/usage-guard/config.json and prints the statusLine snippet.
# Safe to re-run — config is never overwritten.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.claude/usage-guard"

mkdir -p "$DATA_DIR"

if [[ ! -f "$DATA_DIR/config.json" ]]; then
  cp "$REPO_DIR/config.example.json" "$DATA_DIR/config.json"
  echo "usage-guard: created $DATA_DIR/config.json"
else
  echo "usage-guard: config already exists at $DATA_DIR/config.json — skipped"
fi

cat << EOF

Add this to ~/.claude/settings.json:

  "statusLine": {
    "type": "command",
    "command": "bash \"$REPO_DIR/hooks/statusline.sh\""
  }

If you already have a statusLine plugin (e.g. caveman), instead add chain_statusline
to $DATA_DIR/config.json:

  "chain_statusline": "<your existing statusLine command>"

Then point statusLine at usage-guard as shown above.

If you installed via marketplace (extraKnownMarketplaces), the PreToolUse hook
and slash commands are already active — only the statusLine needs manual setup.
EOF
