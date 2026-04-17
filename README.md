# usage-guard

Halts Claude Code agents at a configurable usage threshold and sends notifications. A speed bump, not a brick wall — resume with `/usage-guard:resume` when you're ready to continue.

## Slash commands

| Command | Description |
|---------|-------------|
| `/usage-guard:resume [30m\|1h\|seconds]` | Snooze the halt and continue (default: 30 min) |
| `/usage-guard:status` | Show current usage %, threshold, and snooze state |
| `/usage-guard:cancel` | Cancel an active snooze immediately |

## How it works

1. A `statusLine` hook captures Claude Code's real-time rate limit data and caches it to `~/.claude/usage-guard/rate_limits.json`
2. A `PreToolUse` hook reads that cache before every tool call — if usage hits the threshold, it outputs `{"continue": false}` to halt the agent and fires a notification
3. When halted, the stopReason tells you to run `/usage-guard:resume`
4. `snooze.sh` writes a timed flag; the guard passes silently until it expires

---

## Install

### Option A — Claude Code marketplace (recommended)

Add to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "usage-guard": {
      "source": {
        "source": "github",
        "repo": "denverbaumgartner/usage-guard"
      }
    }
  },
  "enabledPlugins": {
    "usage-guard@usage-guard": true
  }
}
```

The `PreToolUse` hook and all slash commands are wired automatically. Then run `bash install.sh` once to create your config:

```bash
git clone https://github.com/denverbaumgartner/usage-guard.git
cd usage-guard
bash install.sh
```

### Option B — Manual local install

```bash
git clone https://github.com/denverbaumgartner/usage-guard.git
cd usage-guard
bash install.sh
```

Follow the printed instructions to add the hook to `~/.claude/settings.json`.

---

## statusLine setup (both install methods)

The statusLine slot must be configured manually because it needs to chain to any existing statusLine plugin (e.g. caveman).

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"/path/to/usage-guard/hooks/statusline.sh\""
  }
}
```

**If you use caveman or another statusLine plugin**, set `chain_statusline` in your config so both run:

```json
{
  "chain_statusline": "bash \"/Users/you/.claude/plugins/cache/caveman/caveman/<hash>/hooks/caveman-statusline.sh\""
}
```

Find your caveman path in the current `statusLine.command` value in `~/.claude/settings.json`.

---

## Configuration

Edit `~/.claude/usage-guard/config.json`:

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
| `snooze_seconds` | `1800` | Default snooze duration (30 min) |
| `windows` | `["seven_day","five_hour"]` | Which windows to monitor |
| `chain_statusline` | `""` | Command to call after saving rate limits |
| `notifiers` | `["macos"]` | Active notifiers |

---

## Adding notifiers

1. Create `notifiers/<name>.sh` — args: `$1=pct $2=threshold $3=window $4=config_path`
2. Add `"<name>"` to the `notifiers` array in your `config.json`

---

## Updating

```bash
git pull
bash install.sh  # re-runs safely; config is preserved
```

---

## Publishing / sharing

This plugin is just a GitHub repo. To share it:
- Give people your repo URL and these install instructions
- They add `denverbaumgartner/usage-guard` (or your fork) to `extraKnownMarketplaces`

To get into the official `claude-plugins-official` marketplace, submit to Anthropic — no public process is documented yet, so reach out via the Claude Code community.

---

## Tests

```bash
make deps        # brew install bats-core jq
make test-unit   # 41 unit tests (no side effects)
make test        # + 5 integration tests (fires real macOS notifications)
```
