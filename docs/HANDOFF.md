# Coheronia - Handoff

## Current State

**FQ-06 (visual player skill tree navigator) implemented and closed out** (run `20260707_coheronia_fq06_skill_tree_navigator`; lineage: v0.1 oneshot -> input repair -> v0.2 -> v0.3 -> `20260702_coheronia_v04_shell` -> `20260703_coheronia_v05_increment` -> `20260704_coheronia_v06_increment` -> FQ-00 -> FQ-01 -> FQ-02 -> FQ-03 -> FQ-04 -> FQ-05; Godot 4.6.1 stable).

v0.6 executed the six waves of `docs/WORK_ORDER_V0_6_CHARACTER_INVENTORY_WORLD_TOOLS.md` in three implementation commits (A/D, B/C, E/F) plus closeout. FQ-00 (closeout repair), FQ-01 (player health loop), FQ-02 (background trees), FQ-03 (equipment model), FQ-04 (combat gear), FQ-05 (attunement), and FQ-06 (skill tree) followed from `docs/FABLE_TASK_QUEUE.md`.

## FQ-06 Additions

- **Perk node schema**: every node in `data/progression/perks.json` (7 lanes x 3) gained description, cost, grid position, and same-lane prerequisites (validator-enforced, unique ids). The **Miner lane is live**: `stone_recovery` (root, `mining_speed` x1.15 -> `effective_mine_speed`), with `deep_sense` and `tunnel_safety` as prerequisite-gated branches whose planning effect keys stay inert until ore-sensing/cave-hazard systems ship.
- **Perk economy**: one point per player level above 1 (`perk_points_total = player_level - 1`); spent points derive from purchased costs. `purchased_perks` is world-owned progression state (like XP/levels); unknown ids are dropped on load. `game_root.try_purchase_perk` gates on state ("purchased"/"available"/"locked" via prerequisites) and affordability, then recomputes combined effects onto the player — `mining_speed` multiplies, `attunement_bonus` adds into `max_attunement()` (the FQ-05 join point is now live code, awaiting a node that carries it).
- **Skill tree panel** (`scripts/ui/skill_tree_panel.gd`, K / `toggle_skills`): scrollable node canvas laid out from data positions, state-colored buttons with [OWNED]/[LOCKED] markers, an inspector (title, state, cost, effect, prerequisites, description), a learn button backed by real points, and the planned lanes listed. Mutually exclusive with the inventory/town panels; Esc closes it first in the chain.

## FQ-05 Additions

- **Attunement resource**: current pool world-saved next to health (pre-FQ-05 saves default to full); `player.max_attunement()` is computed live as base (`player_defaults.base_max_attunement` 50) + ancestry `attunement_bonus` + gear `attunement_bonus` sum, so modifiers can never go stale. Constant slow regen everywhere (`attunement_regen_per_sec` 2.0, scaled by ancestry `attunement_regen_mult`). New HUD bar directly under health.
- **First active use**: `attune_pulse` (R) releases a harmless light pulse — spends `attunement_pulse_cost` (15), gated by its own cooldown (1s), a lazy PointLight2D on the player fades over 4s. Insufficient attunement logs a message and spends nothing.
- **Data hooks**: ancestry `player_effects.attunement_bonus`/`attunement_regen_mult` (read by `apply_ancestry_effects`; no live ancestry sets them, so non-magic characters play exactly as before), equipment `effects.attunement_bonus` (summed like armor; `amulet_focus` is the first carrier, not yet acquirable in play), and a documented perk join point inside `max_attunement()`. Extension points written up in `docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md`.
- All five tuning keys live in `player_defaults` and are validator-required.

## FQ-04 Additions

- **Crude sword**: `sword_crude` (weapon slot, `attack_damage: 3`) forged at the Town Hall via the new `craft_sword` recipe (2 wood + 3 stone). `player.attack_damage()` returns the equipped weapon's damage (1 bare-handed) and feeds `_try_hit_threat` -> `threat.take_hit`, so a fresh slime (3 hp) dies to one sword strike instead of three punches.
- **Crude armor set**: `helmet_crude`/`torso_crude`/`feet_crude` (armor 1/2/1) forged in one craft via `craft_armor_set` (6 wood + 4 stone). `player.armor_total()` sums the `armor` effect over all equipped items; `take_damage` applies flat mitigation with a minimum 1-health chip per landed hit so armor can never grant immunity. Enemy contact damage, i-frames, collapse, and ancestry health modifiers are untouched.
- **Forge flow**: `town_hall.forge_sword`/`forge_armor` follow the forge_axe pattern (stockpile inputs via a shared `_consume_recipe_inputs` helper, occupancy guards on the weapon/torso slots, equip via `player.equip_item`); two new town-panel buttons with crafted-state refresh; XP via `tool_crafted`.
- **Visible state**: the toolbelt line shows "Weapon <name> · Armor N"; the inventory panel's EQUIPMENT section gained an "Attack N · Armor N" summary. Rings, amulet, and accessory remain inert slot-ready data.

## FQ-03 Additions

- **Equipment data surface**: new `data/equipment.json` defines 12 gear slots (weapon, axe, pickaxe, helmet, torso, feet, ring_1-4, amulet, accessory — each with `accepts` slot_type) and item defs with `slot_type` + `effects`: `pick_basic` (pick_tier 1), `pick_forged` (pick_tier 2), `axe_crude` (axe_tier 1), and the inert `ring_band`. Loaded by the `BlockRegistry` autoload with helper functions (slots, items, `item_fits_slot`, `normalize_equipment`, `pick_item_for_tier`/`axe_item_for_tier`). Validator enforces the slot list, required items, and slot_type coherence.
- **Authority model**: `player.tool_tier`/`axe_tier` remain the live mining authority — mining, `forge_pick`/`forge_axe`, and all prior smoke checks are untouched. Equipment is the persistence/display shape: `player.equipped_dict()` derives the pickaxe/axe slots from the live tiers (so display and saves can never drift from behavior); the 10 other slots live in `player.equipment` and are slot-ready data for FQ-04. `player.equip_item(slot, item)` validates slot/item fit; tool slots route to the tiers.
- **Character-owned persistence**: character records gain an `equipment` dict (new characters: `pick_basic` + 11 empty). `save_character_carried` gained an optional 5th equipment param (`{}` = leave stored gear untouched, keeping legacy 4-arg callers safe); `save_manager.save_game` passes `player.equipped_dict()`. Both carried-state load paths apply the dict; pre-FQ-03 characters keep tiers/inventory and gain gear on migration/first save. Backpack inventory stays fully separate from equipped gear.
- **Minimal UI**: the inventory panel (I) gained a read-only EQUIPMENT section listing all 12 slots with item names or `(empty)`.

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
| Automated smoke | PASS 169/169 | waited Windows Godot process wrote `user://smoke_results.json` (122 v0.6 -> 134 FQ-01 -> 142 FQ-02 -> 149 FQ-03 -> 157 FQ-04 -> 163 FQ-05 -> 169 FQ-06) |

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
- Equipment UI remains read-only (`player.equip_item` is the API; no drag/drop). Rings, amulet, and accessory still have no live effects; ring_band exists only for the round-trip smoke.
- FQ-04 armor is flat mitigation with a 1-health minimum chip; there is no unequip flow for forged gear in play (forge guards prevent duplicates). Combat feel (sword damage 3, armor total 4 vs slime 8) is untested by human play; all numbers are data-tunable in `data/equipment.json`.
- FQ-05 attunement has exactly one use (the light pulse); no live ancestry or acquirable gear modifies it yet — the hooks are data-ready and smoke-proven but dormant. The pulse light is cosmetic (does not affect `light_score`, night spawns, or occlusion safety math).
- FQ-06: only the Miner lane's `mining_speed` effect is live; `detect_ore_range`, `cave_safety`, and all non-miner lane effect keys are inert data awaiting their systems. There is no perk refund/respec. Perk points come only from player levels; XP pacing (100 x 1.35^n) means points arrive slowly — untested by human play.
- A hypothetical pick tier above 2 has no matching equipment item; the gear shape would record the highest defined pick (`pick_forged`) while the live tier is preserved in `carried_tool_tiers`. No real character can exceed tier 2 today (forge caps at 2).

## Next Action

Use `docs/FABLE_TASK_QUEUE.md` as the active queue for future Fable/Claude Code increments. FQ-00 through FQ-06 are complete (FQ-06: data-complete perk node schema, level-derived perk points, live Miner lane, K-key skill tree panel with locked/available/purchased states, world-saved purchases, smoke 169/169); FQ-07 (visual asset pipeline with color fallback) is next.

Operator playthrough of v0.6 (make two characters, swap between worlds, forge the axe, harvest a supported bush line, open the inventory panel). Then pick the next increment from:

- farming or plantable/regrowable food sources (bush support rule is the groundwork)
- research bench MVP (craft/survival/military domains — data validated)
- perk spending UI for one lane
- workbench/crafting menu consolidating hand/hall recipes
- more enemies from the MVP expansion order (thornrat, ore_tick, raider_torchbearer)
- axe tier 2 + tool durability, or character-owned XP migration
- underground-start generation for phase C deep ancestries

Recommended next product move: farming (plantable crops using `requires_support`) plus a compact crafting menu, then the research bench MVP.
