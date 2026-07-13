# Run Ledger: 20260713_coheronia_fq11_station_chain

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
| Queue Item | FQ-11 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-13T17:20:00-04:00 |
| Ended At | 2026-07-13T18:20:00-04:00 |

## User Request

"proceed" — continue the queue after FQ-10. Executed the queue head FQ-11
(workbench / furnace / anvil station chain).

## What Shipped (implementation commit `fcd5f8e`)

- **Three buildable stations** (`data/recipes.json` `stations`): workbench ->
  furnace -> anvil, each with a `prereq` and a `build_cost`. Built state
  (`stations_built`) is Town Hall settlement state, saved in to_dict/from_dict
  (pre-FQ-11 saves default to nothing built). `town_hall.build_station` gates
  on prerequisite + stockpile affordability.
- **Unified `town_hall.craft_station`**: inputs from the stockpile; outputs
  route by recipe — smelted ingots (`output_to: stockpile`) stay in the
  stockpile, anvil gear (`equip_slots`) equips onto the player with an
  empty-slot + fit check BEFORE inputs are consumed, everything else to
  inventory. `BlockRegistry` gained `station_defs`/`station_def`/
  `recipes_for_station`.
- **Metallurgy chain**: furnace smelts raw ore + coal into copper/tin/iron/
  silver ingots and alloys bronze; anvil forges iron gear (`sword_iron`
  attack 5, iron helm/cuirass/boots) from ingots. Metal gate: no recipe turns
  raw ore into gear. Crude wood/stone gear (town_hall) unchanged. New ores +
  coal are depositable; ingots are new `items.json` entries; iron gear is new
  in `equipment.json`; the workbench hosts `workbench_torch_bundle`.
- **UI** (`hud.gd`): a data-driven, scrollable station section in the Town
  Hall panel (build buttons + per-station recipe buttons), rebuilt each
  refresh, wired via `game_root` (`build_station_requested`/
  `craft_station_requested`).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0; incl. "station chain and metal gate" |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 269/269 | 7 new `fq11_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 7 `fq11_*` checks: station gating (recipes locked until built; no build
before prerequisite); the workbench -> furnace build chain spending costs;
furnace smelting (iron_ore + coal -> iron_ingot in the stockpile, not
inventory); anvil forging the iron sword from ingots (equipped, attack 5);
the metal gate (raw ore alone cannot forge the sword); the bronze alloy
(copper + tin ingots -> bronze); and `stations_built` round-tripping through
save/load.

## Acceptance vs FQ-11

- Player cannot use raw ore directly for metal gear. [done — metal gate,
  validator- and smoke-enforced]
- Furnace consumes ore + fuel and produces an intermediate. [done — smelt
  recipes: ore + coal -> ingot to stockpile]
- Anvil consumes intermediates and creates a tool/gear item. [done —
  anvil_iron_sword / anvil_iron_armor from ingots]
- Station state saves/loads. [done — stations_built in to_dict/from_dict,
  smoke round-trip]

## Review

Self-reviewed the diff (no agent spawned). Verified: equip occupancy + fit
checks run BEFORE inputs are consumed (a full slot or data regression cannot
eat the stockpile — mirrors the FQ-04 forge guards); station gating blocks
recipes and builds correctly; ingots stay in the stockpile (never leak to
inventory); the metal gate has no ore->gear path; pre-FQ-11 saves migrate
(nothing built); no world-gen or block-placement change. The town-panel
station buttons render (visual check of the panel confirmed no layout break).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260713_coheronia_fq11_station_chain.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260713_coheronia_fq11_station_chain.json`

## Git Closeout

Implementation commit `fcd5f8e` (data, town_hall/hud/game_root/block_registry
code, validator, smoke, docs), then this evidence-only commit.

## Remaining Risks

- The station section sits below the existing forge buttons in a scrollable
  panel, so build/craft buttons can be below the fold — a future UI pass could
  tab/reorganize. Visual review confirmed the panel renders without breakage
  but the shots tour captures it unscrolled.
- Ingot economy and iron-gear balance (sword_iron 5 vs crude 3; iron armor
  2/4/2) are data-tunable and untested by human play.
- Ingots and built stations are settlement/save state only; no new world-gen
  or placement.

## Next Action

FQ-12 (farming and food stability) — plantable/regrowable crops on the
`requires_support` groundwork. Art backlog (ore/ingot/iron-gear icons)
continues via `docs/ASSET_ROADMAP.md`.
