#!/usr/bin/env bats

load '../helpers/setup'

setup()    { setup_usage_guard; }
teardown() { teardown_usage_guard; }

# Injects a mock curl into PATH that writes its -d payload to $TEST_DIR/payload.json
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

_config_with_url() {
  local url="${1:-https://hooks.slack.com/test}"
  cat > "$TEST_DIR/config.json" <<EOF
{ "notifier_config": { "slack": { "webhook_url": "$url" } } }
EOF
}

@test "exits 0 and warns when webhook_url is empty" {
  cat > "$TEST_DIR/config.json" <<'EOF'
{ "notifier_config": { "slack": { "webhook_url": "" } } }
EOF
  run bash "$HOME/.claude/usage-guard/notifiers/slack.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  [ "$status" -eq 0 ]
}

@test "exits 0 and warns when webhook_url key is absent" {
  cat > "$TEST_DIR/config.json" <<'EOF'
{ "notifier_config": { "slack": {} } }
EOF
  run bash "$HOME/.claude/usage-guard/notifiers/slack.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  [ "$status" -eq 0 ]
}

@test "sends POST request when webhook_url is configured" {
  _mock_curl
  _config_with_url
  run bash "$HOME/.claude/usage-guard/notifiers/slack.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/payload.json" ]
}

@test "payload contains the usage percentage" {
  _mock_curl
  _config_with_url
  bash "$HOME/.claude/usage-guard/notifiers/slack.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  run cat "$TEST_DIR/payload.json"
  [[ "$output" == *"94.5%"* ]]
}

@test "payload is valid JSON" {
  _mock_curl
  _config_with_url
  bash "$HOME/.claude/usage-guard/notifiers/slack.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  run jq . "$TEST_DIR/payload.json"
  [ "$status" -eq 0 ]
}

@test "payload contains window name" {
  _mock_curl
  _config_with_url
  bash "$HOME/.claude/usage-guard/notifiers/slack.sh" \
    "94.5" "90" "seven_day" "$TEST_DIR/config.json"
  payload=$(cat "$TEST_DIR/payload.json")
  [[ "$payload" == *"seven day"* ]]
}
