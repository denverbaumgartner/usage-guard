# Usage Guard: Set Limit

**Date:** 2026-04-28

## Problem

Users cannot change the usage guard threshold without manually editing `~/.claude/usage-guard/config.json`. Current threshold is hardcoded at 90% by default.

## Solution

Add `usage-guard:set-limit` skill to update threshold via command.

## Requirements

### User-Facing Behavior

- Command: `/usage-guard:set-limit <percentage>`
- Accepts integer percentage (0-100)
- Updates `config.json` threshold field
- Validates input (must be 0-100)
- Reports success/failure

### Edge Cases

- Invalid percentage (< 0 or > 100): error message, no change
- Missing config file: create with default structure
- Non-integer input: error message

### Success Criteria

- Skill updates threshold in config.json
- Next hook invocation uses new threshold
- Invalid inputs rejected cleanly

## Scope Boundaries

**Included:**
- Threshold update skill
- Input validation
- Success/error reporting

**Excluded:**
- UI for threshold selection
- Threshold history/undo
- Per-window thresholds (single threshold for all windows)

## Dependencies

- Existing `config.json` structure
- Existing `check-usage.sh` reads threshold from config

## Notes

- Follows pattern of existing skills (`usage-guard:resume`, `usage-guard:cancel`)
- Simple bash skill using `jq` to update config
