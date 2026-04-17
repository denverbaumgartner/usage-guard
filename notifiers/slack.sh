#!/usr/bin/env bash

PCT="$1"
THRESHOLD="$2"
WINDOW="$3"
CONFIG="$4"

WEBHOOK_URL=$(jq -r '.notifier_config.slack.webhook_url // ""' "$CONFIG" 2>/dev/null)
if [[ -z "$WEBHOOK_URL" ]]; then
  echo "usage-guard[slack]: webhook_url not configured in config.json" >&2
  exit 0
fi

curl -sf -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\":warning: *Claude Code Usage Guard*: \`${WINDOW//_/ }\` at *${PCT}%* (threshold: ${THRESHOLD}%). Agent paused.\"}" \
  > /dev/null
