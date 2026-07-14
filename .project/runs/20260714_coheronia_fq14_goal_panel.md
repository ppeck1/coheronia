# Run Ledger: 20260714_coheronia_fq14_goal_panel

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Opus 4.8) implementation lead, remote-control session |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-14 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T12:00:00-04:00 |
| Ended At | 2026-07-14T12:35:00-04:00 |

## User Request

"proceed with FQ-14, upon completion make sure to fully update handoff, readme,
and variable matrix before pushing to github."

## What Shipped (implementation commit `7f87659`)

- **`scripts/main/goal_tracker.gd`** — a pure, scene-free, testable goal model.
  The five early objectives (gather → light the hall → deposit → forge a
  tool/build a station → survive the night) latch **prefix-monotonically**:
  satisfying objective *i* marks 0..*i* done. This keeps the panel from
  regressing when a transient input clears (depositing empties the backpack) and
  makes a loaded game resolve to the right goal on the first update, with **no
  saved tutorial flag**.
- **`scripts/main/game_root.gd`** — `_goal_snapshot` derives each objective's
  boolean from live state (inventory wood/stone, a cached settlement
  `light_score`, `town_hall.total_stock`, `tool_tier`/`axe_tier`/
  `stations_built`, `day_count`); `_refresh_goals` latches and pushes
  `goal_tracker.current()` to the HUD. Wired to `settlement.updated` (also caches
  light score), `player.inventory_changed`, and the forge/axe/build handlers;
  seeded once in `_ready`.
- **`scripts/ui/hud.gd`** — a compact top-center goal panel (semi-transparent,
  `MOUSE_FILTER_IGNORE`, hidden with `toggle_goals`). `update_goal` shows
  "Goal i/5: <text>" + a one-line hint and a completed sentinel; the controls
  hint gained "O goals".
- **`project.godot`** — `toggle_goals` bound to **O** (79).
- **`docs/PLAYTEST_CHECKLIST.md`** — an operator first-loop pass keyed to the
  same goals, confirming the loop is playable without the handoff.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0 |
| `python scripts/asset_audit.py --strict` | PASS | exit 0 |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 302/302 | 4 new `fq14_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 4 `fq14_*` checks: `fq14_goals_advance_in_order` (gather → … → survive →
all_done), `fq14_goals_prefix_latch` (noting `deposit` latches gather+light+
deposit; a transient clear never regresses; current stays `craft`),
`fq14_goal_panel_wired` (the game_root snapshot exposes all five conditions and
the built HUD panel is populated and `MOUSE_FILTER_IGNORE`), and
`fq14_goal_survive_and_toggle` (survive derives from `day_count>=2`; the panel
hides/shows). Suite 298 -> 302.

## Acceptance vs FQ-14

- Compact current-goal panel surfacing the early objectives. [done]
- Prompts driven by actual game state, not static text. [done — `_goal_snapshot`
  derives from live inventory/light/stock/tools/day]
- Goal panel advances from real state changes. [done — latched via signals]
- Prompts can be hidden / unobtrusive. [done — `O` toggle; mouse-ignoring,
  semi-transparent, top-center]
- Operator can play the first loop without reading the handoff.
  [done — `docs/PLAYTEST_CHECKLIST.md` follows the in-game panel alone]

## Docs Refreshed (per the request)

- **README.md** — suite count 283/298 → **302** (all four spots), a new
  "Learns as you play" goal-panel highlight, and the roadmap advanced to FQ-15.
- **docs/HANDOFF.md** — smoke row 298 → 302; completed list now includes the
  FQ-13P arc and FQ-14; Next Action → FQ-15.
- **docs/VARIABLE_MATRIX.md** — audit state → FQ-14; a Goal panel authority row;
  a coverage-list line.
- **docs/FABLE_TASK_QUEUE.md** — FQ-14 marked Done.

## Review

Self-reviewed the diff (no agent spawned). Verified: the goal model is pure and
never touches scenes; prefix-latching prevents regression on transient state and
covers reload without persistence; the panel ignores mouse input and hides on
toggle (unobtrusive); the survive objective latches at the first dawn via
`settlement.compute`; no `Node2D`-typed-`world` inference trap (the goal snapshot
reads only typed members). No gameplay math changed.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq14_goal_panel.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq14_goal_panel.json`

## Git Closeout

Implementation commit `7f87659` (goal_tracker, game_root, hud, project.godot,
smoke, playtest doc, README/HANDOFF/VARIABLE_MATRIX/FABLE_TASK_QUEUE), then this
evidence-only commit. Pushed to origin/main after evidence.

## Remaining Risks

- The panel's live goal advance depends on the settlement/inventory signals
  firing; the forge/axe/build handlers call `_refresh_goals` explicitly, but a
  future craft path that changes tool state without one of those triggers would
  latch only on the next settlement recompute.
- Goal copy and the "tool/station" reading of the craft objective (pick/axe/
  station; sword/armor/lantern not counted) are tunable in `goal_tracker.gd`.
- The panel is not exercised as a live widget by the headless smoke (input
  toggle is simulated by setting visibility); the value/logic path is covered.

## Next Action

FQ-15 (map, scouting, and navigation). Authored art continues via
`docs/ASSET_ROADMAP.md`.
