# usage-guard

Halts Claude Code agents at a configurable usage threshold and notifies you. A speed bump, not a brick wall — resume with `/usage-guard:resume` when you're ready.

---

## Quickstart

**Step 1 — Add the plugin to `~/.claude/settings.json`:**

```json
{
  "extraKnownMarketplaces": {
    "usage-guard": {
      "source": { "source": "github", "repo": "denverbaumgartner/usage-guard" }
    }
  },
  "enabledPlugins": {
    "usage-guard@usage-guard": true
  }
}
```

Claude Code downloads the plugin automatically. The `PreToolUse` hook and slash commands are wired with no further action.

**Step 2 — Run the installer to create your config:**

```bash
bash ~/.claude/plugins/cache/usage-guard/usage-guard/*/install.sh
```

This creates `~/.claude/usage-guard/config.json` and prints the exact `statusLine` snippet you need to add to `~/.claude/settings.json`.

**Step 3 — Add the printed `statusLine` to `~/.claude/settings.json`.**

That's it. Restart Claude Code.

---

## Slash commands

| Command | What it does |
|---------|-------------|
| `/usage-guard:resume [30m\|1h\|seconds]` | Snooze the halt and continue (default from config, usually 30 min) |
| `/usage-guard:status` | Show current usage %, threshold, and active snooze |
| `/usage-guard:cancel` | Cancel snooze immediately — re-enables the guard |

---

## If you use caveman (or any other statusLine plugin)

`usage-guard` needs the `statusLine` slot to read live rate limit data. If you already have a plugin using it, set `chain_statusline` in `~/.claude/usage-guard/config.json` so both run:

```json
{
  "chain_statusline": "bash \"/path/to/caveman-statusline.sh\""
}
```

Find your caveman path: look at the current `statusLine.command` value in `~/.claude/settings.json`. Copy that path here, then point `statusLine` at usage-guard instead.

---

## Configuration

`~/.claude/usage-guard/config.json` — created by `install.sh`:

```json
{
  "threshold": 90,
  "snooze_seconds": 1800,
  "windows": ["seven_day", "five_hour"],
  "chain_statusline": "",
  "notifiers": ["macos"],
  "notifier_config": {
    "macos": { "sound": "Basso" },
    "slack": { "webhook_url": "" },
    "webhook": { "url": "", "headers": {} }
  }
}
```

| Key | Default | Description |
|-----|---------|-------------|
| `threshold` | `90` | Usage % that triggers a halt |
| `snooze_seconds` | `1800` | Default snooze duration when no arg given to `/usage-guard:resume` |
| `windows` | `["seven_day","five_hour"]` | Which rate limit windows to monitor |
| `chain_statusline` | `""` | Existing statusLine command to call after usage-guard (e.g. caveman) |
| `notifiers` | `["macos"]` | Active notification channels |

---

## How it works

1. `statusLine` hook captures Claude Code's real-time rate limit data → saves to `~/.claude/usage-guard/rate_limits.json`
2. `PreToolUse` hook reads that file before every tool call — if usage ≥ threshold, outputs `{"continue": false}` to halt the agent and fires notifications
3. The halt message tells you exactly how to resume: `/usage-guard:resume [duration]`
4. Resume writes a timed flag; the guard passes silently until it expires

---

## Adding notifiers

1. Create `notifiers/<name>.sh` with args `$1=pct $2=threshold $3=window $4=config_path`
2. Add `"<name>"` to `notifiers` in your config
3. Slack and webhook stubs are included — just add your URL

---

## Manual install (no marketplace)

```bash
git clone https://github.com/denverbaumgartner/usage-guard.git
cd usage-guard
bash install.sh
```

Follow the printed output to add the hook and statusLine to `~/.claude/settings.json`.

---

## Updating

```bash
# Marketplace install — Claude Code handles it automatically on next start

# Manual install
git pull && bash install.sh
```

Config is always preserved on update.

---

## Tests

```bash
make deps          # brew install bats-core jq
make test-unit     # 41 unit tests, no side effects
make test          # + 5 integration tests (fires real macOS notifications)
```
