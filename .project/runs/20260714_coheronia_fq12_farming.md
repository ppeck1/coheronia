# Run Ledger: 20260714_coheronia_fq12_farming

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
| Queue Item | FQ-12 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T07:10:00-04:00 |
| Ended At | 2026-07-14T07:40:00-04:00 |

## User Request

"computer shut down, where did we leave off?" then "proceed" — resume the
in-progress, uncommitted FQ-12 (farming and food stability) work: validate,
close the parse-error hang, and commit in the two-commit pattern.

## What Shipped (implementation commit `3f916dd`)

- **Farming loop on one key** (`farm_action` = G). `player.try_farm` is
  context-sensitive: aiming at dirt/grass tills it into `farm_soil`
  (`world.till_soil`); aiming at an air cell sitting directly on `farm_soil`
  plants a seedling (`world.plant_crop`), consuming one `crop_seeds` from the
  backpack. Both paths reach-gated with honest player messages.
- **Crop growth** (`world._tick_crop_growth`, run each `_process`): a
  `crop_seedling` on tilled soil ripens to `crop_ripe` after `CROP_GROW_SECONDS`
  (60s). Guardrails: an unsupported crop is removed (crops never float); a crop
  whose cell was mined/replaced simply drops its timer (never regrows into an
  invalid cell); crops never reschedule like berry bushes. Harvest (mine) of
  `crop_ripe` yields 3 food + 1 seed.
- **Bootstrap + economy**: `craft_seeds` (hand recipe) turns 1 food into 2
  seeds, so the loop starts from a single bush. `farm_soil`/`crop_seedling`/
  `crop_ripe` are new `blocks.json` entries (crops `requires_support`,
  non-solid, non-placeable); `crop_seeds` and the crop/soil display items are
  new in `items.json`.
- **Persistence + score**: `crop_growth` timers serialize/parse exactly like
  bush regrowth (`serialize_crop_growth`/`parse_crop_growth`, wired through
  `save_manager.collect_state`/`apply_state` and `world.setup`). `break_block`
  and the load-time support sweep clear crop timers. `world.farm_tile_count()`
  (tilled soil + crop cells) is a food-yard score exposed in
  `game_root.summary()` for future base levels.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0; incl. "farming blocks and seeds" |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 276/276 | 7 new `fq12_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 7 `fq12_*` checks: `fq12_till_soil` (dirt->farm_soil, stone not tillable),
`fq12_plant_on_soil_only` (planting requires tilled soil below; floating
planting refused), `fq12_crop_ripens` (seedling->ripe on timer),
`fq12_harvest_yields_food` (ripe crop drops food + a seed),
`fq12_no_float_no_regrow` (removing the tilled soil removes the crop; it never
floats and never enters bush_regrow), `fq12_crop_saves` (crop + growth timer
round-trip through save/load), and `fq12_farm_score` (food-yard count exposed
to UI). Suite 269 -> 276.

## Fix Made This Run

The uncommitted tree carried a parse error: `var target := world.block_at(cell)`
in `player.try_farm`. Because `player.world` is typed `Node2D`, GDScript could
not infer the `:=` type, so `player.gd` failed to load — the player node
degraded to a bare `CharacterBody2D`, cascading errors made `game_root._process`
loop forever, and the headless smoke never wrote results (the run hung). Fixed
by annotating `var target: String = world.block_at(cell)`. After the fix the
suite ran clean 276/276.

## Acceptance vs FQ-12

- Player can plant, wait, harvest, and gain food. [done — till -> plant ->
  ripen -> harvest food+seed, smoke-proven]
- Food reserve affects settlement survival as before. [done — harvest yields
  the existing `food` item; population food math unchanged]
- Crops do not float or regrow into invalid cells. [done — `requires_support`
  + `_tick_crop_growth`/`break_block`/setup-sweep guards, smoke-enforced]
- Simple farm/food-yard score for future base levels. [done —
  `world.farm_tile_count()` in `game_root.summary()`]

## Review

Self-reviewed the diff (no agent spawned). Verified: crops can only be planted
on tilled soil (never floating); the ripen tick removes unsupported crops and
never reschedules them as bushes; harvesting and the load sweep clear timers;
seed bootstrap comes only from food (no free seeds); save/load round-trips the
timers. Root-caused and fixed the parse-error hang before signing.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq12_farming.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq12_farming.json`

## Git Closeout

Implementation commit `3f916dd` (data, world/player/game_root/save code,
validator, smoke, docs), then this evidence-only commit. Nothing pushed; push
deferred to explicit operator instruction.

## Remaining Risks

- Crop art is procedural (sprout/golden-stalk drawings in
  `world._make_block_texture`); real sprites for `farm_soil`/`crop_seedling`/
  `crop_ripe` are optional assets pending in `docs/ASSET_ROADMAP.md` (validator
  INFO, fallbacks active).
- Growth pacing (`CROP_GROW_SECONDS` 60s) and yields (3 food + 1 seed) are
  code/data-tunable and untested by human play.
- The food-yard score is informational only (exposed in `summary()`); no base
  level consumes it yet.

## Next Action

FQ-13 (enemy variety and combat pressure — thornrat, ore tick, raider
torchbearer). Art production continues via `docs/ASSET_ROADMAP.md`.
