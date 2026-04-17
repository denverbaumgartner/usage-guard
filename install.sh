#!/usr/bin/env bash
# Local install — only needed for statusLine setup and config creation.
# If installing via Claude Code marketplace (extraKnownMarketplaces), hooks and
# skills are auto-loaded. Only run this script to set up the statusLine chain
# and create your config.json.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.claude/usage-guard"

echo "usage-guard: setting up data directory at $DATA_DIR"
mkdir -p "$DATA_DIR"

if [[ ! -f "$DATA_DIR/config.json" ]]; then
  cp "$REPO_DIR/config.example.json" "$DATA_DIR/config.json"
  echo "usage-guard: created $DATA_DIR/config.json — edit to configure threshold, notifiers, chain_statusline"
else
  echo "usage-guard: config exists — skipped (delete to reset)"
fi

cat << EOF

If installing WITHOUT the marketplace (manual local install only):
Add to ~/.claude/settings.json:

  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \\"$REPO_DIR/hooks/check-usage.sh\\"",
            "timeout": 10
          }
        ]
      }
    ]
  }

statusLine setup (required regardless of install method):
Add to ~/.claude/settings.json:

  "statusLine": {
    "type": "command",
    "command": "bash \\"$REPO_DIR/hooks/statusline.sh\\""
  }

If you use caveman or another statusLine plugin, set chain_statusline in:
  $DATA_DIR/config.json

  "chain_statusline": "bash \\"/path/to/caveman-statusline.sh\\""

Find caveman's path in your current ~/.claude/settings.json statusLine value.
EOF
