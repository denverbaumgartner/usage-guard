#!/usr/bin/env bash
# Shared setup/teardown for all bats tests.
# Overrides HOME to an isolated temp dir so scripts never touch real ~/.claude/usage-guard.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

setup_usage_guard() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export _ORIG_HOME="$HOME"
  export HOME="$TEST_DIR"

  mkdir -p "$HOME/.claude/usage-guard/hooks"
  mkdir -p "$HOME/.claude/usage-guard/notifiers"

  cp "$REPO_DIR/hooks/"*.sh  "$HOME/.claude/usage-guard/hooks/"
  cp "$REPO_DIR/notifiers/"*.sh "$HOME/.claude/usage-guard/notifiers/"
  chmod +x "$HOME/.claude/usage-guard/hooks/"*.sh
  chmod +x "$HOME/.claude/usage-guard/notifiers/"*.sh
}

teardown_usage_guard() {
  export HOME="$_ORIG_HOME"
  rm -rf "$TEST_DIR"
}

skip_if_ci() {
  if [[ -n "${CI:-}" ]]; then
    skip "integration test — skipped in CI (no Notification Center)"
  fi
}
