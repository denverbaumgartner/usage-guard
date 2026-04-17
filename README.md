# usage-guard

Halts Claude Code agents at a configurable usage threshold and sends notifications. Prevents overage costs by pausing autonomous workflows before the budget is exhausted.

## How it works

1. A `statusLine` hook intercepts Claude Code's real-time rate limit data and caches it to disk
2. A `PreToolUse` hook reads that cache before every tool call — if usage exceeds the threshold, it outputs `{"continue": false}` to halt the agent
3. A pluggable notifier system fires alerts (macOS, Slack, webhook, ...)

## Install

```bash
git clone https://github.com/denverbaumgartner/usage-guard.git
cd usage-guard
bash install.sh
```

Then follow the printed instructions to update `~/.claude/settings.json`.

## Merge into existing settings.json

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/usage-guard/hooks/statusline.sh\""
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/usage-guard/hooks/check-usage.sh\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## Configuration

Edit `~/.claude/usage-guard/config.json`:

```json
{
  "threshold": 90,
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

| Key | Description |
|-----|-------------|
| `threshold` | Usage % that triggers a halt (default: 90) |
| `windows` | Which windows to check: `seven_day`, `five_hour` |
| `chain_statusline` | Command to call after saving rate limits — use for caveman or other statusLine plugins |
| `notifiers` | List of active notifiers |

### Chaining with caveman (or any other statusLine plugin)

usage-guard takes the `statusLine` slot. To keep your existing statusLine badge working, find its command in `~/.claude/settings.json` and set it as `chain_statusline`:

```json
{
  "chain_statusline": "bash \"/Users/you/.claude/plugins/cache/caveman/caveman/<hash>/hooks/caveman-statusline.sh\""
}
```

usage-guard runs first (saves data), then pipes the same input to caveman, whose output becomes the status bar text.

## Adding notifiers

1. Create `notifiers/<name>.sh` — receives `$1=pct $2=threshold $3=window $4=config_path`
2. Add `"<name>"` to the `notifiers` array in `config.json`
3. Re-run `bash install.sh` to deploy

## Updating

```bash
git pull
bash install.sh
```

Config is preserved on update.
