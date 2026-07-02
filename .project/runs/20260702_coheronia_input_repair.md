# Run Ledger: 20260702_coheronia_input_repair

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Fable 5) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Started At | 2026-07-02T11:45:00-04:00 |
| Ended At | 2026-07-02T12:00:00-04:00 |

## User Request

Operator reported that keyboard and mouse input produce no effect in real play of the v0.1 build. Diagnose and fix.

## Scope

Input system repair only: `project.godot` `[input]` section, one new smoke-test check, HANDOFF update.

## Non-Goals

Any gameplay/balance/feature change.

## Root Cause

The scaffold's `[input]` section stored events as JSON-style dictionaries (`{"type": "InputEventKey", "keycode": 65, ...}`). Godot 4 parses these as plain Dictionaries, not InputEvents, and silently binds nothing — verified with a temporary SceneTree script: `InputMap.action_get_events()` returned 0 events for every action. The oneshot run's smoke test did not catch this because it drives actions with `Input.action_press()`, which triggers actions directly and bypasses the InputMap bindings entirely.

## Fix

1. Rewrote every action in `[input]` using proper Godot 4 serialization: `Object(InputEventKey, ..., "physical_keycode": <code>, ...)` and `Object(InputEventMouseButton, ..., "button_index": 1/2, ...)`. Same bindings as documented (A/D/arrows, Space, LMB/RMB, E, T, C, F3, F5, F9, 1–9).
2. Added smoke check `input_actions_bound`: asserts all 15 gameplay actions have at least one real InputEventKey/InputEventMouseButton, closing the verification gap.

## Files Changed

- `project.godot` ([input] section rewritten)
- `scripts/main/smoke_test.gd` (input_actions_bound check)
- `docs/HANDOFF.md` (state, gotcha, validation table)
- `.project/runs/`, `.project/atlas_outbox/`, `.project/boh_outbox/` (this run's artifacts)

## Validation Commands

| Command | Result | Evidence |
|---|---|---|
| Temp diagnostic (pre-fix) | CONFIRMED BUG | `move_left/jump/mine/interact/save_game -> 0 events: []` |
| `COHERONIA_SMOKE=1` headless run (post-fix) | PASS | `SMOKE RESULT: PASS (23/23 passed)`, exit 0, including `input_actions_bound — all actions have device events` |

## README Audit

State: audited_no_change (controls table already correct; bindings now actually match it)

## Variable Matrix Audit

State: no_change_verified (no variables added/moved)

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260702_coheronia_input_repair.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260702_coheronia_input_repair.json`

## Git Closeout

State: committed (fix + closeout on `main`; not pushed, push_policy manual)

## Remaining Risks

- Human playthrough still pending; this fix makes real device input reach the InputMap, and the automated binding check passes, but feel/tuning remains unverified by a person.

## Next Action

Operator: relaunch the project and play — input should now work. Report any remaining dead inputs (would indicate an OS/device-level issue rather than the InputMap).
