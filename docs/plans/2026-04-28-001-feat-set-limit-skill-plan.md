---
title: feat: Add usage-guard:set-limit skill
type: feat
status: completed
date: 2026-04-28
origin: docs/brainstorms/set-limit-requirements.md
---

# feat: Add usage-guard:set-limit skill

## Overview

Add a new skill `usage-guard:set-limit` that allows users to update the usage guard threshold percentage without manually editing `config.json`. The skill validates input (0-100), updates the config file, and reports success or failure.

---

## Problem Frame

Users currently cannot change the usage guard threshold without manually editing `~/.claude/usage-guard/config.json`. The threshold is hardcoded at 90% by default, and there's no user-friendly way to adjust it to 95%, 90%, or any other value.

---

## Requirements Trace

- R1. Skill accepts integer percentage (0-100) as argument
- R2. Skill updates `config.json` threshold field
- R3. Skill validates input and rejects invalid percentages (< 0 or > 100)
- R4. Skill creates config with default structure if missing
- R5. Skill reports success/failure to user

---

## Scope Boundaries

- UI for threshold selection
- Threshold history/undo functionality
- Per-window thresholds (single threshold for all windows)

---

## Context & Research

### Relevant Code and Patterns

- **Existing skills:** `skills/usage-guard-resume/SKILL.md`, `skills/usage-guard-cancel/SKILL.md` — follow this pattern for skill structure and bash script invocation
- **Config structure:** `config.example.json` — shows required fields and default values
- **Config reading:** `hooks/check-usage.sh:24` — reads threshold via `jq -r '.threshold // 90'`
- **Test pattern:** `tests/unit/snooze.bats` — uses `setup_usage_guard` helper, isolated temp HOME, bats assertions

### Institutional Learnings

None relevant for this lightweight feature.

### External References

None needed — follows existing bash/jq patterns in the codebase.

---

## Key Technical Decisions

- **Bash script approach:** Use `jq` to update config.json, matching existing patterns in `snooze.sh` and `check-usage.sh`
- **Validation:** Reject non-integer values and out-of-range percentages (< 0 or > 100)
- **Config creation:** If config.json doesn't exist, create it with default structure from `config.example.json`
- **Error handling:** Exit with non-zero status on validation failure, write clear error message to stderr

---

## Open Questions

### Resolved During Planning

None — all requirements are clear from the origin document.

### Deferred to Implementation

None — this is straightforward bash scripting with no runtime unknowns.

---

## Implementation Units

- U1. **Create set-limit.sh script**

**Goal:** Create bash script that validates input and updates config.json threshold

**Requirements:** R1, R2, R3, R4, R5

**Dependencies:** None

**Files:**
- Create: `hooks/set-limit.sh`

**Approach:**
- Parse argument as integer percentage
- Validate range (0-100)
- Create config.json with defaults if missing
- Use `jq` to update threshold field
- Report success with new value, or error with reason

**Patterns to follow:**
- `hooks/snooze.sh` — argument parsing, jq usage, error handling
- `hooks/check-usage.sh:24` — config path and jq pattern for threshold

**Test scenarios:**
- Happy path: valid percentage (50, 90, 100) updates config and reports success
- Edge case: boundary values (0, 100) accepted and written correctly
- Error path: invalid percentage (< 0, > 100) rejected with error message
- Error path: non-integer input rejected with error message
- Edge case: missing config.json creates default structure with new threshold

**Verification:**
- Script exists and is executable
- Manual test with valid percentage updates config.json
- Manual test with invalid percentage exits non-zero and shows error

---

- U2. **Create usage-guard:set-limit skill**

**Goal:** Create skill that invokes set-limit.sh with user argument

**Requirements:** R1, R5

**Dependencies:** U1

**Files:**
- Create: `skills/usage-guard-set-limit/SKILL.md`

**Approach:**
- Follow pattern of `usage-guard:resume` skill
- Parse user argument as percentage
- Invoke set-limit.sh with argument
- Handle marketplace install path fallback
- Report result to user

**Patterns to follow:**
- `skills/usage-guard-resume/SKILL.md` — skill structure, bash invocation, marketplace path fallback

**Test expectation: none -- skill is thin wrapper around bash script, tested via U1

**Verification:**
- Skill file exists with correct frontmatter
- Manual invocation via `/usage-guard:set-limit 95` works

---

- U3. **Add unit tests for set-limit.sh**

**Goal:** Add bats tests covering all validation and update scenarios

**Requirements:** R1, R2, R3, R4, R5

**Dependencies:** U1

**Files:**
- Create: `tests/unit/set-limit.bats`

**Approach:**
- Use `setup_usage_guard` helper from `tests/helpers/setup.bash`
- Test happy path, edge cases, and error paths
- Verify config.json is updated correctly
- Verify error messages and exit codes

**Patterns to follow:**
- `tests/unit/snooze.bats` — test structure, helper usage, assertion patterns

**Test scenarios:**
- Happy path: valid percentage (50, 90, 100) updates config threshold
- Edge case: boundary values (0, 100) accepted and written correctly
- Error path: invalid percentage (< 0, > 100) exits non-zero with error message
- Error path: non-integer input exits non-zero with error message
- Edge case: missing config.json creates default structure with new threshold
- Edge case: existing config preserves other fields (snooze_seconds, windows, notifiers)

**Verification:**
- All tests pass with `bats tests/unit/set-limit.bats`
- Coverage matches test scenarios above

---

## System-Wide Impact

- **Interaction graph:** None — this is a standalone skill that only modifies config.json
- **Error propagation:** Script errors exit non-zero; skill reports error to user
- **State lifecycle risks:** None — config.json update is atomic via jq
- **API surface parity:** None — no external APIs or interfaces
- **Integration coverage:** `check-usage.sh` reads updated threshold on next invocation; covered by existing tests
- **Unchanged invariants:** Existing config fields (snooze_seconds, windows, notifiers) are preserved

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| jq not installed on user system | Already required by existing hooks (check-usage.sh, snooze.sh) — no new dependency |
| Config corruption from concurrent writes | Unlikely — single-user CLI tool; jq writes atomically |

---

## Documentation / Operational Notes

- Update README.md to document the new skill (if README lists available skills)
- No operational changes — skill is user-initiated only

---

## Sources & References

- **Origin document:** [docs/brainstorms/set-limit-requirements.md](../brainstorms/set-limit-requirements.md)
- Related code: `hooks/check-usage.sh`, `hooks/snooze.sh`, `skills/usage-guard-resume/SKILL.md`
- Related tests: `tests/unit/snooze.bats`, `tests/helpers/setup.bash`
