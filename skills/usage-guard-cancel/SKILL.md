---
name: usage-guard:cancel
description: Cancel an active usage-guard snooze immediately, re-enabling the halt at the configured threshold.
---

```bash
RESUME_FLAG=~/.claude/usage-guard/resume.flag
if [ -f "$RESUME_FLAG" ]; then
  rm "$RESUME_FLAG"
  echo "usage-guard: snooze cancelled — threshold enforcement restored"
else
  echo "usage-guard: no active snooze to cancel"
fi
```

Report whether a snooze was active and is now cancelled.
