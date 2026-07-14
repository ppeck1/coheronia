# Run Ledger: 20260714_coheronia_fq13p4_frame_semantics

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
| Queue Item | FQ-13P4 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T10:15:00-04:00 |
| Ended At | 2026-07-14T10:30:00-04:00 |

## User Request

"proceed with P2-P4" — this run is FQ-13P4, the arc closer (opening
variant-vs-animation distinction + block/item variation follow-through).

## What Shipped (implementation commit `1c6ef64`)

- **`data/visual_assets.json` `frame_semantics`** — a new authority stating the
  shared `<id>_NN.png` convention is consumed two DISTINCT ways: **VARIANT**
  categories (blocks/enemies/players) pick exactly one entry deterministically
  and hold it (an alternate form); **ANIMATION** categories (opening) play the
  entries in order as time frames (`prologue.gd` `cel_frame_index =
  (tick*8/TICK_HZ) % n`, an 8fps loop). Item icons are canonical-only so a stack
  never changes icon between refreshes. "A variant is an alternate form; an
  animation frame is a moment in time — never collapse them."
- **`scripts/asset_audit.py`** — `ANIMATION_CATEGORIES = {"opening"}`; opening
  `_NN` files report as `frames=N ANIMATION`, never as a pick-one variant pool
  (and never flagged `AVAILABLE_NOT_CONSUMED`). Sequence-gap/dimension checks
  still apply to frames.
- **`README.md`** — suite count 283 → **298** in all four places.
- **Docs** — `UI_ASSET_GAPS.md` records the arc complete (P0–P4) with a
  frame-semantics section; queue/handoff/variable-matrix updated.

## Follow-through (block/item variation)

- **Blocks**: the per-cell variant mechanism is live; no `<block>_NN` files are
  authored (drop-in art activates variety with zero code) — no new block IDs are
  introduced for visual variation.
- **Items**: icons stay canonical-only and cached (`item_icon`), so an inventory
  stack never shows a different icon between refreshes — now smoke-locked.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0 |
| `python scripts/asset_audit.py --strict` | PASS | exit 0 (0 findings, 0 data bugs) |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 298/298 | 2 new `fq13p4_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 2 `fq13p4_*` checks: `fq13p4_item_icon_stable` (`item_icon` returns the same
texture across refreshes for both an art-backed item and a swatch-only item, and
items carry no variant pool) and `fq13p4_frame_semantics_documented` (the
manifest carries `frame_semantics` naming both VARIANT and ANIMATION and the
opening category). Suite 296 -> 298.

## Acceptance vs FQ-13P4 / arc close

- Opening manifest distinguishes variant vs animation (and layered tracks
  conceptually). [done — `frame_semantics`; audit `ANIMATION_CATEGORIES`]
- Do not collapse variant and animation into the same runtime behavior. [done —
  they already differ in code (pick-one vs ordered play); now documented and
  audit-enforced]
- Inventory icons stable, never varying per refresh. [done — cached
  `item_icon`; smoke-locked]
- No new gameplay block IDs for visual variation; deterministic block behavior
  preserved. [done — unchanged]
- FQ-13P arc acceptance: variants inventoried, every variant has a consumer or a
  documented deferred state, enemy/player variants consumed and stable, UI hooks
  + placeholders exist with clean fallback, variants never affect gameplay math,
  no unnecessary world-save state. [done across P0–P4]

## Review

Self-reviewed the diff (no agent spawned). Confirmed the manifest JSON parses
(validator), the audit treats opening as animation without regressing the
variant categories, item-icon caching guarantees per-refresh stability, and no
runtime behavior changed (opening already played frames in order; this run
documents and audit-enforces the distinction).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq13p4_frame_semantics.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq13p4_frame_semantics.json`

## Git Closeout

Implementation commit `1c6ef64` (manifest, audit, smoke, README, docs), then
this evidence-only commit. Pushed to origin/main after evidence. **The FQ-13P
arc (P0–P4) is complete.**

## Remaining Risks

- No opening cel frames are authored, so the animation path is documented and
  audit-aware but not exercised at runtime (it remains `DEFERRED`).
- Block/item authored variant art is a drop-in backlog item, not a code gap.

## Next Action

FQ-14 (goal panel, tutorial prompts, and playtest checklist) — the queue head.
Authored art (enemy/ore/ingot/crop/UI-final sprites, block/player variant pools)
continues in parallel via `docs/ASSET_ROADMAP.md`.
