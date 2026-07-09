# Coheronia - Handoff

## Current State

**FQ-09R (review hardening: unified trees, creation-rule clarity) implemented and closed out** (run `20260709_coheronia_fq09r_review_hardening`; lineage: v0.1 oneshot -> input repair -> v0.2 -> v0.3 -> `20260702_coheronia_v04_shell` -> `20260703_coheronia_v05_increment` -> `20260704_coheronia_v06_increment` -> FQ-00 through FQ-08; Godot 4.6.1 stable).

v0.6 executed the six waves of `docs/WORK_ORDER_V0_6_CHARACTER_INVENTORY_WORLD_TOOLS.md` in three implementation commits (A/D, B/C, E/F) plus closeout. FQ-00 through FQ-09 followed from `docs/FABLE_TASK_QUEUE.md`.

## FQ-09 Additions

- **Toolbelt**: five slot tiles (icon + count + numbered tooltip) with a gold border on the selected slot. Icons come from `BlockRegistry.item_icon` — FQ-07 art when present, else a generated color swatch (`data/items.json` color, else a stable hash-derived hue) — so every slot always reads visually. The text line below keeps the extras + tool/gear summary.
- **Inventory panel**: a 6-column icon grid of stacks (count under each tile, display name + descriptor on hover) sits above the existing text block, which is unchanged so all prior panel assertions still hold.
- **Town Hall panel**: the stockpile text list became an icon grid; station buttons carry item icons; disabled/crafted states keep the engine dimming plus the existing state text.
- **`data/items.json` (new)**: display names, descriptions, and swatch colors for non-block item ids (food, drops, forge icons) plus icon colors for block items. `BlockRegistry.display_name` now falls back blocks -> items.json -> id, improving every log/tooltip surface.
- Keyboard/mouse behavior unchanged: I toggles inventory, hotbar keys 1-5 select, E/T town panel, K skills — all pre-existing bindings and the Esc chain untouched.

## FQ-09R Additions

- **Unified tree rule (replaces the FQ-02 split)**: every generated tree is now a `tree_trunk` column (3-5 tall, wood hardness 0.55, axe-preferred, drops 1 wood per cell) topped by a `tree_leaves` canopy (3x2, fast to clear, no drops). Both blocks are non-solid and non-placeable: the player walks in front of/past every tree with no collision, and harvests any tree through the existing mining/axe path. There is no walkable-but-not-harvestable tree class anymore.
- **Retired FQ-02 surfaces**: `background_cells`, the `BackgroundFlora` TileMapLayer, `bg_trunk`/`bg_canopy`, `WorldGen._grow_background_tree`, `world.background_at`, and the `generation.tree_foreground_ratio` config key + "Solid Tree Ratio" world-builder slider are all removed. Trees live in `cells` like any block: regenerated from seed+config, mined cells persist as normal `air` deltas, and the Town Hall stamp clears its footprint. Placed `wood` blocks are untouched (still solid, buildable, roof/shelter material).
- **Creation-rule clarity**: the character create form states that backpack, tools, equipment, ancestry, role, and traits follow the character between worlds, role starter items are granted once, and collapse loses a fraction of carried stacks (wording matches the live destroy-not-drop behavior). The world create form states that terrain, stockpile, threats, storms, base level, player level, position, and current health belong to the world, and that entering with another character uses that character's carried gear. No future mechanics are implied.
- **Smoke**: the 8 `fq02_*` checks are replaced by 8 `fq09r_*` checks (suite total unchanged at 183); the wood mining/axe baselines now harvest `tree_trunk` (same hardness, same wood drop, same frame expectations).
- **Skill tree direction**: FQ-09S should be a presentation-only pass: Skyrim-style constellation/star-map vibes with 8-16bit readability, using the existing perk data, point economy, Miner lane, K/Esc behavior, and `try_purchase_perk` purchase path.

## FQ-08 Additions

- **Block damage stages**: `player.mine_damage_stage()` (0-3 from mining progress) drives a crack overlay drawn on the target cell while mining — deterministic per cell (seeded from the target, no flicker), denser cracks per stage, layered over the existing highlight/progress bar. Purely transient: never enters `cells`/deltas/saves, resets via the existing `_reset_mining` on target change or release, and `apply_state` now clears in-memory progress so a load can never resurrect partial damage.
- **Crack sprite mask (post-FQ-09R hardening)**: crack segments are rasterized pixel by pixel through `world.block_opaque_mask(block_id)` — a cached BitMap of the tile texture's opaque pixels (art or generated fallback) — so degradation never draws outside the visible sprite: a thin `tree_trunk` bar, leaves, a bush, or a torch only crack where their pixels actually are. Solid tiles are fully opaque, so their crack layout is unchanged. The same principle already held elsewhere: the Town Hall damage overlay covers exactly its drawn wall rect, and enemy hurt tints ride the sprite/fallback shape.
- **Enemy hurt feedback**: a mini health bar appears above any damaged enemy (both the FQ-07 art path and the drawn-rect fallback, which also keep their tint/lighten cues); `health_bar_ratio()` exposes the fill. Damage is clearly visible well before death.
- Drops, mining frame counts, and save/load behavior are untouched — verified by dedicated checks plus the unchanged legacy baselines.

## FQ-07 Additions

- **Image-first rendering with safe fallback**: `BlockRegistry.visual_texture(category, id)` resolves `data/visual_assets.json` explicit entries or the `art/generated/<category>/<id>.png` convention, loading via `Image.load_from_file` (no editor import pass — plain runs pick up new art immediately, matching how this repo is always run). Misses are cached as null and every render site keeps its existing generated look: `world._make_block_texture` (blocks, with nearest-neighbor resize to tile size), `simple_threat._draw` (enemies, hurt tint preserved via modulate), and a new 5-slot hotbar icon strip (items; icons hidden without art, so the text hotbar stays the fallback).
- **Asset workflow docs**: `art/source_templates/ASSET_TEMPLATE.md` — naming rules (data ids, lowercase snake_case), target sizes (16px blocks/items/enemies, 32px ui), prompt skeletons for local Ollama/image-model iteration (which stays entirely outside the game and validation), and a review checklist for one-by-one art passes.
- **Validator policy**: broken explicit `visual_assets.json` references fail; convention-path gaps print INFO lines and never fail — art arrives incrementally.
- The repo ships zero art: everything renders from fallbacks today, and the smoke proves both directions (image wins when present, fallback returns when removed) with self-cleaning temp files.

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

## FQ-02 Additions (superseded by FQ-09R)

- FQ-02 introduced a foreground/background tree split: solid mineable `wood` columns vs. pass-through `bg_trunk`/`bg_canopy` visuals on a separate `BackgroundFlora` layer, controlled by `generation.tree_foreground_ratio`. **FQ-09R replaced this split with one unified tree rule** (see FQ-09R Additions); the background layer, ratio key, and slider no longer exist.
- Still true from FQ-02: trees generate on their own seed channel, tree density is world-builder controlled, and mining frame contracts (dirt 21 / trunk-at-wood-hardness 33 / stone 66; with axe 24) plus wood drops, axe preference, bush support/regrowth, and save/load were preserved through both passes.

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
| Automated smoke | PASS 184/184 | waited Windows Godot process wrote `user://smoke_results.json` (122 v0.6 -> 134 FQ-01 -> 142 FQ-02 -> 149 FQ-03 -> 157 FQ-04 -> 163 FQ-05 -> 169 FQ-06 -> 173 FQ-07 -> 179 FQ-08 -> 183 FQ-09 -> 183 FQ-09R -> 184 crack mask) |

## Known Risks / Gotchas

- The Windows Godot GUI binary does not reliably run smoke through a direct headless invocation. Use `Start-Process -Wait` and verify `user://smoke_results.json`.
- The smoke run mutates the real `user://shell.json` profile; its tests create and delete their own characters/worlds. If a smoke run is killed mid-test, stray "Smoke"/"Legacy" test characters may remain in the shell.
- A character's backpack now follows them between worlds — dropping items "in a world" for another character is no longer possible (no ground-drop mechanic exists).
- Player position/health are still world-owned: entering a world last played by another character starts from that world's saved position/health with the entering character's inventory/tools/traits.
- The inventory panel is read-only; hotbar contents remain the fixed block set.
- Axe tiers stop at 1; only the pick has a tier-2 upgrade path.
- Raider pressure, XP pacing, and base-level thresholds remain untested by human play.
- FQ-09R changes the tree layout of regenerated terrain (as FQ-02 did before it): worlds saved earlier regenerate with unified `tree_trunk`/`tree_leaves` trees where solid wood columns or background flora used to stand. Terrain deltas still apply cleanly (they overlay regenerated cells); an old "air" delta where a tree used to stand may sit oddly next to new trees. Cosmetic only; no data loss. Old world configs may still carry a stored `tree_foreground_ratio` key; it is simply ignored.
- Generated trees no longer contribute to shelter/roof/occlusion math (trunk and leaves are non-solid and do not block light); only placed solid blocks such as `wood` do. Wood supply per tree site rose slightly (every tree is now harvestable), untested by human play.
- Mining a low trunk cell leaves the upper trunk/canopy cells floating (no support rule on trees, mirroring the old floating wood columns). Cosmetic; each floating cell remains harvestable.
- Equipment UI remains read-only (`player.equip_item` is the API; no drag/drop). Rings, amulet, and accessory still have no live effects; ring_band exists only for the round-trip smoke.
- FQ-04 armor is flat mitigation with a 1-health minimum chip; there is no unequip flow for forged gear in play (forge guards prevent duplicates). Combat feel (sword damage 3, armor total 4 vs slime 8) is untested by human play; all numbers are data-tunable in `data/equipment.json`.
- FQ-05 attunement has exactly one use (the light pulse); no live ancestry or acquirable gear modifies it yet — the hooks are data-ready and smoke-proven but dormant. The pulse light is cosmetic (does not affect `light_score`, night spawns, or occlusion safety math).
- FQ-06: only the Miner lane's `mining_speed` effect is live; `detect_ore_range`, `cave_safety`, and all non-miner lane effect keys are inert data awaiting their systems. There is no perk refund/respec. Perk points come only from player levels; XP pacing (100 x 1.35^n) means points arrive slowly — untested by human play.
- FQ-07: art loads bypass the Godot import system (`Image.load_from_file`) by design for plain non-editor runs — an exported build would need an import-aware path (out of scope; this repo never exports). The block tileset reads art at `world.setup`/tileset-build time; dropping in new art requires re-entering the world (no hot-reload). Player/hall visuals are still drawn shapes (not yet image-capable; extend when their art lands).
- A hypothetical pick tier above 2 has no matching equipment item; the gear shape would record the highest defined pick (`pick_forged`) while the live tier is preserved in `carried_tool_tiers`. No real character can exceed tier 2 today (forge caps at 2).

## Next Action

Use `docs/FABLE_TASK_QUEUE.md` as the active queue for future Fable/Claude Code increments. FQ-00 through FQ-09 plus FQ-09R are complete. Next is FQ-09S for the skill tree visual treatment pass, then FQ-09V/FQ-09A/FQ-09M for deterministic visual variants, the future asset roadmap/prompt packs, and lightweight action animation. FQ-10 (more ores and metallurgy data) should wait until those presentation-foundation items are closed or the operator explicitly changes priority.

Operator playthrough of v0.6 (make two characters, swap between worlds, forge the axe, harvest a supported bush line, open the inventory panel). Then pick the next increment from:

- farming or plantable/regrowable food sources (bush support rule is the groundwork)
- research bench MVP (craft/survival/military domains — data validated)
- perk spending UI for one lane
- workbench/crafting menu consolidating hand/hall recipes
- more enemies from the MVP expansion order (thornrat, ore_tick, raider_torchbearer)
- axe tier 2 + tool durability, or character-owned XP migration
- underground-start generation for phase C deep ancestries

Recommended next product move: farming (plantable crops using `requires_support`) plus a compact crafting menu, then the research bench MVP.
