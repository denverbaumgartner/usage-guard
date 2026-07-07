---
name: usage-guard:set-limit
description: Set the usage-guard threshold percentage. Accepts an integer between 0 and 100.
---

Parse the user's argument as a threshold percentage (0-100).

Run:

```bash
bash ~/.claude/usage-guard/hooks/set-limit.sh <arg>
```

If the plugin was installed via marketplace, set-limit.sh may be at a different path. Try:

```bash
bash ~/.claude/usage-guard/hooks/set-limit.sh "$ARG" 2>/dev/null \
  || find ~/.claude/plugins/cache -name set-limit.sh 2>/dev/null | head -1 | xargs -I{} bash {} "$ARG"
```

Report: success with new threshold value, or error with reason.
