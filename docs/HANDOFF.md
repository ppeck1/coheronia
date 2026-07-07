# Coheronia - Handoff

## Current State

**FQ-02 (background trees and pass-through flora) implemented and closed out** (run `20260706_coheronia_fq02_background_trees`; lineage: v0.1 oneshot -> input repair -> v0.2 -> v0.3 -> `20260702_coheronia_v04_shell` -> `20260703_coheronia_v05_increment` -> `20260704_coheronia_v06_increment` -> FQ-00 -> FQ-01; Godot 4.6.1 stable).

v0.6 executed the six waves of `docs/WORK_ORDER_V0_6_CHARACTER_INVENTORY_WORLD_TOOLS.md` in three implementation commits (A/D, B/C, E/F) plus closeout. FQ-00 (closeout repair), FQ-01 (player health loop), and FQ-02 (background trees) followed from `docs/FABLE_TASK_QUEUE.md`.

## FQ-02 Additions

- **Foreground/background tree split**: each tree site from the tree seed channel now becomes either a solid, mineable foreground `wood` column (unchanged 3-5 tall) or a pass-through background tree (4-7 trunk + small canopy) the player simply walks past. New config key `generation.tree_foreground_ratio` (0-1, default 0.4, world-builder slider "Solid Tree Ratio"); a foreground tree is forced after 2 consecutive background trees so wood supply stays meaningful.
- **Background visual layer**: `world.gd` renders `background_cells` (`bg_trunk`/`bg_canopy`, produced by `WorldGen.generate`) on a new `BackgroundFlora` TileMapLayer added before the `Blocks` layer, modulated with a dim cool tint. Its tileset has no physics and no occlusion layers, so background flora can never collide, block light, or shelter. Background cells are pure visuals: never in `cells`, never mineable/placeable/saved (deterministic from seed+config), never overwrite terrain/wood/bushes, and are cleared across the Town Hall footprint columns.
- **Preserved contracts**: mining frames (dirt 21 / wood 33 / stone 66; wood with axe 24), wood drops, axe preference, bush support/regrowth (bushes also skip background-occupied cells), save/load, player health loop — all unchanged and re-verified by smoke.

## v0.6 Additions

- **Wave A — ancestry details**: character creation shows a compact data-driven panel per ancestry (`scripts/data/ancestry_detail.gd`, pure `build_panel_text` used by UI and smoke): description, live player effects formatted from `player_effects` keys, tradeoffs, spawn band, biome affinity summary; non-live ancestries labeled "[Planned — not playable yet]". All 12 ancestries gained one-line `description` fields (validator-required).
- **Wave D — world builder clarity**: new `ui_help` section in `data/world_settings.json` (validator-required) with `axis_help` for all six difficulty axes, `gen_help` for generation sliders, and `preset_descriptions` with deviations; the create screen shows preset description/deviations, size dimensions from data, and one-line help under each slider.
- **Wave B — character-owned inventory**: carried state (inventory counts, hotbar slot, tool tiers) lives on the character record in `user://shell.json` (`carried_inventory`, `carried_slot`, `carried_tool_tiers` {pick, axe}, legacy `carried_tool_tier` alias, `items_granted`). World saves retired `player.inventory/selected_slot/tool_tier` and keep terrain, hall stockpile, time, threats, storms, base/settlement state, progression, player position and health, and summary. Role starter items grant once per character. F5 and Esc persist both world and carried state. No world save version bump (dropped keys tolerate `.get` defaults; `ACCEPTED_VERSIONS` still `["0.5", "0.4"]`).
- **Wave C — openable inventory**: new `toggle_inventory` action (I) opens a HUD panel listing all carried stacks plus a tool line; inventory and Town Hall panels are mutually exclusive; Esc closes open panels before falling through to save-and-exit.
- **Wave E — bush support rule**: `berry_bush` has `requires_support: true` (generic flag read by `world.gd`): mining the support breaks the bush with normal drops and schedules regrowth; the post-delta load sweep cleans unsupported bushes without granting items; regrowth re-schedules when support is missing.
- **Wave F — differentiated tools**: blocks gained `preferred_tool` (wood/berry_bush -> axe; stone/ore -> pick). The `craft_axe` recipe (4 wood + 2 stone, town_hall station) forges an axe via a second hall button, awarding `tool_crafted` XP. With an axe, axe-preferred blocks mine 1.4x faster; stone/ore and the tier-2 pick gate are untouched (baseline mining-frame assertions unchanged: dirt 21 / wood 33 / stone 66; wood with axe 24). Tool state persists as character-owned `{pick, axe}`.

## Explicit Decisions

- **Player XP/level stay world-owned in v0.6.** Carried inventory moved to the character, but `xp_totals`, `player_level`, `base_xp`, and `base_level` remain in the world save. Revisit if characters should level across worlds.
- **Legacy migration is conservative**: a pre-v0.6 character (no `carried_inventory` key) adopts the world save's player inventory/hotbar/pick tier once, then the character record is authoritative. Legacy `carried_tool_tier` maps to `{pick: N, axe: 0}` — the axe must still be crafted; nobody gets one free.
- Unsupported-bush cleanup during load grants no drops (avoids inventory changes on load); mining the support does grant drops (keeps the food loop fair).

## Validation Status

| Check | State | Evidence |
|---|---|---|
| Repo identity | PASS | `main...origin/main`; project_id `coheronia-game` |
| JSON/scaffold validator | PASS | `python scripts/validate_repo.py` covers v0.6 fields (descriptions, ui_help, requires_support, preferred_tool, craft_axe) |
| Capsule doctor | PASS | `public_repo` profile: healthy |
| Automated smoke | PASS 142/142 | waited Windows Godot process wrote `user://smoke_results.json` (122 v0.6 -> 134 FQ-01 -> 142 FQ-02) |

## Known Risks / Gotchas

- The Windows Godot GUI binary does not reliably run smoke through a direct headless invocation. Use `Start-Process -Wait` and verify `user://smoke_results.json`.
- The smoke run mutates the real `user://shell.json` profile; its tests create and delete their own characters/worlds. If a smoke run is killed mid-test, stray "Smoke"/"Legacy" test characters may remain in the shell.
- A character's backpack now follows them between worlds — dropping items "in a world" for another character is no longer possible (no ground-drop mechanic exists).
- Player position/health are still world-owned: entering a world last played by another character starts from that world's saved position/health with the entering character's inventory/tools/traits.
- The inventory panel is read-only; hotbar contents remain the fixed block set.
- Axe tiers stop at 1; only the pick has a tier-2 upgrade path.
- Raider pressure, XP pacing, and base-level thresholds remain untested by human play.
- FQ-02 changes the tree layout of regenerated terrain: worlds saved before FQ-02 will regenerate with some former solid trees now background flora. Terrain deltas still apply cleanly (they overlay regenerated cells), but a pre-FQ-02 "air" delta where a tree used to stand may sit oddly next to new background flora. Cosmetic only; no data loss.
- Background trees are intentionally not harvestable in this pass (no minimal hook was needed); revisit if a "clear background flora" action is ever wanted.

## Next Action

Use `docs/FABLE_TASK_QUEUE.md` as the active queue for future Fable/Claude Code increments. FQ-00 (v0.6.1 closeout repair), FQ-01 (player health loop, smoke 134/134), and FQ-02 (background trees and pass-through flora: foreground/background tree split, `tree_foreground_ratio`, `BackgroundFlora` layer, smoke 142/142) are complete; FQ-03 (equipment data model and character-owned gear slots) is next.

Operator playthrough of v0.6 (make two characters, swap between worlds, forge the axe, harvest a supported bush line, open the inventory panel). Then pick the next increment from:

- farming or plantable/regrowable food sources (bush support rule is the groundwork)
- research bench MVP (craft/survival/military domains — data validated)
- perk spending UI for one lane
- workbench/crafting menu consolidating hand/hall recipes
- more enemies from the MVP expansion order (thornrat, ore_tick, raider_torchbearer)
- axe tier 2 + tool durability, or character-owned XP migration
- underground-start generation for phase C deep ancestries

Recommended next product move: farming (plantable crops using `requires_support`) plus a compact crafting menu, then the research bench MVP.
