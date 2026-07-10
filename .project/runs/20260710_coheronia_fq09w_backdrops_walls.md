# Run Ledger: 20260710_coheronia_fq09w_backdrops_walls

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) implementation lead + 3 haiku read-only scouts + haiku read-only verifier |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09W (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-10T09:30:00-04:00 |
| Ended At | 2026-07-10T12:10:00-04:00 |

## User Request

"commit and proceed with token saving swarm agent protocols" — FQ-09C was
committed and pushed; FQ-09W (scene backdrops, underground darkness, and
backing-wall foundation) is the queue head.

## Agent Protocol Notes

Three haiku scouts ran read-only recon in parallel: (1) the rendering/
lighting stack (node tree, tileset occluders, PointLight2D torches, the
CanvasModulate writers, DirectionalLight2D feasibility), (2) worldgen and
persistence (generation channels, delta flow, save keys, zero FQ-02
remnants, where pristine terrain is derivable), (3) smoke/screenshot/
validator conventions and settlement-math isolation. One implementation
lead owned every edit. A haiku verifier inspected the finished diff:
NO FINDINGS across wall-tileset inertness, sky-line invalidation coverage,
backdrop determinism/loop guards, ambient writer completeness, check
counts, tour save-safety, validator additions, and doc claims.

## Key Design Decision (documented approximation)

The work order preferred roof-aware sunlight via directional shadows.
Scout evidence: no DirectionalLight2D exists, occluders are tileset-level
and only on `blocks_light` blocks — that path needs an occluder redesign.
Per the work order's sanctioned fallback and the template's lighting
contract, this slice ships a **live column-skylight ambient**: sunlight
reaches down each column of the LIVE cells to its first solid block
(`world.sky_line(x)`, cached per column, invalidated on any block change
there), and the player's burial depth below that line fades the global
CanvasModulate target from the day/night/storm base toward `CAVE_TINT`
over `CAVE_FADE_CELLS` (6). Mining an open shaft genuinely re-admits
daylight; a sealed column at the same depth stays dark. Limits stated
plainly: no lateral light bleed; the ambient follows the player, not
per-cell; true skylight (directional shadows or cell connectivity over
extended occluders) is the recorded future path.

## What Shipped (implementation commit `de7fe83`)

1. **Scenic backdrop** — new `scripts/world/world_backdrop.gd` (child of
   World at z -10, inside the modulated canvas): code-drawn sky gradient
   bands reaching the deepest valley line, far/mid silhouette ridges with
   2px-stepped parallax stable in world space, deep earth tone below;
   `light_mask = 0` so torches cannot paint glow onto distant scenery.
   Optional image hooks: `art/generated/backgrounds/surface_sky.png`
   (640x360 full frame), `surface_far_terrain.png`,
   `surface_mid_silhouette.png` (tiling strips) — missing files fall back.
2. **Natural backing walls** — `BackgroundWalls` TileMapLayer (z -2)
   rebuilt each `world.setup` from the pristine generated surface +
   `generation.dirt_depth`: dirt-wall band then stone wall, nothing at or
   above the surface row. The wall tileset has zero physics and zero
   occlusion layers; walls never enter cells/deltas/saves. Tiles from
   `art/generated/back_walls/dirt_wall.png`/`stone_wall.png` when present,
   else the matching block texture darkened and fully opaque.
   `world.wall_at(cell)` is the visual-only query.
3. **Underground darkness** — `game_root.ambient_darkness_factor()` /
   `ambient_target_color()` (CAVE_TINT 0.10/0.11/0.16) consumed by both
   `_advance_time` (smoothing lerp) and `apply_time_state` (instant on
   load). Torch/lantern PointLight2D behavior, light_score, shelter,
   occlusion, mining, collision, and the save format are untouched.
4. **Verification surfaces** — 7 `fq09w_*` smoke checks (suite 203 -> 210);
   screenshot tour gained `09_underground_midday_torch` (mined chamber,
   midday, dark ambient, one torch); validator requires the new script,
   both art directories, and the `backgrounds`/`back_walls` categories.
5. Docs: HANDOFF, VARIABLE_MATRIX (live authority rows + planned rows
   reduced to what is genuinely not live), FABLE_TASK_QUEUE (FQ-09W Done,
   FQ-09A next), README (210 checks + world-depth bullet),
   BACKGROUND_TEMPLATE status now live-contract.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. world_backdrop.gd, backgrounds/back_walls dirs and categories |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS 210/210 | `user://smoke_results.json` at 2026-07-10T11:47:17 (first FQ-09W-complete run was also green 210/210 at 10:58) |
| `git diff --check` | PASS | exit 0 |
| haiku read-only diff verifier | NO FINDINGS | 7/7 items confirmed |
| Screenshot tour review | PASS | `01_settlement_day` (backdrop, sky to the deepest valley, no torch glow on ridges — two composition bugs found in frame review and fixed: average-horizon void, light-splash on scenery), `02_night_torchlight`, new `09_underground_midday_torch` (dark chamber, torch-lit backing walls, open shaft) |

## Acceptance vs FQ-09W

- Surface view has an intentional fallback backdrop with no blank edges
  (deepest-valley sky rule; frame-reviewed).
- A mined underground chamber reveals backing walls while `block_at` stays
  air and collision/mining behavior is unchanged (fq09w_mined_chamber_
  reveals_wall + the untouched mining baselines).
- Underground is visibly dark at midday; torches and lanterns brighten it
  locally; an open shaft admits roof-aware daylight (fq09w checks c/d, the
  09 tour shot).
- Backing walls have no collision, drops, deltas, settlement tags, or
  shelter/light-score effects (zero physics/occlusion layers by
  construction; settlement math reads only cells/registry).
- Same seed/config produces the same natural backing-wall map
  (fq09w_walls_deterministic_and_inert).
- Old world saves load unchanged; no wall state persisted (no new save
  keys; fq09w_world_restored plus every legacy save/load check green).
- Missing optional images return to code-drawn fallbacks (backdrop hook
  nulls + fq09w_wall_art_hook).
- Night/storm, torch, save, smoke, and screenshot behavior remain green
  (210/210; tour re-run reviewed).
- Retired FQ-02 surfaces stay retired (scout-confirmed zero remnants; no
  background_cells/BackgroundFlora introduced).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260710_coheronia_fq09w_backdrops_walls.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260710_coheronia_fq09w_backdrops_walls.json`

## Git Closeout

Implementation commit `de7fe83`, then this evidence-only commit. Not pushed
(push only on explicit operator request; this run's instruction was
"commit and proceed").

## Remaining Risks

- The ambient is player-column based: the whole canvas darkens when the
  player is buried, so surface areas visible at screen edges darken too
  while underground (and vice versa at cave mouths). Documented as the
  first-slice approximation; per-cell skylight is the future path and
  would require occluders beyond blocks_light blocks.
- The backdrop's silhouette ridges are cosmetic and do not correspond to
  real terrain; per the template they stay below foreground contrast.
- Backing walls ship only dirt/stone materials; ore/fungal/crystal/timber
  wall variants and cave/deep background layers are planned (FQ-09A).
- Constructed (player-placeable) walls remain a separate future gameplay
  task: drops, wall deltas, recipes, and save migration are deliberately
  out of scope here.
- The repo still ships zero art; both new hook categories are proven via
  temp files only.

## Next Action

FQ-09A (future asset manifest and prompt packs) is the queue head — it
should include the opening's cel-frame sprite sheets, the scenic background
layers, and the back-wall tile set now that all their runtime contracts are
real.
