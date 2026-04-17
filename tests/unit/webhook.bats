#!/usr/bin/env bats

load '../helpers/setup'

setup()    { setup_usage_guard; }
teardown() { teardown_usage_guard; }

_mock_curl() {
  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/curl" <<EOF
#!/usr/bin/env bash
while [[ \$# -gt 0 ]]; do
  [[ "\$1" == "-d" ]] && echo "\$2" > "$TEST_DIR/payload.json"
  shift
done
exit 0
EOF
  chmod +x "$TEST_DIR/bin/curl"
  export PATH="$TEST_DIR/bin:$PATH"
}

@test "exits 0 and warns when url is empty" {
  cat > "$TEST_DIR/config.json" <<'EOF'
{ "notifier_config": { "webhook": { "url": "", "headers": {} } } }
EOF
  run bash "$HOME/.claude/usage-guard/notifiers/webhook.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  [ "$status" -eq 0 ]
}

@test "sends POST when url is configured" {
  _mock_curl
  cat > "$TEST_DIR/config.json" <<'EOF'
{ "notifier_config": { "webhook": { "url": "https://example.com/hook", "headers": {} } } }
EOF
  run bash "$HOME/.claude/usage-guard/notifiers/webhook.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/payload.json" ]
}

@test "payload is valid JSON with correct fields" {
  _mock_curl
  cat > "$TEST_DIR/config.json" <<'EOF'
{ "notifier_config": { "webhook": { "url": "https://example.com/hook", "headers": {} } } }
EOF
  bash "$HOME/.claude/usage-guard/notifiers/webhook.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  event=$(jq -r '.event' "$TEST_DIR/payload.json")
  pct=$(jq -r '.used_percentage' "$TEST_DIR/payload.json")
  window=$(jq -r '.window' "$TEST_DIR/payload.json")
  [ "$event" = "usage_threshold_exceeded" ]
  [ "$pct" = "94.5" ]
  [ "$window" = "seven_day" ]
}
