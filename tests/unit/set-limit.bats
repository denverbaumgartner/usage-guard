#!/usr/bin/env bats

load '../helpers/setup'

FIXTURES="$BATS_TEST_DIRNAME/../fixtures"

setup()    { setup_usage_guard; }
teardown() { teardown_usage_guard; }

_config() {
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{
  "threshold": 90,
  "snooze_seconds": 1800,
  "windows": ["seven_day", "five_hour"],
  "notifiers": [],
  "notifier_config": {}
}
EOF
}

@test "set-limit.sh updates threshold in config.json" {
  _config
  bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" 75
  THRESHOLD=$(jq -r '.threshold' "$HOME/.claude/usage-guard/config.json")
  [ "$THRESHOLD" = "75" ]
}

@test "set-limit.sh accepts boundary value 0" {
  _config
  bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" 0
  THRESHOLD=$(jq -r '.threshold' "$HOME/.claude/usage-guard/config.json")
  [ "$THRESHOLD" = "0" ]
}

@test "set-limit.sh accepts boundary value 100" {
  _config
  bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" 100
  THRESHOLD=$(jq -r '.threshold' "$HOME/.claude/usage-guard/config.json")
  [ "$THRESHOLD" = "100" ]
}

@test "set-limit.sh rejects percentage < 0" {
  _config
  run bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" -1
  [ "$status" -ne 0 ]
  [[ "$output" == *"error"* ]]
  THRESHOLD=$(jq -r '.threshold' "$HOME/.claude/usage-guard/config.json")
  [ "$THRESHOLD" = "90" ]
}

@test "set-limit.sh rejects percentage > 100" {
  _config
  run bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" 101
  [ "$status" -ne 0 ]
  [[ "$output" == *"error"* ]]
  [[ "$output" == *"101"* ]]
  THRESHOLD=$(jq -r '.threshold' "$HOME/.claude/usage-guard/config.json")
  [ "$THRESHOLD" = "90" ]
}

@test "set-limit.sh rejects non-integer input" {
  _config
  run bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" abc
  [ "$status" -ne 0 ]
  [[ "$output" == *"error"* ]]
  THRESHOLD=$(jq -r '.threshold' "$HOME/.claude/usage-guard/config.json")
  [ "$THRESHOLD" = "90" ]
}

@test "set-limit.sh creates config.json with defaults if missing" {
  bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" 50
  [ -f "$HOME/.claude/usage-guard/config.json" ]
  THRESHOLD=$(jq -r '.threshold' "$HOME/.claude/usage-guard/config.json")
  [ "$THRESHOLD" = "50" ]
  SNOOZE=$(jq -r '.snooze_seconds' "$HOME/.claude/usage-guard/config.json")
  [ "$SNOOZE" = "1800" ]
}

@test "set-limit.sh preserves other config fields" {
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{
  "threshold": 90,
  "snooze_seconds": 3600,
  "windows": ["seven_day"],
  "notifiers": ["slack"],
  "notifier_config": {
    "slack": {
      "webhook_url": "https://example.com/webhook"
    }
  }
}
EOF
  bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" 75
  THRESHOLD=$(jq -r '.threshold' "$HOME/.claude/usage-guard/config.json")
  [ "$THRESHOLD" = "75" ]
  SNOOZE=$(jq -r '.snooze_seconds' "$HOME/.claude/usage-guard/config.json")
  [ "$SNOOZE" = "3600" ]
  WINDOWS=$(jq -r '.windows[0]' "$HOME/.claude/usage-guard/config.json")
  [ "$WINDOWS" = "seven_day" ]
  NOTIFIERS=$(jq -r '.notifiers[0]' "$HOME/.claude/usage-guard/config.json")
  [ "$NOTIFIERS" = "slack" ]
}

@test "set-limit.sh reports success with new threshold" {
  _config
  run bash "$HOME/.claude/usage-guard/hooks/set-limit.sh" 95
  [ "$status" -eq 0 ]
  [[ "$output" == *"threshold set to 95%"* ]]
}
