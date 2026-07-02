# COHERONIA — Variable Reference
## Phase 1.2  |  Deterministic Save/Load + Delta Overlay

Legend:
- **@export** — editable in Godot Inspector
- **@onready** — assigned from scene tree at `_ready()`, null before then
- **class var** — persists for the lifetime of the node/object
- **local var** — exists only inside a single function call
- **const** — immutable compile-time value
- **[1.1]** / **[1.2]** — phase introduced or last changed

---

## `scripts/main/main.gd` — class `Main` (extends Node)

### @onready
| Variable | Type | Value | Definition |
|----------|------|-------|------------|
| `game_root_scene` | `PackedScene` | `preload("res://scenes/main/GameRoot.tscn")` | Holds the GameRoot packed scene; instantiated and added to tree in `_ready()` |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `gr` | `_ready()` | Node | Instantiated GameRoot node |

---

## `scripts/main/game_root.gd` — class `GameRoot` (extends Node)

### @onready
| Variable | Type | Scene path | Definition |
|----------|------|------------|------------|
| `world` | `World` | `$World` | World node; entry point for terrain, tile queries, player spawn |
| `settlement` | `Settlement` | `$SettlementRoot` | Settlement node; receives world ref, emits C/L/R state |
| `hud` | `HUD` | `$HUD` | HUD CanvasLayer; receives settlement state signal |
| `raid_director` | `RaidDirector` | `$RaidDirector` | Raid logic node; receives world + settlement context |
| `save_manager` | `SaveManager` | `$SaveManager` | **[1.2]** Save/load node; called with `world` reference on F5/F9 |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `player` | `_ready()` | `Player` | Fetched one frame after `spawn_player()`; used to inject `world` reference |
| `player` | `_input() F9 branch` | `Player` | Re-fetched after `load_game()` to re-inject world reference on the existing player node |

---

## `scripts/player/player.gd` — class `Player` (extends CharacterBody2D)

### Constants
| Name | Value | Definition |
|------|-------|------------|
| `TILE_SIZE` | `16` | Tile pixel size; used to convert world-pixel positions to tile grid coordinates |

### @export
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `speed` | `float` | `240.0` | Horizontal movement speed in pixels/sec |
| `jump_velocity` | `float` | `-420.0` | Vertical velocity applied on jump (negative = up) |
| `gravity` | `float` | `1100.0` | Downward acceleration in pixels/sec² when not on floor |
| `mine_range_px` | `float` | `96.0` | Max pixel distance from player to mouse for mining and placing |
| `mine_time` | `float` | `0.6` | Seconds to mine one tile at base speed |
| `place_tile_id` | `String` | `"dirt"` | **[1.1]** Tile type placed on RMB; stopgap until Phase 2 hotbar |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `world` | `World` | `null` | Active World reference; injected by GameRoot; required for tile queries and mutations. **Re-injected after every `load_game()` call** |
| `inventory` | `Dictionary` | `{}` | Maps `item_id → count: int`. Incremented by mining, decremented by placement |
| `_mine_timer` | `float` | `0.0` | Elapsed seconds on current mine target; resets on target change or release |
| `_mine_target` | `Vector2i` | `(-9999,-9999)` | Tile grid coordinate being mined; sentinel = no target |
| `_is_mining` | `bool` | `false` | True while LMB held on valid in-range tile |
| `_mine_bar` | `ColorRect` | `null` | Yellow fill bar showing mine progress (width 0–20px) |
| `_mine_bar_bg` | `ColorRect` | `null` | Dark background rect for mine bar; world-space positioned above target tile |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `cs` | `_ready()` | `CollisionShape2D` | Fetched collision shape; receives fallback `20×32 px` if missing |
| `rect` | `_ready()` | `RectangleShape2D` | Fallback collision shape |
| `mouse_world` | `_handle_mining()` | `Vector2` | Global pixel position of mouse this frame |
| `dist` | `_handle_mining()` | `float` | Pixel distance from player to mouse; gate for range check |
| `tile_pos` | `_handle_mining()` | `Vector2i` | Mouse floored to tile grid: `(floor(x/16), floor(y/16))` |
| `tile_id` | `_handle_mining()` | `String` | Tile at `tile_pos`; empty/"air" = unminable |
| `tile_id` | `_finish_mine()` | `String` | Re-queried at completion to confirm tile still exists |
| `item_id` | `_finish_mine()` | `String` | `_tile_to_item(tile_id)` result; key incremented in inventory |
| `mouse_world` | `_handle_place()` | `Vector2` | **[1.1]** Global mouse position for placement |
| `dist` | `_handle_place()` | `float` | **[1.1]** Range check reusing `mine_range_px` |
| `tile_pos` | `_handle_place()` | `Vector2i` | **[1.1]** Target tile coordinate for placement |
| `existing` | `_handle_place()` | `String` | **[1.1]** Current tile at target; blocks placement if not air |
| `need_item` | `_handle_place()` | `String` | **[1.1]** `_item_for_tile(place_tile_id)`; empty = unplaceable |
| `have` | `_handle_place()` | `int` | **[1.1]** Inventory count of `need_item`; blocks if 0 |
| `tile_world` | `_show_mine_indicator()` | `Vector2` | World-space top-left of target tile minus 6px; bar anchor point |
| `style` | `_build_mine_indicator()` | `StyleBoxFlat` | Style object for bar fill color |

---

## `scripts/world/world.gd` — class `World` (extends Node2D)

### @export
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `world_seed` | `int` | `12345` | RNG seed for terrain generation. **[1.2]** Written by `SaveManager.load_game()` before regeneration; set in Inspector for custom seeds |
| `player_scene` | `PackedScene` | *(set in scene)* | `Player.tscn` reference; used by `spawn_player()` |

### @onready
| Variable | Type | Scene path | Definition |
|----------|------|------------|------------|
| `tm_fg` | `TileMap` | `$TileMapForeground` | Foreground TileMap; terrain tiles with collision. Cleared by `clear_world()` |
| `tm_bg` | `TileMap` | `$TileMapBackground` | Background TileMap; wall tiles, no collision (Phase 2). Cleared by `clear_world()` |
| `player_spawn` | `Marker2D` | `$PlayerSpawn` | World-space position where player instantiates |
| `town_hall_marker` | `Marker2D` | `$TownHallMarker` | World-space anchor for TownHall; used by RaidDirector |
| `ground_shape` | `CollisionShape2D` | `$Ground/CollisionShape2D` | Temporary flat floor; `5000×80 px` |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `settlement` | `Settlement` | *(unset)* | Settlement reference; reserved for future cross-system queries |
| `tilemap_adapter` | `TilemapAdapter` | *(init `_ready`)* | Translates `tile_id: String` → TileMap cell calls |
| `world_gen` | `WorldGen` | *(init `_ready`)* | Terrain generator; called once at startup and again by `load_game()` |
| `chunk_serializer` | `ChunkSerializer` | *(init `_ready`)* | Converts tile coordinates ↔ chunk keys for save/load |
| `modified_chunks` | `Dictionary` | `{}` | **Delta save store.** `Vector2i(cx,cy) → Dictionary(packed_local_key → tile_id)`. Only written when `track_modified=true`. Cleared by `clear_world()` and after delta overlay in `load_game()` |
| `tile_data` | `Dictionary` | `{}` | **Primary tile store.** `Vector2i(tile_x, tile_y) → tile_id`. Absent = air. Always written by `set_tile()`. Cleared by `clear_world()` |

### `set_tile()` signature
```
func set_tile(tile_x, tile_y, tile_id, layer := 0, track_modified := true)
```
| Parameter | Type | Default | Definition |
|-----------|------|---------|------------|
| `tile_x` | `int` | — | Tile column |
| `tile_y` | `int` | — | Tile row |
| `tile_id` | `String` | — | Tile to write; `"air"` erases |
| `layer` | `int` | `0` | TileMap layer (0 = foreground) |
| `track_modified` | `bool` | `true` | **[1.1]** `false` during worldgen and delta overlay; `true` for all player edits |

### `clear_world()` — **[1.2]**
Resets all four world state containers. Called by `SaveManager.load_game()` before regeneration.
- Clears: `tile_data`, `modified_chunks`, `tm_fg` cells, `tm_bg` cells
- Does NOT clear: TileSet assignment, node references, player node

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `scene` | `spawn_player()` | `PackedScene` | Local copy of `player_scene`; fallback to `load()` if export unset |
| `p` | `spawn_player()` | Node (Player) | Instantiated player; named "Player", positioned at `player_spawn` |
| `key` | `set_tile()` | `Vector2i` | `(tile_x, tile_y)` for `tile_data` operations |
| `info` | `set_tile()` | `Dictionary` | `{cx, cy, lx, ly}` from `chunk_serializer.world_to_chunk()` |
| `ckey` | `set_tile()` | `Vector2i` | Chunk coordinate key `(cx, cy)` for `modified_chunks` |
| `pk` | `set_tile()` | `int` | Bitwise-packed local tile position; inner key of chunk dict |
| `key` | `get_tile_at()` | `Vector2i` | Lookup key into `tile_data` |
| `rect` | `_configure_ground()` | `RectangleShape2D` | `5000×80 px` fallback floor shape |

---

## `scripts/world/world_gen.gd` — class `WorldGen` (extends RefCounted)

### Constants
| Name | Value | Definition |
|------|-------|------------|
| `SURFACE_Y` | `15` | Default tile row for surface before noise offset |
| `WORLD_LEFT` | `-100` | Leftmost tile column generated |
| `WORLD_RIGHT` | `200` | Rightmost tile column generated (exclusive) |
| `WORLD_DEPTH` | `80` | Tile rows generated below each column's surface point |
| `DIRT_DEPTH` | `5` | Rows of dirt before stone begins |
| `ATLAS_DIRT` | `Vector2i(0,0)` | TileSet atlas coordinate for dirt |
| `ATLAS_STONE` | `Vector2i(1,0)` | TileSet atlas coordinate for stone |
| `ATLAS_WOOD_WALL` | `Vector2i(2,0)` | TileSet atlas coordinate for wood wall |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `seed` | `int` | `0` | **[1.2]** Stores the seed value used for the most recent `generate()` call. Set by `generate()` before noise construction; readable for debugging |

### Public API
```
func generate(world: World, seed_in: int) -> void   # canonical entry point [1.2]
func generate_basic(world: World, seed_val: int) -> void  # legacy alias → delegates to generate()
```
- All noise sources are seeded deterministically from `seed_in` (surface: `seed_in`, cave: `seed_in+999`, ore: `seed_in+42`)
- `randomize()` is never called
- Every tile call uses `world.set_tile(x, y, tile_id, 0, false)` — baseline never pollutes `modified_chunks`

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `tex_path` | `_setup_tileset()` | `String` | Path to placeholder tilesheet PNG |
| `texture` | `_setup_tileset()` | `Texture2D` | Loaded tilesheet resource |
| `tileset` | `_setup_tileset()` | `TileSet` | Programmatically built TileSet; assigned to both TileMaps |
| `source` | `_setup_tileset()` | `TileSetAtlasSource` | Atlas source with all tile definitions; added to `tileset` at index 0 |
| `atlas_positions` | `_setup_tileset()` | `Array` | All `Vector2i` atlas coords to register |
| `td` | `_setup_tileset()` | `TileData` | Per-tile data; receives `16×16` collision polygon |
| `poly` | `_setup_tileset()` | `PackedVector2Array` | Full tile collision square `(-8,-8)→(8,8)` |
| `surface_noise` | `_generate_terrain()` | `FastNoiseLite` | Perlin noise for surface height variation (±5 tiles); seed = `seed_val` |
| `cave_noise` | `_generate_terrain()` | `FastNoiseLite` | Perlin noise for cave carving (>0.28 = air); seed = `seed_val + 999` |
| `ore_noise` | `_generate_terrain()` | `FastNoiseLite` | Cellular noise for ore placement (reserved); seed = `seed_val + 42` |
| `height_offset` | loop | `int` | Per-column surface deviation; range ±5 tiles |
| `surf_y` | loop | `int` | Actual surface tile row for this column |
| `y` | inner loop | `int` | Absolute tile row being written |
| `depth` | inner loop | `int` | Rows below `surf_y`; drives dirt→stone transition |
| `tile_id` | inner loop | `String` | Resolved tile: `"dirt"`, `"stone"`, or `"air"` |
| `cave_v` | inner loop | `float` | Cave noise sample; compared against 0.28 threshold |
| `ore_v` | inner loop | `float` | Ore noise sample; reserved for Phase 2 ore differentiation |

---

## `scripts/world/tilemap_adapter.gd` — class `TilemapAdapter` (extends RefCounted)

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `tm_fg` | `TileMap` | *(set in `_init`)* | Foreground TileMap; target for layer 0 writes |
| `tm_bg` | `TileMap` | *(set in `_init`)* | Background TileMap; target for layer 1 writes |
| `tile_lookup` | `Dictionary` | *(literal)* | `tile_id: String → {source: int, atlas: Vector2i}`. `"air"` → `null` (erase). Entries: `air`, `dirt`, `stone`, `wood_wall` |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `t` | `set_tile_by_id()` | `TileMap` | Selected TileMap (fg or bg) by layer |
| `coords` | `set_tile_by_id()` | `Vector2i` | `(x, y)` tile coordinate for cell operations |
| `m` | `set_tile_by_id()` | `Dictionary` | `tile_lookup` entry for the requested tile_id |

---

## `scripts/world/chunk_serializer.gd` — class `ChunkSerializer` (extends RefCounted)

### Constants
| Name | Value | Definition |
|------|-------|------------|
| `CHUNK_SIZE` | `32` | Tiles per chunk side; one chunk = `32×32` tiles |

### Public API
| Method | Returns | Definition |
|--------|---------|------------|
| `pack_local(x, y)` | `int` | Bitwise encodes local tile `(x, y)` into a single int: `(y << 16) \| (x & 0xFFFF)` |
| `unpack_local(k)` | `Vector2i` | Reverses `pack_local`; used by `_apply_deltas()` |
| `world_to_chunk(tile_x, tile_y)` | `Dictionary` | Returns `{cx, cy, lx, ly}` for a world tile coordinate |
| `serialize_modified(mc)` | `Array` | **[1.2]** Canonical alias for `serialize_modified_chunks()`; called by `SaveManager.save_game()` |
| `serialize_modified_chunks(mc)` | `Array` | Converts `modified_chunks` dict → JSON-serializable array |
| `deserialize_modified_chunks(arr)` | `Dictionary` | Converts JSON array back → `Vector2i → Dictionary(packed_key → tile_id)` |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `x` | `unpack_local()` | `int` | Local x from `k & 0xFFFF` |
| `y` | `unpack_local()` | `int` | Local y from `k >> 16` |
| `cx, cy` | `world_to_chunk()` | `int` | Chunk column/row = `floor(tile / CHUNK_SIZE)` |
| `lx, ly` | `world_to_chunk()` | `int` | Local tile offset within chunk |
| `out` | `serialize_modified_chunks()` | `Array` | Output array of chunk dicts |
| `cx, cy` | `serialize_modified_chunks()` | `int` | Chunk coords from Vector2i key |
| `local_map` | `serialize_modified_chunks()` | `Dictionary` | Inner `packed_key → tile_id` dict for this chunk |
| `arr` | `serialize_modified_chunks()` | `Array` | Per-chunk tile list `[{x, y, tile}, ...]` |
| `lp` | `serialize_modified_chunks()` | `Vector2i` | Unpacked local tile position |
| `modified` | `deserialize_modified_chunks()` | `Dictionary` | Built result: `Vector2i → Dictionary` |
| `key` | `deserialize_modified_chunks()` | `Vector2i` | Chunk key from JSON fields |
| `local_map` | `deserialize_modified_chunks()` | `Dictionary` | Per-chunk tile dict being rebuilt |
| `pk` | `deserialize_modified_chunks()` | `int` | Re-packed local tile position key |

---

## `scripts/world/chunk.gd` — class `Chunk` (extends RefCounted)

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `chunk_x` | `int` | *(set in `_init`)* | Chunk column in chunk-space |
| `chunk_y` | `int` | *(set in `_init`)* | Chunk row in chunk-space |
| `modified_tiles` | `Dictionary` | `{}` | **Stub — not wired.** `World.modified_chunks` is the live tracking structure |

---

## `scripts/save/save_manager.gd` — class `SaveManager` (extends Node)

### Constants
| Name | Value | Definition |
|------|-------|------------|
| `SAVE_PATH` | `"user://save_v01.json"` | OS-resolved save file path |

### Public API — **[1.2]** (replaces old generic `save_game(payload)` / `load_game()`)
```
func save_game(world: World) -> void
func load_game(world: World) -> void
```
Both require a live `World` reference; called from `GameRoot._input()` on F5/F9.

**`save_game(world)` flow:**
1. Build payload from `SaveSchema.empty_save()`
2. Write `world.world_seed`
3. Write `world.chunk_serializer.serialize_modified(world.modified_chunks)` → `payload["deltas"]`
4. Stringify + write to `SAVE_PATH`

**`load_game(world)` flow:**
1. Read + JSON parse `SAVE_PATH`
2. Validate `world_seed` and `deltas` keys exist
3. Set `world.world_seed = seed_val`
4. `world.clear_world()` — wipe tile_data, modified_chunks, TileMap cells
5. `world.world_gen.generate(world, seed_val)` — regenerate baseline deterministically
6. `_apply_deltas(world, decoded)` — overlay saved edits with `track_modified=false`
7. `world.modified_chunks.clear()` — post-load session starts with empty delta layer

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `payload` | `save_game()` | `Dictionary` | Built from `SaveSchema.empty_save()`; populated and JSON-stringified |
| `f` | `save_game()` | `FileAccess` | File handle for writing |
| `f` | `load_game()` | `FileAccess` | File handle for reading |
| `text` | `load_game()` | `String` | Raw JSON string from disk |
| `parsed` | `load_game()` | `Variant` | `JSON.parse_string(text)` result; type-checked before cast |
| `payload` | `load_game()` | `Dictionary` | Parsed save data |
| `seed_val` | `load_game()` | `int` | `int(payload["world_seed"])`; passed to `generate()` and written to `world.world_seed` |
| `raw_deltas` | `load_game()` | `Variant` | `payload["deltas"]` before type-check; must be `TYPE_ARRAY` |
| `decoded` | `load_game()` | `Dictionary` | Result of `deserialize_modified_chunks(raw_deltas)` → `Vector2i → chunk_map` |
| `cs` | `_apply_deltas()` | `ChunkSerializer` | Local alias for `world.chunk_serializer` |
| `cx, cy` | `_apply_deltas()` | `int` | Chunk coords from `ckey.x / .y` |
| `chunk_map` | `_apply_deltas()` | `Dictionary` | Inner dict of `packed_key → tile_id` for this chunk |
| `pk` | `_apply_deltas()` | `int (Variant)` | Packed local tile key; cast to `int` before `unpack_local()` |
| `tile_id` | `_apply_deltas()` | `String` | Tile string being restored |
| `local` | `_apply_deltas()` | `Vector2i` | Unpacked `(lx, ly)` from `cs.unpack_local(pk)` |
| `wx` | `_apply_deltas()` | `int` | World tile x = `cx * CHUNK_SIZE + local.x` |
| `wy` | `_apply_deltas()` | `int` | World tile y = `cy * CHUNK_SIZE + local.y` |

### Legacy API (kept for console/debug)
```
func save_raw(payload: Dictionary) -> void
func load_raw() -> Dictionary
```
These accept/return raw dicts without any world context; not used by normal game flow.

---

## `scripts/save/schema.gd` — class `SaveSchema` (extends RefCounted)

*No instance or class variables. Static function only.*

### `empty_save()` return shape
```gdscript
{
    "world_seed":  12345,   # int  — seed written by save_game()
    "time_of_day": 0.5,     # float — stub for Phase 5 day/night
    "player":      {},      # dict  — stub for Phase 2 inventory persistence
    "inventory":   [],      # array — stub
    "settlement":  {},      # dict  — stub for Phase 5 settlement persistence
    "deltas":      []       # array — serialized modified_chunks [1.2]
}
```

---

## `scripts/settlement/settlement.gd` — class `Settlement` (extends Node2D)

### @onready
| Variable | Type | Scene path | Definition |
|----------|------|------------|------------|
| `followers_root` | `Node2D` | `$Followers` | Parent node for all Follower instances |
| `buildings_root` | `Node2D` | `$Buildings` | Parent node for buildings (stub) |
| `tick` | `SettlementTick` | `$SettlementTick` | Drives C/L/R computation every 5 seconds |
| `town_hall` | `Area2D` | `$TownHall` | TownHall; position used for raider targeting |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `world` | `World` | `null` | World reference; reserved for cross-system queries |
| `followers` | `Array` | `[]` | All live Follower instances; iterated in `gather_observables()` |
| `nodes` | `Dictionary` | *(9 keys, all 50)* | Nine C/L/R sub-scores. Keys: `C_ALIGNMENT`, `C_TRUST`, `C_RHYTHM`, `L_WORK_DEMAND`, `L_THREAT_PRESSURE`, `L_SCARCITY_PRESSURE`, `R_BUFFERS`, `R_RECOVERY`, `R_REDUNDANCY` |
| `C` | `float` | `50.0` | Mean of C sub-scores (alignment / trust / rhythm) |
| `L` | `float` | `50.0` | Mean of L sub-scores (work demand / threat / scarcity) |
| `R` | `float` | `50.0` | Mean of R sub-scores (buffers / recovery / redundancy) |
| `P_prod` | `float` | `1.0` | Production multiplier. Range `0.25–1.5` |
| `P_injury` | `float` | `0.02` | Per-tick injury probability. Range `0.005–0.12` |
| `P_raid_factor` | `float` | `1.0` | Raid probability multiplier. Range `0.4–2.0`; read by RaidDirector |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `injured_count` | `gather_observables()` | `int` | Followers where `injured == true`; feeds `untreated_injuries_count` observable |
| `guards_count` | `gather_observables()` | `int` | Followers with `role == "guard"`; feeds `guards_count` observable |
| `scene` | `spawn_follower()` | `PackedScene` | Preloaded Follower scene |
| `f` | `spawn_follower()` | `Follower` | Instantiated follower; added to `followers_root` and `followers` |

---

## `scripts/settlement/settlement_tick.gd` — class `SettlementTick` (extends Node)

### @export
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `tick_seconds` | `float` | `5.0` | Real-seconds interval between C/L/R computation cycles |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `settlement` | `Settlement` | `null` | Parent Settlement; injected via `set_settlement()` |
| `coherence_model` | `CoherenceModel` | `CoherenceModel.new()` | Stateless model; called each tick |
| `_accum` | `float` | `0.0` | Delta-time accumulator; triggers `_tick()` at `tick_seconds` |

### Local vars (inside `_tick()`)
| Variable | Type | Definition |
|----------|------|------------|
| `obs` | `Dictionary` | Observable snapshot from `settlement.gather_observables()` |
| `nodes` | `Dictionary` | Updated 9-key node scores from `coherence_model.compute_nodes()` |
| `C` | `float` | Mean of C_ALIGNMENT, C_TRUST, C_RHYTHM |
| `L` | `float` | Mean of L_WORK_DEMAND, L_THREAT_PRESSURE, L_SCARCITY_PRESSURE |
| `R` | `float` | Mean of R_BUFFERS, R_RECOVERY, R_REDUNDANCY |
| `P_prod` | `float` | `clamp(0.5 + 0.01C - 0.008L + 0.01R, 0.25, 1.5)` |
| `P_injury` | `float` | `clamp(0.02 + 0.001L - 0.0008C - 0.0008R, 0.005, 0.12)` |
| `P_raid_factor` | `float` | `clamp(0.6 + 0.012L - 0.008C - 0.006R, 0.4, 2.0)` |
| `s` | `float` | Running sum inside `_mean()` helper |

---

## `scripts/settlement/coherence_model.gd` — class `CoherenceModel` (extends Resource)

*Stateless — no persistent instance variables.*

### Local vars (inside `compute_nodes()`)
| Variable | Type | Definition |
|----------|------|------------|
| `n` | `Dictionary` | Deep copy of `prev_nodes`; nine sub-scores mutated in-place and returned |
| `food_days` | `float` | `obs["food_days"]`; used in R_BUFFERS and R_RECOVERY calculations |

---

## `scripts/settlement/follower.gd` — class `Follower` (extends CharacterBody2D)

### @export
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `role` | `String` | `"laborer"` | Assigned role. Valid: `"laborer"`, `"guard"` |
| `speed` | `float` | `120.0` | Movement speed in pixels/sec (reserved for Phase 5 AI) |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `injured` | `bool` | `false` | Injury state; affects `untreated_injuries_count` observable and `is_working()` |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `cs` | `_ready()` | `CollisionShape2D` | Collision shape; receives fallback `18×30 px` if missing |
| `rect` | `_ready()` | `RectangleShape2D` | Fallback shape |

---

## `scripts/enemies/enemy.gd` — class `Enemy` (extends CharacterBody2D)

### @export
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `speed` | `float` | `100.0` | Movement speed in pixels/sec |
| `max_health` | `int` | `20` | Maximum health |
| `damage` | `int` | `4` | Damage per hit (reserved Phase 3) |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `health` | `int` | `20` | Current health; set to `max_health` on ready |
| `target_position` | `Vector2` | `Vector2.ZERO` | World-space move target; set by `set_target()` |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `dir` | `_physics_process()` | `Vector2` | Normalized direction toward `target_position` |

*`crawler.gd`, `slime.gd`, `raider.gd` — extend Enemy with no additional variables.*

---

## `scripts/raids/raid_director.gd` — class `RaidDirector` (extends Node)

### @export
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `enabled` | `bool` | `false` | Master switch; all raid logic skipped when false |
| `base_threat` | `int` | `10` | Base threat before player progress scaling |
| `check_once_per_night` | `bool` | `true` | Prevents double raid rolls per night |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `settlement` | `Settlement` | `null` | Read `P_raid_factor`; call `register_raid_event()` |
| `world` | `World` | `null` | Get spawn points, TownHall position, `add_enemy()` |
| `last_night_checked_day_index` | `int` | `-999` | Day index of last processed night check |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `player_progress` | `_maybe_spawn_raid()` | `int` | `world.get_progress_score()`; currently always 1 |
| `threat_score` | `_maybe_spawn_raid()` | `int` | `base_threat + player_progress * 5` |
| `raid_chance` | `_maybe_spawn_raid()` | `float` | `threat_score * P_raid_factor * 0.01` |
| `wave_size` | `_spawn_raid_wave()` | `int` | `clamp(floor(2 + threat_score * 0.5), 2, 12)` |
| `spawn_points` | `_spawn_raid_wave()` | `Array` | Candidate spawn `Vector2` positions from `world.get_raid_spawn_points()` |
| `spawn_pos` | `_spawn_raid_wave()` | `Vector2` | Randomly selected spawn point |
| `raider_scene` | `_spawn_raid_wave()` | `PackedScene` | Preloaded Raider scene |
| `raider` | `_spawn_raid_wave()` | `Raider` | Each instantiated raider; offset `i * 16 px` horizontally |

---

## `scripts/ui/hud.gd` — class `HUD` (extends CanvasLayer)

### @onready
| Variable | Type | Scene path | Definition |
|----------|------|------------|------------|
| `coherence_bar` | `ProgressBar` | `$TopLeft/CLRPanel/CoherenceBar` | C display (0–100); red when C < 25 |
| `load_bar` | `ProgressBar` | `$TopLeft/CLRPanel/LoadBar` | L display (0–100); red when L > 75 |
| `resilience_bar` | `ProgressBar` | `$TopLeft/CLRPanel/ResilienceBar` | R display (0–100); red when R < 25 |
| `town_hall_panel` | `Panel` | `$TownHallPanel` | Stub Town Hall info panel; toggled by T key |

### Class vars
| Variable | Type | Default | Definition |
|----------|------|---------|------------|
| `_c_label` | `Label` | `null` | Reserved for C bar label (declared, not yet used) |
| `_l_label` | `Label` | `null` | Reserved for L bar label (declared, not yet used) |
| `_r_label` | `Label` | `null` | Reserved for R bar label (declared, not yet used) |

### Local vars
| Variable | Scope | Type | Definition |
|----------|-------|------|------------|
| `c` | `_on_settlement_state_updated()` | `float` | C value from signal state dict |
| `l` | `_on_settlement_state_updated()` | `float` | L value from signal state dict |
| `r` | `_on_settlement_state_updated()` | `float` | R value from signal state dict |
| `style` | multiple | `StyleBoxFlat` | Temp style object for bar fill color |

---

## Cross-System Variable Flows

```
FIRST RUN
─────────
world_seed (@export, World)
  └─► WorldGen.generate(world, seed)
        ├─► WorldGen.seed = seed_in          (stored for reference)
        ├─► _setup_tileset(world)            (programmatic TileSet)
        └─► _generate_terrain(world, seed)
              └─► world.set_tile(x, y, id, layer=0, track_modified=FALSE)
                    ├─► tile_data[key] = id    (always written)
                    ├─► TilemapAdapter render  (always rendered)
                    └─► modified_chunks        (SKIPPED — baseline)

PLAYER MINE (LMB hold)
──────────────────────
Player._handle_mining(delta)
  └─► world.get_tile_at(tile_pos)       (reads tile_data)
  └─► world.set_tile(x, y, "air", 0, track_modified=TRUE)
        ├─► tile_data.erase(key)
        ├─► TileMap erase_cell()
        └─► modified_chunks[ckey][pk] = "air"   (delta recorded)
  └─► inventory[item_id] += 1

PLAYER PLACE (RMB click)  [1.1]
────────────────────────────────
Player._handle_place()
  └─► guards: range, target empty, inventory > 0
  └─► world.set_tile(x, y, place_tile_id, 0, track_modified=TRUE)
        ├─► tile_data[key] = tile_id
        ├─► TileMap set_cell()
        └─► modified_chunks[ckey][pk] = tile_id   (delta recorded)
  └─► inventory[need_item] -= 1

SAVE (F5)  [1.2]
────────────────
GameRoot._input() → save_manager.save_game(world)
  └─► payload["world_seed"] = world.world_seed
  └─► payload["deltas"] = chunk_serializer.serialize_modified(modified_chunks)
  └─► JSON write → SAVE_PATH

LOAD (F9)  [1.2]
────────────────
GameRoot._input() → save_manager.load_game(world)
  1. JSON read + parse SAVE_PATH
  2. world.world_seed = seed_val
  3. world.clear_world()
       ├─► tile_data.clear()
       ├─► modified_chunks.clear()
       ├─► tm_fg.clear()
       └─► tm_bg.clear()
  4. world.world_gen.generate(world, seed_val)   (deterministic baseline)
  5. save_manager._apply_deltas(world, decoded)
       └─► world.set_tile(wx, wy, tile_id, 0, track_modified=FALSE)
             (restores edits without recording them as new deltas)
  6. world.modified_chunks.clear()               (post-load starts clean)
  → GameRoot re-injects world ref into Player

SETTLEMENT TICK (every 5s)
──────────────────────────
SettlementTick._tick()
  └─► settlement.gather_observables() → obs {}
  └─► coherence_model.compute_nodes(obs, nodes) → updated nodes {}
  └─► C, L, R, P_prod, P_injury, P_raid_factor computed + written to settlement
  └─► settlement_state_updated.emit({C, L, R})
        └─► HUD._on_settlement_state_updated() → bars updated + colored

RAID (disabled — enabled=false)
───────────────────────────────
RaidDirector.on_night_started(day_index)
  └─► reads settlement.P_raid_factor
  └─► world.add_enemy(raider)
  └─► settlement.register_raid_event(wave_size)
        └─► mutates nodes["L_THREAT_PRESSURE"] + nodes["C_RHYTHM"]
```

---

## Controls Reference
| Input | Action | Variables driven |
|-------|--------|-----------------|
| A / D | Move | `velocity.x` via `speed` |
| Space | Jump | `velocity.y` via `jump_velocity` |
| LMB hold | Mine tile | `_mine_timer`, `_mine_target`, `inventory` |
| RMB click | Place tile | `place_tile_id`, `inventory` |
| F5 | Save game | `world.world_seed`, `world.modified_chunks` → disk |
| F9 | Load game | disk → `world.world_seed`, `tile_data`, TileMaps |
| T | Toggle Town Hall panel | `town_hall_panel.visible` |
| E | Interact (reserved) | — |
