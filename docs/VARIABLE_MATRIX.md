# Coheronia — Variable Matrix

State: audited against the v0.1 implementation (run `2026-07-02-mvp-v01-oneshot`). All MVP-required variables exist and are connected to game state.

## Authority

- `data/blocks.json` is the source for block behavior. Read only by the `BlockRegistry` autoload (`scripts/world/block_registry.gd`); scripts query it, never redefine block fields.
- `data/recipes.json` is the source for recipes (used by `player.craft()`).
- `data/settlement_rules.json` is the source for C/L/R inputs, formulas, tick rate, and clamps. `settlement_model.gd` parses the formula strings with `Expression` — changing the JSON changes the game without code edits.
- Score scaling (how raw world counts become 0–30-ish input scores) lives in `settlement_model.gd` (`gather_inputs()`), documented below.

## Core variables

| Variable | Type | Authority | Required for MVP | Implemented in |
|---|---|---|---|---|
| `tile_size` | int | `data/blocks.json` | Yes | `BlockRegistry.tile_size` (16 px) |
| `block_id` | string | `data/blocks.json` | Yes | dirt, grass, wood, stone, ore, torch, town_hall_core, air |
| `hardness` | float | `data/blocks.json` | Yes | `world.mine_time()` → mining duration |
| `required_tool_tier` | int | `data/blocks.json` | Yes | gate in `world.can_mine()` |
| `drops` | dictionary | `data/blocks.json` | Yes | `world.break_block()` return → inventory |
| `is_placeable` | bool | `data/blocks.json` | Yes | gate in `world.place_block()` |
| `is_solid` | bool | `data/blocks.json` | Yes | collision polygons + shelter/defense scores |
| `blocks_light` | bool | `data/blocks.json` | Yes | present in data; per-tile occlusion NOT simulated in v0.1 (known limitation) |
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
| `base_mine_speed` | float | `player.gd` | Yes | 1.0; time = hardness / speed |
| `tool_tier` | int | `player.gd` | Should | starts at 1 (can mine stone/ore); saved |
| `town_hall_position` | Vector2i | `world.hall_info` | Yes | stamped by `WorldGen.stamp_town_hall` |
| `town_hall_stockpile` | dictionary | `town_hall.gd` / save | Yes | deposit via hall panel; repair spends stone |
| `population_count` | int | `town_hall.gd` | Yes | abstract, fixed 4; saved |
| `shelter_score` | float | `settlement_model.gd` | Yes | solid blocks within Chebyshev r=6 of hall × 0.5, cap 30 |
| `light_score` | float | `settlement_model.gd` | Yes | light-emitting blocks within r=8 × 8, cap 30 |
| `stockpile_score` | float | `settlement_model.gd` | Yes | total stored × 0.5, cap 30 |
| `defense_score` | float | `settlement_model.gd` | Should | `defense`-tagged blocks within r=6 × 0.75, cap 25 |
| `damage_score` | float | `settlement_model.gd` | Should | hall damage (0–100) × 0.3, cap 30 |
| `threat_score` | float | `game_root.gd` → model | Yes | night base 10 + 10 per live threat, cap 40 |
| `scarcity_penalty` | float | `settlement_model.gd` | Should | (10 − total stock) × 1.5, clamp 0–15 |
| `population_pressure` | float | `settlement_model.gd` | Should | pop × 2 − stock × 0.1, clamp 0–20 |
| `coherence` | float | formulas in `settlement_rules.json` | Yes | HUD bar, clamp 0–100 |
| `load` | float | formulas in `settlement_rules.json` | Yes | HUD bar (named `load_value` in code; `load` is a GDScript built-in) |
| `resilience` | float | formulas in `settlement_rules.json` | Yes | HUD bar |
| `time_of_day` | float | `game_root.gd` / save | Should | 0–1 over 100 s; night ≥ 0.65 |
| `is_night` | bool | `game_root.gd` | Should | derived from `time_of_day`; drives tint + threat event |
| `event_log` | array | `hud.gd` | Yes | last 6 messages, top-right |
| `save_version` | string | `save_manager.gd` | Yes | "0.1"; mismatched saves rejected |

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

## Required audit behavior

After implementation runs, update this file when variables are added, removed, renamed, or moved between authority surfaces.

A run is not SIGNABLE if core C/L/R variables exist only as decorative HUD values with no connection to world state. **v0.1 verified:** smoke checks `clr_reacts_to_light` (C 31.2→53.2 when torches placed near the hall) and `threat_event_raises_load` (Load 12.3→32.3 at nightfall) prove the connection.
