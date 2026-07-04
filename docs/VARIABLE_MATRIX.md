# Coheronia - Variable Matrix

State: audited against v0.6 closeout run `20260704_coheronia_v06_increment`.

## Authority Surfaces

| Surface | Authority | Consumed by |
|---|---|---|
| Blocks | `data/blocks.json` | `BlockRegistry`, `world`, `player`, `settlement_model`, `hud` |
| Recipes | `data/recipes.json` | `player`, `town_hall` |
| Settlement formulas | `data/settlement_rules.json` | `settlement_model.gd` via Godot `Expression` |
| World settings | `data/world_settings.json` | `WorldConfig`, shell UI, world generation, gameplay systems |
| Character data | `data/character_data.json` | shell UI, `player.apply_character`, role item grant |
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
| `generation.tree_density` | `WorldGen.generate` | tree/wood frequency; 0 disables trees |
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

## Core Gameplay Variables

| Variable | Type | Authority | Notes |
|---|---|---|---|
| `tile_size` | int | `data/blocks.json` | 16 px |
| `block_id` | string | `data/blocks.json` | dirt, grass, wood, stone, ore, berry_bush, torch, lantern, town_hall_core, air |
| `hardness` | float | `data/blocks.json` | mining time input |
| `required_tool_tier` | int | `data/blocks.json` | ore requires tier 2 (pick tier) |
| `preferred_tool` | string | `data/blocks.json` | axe: wood, berry_bush; pick: stone, ore; axe-preferred mine 1.4x faster with an axe |
| `requires_support` | bool | `data/blocks.json` | berry_bush; enforced on mine, load sweep, and regrowth |
| `axe_tier` | int | `player.gd` / character-carried | 0 = no axe; `craft_axe` recipe (4 wood + 2 stone, town_hall) sets 1 |
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
| `inventory_counts` | dictionary | `inventory.gd` / character-carried | stackable resource counts; travels between worlds |
| `selected_hotbar_slot` | int | `player.gd` / character-carried | slots 1-5 |
| `tool_tier` | int | `player.gd` / character-carried | pick tier alias; tier 2 unlocks ore and speed |
| `effective_mine_speed` | func | `player.gd` | tool tier and trait multiplier |
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

The v0.6 smoke suite (122 checks) additionally verifies: ancestry detail text (dwarf effects + constraint, planned label for non-live); world_settings ui_help coverage of all six axes and preset deviations; character inventory isolation (two characters, one world; second world; no starter-item duplication; legacy migration); toggle_inventory binding and panel open/close/content; berry-bush support cleanup on mine/load/regrowth; axe crafting, axe-vs-pick speed differentiation (wood 33 -> 24 frames, stone unchanged), and {pick, axe} save round-trips with legacy tool-tier migration.

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
