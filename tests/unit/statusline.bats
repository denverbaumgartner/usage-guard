#!/usr/bin/env bats

load '../helpers/setup'

FIXTURES="$BATS_TEST_DIRNAME/../fixtures"

setup()    { setup_usage_guard; }
teardown() { teardown_usage_guard; }

_default_config() {
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{
  "threshold": 90,
  "windows": ["seven_day", "five_hour"],
  "chain_statusline": "",
  "notifiers": [],
  "notifier_config": {}
}
EOF
}

@test "writes rate_limits.json when file does not exist" {
  _default_config
  bash "$HOME/.claude/usage-guard/hooks/statusline.sh" < "$FIXTURES/statusline_payload_low.json"
  [ -f "$HOME/.claude/usage-guard/rate_limits.json" ]
}

@test "rate_limits.json contains correct seven_day percentage" {
  _default_config
  bash "$HOME/.claude/usage-guard/hooks/statusline.sh" < "$FIXTURES/statusline_payload_low.json"
  pct=$(jq -r '.seven_day.used_percentage' "$HOME/.claude/usage-guard/rate_limits.json")
  [ "$pct" = "52.8" ]
}

@test "rate_limits.json contains correct five_hour percentage" {
  _default_config
  bash "$HOME/.claude/usage-guard/hooks/statusline.sh" < "$FIXTURES/statusline_payload_low.json"
  pct=$(jq -r '.five_hour.used_percentage' "$HOME/.claude/usage-guard/rate_limits.json")
  [ "$pct" = "45.2" ]
}

@test "produces no output when chain_statusline is empty" {
  _default_config
  run bash "$HOME/.claude/usage-guard/hooks/statusline.sh" < "$FIXTURES/statusline_payload_low.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "chains to configured next statusline and passes its output through" {
  NEXT="$TEST_DIR/next.sh"
  cat > "$NEXT" <<'EOF'
#!/usr/bin/env bash
echo "badge_text"
EOF
  chmod +x "$NEXT"

  cat > "$HOME/.claude/usage-guard/config.json" <<EOF
{
  "chain_statusline": "bash '$NEXT'",
  "notifiers": [],
  "notifier_config": {}
}
EOF

  run bash "$HOME/.claude/usage-guard/hooks/statusline.sh" < "$FIXTURES/statusline_payload_low.json"
  [ "$status" -eq 0 ]
  [ "$output" = "badge_text" ]
}

@test "chain receives the original stdin JSON" {
  RECEIVED="$TEST_DIR/received.json"
  NEXT="$TEST_DIR/next.sh"
  cat > "$NEXT" <<EOF
#!/usr/bin/env bash
cat > "$RECEIVED"
EOF
  chmod +x "$NEXT"

  cat > "$HOME/.claude/usage-guard/config.json" <<EOF
{
  "chain_statusline": "bash '$NEXT'",
  "notifiers": [],
  "notifier_config": {}
}
EOF

  bash "$HOME/.claude/usage-guard/hooks/statusline.sh" < "$FIXTURES/statusline_payload_low.json"
  [ -f "$RECEIVED" ]
  pct=$(jq -r '.rate_limits.seven_day.used_percentage' "$RECEIVED")
  [ "$pct" = "52.8" ]
}

@test "write is atomic — rate_limits.json is always valid JSON under concurrent writes" {
  _default_config
  for _ in {1..10}; do
    bash "$HOME/.claude/usage-guard/hooks/statusline.sh" \
      < "$FIXTURES/statusline_payload_low.json" &
  done
  wait
  run jq . "$HOME/.claude/usage-guard/rate_limits.json"
  [ "$status" -eq 0 ]
}

@test "exits 0 even when chain command fails" {
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{
  "chain_statusline": "exit 1",
  "notifiers": [],
  "notifier_config": {}
}
EOF
  run bash "$HOME/.claude/usage-guard/hooks/statusline.sh" < "$FIXTURES/statusline_payload_low.json"
  [ "$status" -eq 0 ]
}
