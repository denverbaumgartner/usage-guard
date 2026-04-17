---
name: usage-guard:resume
description: Snooze the usage-guard halt so the agent can continue past the usage threshold. Accepts an optional duration (seconds, or human-readable like 30m, 1h). Default is 30 minutes.
---

Parse the user's argument as a snooze duration:
- No arg → use default from config (or 1800s / 30 min)
- Raw number → treat as seconds
- "30m" → 1800, "1h" → 3600, "2h" → 7200, "90m" → 5400, etc.

Convert to seconds, then run:

```bash
bash ~/.claude/usage-guard/hooks/snooze.sh <seconds>
```

Report back: duration set and human-readable expiry time.
