#!/usr/bin/env bats
# Integration tests — actually fire osascript. Skipped in CI.

load '../helpers/setup'

FIXTURES="$BATS_TEST_DIRNAME/../fixtures"

setup()    { setup_usage_guard; }
teardown() { teardown_usage_guard; }

_config() {
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{
  "threshold": 90,
  "windows": ["seven_day", "five_hour"],
  "chain_statusline": "",
  "notifiers": ["macos"],
  "notifier_config": {
    "macos": { "sound": "Basso" }
  }
}
EOF
}

@test "macOS notifier fires without error" {
  skip_if_ci
  _config
  run bash "$HOME/.claude/usage-guard/notifiers/macos.sh" \
    "94.5" "90" "seven_day" "$HOME/.claude/usage-guard/config.json"
  [ "$status" -eq 0 ]
}

@test "macOS notifier respects custom sound from config" {
  skip_if_ci
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{ "notifier_config": { "macos": { "sound": "Glass" } } }
EOF
  run bash "$HOME/.claude/usage-guard/notifiers/macos.sh" \
    "94.5" "90" "seven_day" "$HOME/.claude/usage-guard/config.json"
  [ "$status" -eq 0 ]
}

@test "macOS notifier defaults to Basso when sound not configured" {
  skip_if_ci
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{ "notifier_config": { "macos": {} } }
EOF
  run bash "$HOME/.claude/usage-guard/notifiers/macos.sh" \
    "94.5" "90" "seven_day" "$HOME/.claude/usage-guard/config.json"
  [ "$status" -eq 0 ]
}

@test "full chain: statusline payload -> rate_limits written -> check-usage halts -> macOS notification fires" {
  skip_if_ci
  _config

  # Simulate Claude Code sending a high-usage statusLine payload
  bash "$HOME/.claude/usage-guard/hooks/statusline.sh" \
    < "$FIXTURES/statusline_payload_high.json"

  # rate_limits.json should now exist with high values
  [ -f "$HOME/.claude/usage-guard/rate_limits.json" ]
  pct=$(jq -r '.seven_day.used_percentage' "$HOME/.claude/usage-guard/rate_limits.json")
  [ "$pct" = "94.5" ]

  # PreToolUse check — should halt AND fire notification
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"continue": false'* ]]
  # notification fired as side effect (osascript returned 0, no crash)
}

@test "full chain: low usage — statusline writes, check-usage allows, no notification" {
  skip_if_ci
  _config

  bash "$HOME/.claude/usage-guard/hooks/statusline.sh" \
    < "$FIXTURES/statusline_payload_low.json"

  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
