# Run Ledger: 20260714_coheronia_fq13p0_asset_audit

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
| Queue Item | FQ-13P0 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T08:45:00-04:00 |
| Ended At | 2026-07-14T09:20:00-04:00 |

## User Request

Operator supplied the full FQ-13P (P0–P4) visual-asset placeholder & variation
requirements. Executed the foundational increment **FQ-13P0** (asset & variant
audit + audit tool + player-variation decision), which the spec requires before
any P1–P4 implementation.

## What Shipped (implementation commit `050a400`)

No runtime/engine-consumed change — a standalone audit tool plus documentation,
so the running game and the 283-check suite are provably unaffected.

- **`scripts/asset_audit.py`** — a report-only runtime asset & variant auditor.
  Scans `art/generated/<category>/` against `data/visual_assets.json` and the
  data authorities (blocks/items/live enemies) and classifies every surface
  `LIVE` / `AVAILABLE_NOT_CONSUMED` / `PLACEHOLDER_REQUIRED` / `FALLBACK_ONLY` /
  `DEFERRED`. Reports: variant pools present in non-consuming categories, the
  `FALLBACK_ONLY` data-vs-art gap, the reserved UI hook ids, and two note
  classes — informational **FINDINGS** vs strict-failing **DATA BUGS** (variant
  sequence gaps, wrong dimensions incl. width-only backgrounds/opening,
  unreadable PNGs). `--strict` exits non-zero on data bugs only.
- **`docs/UI_ASSET_GAPS.md`** — the human authority: pipeline recap, a
  per-category runtime-consumer table (exact call sites; canonical-live vs
  variants-live; selection & fallback rules), the HUD sub-surface placeholder
  hooks with their reserved ids, the findings/`FALLBACK_ONLY`/placeholder
  sections, the player cosmetic-variation decision, and a "what remains
  temporary" tracking table.
- **`docs/FABLE_TASK_QUEUE.md`** — FQ-13P0 marked Done; P1 (consume enemy
  variant pools) queued next; P2–P4 stubbed.

## Key Findings

- **Enemy variant pools are `AVAILABLE_NOT_CONSUMED`.** `cave_crawler_01..03`,
  `raider_basic_01..03`, `surface_slime_01..03` (nine valid 16×16 PNGs) exist
  but `simple_threat._draw` reads only the canonical `visual_texture("enemies",
  id)`. This is the headline gap and FQ-13P1's target.
- **Block variant mechanism is live but unauthored.** `world._set_tile` already
  picks per-cell via `posmod(hash(x,y,seed))`; there are simply no `<block>_NN`
  files — drop-in art activates variety with zero code change.
- **`FALLBACK_ONLY`** for everything since the first art pass: FQ-10 ores,
  FQ-11 ingots, FQ-12 crops/soil, FQ-13 enemies + drop items — all render from
  code fallbacks safely.
- **`PLACEHOLDER_REQUIRED`** for the fifteen reserved HUD/orb/slot/button/cursor
  ids (UI category empty) and `player_gear`; **`DEFERRED`** for the opening cels.

## Decision (recorded, operator review requested)

Player cosmetic variation → **full-body pool** reusing the FQ-09V
`<species>_<presentation>_NN.png` convention: character-owned integer
`visual_variant` (presentation-only, never saved to worlds), deterministic
legacy default from the character id, `variant % pool_size` at draw time.
`Masculine`/`Feminine` stay semantic presentation, not a variant axis. Layered
cosmetic composition is the documented future upgrade. **Operator sign-off
requested before FQ-13P wires player variation** (it sets the sprite-authoring
shape for every species×presentation).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0 |
| `python scripts/asset_audit.py --strict` | PASS | exit 0 (3 findings, 0 data bugs) |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 283/283 | unchanged — no runtime change |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

## Acceptance vs FQ-13P0

- Extend `docs/UI_ASSET_GAPS.md` into a complete runtime asset audit. [done —
  created (it did not previously exist); all required per-category fields]
- Audit script reporting orphaned variants, manifest→missing, sequence gaps,
  wrong dimensions, orphaned UI/opening, canonical-only-despite-variants. [done
  — `scripts/asset_audit.py`; manifest→missing stays hard-failed in
  `validate_repo.py`]
- Player-variation approach chosen and documented before implementation. [done
  — full-body pool, with operator review flagged]
- Do not assume a present file is used. [done — enemy pools caught as
  `AVAILABLE_NOT_CONSUMED` precisely because presence != consumption]

## Review

Self-reviewed (no agent spawned). Verified the audit's consumer mapping against
the actual call sites (`simple_threat._draw`, `world._set_tile`/`_build_tileset`,
`player_visual.sync_from_player`, `hud.item_icon`, `world_backdrop.layer_texture`,
`world._make_wall_texture`). Confirmed P0 touches no `.gd`, no scene, and no JSON
the engine loads, so the 283/283 suite is unaffected (re-run to confirm anyway).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq13p0_asset_audit.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq13p0_asset_audit.json`

## Git Closeout

Implementation commit `050a400` (audit tool + audit doc + queue), then this
evidence-only commit. Pushed to origin/main after evidence.

## Remaining Risks

- The audit's "runtime consumer" / "variants live" columns are hand-verified
  against code, not machine-derived; when a consumer changes, update both the
  doc and `VARIANT_CONSUMERS`/`CANONICAL_CONSUMERS` in `asset_audit.py`.
- `asset_audit.py --strict` is not yet wired into `validate_repo.py`; it is a
  separate validation step for the FQ-13P arc.
- The player-variation decision is recorded but unbuilt and awaits operator
  sign-off; P1 (enemy pools) does not depend on it and can proceed.

## Next Action

FQ-13P1 — consume the enemy variant pools with a deterministic, lifetime-stable
per-enemy selection (add smoke coverage; add `"enemies"` to `VARIANT_CONSUMERS`).
Awaiting operator OK on the player full-body-pool direction before the
player-variation slice.
