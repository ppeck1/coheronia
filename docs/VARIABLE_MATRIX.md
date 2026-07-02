# Coheronia — Variable Matrix

State: audited against the v0.3 implementation (run `20260702_coheronia_v03_increment`). All MVP-required variables exist and are connected to game state.

## Authority

- `data/blocks.json` is the source for block behavior. Read only by the `BlockRegistry` autoload (`scripts/world/block_registry.gd`); scripts query it, never redefine block fields.
- `data/recipes.json` is the source for recipes (used by `player.craft()`).
- `data/settlement_rules.json` is the source for C/L/R inputs, formulas, tick rate, and clamps. `settlement_model.gd` parses the formula strings with `Expression` — changing the JSON changes the game without code edits.
- Score scaling (how raw world counts become 0–30-ish input scores) lives in `settlement_model.gd` (`gather_inputs()`), documented below.

## Core variables

| Variable | Type | Authority | Required for MVP | Implemented in |
|---|---|---|---|---|
| `tile_size` | int | `data/blocks.json` | Yes | `BlockRegistry.tile_size` (16 px) |
| `block_id` | string | `data/blocks.json` | Yes | dirt, grass, wood, stone, ore, berry_bush, torch, lantern, town_hall_core, air |
| `hardness` | float | `data/blocks.json` | Yes | `world.mine_time()` → mining duration |
| `required_tool_tier` | int | `data/blocks.json` | Yes | gate in `world.can_mine()`; ore raised to tier 2 in v0.2 (forge gate) |
| `drops` | dictionary | `data/blocks.json` | Yes | `world.break_block()` return → inventory |
| `is_placeable` | bool | `data/blocks.json` | Yes | gate in `world.place_block()` |
| `is_solid` | bool | `data/blocks.json` | Yes | collision polygons + shelter/defense scores |
| `blocks_light` | bool | `data/blocks.json` | Yes | SIMULATED since v0.2: per-tile `OccluderPolygon2D` in the runtime TileSet + shadow-enabled torch lights |
| `emits_light` | bool | `data/blocks.json` | Yes | spawns `PointLight2D` in `world._update_light()` |
| `light_radius` | int | `data/blocks.json` | Yes | scales the light texture (torch = 96 px) |
| `settlement_tags` | array | `data/blocks.json` | Yes | `protected` blocks mining; `defense` feeds defense_score |
| `world_seed` | int | `world.gd` / save | Yes | deterministic regen via `WorldGen.generate` |
| `terrain_deltas` | dictionary | `world.gd` / save | Yes | `Vector2i -> block_id` ("air" = mined); serialized as `"x,y"` keys |
| `player_position` | Vector2 | player / save | Yes | saved/restored exactly |
| `player_health` | float | `player.gd` | Should | HUD label; threat contact damage; respawn at 0 |
| `inventory_counts` | dictionary | `inventory.gd` / save | Yes | `InventoryData.counts` |
| `selected_hotbar_slot` | int | `player.gd` | Yes | keys 1–4; saved |
| `selected_item_id` | string | `player.gd` | Yes | `player.selected_item()` from hotbar |
| `mine_target` | Vector2i | `player.gd` | Yes | progress resets on target change |
| `mine_progress` | float | `player.gd` | Yes | HUD progress bar |
| `base_mine_speed` | float | `player.gd` | Yes | 1.0; time = hardness / `effective_mine_speed()` |
| `tool_tier` | int | `player.gd` | Should | starts at 1 (dirt/wood/stone); tier 2 via Town Hall forge unlocks ore and +50% speed; saved |
| `town_hall_position` | Vector2i | `world.hall_info` | Yes | stamped by `WorldGen.stamp_town_hall` |
| `town_hall_stockpile` | dictionary | `town_hall.gd` / save | Yes | deposit via hall panel; repair spends stone |
| `population_count` | int | `town_hall.gd` | Yes | dynamic 1–8 since v0.3: −1 on a starved dawn, +1 on a fed dawn with coherence ≥ 55 and food ≥ population; saved |
| `shelter_score` | float | `settlement_model.gd` | Yes | solid blocks within Chebyshev r=6 of hall × 0.5, cap 30 |
| `light_score` | float | `settlement_model.gd` | Yes | light-emitting blocks within r=8 × 8, cap 30 |
| `stockpile_score` | float | `settlement_model.gd` | Yes | total stored × 0.5, cap 30 |
| `defense_score` | float | `settlement_model.gd` | Should | `defense`-tagged blocks within r=6 × 0.75, cap 25 |
| `damage_score` | float | `settlement_model.gd` | Should | hall damage (0–100) × 0.3, cap 30 |
| `threat_score` | float | `game_root.gd` → model | Yes | night base 10 + 10 per live threat, cap 40 |
| `scarcity_penalty` | float | `settlement_model.gd` | Should | (10 − total stock) × 1.0 + max(0, population − food stock), clamp 0–15 (food-aware since v0.2) |
| `population_pressure` | float | `settlement_model.gd` | Should | pop × 2 − stock × 0.1, clamp 0–20 |
| `coherence` | float | formulas in `settlement_rules.json` | Yes | HUD bar, clamp 0–100 |
| `load` | float | formulas in `settlement_rules.json` | Yes | HUD bar (named `load_value` in code; `load` is a GDScript built-in) |
| `resilience` | float | formulas in `settlement_rules.json` | Yes | HUD bar |
| `time_of_day` | float | `game_root.gd` / save | Should | 0–1 over 100 s; night ≥ 0.65 |
| `is_night` | bool | `game_root.gd` | Should | derived from `time_of_day`; drives tint + threat event |
| `event_log` | array | `hud.gd` | Yes | last 6 messages, top-right |
| `save_version` | string | `save_manager.gd` | Yes | "0.3"; accepts {"0.1", "0.2", "0.3"}, others rejected |

## Variables added during implementation

| Variable | Type | Authority | Notes |
|---|---|---|---|
| `day_count` | int | `game_root.gd` / save | HUD "Day N" |
| `town_hall.damage` | float | `town_hall.gd` / save | 0–100; raised by threats, lowered by repair (2 stone → −25) |
| `status_labels` | array | `settlement_model.gd` | Stable/Strained/Critical + Well-lit/Exposed/Undersupplied |
| `SEVERITY` | const float | `simple_threat.gd` | 10 per live threat, summed by `game_root.current_threat_severity()` |
| `NIGHT_BASE_SEVERITY` | const float | `game_root.gd` | 10 while night |
| `DAY_LENGTH_SECONDS`, `NIGHT_START` | const | `game_root.gd` | 100 s day; night at 65% |
| `hall_info` | dictionary | `world.gd` | center cell, ground y, protected core cells |

## Variables added in v0.2

| Variable | Type | Authority | Notes |
|---|---|---|---|
| `food` | resource id | `data/blocks.json` (berry_bush drops) | Depositable; settlers consume it; feeds scarcity_penalty |
| `berry_bush` | block | `data/blocks.json` | Surface food source, non-solid, drops food ×2, does not regrow |
| `DAILY_FOOD_NEED` | const int | `game_root.gd` | 2 food eaten at each dawn (`consume_daily_food()`) |
| `effective_mine_speed()` | float | `player.gd` | base_mine_speed × (1 + 0.5 × (tool_tier − 1)) |
| `FORGE_RECIPE_ID` | const | `town_hall.gd` | "basic_pick_upgrade" from `data/recipes.json` (station town_hall, outputs tool_tier_2_pick) |
| `threats` (save key) | array | `save_manager.gd` / `game_root.serialize_threats()` | [{x, y, hp}]; restored on load |

## Variables added in v0.3

| Variable | Type | Authority | Notes |
|---|---|---|---|
| `bush_regrow` | dictionary | `world.gd` / save (`bush_regrow` key) | Vector2i → seconds until a harvested bush regrows (90 s; 10 s retry if the cell is occupied) |
| `lantern` | block | `data/blocks.json` | Placeable light, radius 160; crafted at the Town Hall (`craft_lantern`: 2 ore + 1 wood); hotbar slot 5 |
| `craft_from_stockpile()` | method | `town_hall.gd` | Generic town_hall-station crafting; `forge_pick` now uses it |
| `daily_food_need()` | int | `game_root.gd` | max(1, ⌈population/2⌉); replaces the fixed DAILY_FOOD_NEED |
| `POPULATION_MAX`, `GROWTH_COHERENCE` | const | `game_root.gd` | 8; 55.0 — growth gates checked against the pre-meal dawn coherence snapshot |
| `storm_active`, `storm_time_left`, `_storm_rolled_today` | state | `game_root.gd` / save (time dict) | 50%/day roll at time 0.35; 18 s; severity 8; up to 3 dps × (1 − roof_coverage) |
| `roof_coverage()` | float | `settlement_model.gd` | Fraction of 7 hall columns with any solid cell above the hall (scans to the world top); storms only punish missing roof |
| `_live_threat_count()` | int | `game_root.gd` | Valid, non-queued threats; drives the HUD threat warning |

## Required audit behavior

After implementation runs, update this file when variables are added, removed, renamed, or moved between authority surfaces.

A run is not SIGNABLE if core C/L/R variables exist only as decorative HUD values with no connection to world state. **v0.2 verified:** smoke checks `clr_reacts_to_light` (C 32.4→54.4 when torches placed near the hall) and `threat_event_raises_load` (Load 10.1→30.1 at nightfall) prove the connection.
