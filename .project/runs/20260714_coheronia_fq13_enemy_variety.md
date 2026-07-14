# Run Ledger: 20260714_coheronia_fq13_enemy_variety

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
| Queue Item | FQ-13 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T07:45:00-04:00 |
| Ended At | 2026-07-14T08:10:00-04:00 |

## User Request

"push and proceed" — after pushing FQ-12, execute the queue head FQ-13
(enemy variety and combat pressure).

## What Shipped (implementation commit `7d5ea9d`)

Three `enemies.json` stubs promoted to `status: "live"`, each with a distinct
role, spawn condition, damage profile, and drop — kept conservative in density
until combat tuning is proven.

- **thornrat** (surface): fast (speed 66), frail (`hp_mult` 0.7) crop harasser.
  Its `targets_crops` flag routes `simple_threat` to the nearest crop within
  range, which it eats via `world.eat_crop` — the cell is cleared with **no
  player yield** (the lost harvest is the pressure). Falls back to hall-seeking
  when no crop is in range. Spawns at night past day 2 (`_maybe_spawn_thornrat`,
  difficulty-gated, at most one per night).
- **ore_tick** (underground): frail (`hp_mult` 0.7) ore-pocket nuisance.
  `_advance_cave_spawns` selects it over the cave crawler when
  `world.has_ore_within` finds an ore-family block near the spawn cell.
- **raider_torchbearer** (raider): tankier (`hp_mult` 1.5), hits harder
  (contact_damage 10 vs 8), and burns the Town Hall ~2.5x faster
  (`hall_dps_mult` 2.5). Joins later raids via its own `spawn_rule`
  (`_maybe_spawn_torchbearer`, day 8 / stockpile 40 gate, low base chance).

Mechanism: `_spawn_enemy_at` now applies per-def `hp_mult`, `hall_dps_mult`,
and `targets_crops` (defaults leave the original three enemies unchanged).
`world.gd` gained `nearest_crop`, `eat_crop` (no-drop crop removal mirroring
`break_block` bookkeeping), `has_ore_within`, and an `ORE_IDS` set. `items.json`
gained seven drop items (meat/thorn_quill/hide_scrap/ore_flecks/shell/oil_rags/
torch_heads) for names and icons.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0; incl. "FQ-13 enemy variety" |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 283/283 | 7 new `fq13_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 7 `fq13_*` checks: `fq13_new_enemies_live` (all three live),
`fq13_thornrat_eats_crop` (`nearest_crop` locates it; `eat_crop` clears it with
food_delta 0), `fq13_thornrat_profile` (spawned thornrat carries `targets_crops`
and speed 66), `fq13_ore_tick_near_ore` (`has_ore_within` true beside ore, false
in scrubbed stone), `fq13_torchbearer_burns_faster` (hall_dps 10 vs 4, atk 10 vs
8), `fq13_enemy_hp_profile` (torch hp 5 > thorn hp 2 via hp_mult), and
`fq13_new_enemy_drops` (drops land on death). The suite's `enemies_json_loads`
live-def count moved 3 -> 6. Suite 276 -> 283.

## Fix Made This Run

The same GDScript inference trap as FQ-12 recurred: `var target :=
world.cell_center(crop)` in `simple_threat._seek_and_eat_crop` could not infer a
type because the threat's `world` is typed `Node2D`, so `simple_threat.gd`
failed to load and the headless smoke hung. Fixed by annotating `var target:
Vector2`. (Noted as a recurring pattern — untyped `:=` off a `Node2D`-typed
`world` method return; see [[gdscript-node2d-world-inference-trap]].)

## Acceptance vs FQ-13

- Each new enemy can spawn in the intended condition. [done — thornrat night/
  day-gated surface; ore_tick underground near ore; torchbearer later raids]
- Each pressures the player/base in a distinct way. [done — crop-eating,
  ore-pocket presence, faster hall burn + harder hits; smoke-proven]
- Drops enter inventory correctly. [done — `fq13_new_enemy_drops`]

## Review

Self-reviewed the diff (no agent spawned). Verified: default-omitted
`hp_mult`/`hall_dps_mult`/`targets_crops` leave surface_slime/cave_crawler/
raider_basic identical (existing enemy smoke checks unaffected, suite still
counts count/hp scaling correctly); crop-eating gives the player nothing;
ore-tick selection falls back to the crawler when the def is missing; new
spawns are difficulty- and day-gated and conservative. The smoke restores every
world cell it touches so later global scans (FQ-12 farm count) are unaffected.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq13_enemy_variety.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq13_enemy_variety.json`

## Git Closeout

Implementation commit `7d5ea9d` (data, world/simple_threat/game_root code,
validator, smoke, docs), then this evidence-only commit. Pushed to origin/main
per operator instruction ("push and proceed").

## Remaining Risks

- Enemy art is the family-tinted drawn-rect fallback; per-enemy sprites for
  thornrat/ore_tick/raider_torchbearer are optional assets pending in
  `docs/ASSET_ROADMAP.md` (validator INFO, fallbacks active).
- Combat/spawn tuning (damage, hp_mult, hall_dps_mult 2.5, spawn chances and
  day thresholds) is data-tunable in `enemies.json` and untested by human play.
- The thornrat only eats crops within `CROP_SEEK_CELLS`; it does not path across
  the map to distant farms, and it ignores `farm_soil` (eats the crop, not the
  tilled tile). hp remains a shared baseline scaled by `hp_mult` — enemies do
  not carry fully independent hp curves.

## Next Action

FQ-14 (goal panel, tutorial prompts, and playtest checklist). Enemy sprites
continue via `docs/ASSET_ROADMAP.md`.
