#!/usr/bin/env bash

PCT="$1"
THRESHOLD="$2"
WINDOW="$3"
CONFIG="$4"

URL=$(jq -r '.notifier_config.webhook.url // ""' "$CONFIG" 2>/dev/null)
if [[ -z "$URL" ]]; then
  echo "usage-guard[webhook]: url not configured in config.json" >&2
  exit 0
fi

# Build extra headers from config
HEADER_ARGS=()
while IFS='=' read -r key val; do
  HEADER_ARGS+=(-H "$key: $val")
done < <(jq -r '.notifier_config.webhook.headers // {} | to_entries[] | "\(.key)=\(.value)"' "$CONFIG" 2>/dev/null)

curl -sf -X POST "$URL" \
  "${HEADER_ARGS[@]}" \
  -H "Content-Type: application/json" \
  -d "{\"event\":\"usage_threshold_exceeded\",\"window\":\"${WINDOW}\",\"used_percentage\":${PCT},\"threshold\":${THRESHOLD}}" \
  > /dev/null
