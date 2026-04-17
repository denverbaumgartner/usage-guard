---
name: usage-guard:status
description: Show current Claude Code usage levels, configured threshold, and whether a snooze is active.
---

Run the following and report a clean summary:

```bash
# Current usage
cat ~/.claude/usage-guard/rate_limits.json 2>/dev/null || echo "No data yet — statusLine hook may not have fired"

# Config
cat ~/.claude/usage-guard/config.json 2>/dev/null | jq '{threshold, snooze_seconds, windows}'

# Active snooze
if [ -f ~/.claude/usage-guard/resume.flag ]; then
  EXPIRES=$(cat ~/.claude/usage-guard/resume.flag)
  NOW=$(date +%s)
  if [ "$NOW" -lt "$EXPIRES" ]; then
    echo "Snooze ACTIVE — expires $(date -r $EXPIRES 2>/dev/null || date -d @$EXPIRES)"
  else
    echo "Snooze EXPIRED"
  fi
else
  echo "No snooze active"
fi
```

Present as a concise status block: usage % for each window, threshold, snooze state.
