# Run Ledger: 20260706_coheronia_fq02_background_trees

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + Explore recon agent + sonnet review agent |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-02 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-06T17:15:00-04:00 |
| Ended At | 2026-07-07T10:45:00-04:00 |

## User Request

"using an array of agents/subagents in a token saving mechanism with a
verification and correction loop" — take FQ-02 (background trees and
pass-through flora) from the queue.

## Agent Protocol Notes

Token-saving orchestration: a read-only Explore agent produced a compact map of
world_gen/world/smoke/blocks/settings and the evidence-packet conventions; the
orchestrator implemented directly from that map plus targeted reads, drove the
full verification loop on the operator's Windows machine, then a sonnet review
agent hunted defects on the diff. The first review agent launch died on a
session-token limit and was relaunched after reset. The review found no
must-fix issues; two should-fix findings were applied (negative-y bounds guard
in background tree stamping; a vacuous is_solid_at smoke sub-check replaced
with a meaningful in-bounds + no-overlap assertion) and the full verification
loop was re-run green before commit.

## Scope (design decisions, now documented)

1. Tree split: each accepted tree site on the existing tree seed channel
   becomes either a solid foreground `wood` column (unchanged 3-5 tall) or a
   pass-through background tree (trunk 4-7 `bg_trunk` + 3-wide `bg_canopy`).
   New config key `generation.tree_foreground_ratio` (0-1, default 0.4,
   world-builder slider "Solid Tree Ratio"); a foreground tree is forced after
   2 consecutive background trees (`MAX_CONSECUTIVE_BG_TREES`) so wood supply
   stays meaningful at any ratio > 0.
2. Background trees are pure visuals, not blocks: `WorldGen.generate` returns
   a separate `background` dictionary; `world.gd` renders it on a new
   `BackgroundFlora` TileMapLayer added before the `Blocks` layer, modulated
   with a dim cool tint (`BACKGROUND_TINT`). Its tileset has no physics and no
   occlusion layers, so background flora can never collide, block light, or
   count as shelter. Background cells never enter `cells`/`deltas`, are never
   mineable/placeable/saved (deterministic from seed+config), never overwrite
   terrain/wood/bushes, are y>=0 bounds-guarded, and are cleared across the
   Town Hall footprint columns.
3. Bush generation skips background-occupied cells, so bushes and background
   trunks never coexist; regrowth targets only former bush cells, which by
   construction are never background cells.
4. Harvesting background trees is intentionally NOT built (queue scope: do not
   overbuild); no minimal hook was necessary.
5. blocks.json unchanged: bg_trunk/bg_canopy are not block ids, so the block
   registry, mining, placement, and settlement scoring are untouched by
   construction.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | all file/json/data checks pass |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 142/142 at 2026-07-07T10:34 (was 134), zero failures; fresh results file verified by LastWriteTime |
| `git diff --check` | PASS | exit 0 |

New smoke checks (8): fq02_density_zero_clears_background,
fq02_background_trees_generated, fq02_background_in_bounds_no_overlap,
fq02_background_layer_behind_blocks, fq02_ratio_zero_all_background,
fq02_ratio_one_all_foreground, fq02_walkable_trunk_found,
fq02_player_walks_past_background_tree (live traversal: on flat terrain the
player walks past a background trunk using only move_right — no jump/mining;
evidence x=2231.0 past target 2168.0).

Preserved-contract evidence from the same run: mining frames dirt 21 / wood 33
/ stone 66, wood with axe 24; bush support/regrowth (wave_e_*), save/load,
lights/occlusion, hall protection, FQ-01 health loop — all green.

## Review Findings And Resolutions

- SHOULD-FIX (fixed): background trunk/canopy cells could be stamped at
  negative y on extreme hilltops (surface clamp 6, trunk max 7); both loops now
  guard `pos.y >= 0`.
- SHOULD-FIX (fixed): the `is_solid_at` sub-check in the overlap smoke check
  was structurally vacuous (background cells are never in `cells`); replaced by
  fq02_background_in_bounds_no_overlap asserting no overlap with `cells` and
  all cells inside world bounds. Collision safety remains covered by the
  zero-physics-layers tileset check plus the live walk-through test.
- SHOULD-FIX (rejected, documented): bush regrowth does not consult
  `background_cells` — unreachable in practice because regrowth only targets
  former bush cells and generation guarantees bushes never spawn on background
  cells; same seed+config regenerates the same layout.
- NIT (accepted): a background tree just outside the hall clearing strip can
  lose its canopy cells inside the strip, leaving a trunk stub — cosmetic only.
- NIT (accepted): if fq02_walkable_trunk_found ever failed, the walk-through
  check would be skipped rather than failed — but the found-check itself fails
  the suite, so the regression cannot pass silently.

## Acceptance vs FQ-02

- Surface generation creates pass-through background trees
  (fq02_background_trees_generated: 70 background cells + 30 foreground wood on
  default config, seed 777).
- Player movement is not blocked by background trees
  (fq02_player_walks_past_background_tree, plus zero physics layers on the
  background tileset).
- Foreground wood still exists, remains solid/mineable, drops wood, and works
  with axe behavior (mining_yields_drops, wave_f_axe_speeds_wood 33 -> 24
  frames — unchanged from v0.6 baselines).
- Berry bush support behavior unbroken (all wave_e_* checks green; bushes skip
  background cells at generation).
- Density/flora settings affect the generated surfaces (density_settings,
  fq02_density_zero_clears_background, fq02_ratio_zero_all_background,
  fq02_ratio_one_all_foreground; tree_foreground_ratio slider added).
- Smoke covers the foreground/background distinction (8 fq02_* checks, suite
  134 -> 142).
- No unrelated feature work (diff limited to world_gen/world/smoke/settings +
  one slider row + docs).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260706_coheronia_fq02_background_trees.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260706_coheronia_fq02_background_trees.json`

## Git Closeout

Implementation commit `434c7ae` (code, data, docs), then this evidence-only
commit (ledger + packets recording the real hash).

## Remaining Risks

- Worlds saved before FQ-02 regenerate with some former solid trees now
  background flora; deltas still apply cleanly, but a pre-FQ-02 "air" delta may
  sit next to new background flora. Cosmetic only; no data loss.
- Background tree look (tint, trunk/canopy shapes) is placeholder-grade like
  all current art; FQ-07 (visual asset pipeline) is the upgrade path.
- tree_foreground_ratio feel (0.4 default) untested by human play; tunable in
  data and per world in the builder.

## Next Action

FQ-03 (equipment data model and character-owned gear slots) is next in the
queue.
