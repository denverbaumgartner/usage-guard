#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.claude/usage-guard"

echo "usage-guard: installing to $INSTALL_DIR"

mkdir -p "$INSTALL_DIR/hooks" "$INSTALL_DIR/notifiers"

cp "$REPO_DIR/hooks/statusline.sh"  "$INSTALL_DIR/hooks/"
cp "$REPO_DIR/hooks/check-usage.sh" "$INSTALL_DIR/hooks/"
cp "$REPO_DIR/hooks/notify.sh"      "$INSTALL_DIR/hooks/"
cp "$REPO_DIR/hooks/snooze.sh"      "$INSTALL_DIR/hooks/"

cp "$REPO_DIR/notifiers/macos.sh"   "$INSTALL_DIR/notifiers/"
cp "$REPO_DIR/notifiers/slack.sh"   "$INSTALL_DIR/notifiers/"
cp "$REPO_DIR/notifiers/webhook.sh" "$INSTALL_DIR/notifiers/"

chmod +x "$INSTALL_DIR/hooks/"*.sh "$INSTALL_DIR/notifiers/"*.sh

if [[ ! -f "$INSTALL_DIR/config.json" ]]; then
  cp "$REPO_DIR/config.example.json" "$INSTALL_DIR/config.json"
  echo "usage-guard: created $INSTALL_DIR/config.json"
else
  echo "usage-guard: config exists — skipped (delete to reset)"
fi

cat << EOF

Done. Add to ~/.claude/settings.json:

  "statusLine": {
    "type": "command",
    "command": "bash \\"$INSTALL_DIR/hooks/statusline.sh\\""
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \\"$INSTALL_DIR/hooks/check-usage.sh\\"",
            "timeout": 10
          }
        ]
      }
    ]
  }

If you have another statusLine (e.g. caveman), set chain_statusline in:
  $INSTALL_DIR/config.json

Example:
  "chain_statusline": "bash \\"/path/to/caveman-statusline.sh\\""

Find caveman's path in your current ~/.claude/settings.json statusLine command.
EOF
