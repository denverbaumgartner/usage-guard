#!/usr/bin/env bats

load '../helpers/setup'

setup()    { setup_usage_guard; }
teardown() { teardown_usage_guard; }

_spy_notifier() {
  local name="$1"
  local out_file="$2"
  cat > "$HOME/.claude/usage-guard/notifiers/${name}.sh" <<EOF
#!/usr/bin/env bash
echo "\$1 \$2 \$3" > "$out_file"
EOF
  chmod +x "$HOME/.claude/usage-guard/notifiers/${name}.sh"
}

@test "dispatches to a single listed notifier" {
  CALLED="$TEST_DIR/called"
  _spy_notifier "spy" "$CALLED"
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{ "notifiers": ["spy"], "notifier_config": {} }
EOF
  run bash "$HOME/.claude/usage-guard/hooks/notify.sh" "94.5" "90" "seven_day"
  [ "$status" -eq 0 ]
  [ -f "$CALLED" ]
}

@test "passes pct, threshold, window as positional args to notifier" {
  ARGS="$TEST_DIR/args"
  _spy_notifier "argspy" "$ARGS"
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{ "notifiers": ["argspy"], "notifier_config": {} }
EOF
  bash "$HOME/.claude/usage-guard/hooks/notify.sh" "94.5" "90" "seven_day"
  run cat "$ARGS"
  [ "$output" = "94.5 90 seven_day" ]
}

@test "dispatches to multiple notifiers" {
  A="$TEST_DIR/a"; B="$TEST_DIR/b"
  _spy_notifier "notif_a" "$A"
  _spy_notifier "notif_b" "$B"
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{ "notifiers": ["notif_a", "notif_b"], "notifier_config": {} }
EOF
  bash "$HOME/.claude/usage-guard/hooks/notify.sh" "94.5" "90" "seven_day"
  [ -f "$A" ]
  [ -f "$B" ]
}

@test "continues dispatching after a notifier fails" {
  cat > "$HOME/.claude/usage-guard/notifiers/fail.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$HOME/.claude/usage-guard/notifiers/fail.sh"
  CALLED="$TEST_DIR/called"
  _spy_notifier "after" "$CALLED"
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{ "notifiers": ["fail", "after"], "notifier_config": {} }
EOF
  run bash "$HOME/.claude/usage-guard/hooks/notify.sh" "94.5" "90" "seven_day"
  [ "$status" -eq 0 ]
  [ -f "$CALLED" ]
}

@test "handles missing notifier script gracefully without crashing" {
  cat > "$HOME/.claude/usage-guard/config.json" <<'EOF'
{ "notifiers": ["nonexistent"], "notifier_config": {} }
EOF
  run bash "$HOME/.claude/usage-guard/hooks/notify.sh" "94.5" "90" "seven_day"
  [ "$status" -eq 0 ]
}
