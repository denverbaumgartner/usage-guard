#!/usr/bin/env bats

load '../helpers/setup'

FIXTURES="$BATS_TEST_DIRNAME/../fixtures"

setup()    { setup_usage_guard; }
teardown() { teardown_usage_guard; }

_config() {
  local threshold="${1:-90}"
  local windows="${2:-[\"seven_day\",\"five_hour\"]}"
  cat > "$HOME/.claude/usage-guard/config.json" <<EOF
{
  "threshold": $threshold,
  "windows": $windows,
  "notifiers": [],
  "notifier_config": {}
}
EOF
}

@test "allows tool when rate_limits.json does not exist yet" {
  _config
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows tool when usage is below threshold" {
  _config
  cp "$FIXTURES/rate_limits_low.json" "$HOME/.claude/usage-guard/rate_limits.json"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "halts agent when seven_day usage exceeds threshold" {
  _config
  cp "$FIXTURES/rate_limits_high.json" "$HOME/.claude/usage-guard/rate_limits.json"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"continue": false'* ]]
}

@test "halt output is valid JSON" {
  _config
  cp "$FIXTURES/rate_limits_high.json" "$HOME/.claude/usage-guard/rate_limits.json"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  echo "$output" | jq . > /dev/null
  [ "$status" -eq 0 ]
}

@test "halt output contains non-empty stopReason" {
  _config
  cp "$FIXTURES/rate_limits_high.json" "$HOME/.claude/usage-guard/rate_limits.json"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  reason=$(echo "$output" | jq -r '.stopReason')
  [ -n "$reason" ]
  [ "$reason" != "null" ]
}

@test "stopReason includes the window name" {
  _config
  cp "$FIXTURES/rate_limits_high.json" "$HOME/.claude/usage-guard/rate_limits.json"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  reason=$(echo "$output" | jq -r '.stopReason')
  [[ "$reason" == *"seven_day"* ]]
}

@test "halts at exactly the threshold (>= not >)" {
  _config 90
  cp "$FIXTURES/rate_limits_at_threshold.json" "$HOME/.claude/usage-guard/rate_limits.json"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [[ "$output" == *'"continue": false'* ]]
}

@test "respects custom threshold — allows when below custom value" {
  _config 95
  # rate_limits_high.json has seven_day=94.5%, which is under 95%
  cp "$FIXTURES/rate_limits_high.json" "$HOME/.claude/usage-guard/rate_limits.json"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "only checks configured windows — ignores high five_hour when not listed" {
  _config 90 '["seven_day"]'
  cat > "$HOME/.claude/usage-guard/rate_limits.json" <<'EOF'
{
  "five_hour": { "used_percentage": 99.0, "resets_at": 9999999999 },
  "seven_day": { "used_percentage": 40.0, "resets_at": 9999999999 }
}
EOF
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "halts on five_hour when it is the only configured window and it is high" {
  _config 90 '["five_hour"]'
  cat > "$HOME/.claude/usage-guard/rate_limits.json" <<'EOF'
{
  "five_hour": { "used_percentage": 99.0, "resets_at": 9999999999 },
  "seven_day": { "used_percentage": 10.0, "resets_at": 9999999999 }
}
EOF
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [[ "$output" == *'"continue": false'* ]]
}

@test "allows tool when config.json is missing" {
  rm -f "$HOME/.claude/usage-guard/config.json"
  cp "$FIXTURES/rate_limits_high.json" "$HOME/.claude/usage-guard/rate_limits.json"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
}
