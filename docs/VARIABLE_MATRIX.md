# Coheronia - Variable Matrix

State: audited against FQ-09R run `20260709_coheronia_fq09r_review_hardening`.

## Authority Surfaces

| Surface | Authority | Consumed by |
|---|---|---|
| Blocks | `data/blocks.json` | `BlockRegistry`, `world`, `player`, `settlement_model`, `hud` |
| Recipes | `data/recipes.json` | `player`, `town_hall` |
| Settlement formulas | `data/settlement_rules.json` | `settlement_model.gd` via Godot `Expression` |
| World settings | `data/world_settings.json` | `WorldConfig`, shell UI, world generation, gameplay systems |
| Character data | `data/character_data.json` | shell UI, `player.apply_character`, role item grant |
| Equipment (FQ-03) | `data/equipment.json` | `BlockRegistry` equipment helpers -> `player` gear API, `hud` panel, `game_root` carried-state load, `save_manager` |
| Visual assets (FQ-07) | `data/visual_assets.json` + `art/generated/<category>/<id>.png` convention | `BlockRegistry.visual_texture` -> `world._make_block_texture` (blocks), `simple_threat._draw` (enemies), `hud` toolbelt/grids (items via `item_icon`); missing images always fall back to generated colors/shapes; loaded via `Image.load_from_file` (no editor import pass needed); explicit json entries validator-fail when broken, convention gaps are INFO-only |
| Item metadata (FQ-09) | `data/items.json` | `BlockRegistry.display_name` fallback chain (blocks -> items.json -> id), `item_description` (tooltips), `item_fallback_color` -> `item_icon` swatches for the FQ-09 icon grids; unknown ids get a stable hash-derived hue |
| Enemies | `data/enemies.json` | `enemy_registry.gd` -> `game_root` spawn paths, `simple_threat` drops |
| Ancestries | `data/ancestries.json` | `ancestry_registry.gd` -> `player.apply_ancestry_effects`, shell create form |
| Progression | `data/progression/*.json` | `progression_registry.gd` -> XP awards, base levels, HUD |
| Shell profile + character-carried state | `user://shell.json` | `GameState`, `game_root` carried-state load/apply |
| World files | `user://worlds/<id>.json` | `GameState`, `SaveManager`, shell world list |
| Shell UI help text | `data/world_settings.json` `ui_help` | shell create screen (axis/gen/preset help) |
| Ancestry detail text | `scripts/data/ancestry_detail.gd` `build_panel_text` | shell create form, smoke |

All registries load through `scripts/data/json_data.gd` (`load_dict`, push_error + `{}` on failure).

## v0.6 Ownership Boundary

| State | Owner | Notes |
|---|---|---|
| Inventory counts, hotbar slot, tool tiers {pick, axe} | character (`user://shell.json`) | `carried_inventory`, `carried_slot`, `carried_tool_tiers`, legacy `carried_tool_tier` alias |
| Gear slots (FQ-03) | character (`user://shell.json`) | `equipment` dict (12 slot_id -> item_id, "" = empty); pickaxe/axe slots are derived from the live tool tiers at save time; the other 10 slots are slot-ready data for FQ-04; pre-FQ-03 characters gain the dict on first save/migration |
| Role starter items | character | `items_granted` flag; granted once per character |
| Terrain, hall stockpile, time, threats, storms, settlement | world file | unchanged |
| Player position, health | world file | entering character inherits world position/health |
| XP totals, player level, base level/XP | world file | explicit v0.6 decision; revisit for cross-world leveling |
| Legacy migration | one-time | character without `carried_inventory` adopts world save's player keys once; legacy tool tier -> {pick: N, axe: 0} |

## World Config Matrix

| Config key | Consumed by | Effect |
|---|---|---|
| `size` | `WorldConfig.size_dims`, `WorldGen.generate`, `world.world_bounds`, camera limits | small 160x64, medium 240x80, large 360x100 |
| `seed` | `WorldGen.generate` | deterministic base terrain |
| `generation.terrain_amplitude` | `WorldGen.generate` | surface height variation |
| `generation.terrain_frequency` | `WorldGen.generate` | surface noise frequency |
| `generation.dirt_depth` | `WorldGen.generate` | dirt layer depth before stone/ore |
| `generation.ore_abundance` | `WorldGen.generate` | ore threshold; 0 disables ore |
| `generation.ore_seed_offset` | `WorldGen.generate` | independent ore layout channel |
| `generation.tree_density` | `WorldGen.generate` | tree site frequency; 0 disables trees. FQ-09R: every site grows one unified tree (`tree_trunk` column + `tree_leaves` canopy), walk-past and harvestable. The FQ-02 `tree_foreground_ratio` key/slider is removed (stored copies in old world configs are ignored) |
| `generation.tree_seed_offset` | `WorldGen.generate` | independent tree channel |
| `generation.bush_density` | `WorldGen.generate` | berry bush frequency; 0 disables bushes |
| `generation.bush_seed_offset` | `WorldGen.generate` | independent bush channel |
| `difficulty.enemy` | `night_spawn_count`, `threat_hp`, threat `hall_dps` | night threat count, hp, hall damage |
| `difficulty.ruler` | `settlement_model.gather_inputs` | population pressure multiplier |
| `difficulty.survival` | `daily_food_need` | food demand multiplier |
| `difficulty.economy` | `settlement_model.gather_inputs` | stockpile/scarcity scaling |
| `difficulty.social` | stored only | reserved for social simulation |
| `difficulty.impressionability` | `growth_threshold` | lower threshold means easier population growth |
| `environment_danger` | storm roll and storm dps | storm frequency/damage multiplier |
| `rules.subjects_require_food` | food consumption, starvation, scarcity, growth gate | disables/enables food pressure |
| `rules.weather_affects_survival` | storm roll and `force_storm` | disables/enables storms |
| `rules.lighting_affects_safety` | `night_spawn_count` | torch light can reduce night spawns |
| `rules.darkness_increases_enemies` | night spawns and threat severity | disables/enables night threats |
| `rules.enemies_scale_over_time` | `threat_hp` | threat hp grows with day count |
| future rule toggles | persisted only | sleep, sickness, morale, loyalty, rebellion, ruler pressure growth, scarcity growth |

## Character Matrix

| Character key | Authority | Consumed by | Effect |
|---|---|---|---|
| `name` | shell create form / `shell.json` | shell lists | display identity |
| `species` | `character_data.json` + `ancestries.json` | shell create form, `game_root.apply_ancestry_for_species` | live phase B ancestries: human, dwarf, elf, goblin, orc; effects re-derived from data at world entry |
| `appearance` | `character_data.json` | `player.apply_character` | body/trim draw colors |
| `traits` | `character_data.json` | `player.apply_character` | max health, mining speed, reach, food bonus, growth delta |
| `role` | `character_data.json` | role grant and `player.apply_character` | starting items and role effects |

## FQ-01 Player Defaults (Health, Healing, Collapse)

| Variable | File / Field | Default | Effect |
|---|---|---|---|
| `base_max_health` | `data/character_data.json` `player_defaults.base_max_health` | 100 | base max health before trait/role/ancestry bonuses (`player._base_max_health`) |
| `hurt_cooldown_sec` | `data/character_data.json` `player_defaults.hurt_cooldown_sec` | 0.8 | i-frame window after `take_damage`; blocks re-damage until it expires |
| `food_heal_amount` | `data/character_data.json` `player_defaults.food_heal_amount` | 25 | health restored per food eaten (clamped to max_health) |
| `eat_cooldown_sec` | `data/character_data.json` `player_defaults.eat_cooldown_sec` | 0.5 | minimum time between `eat_food` actions |
| `passive_regen_per_sec` | `data/character_data.json` `player_defaults.passive_regen_per_sec` | 1.0 | health/sec regenerated near the Town Hall when safe |
| `safe_radius_px` | `data/character_data.json` `player_defaults.safe_radius_px` | 160 | distance from hall center within which passive regen can trigger |
| `collapse_loss_fraction` | `data/character_data.json` `player_defaults.collapse_loss_fraction` | 0.25 | fraction (floored per stack) of carried inventory lost on collapse (health reaching 0) |
| `low_health_fraction` | `data/character_data.json` `player_defaults.low_health_fraction` | 0.25 | health/max_health ratio below which the HUD tints red and logs "You are badly hurt." once per crossing |

All eight keys are read once via `player._load_player_defaults()` from `BlockRegistry.character_data["player_defaults"]` (same JSON-load pattern as traits/roles/appearances); missing keys fall back to the `DEFAULT_*` consts in `player.gd`.

## FQ-05 Attunement (Player Magic Resource)

| Variable | File / Field | Default | Effect |
|---|---|---|---|
| `base_max_attunement` | `player_defaults.base_max_attunement` | 50 | base of the computed `player.max_attunement()` |
| `attunement_regen_per_sec` | `player_defaults.attunement_regen_per_sec` | 2.0 | constant regen everywhere (no safety gate), scaled by ancestry `attunement_regen_mult` |
| `attunement_pulse_cost` | `player_defaults.attunement_pulse_cost` | 15 | attunement spent per light pulse (`attune_pulse` action, R) |
| `attunement_pulse_cooldown_sec` | `player_defaults.attunement_pulse_cooldown_sec` | 1.0 | pulse re-cast gate |
| `attunement_pulse_duration_sec` | `player_defaults.attunement_pulse_duration_sec` | 4.0 | pulse light fade time |
| `player.attunement` | `player.gd` / world save (`player.attunement`) | full | current pool; world-saved next to health; pre-FQ-05 saves default to full |
| `player.max_attunement()` | `player.gd` (computed) | 50 | base + ancestry `attunement_bonus` + gear `attunement_bonus` sum; perks join here at FQ-06 |
| `attunement_bonus` / `attunement_regen_mult` | `data/ancestries.json` `player_effects` (hooks; no live ancestry sets them yet) + `data/equipment.json` item effects (`amulet_focus` = +10) | 0 / 1.0 | ancestry additive max + regen multiplier; gear additive max |

Extension points documented in `docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md` ("Attunement Extension Points"). A non-magic character never spends or needs attunement; nothing existing is gated by it.

### Health, Healing, And Collapse

Two healing sources are wired in FQ-01: **eat food** (active, bound to the `eat_food` input action — key H — consumes 1 food from the inventory for an instant `food_heal_amount` heal, no-op at full health or during its own cooldown) and **safe passive regen** (near the Town Hall center within `safe_radius_px` and clear of any "threats" group node within 200px, health trickles back at `passive_regen_per_sec`; logs "You feel safe near the Town Hall and begin to recover." once per regen streak). Damage still gates through the existing `hurt_cooldown_sec` i-frame window and flashes the player sprite red for ~0.2s. Reaching 0 health triggers a **collapse**: each carried inventory stack loses `floor(count * collapse_loss_fraction)` (deterministic, per stack) before the player respawns at the Town Hall at full health, with the log message "You collapsed and awoke near the Town Hall. Some of your supplies were lost." Crossing below `low_health_fraction` of max_health logs "You are badly hurt." once per crossing and tints the HUD health bar/label; it resets when health rises back above the threshold.

## Core Gameplay Variables

| Variable | Type | Authority | Notes |
|---|---|---|---|
| `tile_size` | int | `data/blocks.json` | 16 px |
| `block_id` | string | `data/blocks.json` | dirt, grass, wood, stone, ore, tree_trunk, tree_leaves, berry_bush, torch, lantern, town_hall_core, air |
| `tree_trunk` / `tree_leaves` | blocks | `data/blocks.json` | FQ-09R unified trees: both non-solid (walk in front of/past, no occlusion) and non-placeable; trunk = wood hardness 0.55, axe-preferred, drops 1 wood; leaves = hardness 0.15, no drops. Generated into `cells` like any block; mined cells persist as normal `air` deltas |
| `hardness` | float | `data/blocks.json` | mining time input |
| `required_tool_tier` | int | `data/blocks.json` | ore requires tier 2 (pick tier) |
| `preferred_tool` | string | `data/blocks.json` | axe: wood, berry_bush; pick: stone, ore; axe-preferred mine 1.4x faster with an axe |
| `requires_support` | bool | `data/blocks.json` | berry_bush; enforced on mine, load sweep, and regrowth |
| `axe_tier` | int | `player.gd` / character-carried | 0 = no axe; `craft_axe` recipe (4 wood + 2 stone, town_hall) sets 1 |
| `equipment` (slots) | data | `data/equipment.json` | FQ-03: 12 slots (weapon, axe, pickaxe, helmet, torso, feet, ring_1-4, amulet, accessory) with `accepts` slot_type; validator-enforced |
| `equipment` (items) | data | `data/equipment.json` | item defs {display_name, slot_type, description, effects}; live: pick_basic (pick_tier 1), pick_forged (pick_tier 2), axe_crude (axe_tier 1), sword_crude (attack_damage 3), helmet_crude/torso_crude/feet_crude (armor 1/2/1); inert: ring_band |
| `attack_damage` | int effect | `data/equipment.json` -> `player.attack_damage()` | FQ-04: melee damage per hit from the equipped weapon; 1 bare-handed; consumed by `_try_hit_threat` -> `threat.take_hit` |
| `armor` | int effect | `data/equipment.json` -> `player.armor_total()` | FQ-04: flat incoming-damage reduction summed over ALL equipped items (helmet/torso/feet today); applied in `take_damage` with a minimum 1-health chip per landed hit |
| `craft_sword` / `craft_armor_set` | recipes | `data/recipes.json` | FQ-04: town_hall station, empty outputs; consumed by `town_hall.forge_sword`/`forge_armor` which equip gear via `player.equip_item` (guards: weapon/torso slot must be empty) |
| `player.equipment` | dictionary | `player.gd` / character-carried | slot_id -> item_id for the 10 non-tool slots; `equipped_dict()` merges in pickaxe/axe derived from live tiers; `equip_item(slot, item)` validates fit via `BlockRegistry.item_fits_slot`; tool slots cannot be cleared (tiers come from forging) |
| `drops` | dictionary | `data/blocks.json` | inventory additions on break |
| `is_placeable` | bool | `data/blocks.json` | placement gate |
| `is_solid` | bool | `data/blocks.json` | collision, shelter, roof, defense |
| `blocks_light` | bool | `data/blocks.json` | runtime occluder polygons |
| `emits_light` | bool | `data/blocks.json` | runtime `PointLight2D` nodes |
| `light_radius` | int | `data/blocks.json` | torch/lantern radius |
| `settlement_tags` | array | `data/blocks.json` | protected, defense |
| `world_seed` | int | world file state | deterministic terrain regen |
| `terrain_deltas` | dictionary | world file state | edits over regenerated terrain |
| `world.width/height` | int | `WorldConfig.size_dims` | replaces old constants |
| `surface` | dictionary | `WorldGen.generate` | top solid y per x |
| `hall_info` | dictionary | `WorldGen.stamp_town_hall` | center cell, ground y, protected core cells |
| `bush_regrow` | dictionary | `world.gd` / save | harvested bush timers |
| `player_position` | Vector2 | save state | restored after world rebuild |
| `player_health` | float | `player.gd` / save | HUD and threat damage |
| `player.max_health` | float | `player.gd` | `player_defaults.base_max_health` + trait/role/ancestry bonuses; recomputed by `apply_character`/`apply_ancestry_effects`, not persisted directly (derived at world entry) |
| `inventory_counts` | dictionary | `inventory.gd` / character-carried | stackable resource counts; travels between worlds |
| `selected_hotbar_slot` | int | `player.gd` / character-carried | slots 1-5 |
| `tool_tier` | int | `player.gd` / character-carried | pick tier alias; tier 2 unlocks ore and speed |
| `effective_mine_speed` | func | `player.gd` | tool tier, trait, and FQ-06 perk multiplier |
| `mine_damage_stage()` | func | `player.gd` | FQ-08: 0-3 from mining progress; drives the transient crack overlay drawn on the target cell; never saved; resets via `_reset_mining` (target change, release, and on load via `apply_state`) |
| `health_bar_ratio()` | func | `simple_threat.gd` | FQ-08: hp/max_hp fill for the mini hurt bar drawn above damaged enemies on both art and fallback paths |
| `reach_bonus` | float | character effects | extends mining/placement reach |
| `bush_bonus_food` | int | character effects | extra food from berry bushes |
| `growth_threshold_delta` | float | character effects | modifies settler growth threshold |
| `town_hall_stockpile` | dictionary | `town_hall.gd` / save | resources deposited at hall |
| `town_hall.damage` | float | `town_hall.gd` / save | 0-100 damage |
| `population_count` | int | `town_hall.gd` / save | dynamic 1-8 |
| `day_count` | int | `game_root.gd` / save | HUD day |
| `time_of_day` | float | `game_root.gd` / save | 0-1 over 100 seconds |
| `is_night` | bool | derived | night begins at 0.65 |
| `storm_active` | bool | `game_root.gd` / save | current storm state |
| `storm_time_left` | float | `game_root.gd` / save | countdown |
| `_storm_rolled_today` | bool | `game_root.gd` / save | prevents repeated daily storm rolls |
| `threats` | array | save state | saved/restored active threats: x, y, hp, max_hp, enemy_id; restored via `_spawn_enemy_at` |
| `meta.summary` | dictionary | world file | day, population, coherence, damage for shell list |

## v0.5 Enemy Variables

| Variable | Type | Authority | Notes |
|---|---|---|---|
| `enemy_id` / `family` | string | `data/enemies.json` | live: surface_slime (surface), cave_crawler (underground), raider_basic (raider) |
| `drops[].item_id` / `.chance` | array | `data/enemies.json` | rolled on death into player inventory |
| `spawn_rule` (raider) | dictionary | `data/enemies.json` | day_threshold 5, stockpile_threshold 25, base_chance 0.3 |
| `difficulty_scaling.density_mult` | float | `data/enemies.json` | multiplies night spawn count and raider chance |
| `difficulty_scaling.loot_mult` | float | `data/enemies.json` | multiplies drop chances |
| `loot_mult` / `drop_chance_override` | float | `simple_threat.gd` | per-instance; override is a test hook |
| `hall_dps` | float | `game_root._spawn_enemy_at` | raider Town Hall damage; survives save/load |
| `CAVE_SPAWN_INTERVAL` / cap | const | `game_root.gd` | 30s check, 2 active underground-family max |
| `contact_damage` | float | `data/enemies.json` (live enemies) -> `simple_threat.contact_damage` | player damage on contact; scaled by `difficulty("enemy")` at spawn (mirrors `hall_dps`); falls back to `PLAYER_DAMAGE` const if the def omits it |
| `speed` | float | `data/enemies.json` (live enemies) -> `simple_threat.move_speed` | horizontal chase speed; falls back to `SPEED` const if the def omits it |
| `hp` | int | `data/enemies.json` (live enemies) | data-completeness/validator field; runtime hp is still set from `game_root.threat_hp()` (difficulty + day scaling), not read from this field |

## FQ-06 Perk Variables

| Variable | Type | Authority | Notes |
|---|---|---|---|
| perk node schema | data | `data/progression/perks.json` | 7 lanes x 3 nodes; each node: id, display_name (title), description, effect_key, effect_value, cost, position [x,y], prerequisites (same-lane ids), xp_type_gate; validator-enforced |
| `purchased_perks` | Array[String] | `game_root.gd` / world save (`progression.purchased_perks`) | world-owned like XP/levels; unknown ids dropped on load (silent refund) |
| perk points | derived | `game_root.perk_points_total/spent/available` | one point per player level above 1; spent = sum of purchased costs |
| `perk_state(id)` | func | `game_root.gd` | "purchased" / "available" (prereqs owned) / "locked"; affordability gates only purchase |
| `player.perk_mine_speed_mult` | float | `game_root._apply_purchased_perk_effects` -> `player.apply_perk_effects` | live effect_key `mining_speed` (Miner lane); multiplies `effective_mine_speed` |
| `player.perk_attunement_bonus` | float | same | live effect_key `attunement_bonus`; the FQ-05 join point inside `max_attunement()` (no node carries it yet) |
| planning effect keys | data-only | `data/progression/perks.json` | detect_ore_range, cave_safety, and all non-miner lane keys stay inert until their systems ship |
| skill tree panel | UI | `scripts/ui/skill_tree_panel.gd` (K, `toggle_skills`) | scrollable node canvas from data positions; locked/available/purchased colors + [OWNED]/[LOCKED] markers; inspector + learn button; joins the Esc close chain ahead of inventory |

## v0.5 Progression Variables

| Variable | Type | Authority | Notes |
|---|---|---|---|
| `xp_totals` | dictionary (float) | `game_root.gd` / save | per-type fractional accrual; int() at read points |
| `player_level` | int | `game_root.gd` / save | 100 * 1.35^(n-1) curve from `player_xp.json` |
| `base_level` | int | `game_root.gd` / save | ratchet 1-3 (MVP cap); one tier per check; fail-closed requires |
| `base_xp` | int | `game_root.gd` / save | informational only |
| `_depth_hwm` | int | `game_root.gd` / save | 10-tile depth bands for exploration XP |
| `effective_population_cap()` | func | `game_root.gd` | base level's unlocks.population_cap clamped to POPULATION_MAX (camp 4, hamlet 6, village 8) |
| `xp_events` | data | `data/progression/player_xp.json` | 9 events wired: enemy_defeated, block_mined, block_placed, resource_deposited, storm_survived, night_survived, subject_fed, tool_crafted, new_depth_reached |

## v0.5 Ancestry Variables

| Variable | Type | Authority | Notes |
|---|---|---|---|
| `ancestry_move_mult` / `ancestry_jump_mult` | float | `data/ancestries.json` -> `player.gd` | dwarf 0.9/0.85; elf jump 1.15 (from jump_bonus) |
| `stone_ore_mine_mult` | float | same | dwarf 1.2 on stone/ore blocks |
| `ancestry_health_bonus` | int | same | orc +25 |
| `health_reduction` | float | same | goblin 0.8x max health (multiplicative, after bonus) |
| `learning_speed_mult` | float | same | human 1.05x on all award_xp amounts |
| `phase_b_ids()` | func | `ancestry_registry.gd` | derived from `implementation_phase == "B"` in data |

## C/L/R Inputs

| Input | Authority | Notes |
|---|---|---|
| `shelter_score` | `settlement_model.gather_inputs` | nearby solid blocks, cap 30 |
| `light_score` | `settlement_model.gather_inputs` | nearby light blocks, cap 30 |
| `stockpile_score` | `settlement_model.gather_inputs` | total stock adjusted by economy difficulty |
| `defense_score` | `settlement_model.gather_inputs` | nearby defense-tagged blocks |
| `damage_score` | `settlement_model.gather_inputs` | Town Hall damage pressure |
| `threat_score` | `game_root.current_threat_severity` | night/storm/live threat severity |
| `scarcity_penalty` | `settlement_model.gather_inputs` | total stock and food shortage pressure |
| `population_pressure` | `settlement_model.gather_inputs` | population versus stockpile, scaled by ruler difficulty |

`coherence`, `load_value`, and `resilience` are formula outputs from `data/settlement_rules.json`, clamped to 0-100.

## Validation Hooks

FQ-09 adds 4 checks (`fq09_*`, suite total 183) covering: toolbelt slot tiles
show live counts and the gold selected-slot highlight follows the selected
slot; the inventory panel's icon grid mirrors injected counts while the panel
opens normally; the town stockpile grid mirrors the hall stockpile; and the
acceptance flow — grids track counts through mine (+1 dirt), craft
(craft_torch: 3 torches appear), deposit (stockpile grid rises; torches are
not depositable), and load (grid matches the restored inventory exactly). The
FQ-07 hotbar item check was rewritten to art-vs-fallback semantics
(`hotbar_icon_is_art`) because slots now always display an icon.

FQ-08 adds 6 checks (`fq08_*`, suite total 179) covering: a stone target's
damage stage rises from 0 to 1-3 mid-mine; the stage resets on target change
and on mining stop; partial damage is transient — it survives neither save nor
load, the block stays intact, and finishing the mine still yields exactly one
drop; and enemy damage is visible before death (hurt-bar ratio 1.00 -> 0.67
after a non-lethal hit, enemy alive, no drops rolled).

FQ-07 adds 4 checks (`fq07_*`, suite total 173) covering: visual_assets.json
loads with the four categories; missing images return null lookups while
generated block textures still render and hotbar icons stay hidden (no crash);
a runtime-written block PNG wins over the generated texture and the fallback
returns after removal (pixel-verified both ways); and an item PNG lights its
hotbar icon then hides on removal. The smoke writes and deletes its own temp
art (with leftover cleanup at section start) so the repo stays art-free.
`validate_repo.py` requires visual_assets.json + the art/generated dirs,
fails on broken explicit references, and reports convention gaps as INFO.

FQ-06 adds 6 checks (`fq06_*`, suite total 169) covering: perk data loads with
7 lanes and correct miner prerequisites; at level 1 with nothing purchased the
root node is available, its child locked, points 0, and purchase refused; at
level 3 (2 points) purchasing stone_recovery succeeds, leaves 1 point, and
multiplies effective_mine_speed by exactly 1.15; prerequisites unlock children
while the 2-cost node stays unaffordable and re-purchase is refused; purchased
perks + level persist through the world save round-trip with the effect
re-applied; and the panel opens, selects/inspects nodes (PURCHASED/AVAILABLE
states, prerequisite names, description), and closes. The `toggle_skills`
binding joined input_actions_bound; `validate_repo.py` enforces the perk node
schema (fields, unique ids, cost >= 1, [x,y] positions, same-lane prereqs).

FQ-05 adds 6 checks (`fq05_*`, suite total 163) covering: data-driven defaults
(max 50); the pulse spends exactly its cost, lights up, and respects its
cooldown; insufficient attunement blocks the pulse without spending; attunement
regenerates over time; ancestry (`attunement_bonus` 20 -> max 70,
`attunement_regen_mult` 2.0) and gear (`amulet_focus` -> max 80) hooks raise
the maximum and removal clamps back to 50; and the current value rides the
world save (21.0 round-trips). The `attune_pulse` binding joined the
input_actions_bound list; `validate_repo.py` requires the five attunement
player_defaults keys and the amulet_focus item.

FQ-04 adds 8 checks (`fq04_*`, suite total 157) covering: bare-handed baseline
(attack 1, armor 0); forging the sword equips it, consumes 2 wood + 3 stone,
and cannot repeat; one real hit-path strike kills a 3 hp slime; forging the
armor set equips helmet/torso/feet (armor total 4) and cannot repeat; a
10-damage hit loses exactly 10 - armor_total(); a 2-damage hit under 4 armor
still chips exactly 1 (no immunity); combat gear round-trips through character
save/load with ancestry/trait max_health untouched; and the equipment UI shows
"Attack 3 · Armor 4" plus the equipped weapon/torso names. `validate_repo.py`
additionally requires the four combat items with meaningful effects and the
two forge recipes.

FQ-03 adds 7 checks (`fq03_*`, suite total 149) covering: equipment.json loads
with the 12 expected slots in order; a new character record carries default
gear (pick_basic + 11 empty slots); equipped tool slots mirror the live tool
tiers both ways; slot/item mismatches are rejected and equipping never touches
the backpack; an equipped inert item (ring_band) round-trips through character
save/load while empty slots stay valid; the inventory panel shows every gear
slot with (empty) placeholders; and a pre-FQ-03 character (no equipment key)
migrates with tool tiers and inventory preserved and gear derived from tiers.
`validate_repo.py` additionally enforces the equipment.json schema (slot list,
required items, slot_type coherence, tool item tiers).

FQ-09R replaces the 8 FQ-02 checks with 8 `fq09r_*` checks (suite total
unchanged at 183) covering: tree_density 0 clears trunks and leaves; default
generation produces trees with leaves (trunk and leaf counts both > 0); every
generated tree cell is non-solid and bare-hand mineable (one tree class — no
walk-past-only kind); density 2.0 grows more trunks than default on the same
seed; mining a trunk yields exactly 1 wood through the normal drop path and
leaves an air delta; clearing a leaf cell changes no inventory count; and the
live traversal pair — a surface trunk is found on flat terrain and the player
walks past it using only `move_right` (no jump, no mining). The baseline
mining checks (`mineable_blocks_found`, `hardness_orders_mining_time`,
`wave_f_*`) now harvest `tree_trunk`, preserving the dirt < trunk < stone
ordering and the axe speed-up on the same wood-hardness value.

FQ-01 adds 8 checks (`fq01_*`) covering: i-frame damage gating and the post-cooldown hit; eat-food healing (consumes 1 food, clamps to max_health) and its full-health no-op; passive regen near vs. far from the Town Hall; collapse inventory loss (floored per stack) plus respawn-at-hall-at-full-health; health save/load round-trip with max_health preserved; and enemy contact damage read from `data/enemies.json` scaled by `difficulty("enemy")`.

The v0.6 smoke suite (122 checks) additionally verifies: ancestry detail text (dwarf effects + constraint, planned label for non-live); world_settings ui_help coverage of all six axes and preset deviations; character inventory isolation (two characters, one world; second world; no starter-item duplication; legacy migration); toggle_inventory binding and panel open/close/content; berry-bush support cleanup on mine/load/regrowth; axe crafting, axe-vs-pick speed differentiation (33 -> 24 frames at wood hardness — originally on solid `wood` columns, harvested from `tree_trunk` since FQ-09R; stone unchanged), and {pick, axe} save round-trips with legacy tool-tier migration.

The v0.5 smoke suite (90 checks) additionally verifies: enemies.json loads with 3 live defs; each live enemy spawns with its def id; drops enter the inventory; enemy save/load round-trips id/hp/max_hp/hall_dps; progression JSONs load; XP awards accrue (including human fractional bonus 21 vs 20 over 20 events); level curve; base level advances camp -> hamlet; population caps at 4/6/8 by level and growth is gated; underground threats survive dawn while surface threats are freed; peaceful rule blocks cave spawns; ancestry effects (dwarf mults, orc health, goblin reduction, elf jump) and unknown-species baseline.

The v0.4 smoke suite verifies:

- shell character/world persistence
- presets and world config overlay
- role items and character trait effects
- input bindings
- movement, jump, mining, drops, hardness order
- ore/tool-tier gate and tier-2 speed
- berry food and regrowth
- placement, torches, occlusion, lanterns
- deposit, population food use, population floor/cap/growth
- rule toggles for food, weather, darkness
- enemy difficulty and impressionability scaling
- C/L/R reaction to light and threats
- storm pressure, damage, and roof mitigation
- save/load of player, terrain, stockpile, lights, threats, tool tier, regrow timer, storm state
- world size, ore abundance, density controls, and per-block seed variation

## Required Audit Behavior

After implementation runs, update this file when variables are added, removed, renamed, or moved between authority surfaces. A run is not SIGNABLE if C/L/R values are decorative or disconnected from world state.
