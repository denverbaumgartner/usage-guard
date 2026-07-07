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

_high_usage() {
  cp "$FIXTURES/rate_limits_high.json" "$HOME/.claude/usage-guard/rate_limits.json"
}

@test "snooze.sh creates resume.flag" {
  _config
  bash "$HOME/.claude/usage-guard/hooks/snooze.sh" 60
  [ -f "$HOME/.claude/usage-guard/resume.flag" ]
}

@test "resume.flag contains a future epoch timestamp" {
  _config
  bash "$HOME/.claude/usage-guard/hooks/snooze.sh" 60
  EXPIRES=$(cat "$HOME/.claude/usage-guard/resume.flag")
  NOW=$(date +%s)
  [ "$EXPIRES" -gt "$NOW" ]
}

@test "check-usage allows through when snooze is active" {
  _config
  _high_usage
  bash "$HOME/.claude/usage-guard/hooks/snooze.sh" 3600
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-usage halts again after snooze expires" {
  _config
  _high_usage
  # Write an already-expired flag (epoch 1 = 1970)
  echo "1" > "$HOME/.claude/usage-guard/resume.flag"
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"continue": false'* ]]
}

@test "expired resume.flag is deleted after check-usage runs" {
  _config
  _high_usage
  echo "1" > "$HOME/.claude/usage-guard/resume.flag"
  bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}' || true
  [ ! -f "$HOME/.claude/usage-guard/resume.flag" ]
}

@test "snooze.sh uses snooze_seconds from config when no arg given" {
  _config
  bash "$HOME/.claude/usage-guard/hooks/snooze.sh"
  EXPIRES=$(cat "$HOME/.claude/usage-guard/resume.flag")
  NOW=$(date +%s)
  DIFF=$(( EXPIRES - NOW ))
  # Should be ~1800s (allow ±5s for execution time)
  [ "$DIFF" -ge 1795 ] && [ "$DIFF" -le 1805 ]
}

@test "snooze.sh arg overrides config snooze_seconds" {
  _config
  bash "$HOME/.claude/usage-guard/hooks/snooze.sh" 300
  EXPIRES=$(cat "$HOME/.claude/usage-guard/resume.flag")
  NOW=$(date +%s)
  DIFF=$(( EXPIRES - NOW ))
  [ "$DIFF" -ge 295 ] && [ "$DIFF" -le 305 ]
}

@test "stopReason includes the snooze command" {
  _config
  _high_usage
  run bash "$HOME/.claude/usage-guard/hooks/check-usage.sh" <<< '{}'
  reason=$(echo "$output" | jq -r '.stopReason')
  [[ "$reason" == *"snooze.sh"* ]]
}
