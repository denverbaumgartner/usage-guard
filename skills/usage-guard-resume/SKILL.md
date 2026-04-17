---
name: usage-guard:resume
description: Snooze the usage-guard halt so the agent can continue past the usage threshold. Accepts optional duration as seconds, "30m", or "1h". Default is 30 minutes.
---

Parse the user's argument as a snooze duration. The snooze.sh script handles these formats natively:
- No arg → uses snooze_seconds from config (default 1800 / 30 min)  
- "30m", "90m", etc → minutes
- "1h", "2h", etc → hours
- Raw integer → seconds

Run:

```bash
bash ~/.claude/usage-guard/hooks/snooze.sh <arg>
```

If the plugin was installed via marketplace, snooze.sh may be at a different path. Try:

```bash
bash ~/.claude/usage-guard/hooks/snooze.sh "$ARG" 2>/dev/null \
  || find ~/.claude/plugins/cache -name snooze.sh 2>/dev/null | head -1 | xargs -I{} bash {} "$ARG"
```

Report: duration set and human-readable expiry time.
