# Open Questions

## Unresolved

- [ ] **Q4 (Behavioral): Where does the "resume message" come from, and is it fixed or dynamic?**
  - Context: User asked for a configurable resume message. Three plausible sources:
    - **Global default** in `config.json` (`"resume_message": "continue where you left off"`).
    - **Per-invocation override** on `/usage-guard:resume-when-ready` — e.g. `/usage-guard:resume-when-ready "wrap up the refactor"`.
    - **Auto-captured context** from the halted session — last user prompt, last assistant TODO, etc. (Much harder; would need transcript parsing.)
  - Sub-question: should an empty / unset message just exec `claude --resume <id>` with no initial prompt (user arrives at a live session, types next)? Or should we always seed a prompt so the agent starts work on reattach?
  - Recommendation: config default + optional per-invocation override; empty means "plain interactive resume" (no initial prompt). Skip auto-captured context in v1.

- [ ] **Q6 (Edge Cases): What happens when the environment makes resume impossible?**
  - Cases to handle:
    - Machine is asleep when `resets_at` fires → launchd fires on wake with the original scheduled time. Acceptable.
    - User already manually resumed (typed a new prompt) before the trigger fired → the trigger script should detect this (transcript mtime advanced past `halted_at`) and disarm itself.
    - Multiple concurrent halts in different projects → each gets its own halt-state file and its own launchd label; each schedules its own wake.
    - Nested halts: auto-resume fires, budget is still over (e.g. partial reset), `check-usage.sh` halts again → do NOT re-arm automatically, to avoid loops. User re-arms manually.
    - Session id no longer valid (too old, transcripts rotated) → `claude --resume` fails; trigger script logs and gives up.
  - Recommendation: lean on filesystem primitives for state, fail closed (give up silently rather than retry) on any error, log everything to `~/.claude/usage-guard/auto-resume.log`.

## Resolved

- [x] **Q1 (Architectural): What external mechanism actually wakes Claude Code and issues the resume?**
  - Resolution: **launchd.** On opt-in arming, the plugin writes a one-shot user LaunchAgent plist keyed off `resets_at` and loads it via `launchctl`. The plist exec's a trigger script that performs the reattach.
  - Rationale: macOS-only is explicitly acceptable. launchd is the "proper" macOS mechanism — it survives reboot, survives sleep (fires on wake for missed runs), and has no lingering `sleep` PIDs on the system. It matches the project's file-only ethos: one plist + one trigger script, both on disk.
  - Codebase evidence: current plugin is 100% filesystem state (`resume.flag`, `rate_limits.json`). A generated plist file under `~/Library/LaunchAgents/` is the natural extension of that pattern. No daemon code to maintain, no process supervision.

- [x] **Q2 (Architectural): What is the resume trigger — wall-clock time (snooze end) or actual budget availability?**
  - Resolution: **Trigger on `rate_limits.<window>.resets_at` from the hook payload.** This is the authoritative "budget back" timestamp emitted by Claude Code itself. The launchd plist is scheduled for `resets_at` of whichever window tripped the halt.
  - Rationale: `resets_at` is ground truth; a snooze duration is a user guess. Auto-resume that fires before budget is actually free just re-halts immediately.
  - Do NOT conflate with snooze expiry. Snooze is a user-chosen override to keep working *through* a threshold; auto-resume is a budget-driven wake-up *after* a halt. Different concepts, different state, different triggers. If a snooze is active when the trigger fires, the trigger no-ops (the session isn't halted).
  - Codebase evidence: `hooks/statusline.sh` already extracts `rate_limits` from the hook stdin payload into `~/.claude/usage-guard/rate_limits.json`. The `resets_at` epochs are there today (see `tests/fixtures/statusline_payload_high.json`).

- [x] **Q3 (Integration): Which session does auto-resume target, and how does the plugin capture it?**
  - Resolution: **Capture `session_id`, `transcript_path`, `cwd`, and `resets_at` in `hooks/check-usage.sh` at the moment of halt.** These arrive together on the hook's stdin payload. Persist to the same state directory as the existing snooze state (`~/.claude/usage-guard/`), establishing this as the single state-dir pattern for the plugin.
  - Rationale: halt is the canonical arming point — it's the one moment the plugin knows a resume will be needed and has all four fields in one payload. Capturing in `statusline.sh` would be noisier (runs every turn) and doesn't add information. Per-cwd scoping (session scoped by `cwd`) keeps multi-project concurrent halts from cross-triggering.
  - Codebase evidence:
    - `hooks/check-usage.sh` currently does not read stdin; adding a single `jq` extraction at the top is a minimal diff.
    - The hook stdin payload shape is confirmed by Q7 spike and by the existing `statusline.sh` consumer.
    - Transcript convention from Q7: `~/.claude/projects/<cwd-slug>/<uuid>.jsonl`, slug is cwd with `/` → `-`.

- [x] **Q5 (Behavioral): Is auto-resume opt-in or opt-out?**
  - Resolution: **Opt-in, required.** The user must explicitly enable auto-resume per halt (via a skill invocation, e.g. `/usage-guard:resume-when-ready [message]`, or equivalent config surface). If the user does nothing, current halt behavior stands — the session halts and stays halted until manually resumed. There is no global "always on" mode in v1.
  - Rationale: auto-resume changes the social contract of halt ("speed bump, not a brick wall"). It runs code without the user present. Per-halt opt-in keeps existing `/usage-guard:resume` semantics untouched, makes the capability discoverable, and leaves the door open for a later global flag without breaking defaults. User's framing: "you need to opt in for auto resume, and then what happens if you don't" → nothing happens, current halt behavior stands.
  - Codebase evidence: existing skill pattern (`usage-guard-resume`, `usage-guard-cancel`, `usage-guard-status`) is the natural home for a new `usage-guard-resume-when-ready` skill. Pure additive — no changes to existing skill semantics.

- [x] **Q7 (Integration): Does `claude --resume <id> -p "<message>"` actually work headlessly the way we need?**
  - Resolution: Yes. Spike (haiku model) confirmed:
    - `claude -p --resume <uuid> "<prompt>"` runs to completion, preserves full session context, and exits 0.
    - Cross-session memory works (stored "42" in session 1, recalled it in session 2 via headless resume).
    - `--session-id <uuid>` flag lets the caller assign the UUID upfront (optional — we get it from hook stdin).
    - Transcripts live at `~/.claude/projects/<cwd-slug>/<uuid>.jsonl`; continuation runs append to the same file.
  - Rationale: proves the underlying resume primitive works. Even though v1 ships reattach (interactive), this validated that session ids, transcript paths, and resume semantics behave as assumed. Headless `-p` remains available as a follow-up delivery mode.
  - Codebase evidence: hook stdin already carries `session_id`, `transcript_path`, `cwd` — no transcript sniffing, no UUID assignment required.

- [x] **Q8 (Behavioral/Integration): Headless resume vs. reattach resume — which UX ships first?**
  - Resolution: **Reattach.** When `resets_at` arrives, the trigger script spawns a new Terminal window running an interactive `claude --resume <session_id>` session, optionally seeded with the configured resume message as the initial prompt. Headless `-p` is NOT shipped in MVP.
  - Rationale: user wants to "continue wherever we left off" with a live session — walk back to the laptop and find a live TUI mid-conversation, not a completed headless transcript. Matches the "agent picks up where we stopped" mental model.
  - Implementation path: macOS `osascript -e 'tell app "Terminal" to do script "cd <cwd> && claude --resume <id> \"<msg>\""'` (or equivalent for iTerm). Single platform (macOS) matches the launchd scheduler choice in Q1. Terminal.app is the default target; iTerm can come later behind a config knob.
  - Codebase evidence: no existing terminal-spawn surface to conflict with; this is a greenfield addition to the trigger script.

---

# Auto-resume after usage-guard halt — draft

## Problem

`usage-guard` halts a Claude Code agent when the 5-hour or 7-day rate-limit window crosses the configured threshold. The halt is effective but one-sided: when the window resets and budget frees up, the user has to come back, open the session, and re-prompt the agent. For long-running agentic work (overnight runs, large refactors, research loops) this means multi-hour idle gaps baked into the workflow — the agent halts at 92%, budget frees up at 3am, nothing happens until the user wakes up and pokes it.

`usage-guard` should close that loop: when the user opts in at halt time, the plugin arms a scheduled wake-up at `resets_at`, and when the window resets it spawns a new interactive Terminal window running `claude --resume <session_id>` so the user walks back to a live session mid-conversation.

## What the repo already has (relevant bits)

- **`hooks/statusline.sh`** — runs every statusLine tick. Receives full context on stdin (`session_id`, `transcript_path`, `cwd`, `model`, `rate_limits`). Today only extracts `.rate_limits` → `~/.claude/usage-guard/rate_limits.json`.
- **`hooks/check-usage.sh`** — runs on `PreToolUse`, reads `rate_limits.json`, emits `{"continue": false, "stopReason": ...}` when threshold exceeded. Currently does not read stdin. This is the moment of halt — the natural place to capture session state and arm auto-resume.
- **`hooks/snooze.sh`** — writes `~/.claude/usage-guard/resume.flag` with an expiry epoch. Pure filesystem state, no daemons. Distinct concept from auto-resume (user override vs. budget-driven wake).
- **`rate_limits.json`** — contains `resets_at` epochs per window. Authoritative source for "when will budget actually return."
- **Skills** — `usage-guard-resume`, `usage-guard-cancel`, `usage-guard-status`. Thin wrappers over bash scripts. Pattern is established; a new `usage-guard-resume-when-ready` skill slots in cleanly.
- **Notifiers** — factory pattern in `notifiers/`, dispatched from `hooks/notify.sh`. Natural fit for "auto-resume fired" / "auto-resume disarmed" surfacing.

## Final architecture (MVP)

Four moving parts, all on disk, all macOS-native:

### 1. Opt-in arming

User invokes `/usage-guard:resume-when-ready [message]` (or equivalent config surface) *before* or *at* halt time. This flips a flag that `check-usage.sh` reads when it halts:

```
~/.claude/usage-guard/auto-resume.armed    # presence = armed; contents = optional message
```

If the flag is not present at halt time, the plugin halts as it does today and does nothing else. This is the non-negotiable opt-in gate.

### 2. State capture at halt (`hooks/check-usage.sh`)

When `check-usage.sh` decides to halt AND `auto-resume.armed` is present:

1. Read the hook stdin JSON (new; does not today) and extract `session_id`, `transcript_path`, `cwd`.
2. Read `rate_limits.json` for the tripping window's `resets_at`.
3. Write halt state:
   ```
   ~/.claude/usage-guard/halt-state.json
     { halt_id, session_id, cwd, transcript_path, window, pct,
       halted_at, resets_at, message }
   ```
4. Generate and load a one-shot launchd plist keyed off `resets_at`:
   ```
   ~/Library/LaunchAgents/ai.semiotic.usage-guard.resume.<halt_id>.plist
   ```
   The plist exec's `hooks/auto-resume-fire.sh <halt_id>` at `resets_at`.
5. Emit the existing halt response; the user sees the normal "budget exceeded" stop reason.

### 3. Trigger fire (`hooks/auto-resume-fire.sh`)

When launchd fires at `resets_at`:

1. Re-read `halt-state.json`. Abort if absent (user cancelled) or if the snooze flag is active (user is working through the halt manually — auto-resume would collide).
2. Abort if `transcript_path`'s mtime is newer than `halted_at` — user already resumed manually.
3. Spawn interactive Terminal window via `osascript`:
   ```
   osascript -e 'tell app "Terminal" to do script
     "cd <cwd> && claude --resume <session_id> \"<message>\""'
   ```
   (message is optional; empty means plain interactive resume with no initial prompt.)
4. Dispatch a notifier ("usage-guard auto-resume fired in `<cwd>`").
5. Remove `halt-state.json`, unload/remove the plist.

### 4. Disarming

Three paths that must all leave the system clean:

- **User cancel** (`/usage-guard:cancel`): remove `auto-resume.armed`, remove `halt-state.json` if present, `launchctl unload` + delete the plist.
- **Successful fire**: trigger script removes its own state + plist after spawning the Terminal.
- **Snooze-active-at-fire-time**: trigger script no-ops and disarms itself (snooze means user is actively overriding; don't double-up with an auto-resume).

## Config schema (MVP)

```json
{
  "auto_resume": {
    "default_message": "",
    "resets_at_buffer_seconds": 30
  }
}
```

That's it for MVP. Intentionally minimal:

- No `enabled` field — opt-in is per-halt via the skill, not a global toggle.
- No `scheduler` field — launchd is the decision (Q1).
- No `delivery` field — reattach is the decision (Q8).
- No `trigger` field — `resets_at` is the decision (Q2).
- `default_message` is the fallback when the skill is invoked without an argument.
- `resets_at_buffer_seconds` is a small pad (default 30s) added to `resets_at` to avoid firing a hair too early and re-tripping the threshold.

## New surface area

### Scripts
- `hooks/auto-resume-arm.sh` — invoked by the skill; writes `auto-resume.armed` with the (optional) message.
- `hooks/auto-resume-fire.sh <halt-id>` — invoked by launchd; does the osascript reattach.
- `hooks/auto-resume-disarm.sh` — invoked by `/usage-guard:cancel` and by `auto-resume-fire.sh` on completion; cleans up state + plist.
- `hooks/check-usage.sh` changes — read stdin, check `auto-resume.armed`, write `halt-state.json`, generate + load plist. All new code is gated on the opt-in flag; non-opt-in users see zero behavior change.

### Skills
- `skills/usage-guard-resume-when-ready/SKILL.md` — arms auto-resume with an optional message argument.

### State files (all under `~/.claude/usage-guard/`)
- `auto-resume.armed` — presence flag with optional message contents.
- `halt-state.json` — captured session state at halt.
- `auto-resume.log` — append-only log of arm / fire / cancel / error events.

### launchd artifacts
- `~/Library/LaunchAgents/ai.semiotic.usage-guard.resume.<halt_id>.plist` — one-shot, deleted after fire or cancel.

## Implementation concerns for spec-architect

These are not open questions — they are known implementation surfaces the spec needs to pin down:

1. **Plist lifecycle.** Generation, loading (`launchctl bootstrap gui/<uid>` vs. legacy `launchctl load`), unloading, and deletion. What happens if the user deletes the plist manually? If launchctl fails to load? Error paths must fail closed (clean up halt-state and log).

2. **Label collisions across multiple halted sessions.** Multiple concurrent halts in different projects each generate their own plist. Label scheme must be collision-free (`ai.semiotic.usage-guard.resume.<halt_id>` with a UUID or timestamp-based `halt_id`). Enumeration / cleanup of stale plists (e.g. after a crash) needs a design.

3. **osascript reliability.** `tell app "Terminal"` assumes Terminal.app is available and willing. Cases to handle: Terminal not installed / replaced with iTerm; Terminal not running (does `do script` launch it?); user has disabled automation permissions for the launchd agent (first-run TCC prompt will fire from a background context, which may be invisible). Spec needs a fallback when osascript fails (log + notifier, don't retry).

4. **TCC / permissions on first run.** Automation permissions for launchd-spawned osascript are granted via TCC. First fire may prompt or silently fail depending on the user's security settings. Spec needs a documented first-run dance (ideally arm once in foreground to trigger the prompt, then real fires work silently).

5. **Resume-message UX and config surface.** Q4 remains open. Spec should define: skill argument parsing (`/usage-guard:resume-when-ready "msg with spaces"`), interaction with `default_message`, empty-message semantics (plain interactive resume vs. skip vs. error), escaping of the message when it's interpolated into the osascript `do script` command (quotes, backslashes, newlines — this is a real injection surface).

6. **Snooze / auto-resume interaction.** Both live in the same state dir. Arming auto-resume while a snooze is active: allowed? Snooze activated after auto-resume is armed: does the armed state persist through the snooze? Spec needs a truth table. Current plan: snooze suppresses the halt (so `auto-resume.armed` never triggers capture), and if a snooze is active when the trigger fires, the trigger no-ops.

7. **Skill surface.** Does `/usage-guard:resume-when-ready` require a halt to already be in progress, or can it pre-arm before the halt happens? Can it be re-invoked to change the message? Does it show status (armed / fired / disarmed)? Does `/usage-guard:status` surface auto-resume state?

8. **Transcript-mtime staleness check.** The "user already resumed manually" guard compares `transcript_path` mtime against `halted_at`. What counts as "advanced"? Any write? A write of a user message specifically? Spec should pin this down; a too-loose check causes false-positive disarm, too-tight causes double-sessions.

9. **Cleanup on uninstall.** Removing the plugin must enumerate and unload any armed plists. Spec should define the uninstall hook (or document it as user responsibility with a cleanup command).

10. **Testing.** Existing bats tests are hook-level and synchronous. launchd-scheduled fires and osascript are hard to unit-test. Spec should identify what's testable as pure bash (arm, capture, disarm, fire script with stubbed osascript) vs. what needs manual/integration testing.

## Out of scope (v1)

- Headless delivery (`claude -p --resume`). Reattach only.
- Linux / Windows support. macOS only.
- Global "always on" auto-resume. Per-halt opt-in only.
- Auto-re-arming on repeated halts.
- Smart resume messages derived from transcript contents.
- Non-Terminal reattach targets (iTerm, tmux, existing windows).
- Multi-session orchestration beyond per-cwd scoping.

## Readiness for spec-architect handoff

Resolved: Q1, Q2, Q3, Q5, Q7, Q8. Remaining: Q4 (resume-message UX details) and Q6 (edge cases) — both have working recommendations that need user sign-off but are not architectural blockers. The MVP shape (launchd + halt-time capture + osascript reattach + per-halt opt-in) is concrete enough to spec. The "Implementation concerns" list above captures the surfaces the spec will need to nail down.
