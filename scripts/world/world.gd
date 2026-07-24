extends Node2D
## Owns the block grid, the TileMapLayer presentation, torch lights,
## and the terrain delta record used by save/load.

signal block_changed(cell: Vector2i, block_id: String)

const BUSH_REGROW_SECONDS := 90.0
const BUSH_RETRY_SECONDS := 10.0
# FQ-12: a planted crop ripens after this many seconds; if it is not sitting on
# tilled soil yet (e.g. player mid-edit) it waits this retry interval.
const CROP_GROW_SECONDS := 60.0
const CROP_RETRY_SECONDS := 5.0
const CROP_IDS := ["crop_seedling", "crop_ripe"]
# FQ-13: ore-family blocks (FQ-10) the ore tick keys off when choosing a spawn.
const ORE_IDS := ["ore", "coal", "copper_ore", "tin_ore", "iron_ore",
	"silver_ore", "crystal"]

var width := 240
var height := 80

var world_seed: int = 0
var cells: Dictionary = {}          # Vector2i -> block_id (air cells absent)
var deltas: Dictionary = {}         # Vector2i -> block_id ("air" = mined out)
var surface: Dictionary = {}        # int x -> int y of surface
var hall_info: Dictionary = {}
var bush_regrow: Dictionary = {}    # Vector2i -> float seconds until regrowth
var crop_growth: Dictionary = {}    # FQ-12: Vector2i -> float seconds until a seedling ripens

var _tilemap: TileMapLayer
var _source_ids: Dictionary = {}    # block_id -> Array of tileset source ids (FQ-09V: one per variant)
var _lights: Dictionary = {}        # Vector2i -> PointLight2D
var _light_texture: GradientTexture2D
var _opaque_masks: Dictionary = {}  # block_id -> BitMap of the tile's opaque pixels

# FQ-09W: natural backing walls — a purely visual rear plane derived from
# the generated surface each setup. No physics/occlusion layers, no deltas,
# never saved; mining a foreground block reveals the wall behind it.
var _walls: TileMapLayer
var _wall_source_ids: Dictionary = {}   # wall_id -> tileset source id
# FQ-09W: column skylight cache — int x -> first solid y from the top of the
# LIVE cells (mining a shaft re-admits daylight). Invalidated per column on
# any block change; documented approximation (no lateral light bleed).
var _sky_line: Dictionary = {}

const BackdropScript := preload("res://scripts/world/world_backdrop.gd")
const ItemDropScript := preload("res://scripts/entities/item_drop.gd")   # R-08 slice 3
const WALL_MATERIALS := {"dirt_wall": "dirt", "stone_wall": "stone"}

const BLOCK_COLORS := {
	"dirt": Color(0.47, 0.33, 0.18),
	"grass": Color(0.30, 0.62, 0.25),
	"wood": Color(0.62, 0.45, 0.22),
	"stone": Color(0.45, 0.46, 0.50),
	"ore": Color(0.72, 0.62, 0.35),
	"coal": Color(0.18, 0.18, 0.20),
	"copper_ore": Color(0.78, 0.44, 0.28),
	"tin_ore": Color(0.70, 0.72, 0.66),
	"iron_ore": Color(0.62, 0.50, 0.44),
	"silver_ore": Color(0.82, 0.84, 0.90),
	"crystal": Color(0.45, 0.78, 0.85),
	"torch": Color(1.0, 0.75, 0.25),
	"lantern": Color(0.95, 0.90, 0.55),
	"berry_bush": Color(0.20, 0.45, 0.18),
	"farm_soil": Color(0.35, 0.24, 0.14),
	"crop_seedling": Color(0.48, 0.65, 0.30),
	"crop_ripe": Color(0.85, 0.72, 0.25),
	"tree_trunk": Color(0.48, 0.35, 0.20),
	"tree_leaves": Color(0.22, 0.44, 0.19),
	"town_hall_core": Color(0.42, 0.30, 0.55),
}


func _ready() -> void:
	_light_texture = _make_light_texture()
	# FQ-09W plane order (back to front): scenic backdrop, backing walls,
	# foreground blocks. Only the Blocks layer has collision/occlusion.
	var backdrop: Node2D = BackdropScript.new()
	backdrop.z_index = -10
	add_child(backdrop)
	_walls = TileMapLayer.new()
	_walls.name = "BackgroundWalls"
	_walls.z_index = -2
	_walls.tile_set = _build_wall_tileset()
	add_child(_walls)
	_tilemap = TileMapLayer.new()
	_tilemap.name = "Blocks"
	_tilemap.tile_set = _build_tileset()
	add_child(_tilemap)


func _process(delta: float) -> void:
	_tick_bush_regrowth(delta)
	_tick_crop_growth(delta)


## FQ-12: ripens planted seedlings after their timer. A seedling only ripens on
## tilled soil; if its support is gone it is removed (crops never float), and if
## the cell was mined/replaced the timer is simply dropped — crops never regrow
## into invalid cells.
func _tick_crop_growth(delta: float) -> void:
	for cell in crop_growth.keys():
		crop_growth[cell] -= delta
		if crop_growth[cell] > 0.0:
			continue
		if block_at(cell) != "crop_seedling":
			crop_growth.erase(cell)
		elif block_at(cell + Vector2i(0, 1)) == "farm_soil":
			cells[cell] = "crop_ripe"
			deltas[cell] = "crop_ripe"
			_set_tile(cell, "crop_ripe")
			block_changed.emit(cell, "crop_ripe")
			crop_growth.erase(cell)
		elif not _is_supported(cell):
			cells.erase(cell)
			deltas[cell] = "air"
			_set_tile(cell, "air")
			block_changed.emit(cell, "air")
			crop_growth.erase(cell)
		else:
			crop_growth[cell] = CROP_RETRY_SECONDS


func _tick_bush_regrowth(delta: float) -> void:
	for cell in bush_regrow.keys():
		bush_regrow[cell] -= delta
		if bush_regrow[cell] > 0.0:
			continue
		if block_at(cell) == "air":
			# Wave E: only regrow if a solid support block is present below.
			if not _is_supported(cell):
				bush_regrow[cell] = BUSH_RETRY_SECONDS
			else:
				cells[cell] = "berry_bush"
				deltas[cell] = "berry_bush"
				_set_tile(cell, "berry_bush")
				block_changed.emit(cell, "berry_bush")
				bush_regrow.erase(cell)
		else:
			# Cell is occupied (player built there); try again later.
			bush_regrow[cell] = BUSH_RETRY_SECONDS


func setup(new_seed: int, saved_deltas: Dictionary = {}, saved_regrow: Dictionary = {},
		saved_crop: Dictionary = {}) -> void:
	world_seed = new_seed
	deltas = saved_deltas.duplicate()
	bush_regrow = saved_regrow.duplicate()
	crop_growth = saved_crop.duplicate()
	for cell in _lights.keys():
		_lights[cell].queue_free()
	_lights.clear()
	var config: WorldConfig = GameState.current_config
	if config == null:
		config = WorldConfig.new()
	var gen := WorldGen.generate(world_seed, config)
	cells = gen["cells"]
	surface = gen["surface"]
	width = int(gen["width"])
	height = int(gen["height"])
	hall_info = WorldGen.stamp_town_hall(cells, surface, width / 2)
	# FQ-09W: natural backing walls derive from the pristine generated surface
	# (before deltas), so the same seed/config always yields the same wall map
	# and player edits can never alter it.
	_rebuild_walls(config)
	_sky_line.clear()
	for cell in deltas:
		var block_id: String = deltas[cell]
		if block_id == "air":
			cells.erase(cell)
		else:
			cells[cell] = block_id
	# Wave E: sweep for requires_support blocks that lost their support via deltas.
	# No drops during load-time cleanup. Berry bushes reschedule regrowth; FQ-12
	# crops are simply removed (they never auto-regrow or float).
	for sweep_cell in cells.keys():
		var sbid: String = cells[sweep_cell]
		if BlockRegistry.requires_support(sbid) and not _is_supported(sweep_cell):
			cells.erase(sweep_cell)
			deltas[sweep_cell] = "air"
			crop_growth.erase(sweep_cell)
			if sbid == "berry_bush" and not bush_regrow.has(sweep_cell):
				bush_regrow[sweep_cell] = BUSH_REGROW_SECONDS
	_redraw_all()


func tile_size() -> int:
	return BlockRegistry.tile_size


func cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / tile_size()), floori(world_pos.y / tile_size()))


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * tile_size() + Vector2.ONE * (tile_size() / 2.0)


func block_at(cell: Vector2i) -> String:
	return cells.get(cell, "air")


func is_solid_at(cell: Vector2i) -> bool:
	return BlockRegistry.is_solid(block_at(cell))


## Opaque-pixel mask of a block's tile texture (art or generated fallback),
## so damage overlays can stay inside the visible sprite — cracks on a thin
## tree trunk or a torch must not float in the transparent part of the cell.
## Cached per block id; like the tileset, masks reflect the art present when
## first built (null for air/unknown ids).
func block_opaque_mask(block_id: String) -> BitMap:
	if block_id == "air" or not BlockRegistry.blocks.has(block_id):
		return null
	if not _opaque_masks.has(block_id):
		var img: Image = _make_block_texture(block_id, tile_size()).get_image()
		var mask := BitMap.new()
		mask.create_from_image_alpha(img, 0.1)
		_opaque_masks[block_id] = mask
	return _opaque_masks[block_id]


func can_mine(cell: Vector2i, tool_tier: int) -> bool:
	var block_id := block_at(cell)
	if block_id == "air":
		return false
	if BlockRegistry.has_tag(block_id, "protected"):
		return false
	return BlockRegistry.required_tool_tier(block_id) <= tool_tier


func mine_time(cell: Vector2i, base_mine_speed: float) -> float:
	return BlockRegistry.hardness(block_at(cell)) / maxf(base_mine_speed, 0.01)


## Returns true if the cell directly below has a solid block.
func _is_supported(cell: Vector2i) -> bool:
	return is_solid_at(cell + Vector2i(0, 1))


## Removes the block and returns its drops. Caller adds drops to inventory.
## Wave E: if the block directly above requires solid support, it is also broken,
## its drops are merged in, and its regrowth is scheduled.
func break_block(cell: Vector2i) -> Dictionary:
	var block_id := block_at(cell)
	if block_id == "air":
		return {}
	var block_drops := BlockRegistry.drops(block_id)
	cells.erase(cell)
	deltas[cell] = "air"
	_set_tile(cell, "air")
	if block_id == "berry_bush":
		bush_regrow[cell] = BUSH_REGROW_SECONDS
	crop_growth.erase(cell)   # FQ-12: harvesting/removing a crop clears its timer
	block_changed.emit(cell, "air")
	# Wave E: check the cell directly above; if it requires support it's now floating.
	var above := Vector2i(cell.x, cell.y - 1)
	var above_id := block_at(above)
	if above_id != "air" and BlockRegistry.requires_support(above_id):
		var above_drops := BlockRegistry.drops(above_id)
		cells.erase(above)
		deltas[above] = "air"
		_set_tile(above, "air")
		crop_growth.erase(above)
		# Only berry bushes reschedule; FQ-12 crops just fall (no auto-regrow).
		if above_id == "berry_bush":
			bush_regrow[above] = BUSH_REGROW_SECONDS
		block_changed.emit(above, "air")
		for item_id in above_drops:
			block_drops[item_id] = int(block_drops.get(item_id, 0)) + int(above_drops[item_id])
	return block_drops


func place_block(cell: Vector2i, block_id: String) -> bool:
	if block_at(cell) != "air":
		return false
	if not BlockRegistry.is_placeable(block_id):
		return false
	cells[cell] = block_id
	deltas[cell] = block_id
	_set_tile(cell, block_id)
	block_changed.emit(cell, block_id)
	return true


## FQ-12: tills a dirt/grass cell into farm_soil (a delta, saved). Returns true
## on success. Only natural earth can be tilled — not stone, ore, or structures.
func till_soil(cell: Vector2i) -> bool:
	if block_at(cell) not in ["dirt", "grass"]:
		return false
	cells[cell] = "farm_soil"
	deltas[cell] = "farm_soil"
	_set_tile(cell, "farm_soil")
	block_changed.emit(cell, "farm_soil")
	return true


## FQ-12: plants a seedling in an air cell sitting directly on tilled soil, and
## schedules its growth. Returns false if the target is occupied or not on
## farm_soil (so crops can never be planted floating).
func plant_crop(cell: Vector2i) -> bool:
	if block_at(cell) != "air":
		return false
	if block_at(cell + Vector2i(0, 1)) != "farm_soil":
		return false
	cells[cell] = "crop_seedling"
	deltas[cell] = "crop_seedling"
	_set_tile(cell, "crop_seedling")
	crop_growth[cell] = CROP_GROW_SECONDS
	block_changed.emit(cell, "crop_seedling")
	return true


## FQ-12: a simple food-yard score for future base levels — tilled soil plus any
## growing/ripe crop cell.
func farm_tile_count() -> int:
	var count := 0
	for cell in cells:
		var id: String = cells[cell]
		if id == "farm_soil" or id in CROP_IDS:
			count += 1
	return count


## FQ-13: nearest growing/ripe crop cell within `radius` (Chebyshev) of `from`,
## or Vector2i(-1, -1) if none. Used by the crop-eating thornrat to pick a
## target. Cheap scan of the crop_growth timers plus any ripe cells.
func nearest_crop(from: Vector2i, radius: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := radius + 1
	for cell in cells:
		if not (cells[cell] in CROP_IDS):
			continue
		var d: int = maxi(absi(cell.x - from.x), absi(cell.y - from.y))
		if d <= radius and d < best_d:
			best_d = d
			best = cell
	return best


## FQ-13: a thornrat eating a crop — clears the crop cell to air with no drops
## (the player gets nothing; the loss IS the pressure). Mirrors the crop-removal
## bookkeeping in break_block without the harvest yield. Returns true if a crop
## was actually removed.
func eat_crop(cell: Vector2i) -> bool:
	if not (block_at(cell) in CROP_IDS):
		return false
	cells.erase(cell)
	deltas[cell] = "air"
	_set_tile(cell, "air")
	crop_growth.erase(cell)
	block_changed.emit(cell, "air")
	return true


## R-08: the nearest RIPE crop within `radius` (Chebyshev), or (-1,-1). Unlike
## nearest_crop this ignores seedlings -- a farmhand only harvests ripe crops.
func nearest_ripe_crop(from: Vector2i, radius: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := radius + 1
	for cell in cells:
		if cells[cell] != "crop_ripe":
			continue
		var d: int = maxi(absi(cell.x - from.x), absi(cell.y - from.y))
		if d <= radius and d < best_d:
			best_d = d
			best = cell
	return best


## R-08: a farmhand harvesting a ripe crop -- removes it and returns its drops
## (food + seed). Only crop_ripe yields; anything else returns {}. Mirrors
## eat_crop's bookkeeping but keeps the harvest yield for the settlement.
func harvest_crop(cell: Vector2i) -> Dictionary:
	if block_at(cell) != "crop_ripe":
		return {}
	var drops: Dictionary = BlockRegistry.get_block("crop_ripe").get("drops", {}).duplicate()
	cells.erase(cell)
	deltas[cell] = "air"
	_set_tile(cell, "air")
	crop_growth.erase(cell)
	block_changed.emit(cell, "air")
	return drops


## R-08 slice 3: spawn a loose ground item at `pos`. Mining yield and enemy loot
## route their drops through here so a hauler settler can carry them to the
## stockpile; the player auto-collects any within reach (Player.collect_ground_drops).
## Refuses an empty id or a non-positive count -- neither is a real ground item.
func spawn_item_drop(pos: Vector2, item_id: String, count: int = 1) -> Node:
	if item_id == "" or count <= 0:
		return null
	var drop := ItemDropScript.new()
	add_child(drop)
	drop.setup(self, item_id, count, pos)
	return drop


## R-08 slice 3: the nearest live ground item drop within `radius` cells
## (Chebyshev) of `from`, or null. Skips drops already queued for deletion so a
## just-collected drop is never chased. Used by the hauler to pick a target.
func nearest_item_drop(from: Vector2i, radius: int) -> Node:
	var best: Node = null
	var best_d: int = radius + 1
	for d in get_tree().get_nodes_in_group("item_drops"):
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		var c: Vector2i = cell_of(d.global_position)
		var dist: int = maxi(absi(c.x - from.x), absi(c.y - from.y))
		if dist <= radius and dist < best_d:
			best_d = dist
			best = d
	return best


## FQ-13: true if any ore-family block sits within `radius` (Chebyshev) of
## `cell`. The ore tick spawns only where the underground actually carries ore,
## so it reads as an ore-pocket nuisance rather than a generic crawler.
func has_ore_within(cell: Vector2i, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if block_at(cell + Vector2i(dx, dy)) in ORE_IDS:
				return true
	return false


func has_light_at(cell: Vector2i) -> bool:
	return _lights.has(cell)


## Counts cells within Chebyshev radius of a center that satisfy a predicate.
func count_near(center: Vector2i, radius: int, predicate: Callable) -> int:
	var count := 0
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if predicate.call(block_at(cell), cell):
				count += 1
	return count


func world_bounds() -> Rect2:
	return Rect2(0, 0, width * tile_size(), height * tile_size())


func _redraw_all() -> void:
	_tilemap.clear()
	for cell in cells:
		_set_tile(cell, cells[cell])


# ---------- FQ-09W: backing walls and column skylight ----------

## Fills the BackgroundWalls layer from the generated surface: a dirt wall
## band for the configured dirt depth, stone wall below, nothing at or above
## the surface row (mining the top block reveals sky/backdrop, not a wall).
func _rebuild_walls(config: WorldConfig) -> void:
	_walls.clear()
	var dirt_depth := int(config.gen("dirt_depth"))
	for x in range(width):
		var sy: int = int(surface.get(x, height))
		for y in range(sy + 1, height):
			var wall_id := "dirt_wall" if y <= sy + dirt_depth else "stone_wall"
			_walls.set_cell(Vector2i(x, y), _wall_source_ids[wall_id], Vector2i.ZERO)


## The wall id behind a cell ("" above the wall line) — a visual-only query.
func wall_at(cell: Vector2i) -> String:
	var sid := _walls.get_cell_source_id(cell)
	if sid == -1:
		return ""
	for wall_id in _wall_source_ids:
		if _wall_source_ids[wall_id] == sid:
			return wall_id
	return ""


## First solid cell y from the top of column x in the LIVE world (cached per
## column, invalidated on block change). Cells above it are sky-exposed:
## mining a full shaft makes the column admit daylight to the shaft floor.
func sky_line(x: int) -> int:
	if x < 0 or x >= width:
		return height   # off-world columns are open sky
	if not _sky_line.has(x):
		var y := 0
		while y < height and not BlockRegistry.is_solid(cells.get(Vector2i(x, y), "air")):
			y += 1
		_sky_line[x] = y
	return _sky_line[x]


## Walls have no physics or occlusion layers at all — variety in this layer
## can never change collision, lighting, shelter, or settlement math.
func _build_wall_tileset() -> TileSet:
	var ts := TileSet.new()
	var t := tile_size()
	ts.tile_size = Vector2i(t, t)
	for wall_id in WALL_MATERIALS:
		var src := TileSetAtlasSource.new()
		src.texture = _make_wall_texture(wall_id, str(WALL_MATERIALS[wall_id]), t)
		src.texture_region_size = Vector2i(t, t)
		src.create_tile(Vector2i.ZERO)
		_wall_source_ids[wall_id] = ts.add_source(src)
	return ts


## Back-wall tile: art at art/generated/back_walls/<wall_id>.png when
## present, else the matching block texture pushed darker and fully opaque
## (walls must read quieter than foreground and never as open sky).
func _make_wall_texture(wall_id: String, base_block: String, t: int) -> ImageTexture:
	var art := BlockRegistry.visual_texture("back_walls", wall_id) as ImageTexture
	if art != null:
		return _normalize_art(art, t)
	var img: Image = _make_block_texture(base_block, t).get_image()
	for y in range(t):
		for x in range(t):
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * 0.40, c.g * 0.40, c.b * 0.46, 1.0))
	return ImageTexture.create_from_image(img)


func _set_tile(cell: Vector2i, block_id: String) -> void:
	_sky_line.erase(cell.x)   # FQ-09W: any block change re-derives that column's skylight
	# _block_textures guarantees at least one source per known block; the
	# is_empty guard makes that invariant explicit rather than an index crash.
	if block_id == "air" or (_source_ids.get(block_id, []) as Array).is_empty():
		_tilemap.erase_cell(cell)
	else:
		# FQ-09V: blocks with a variant pool pick one deterministically from
		# world seed + cell position — the same world always renders the same
		# variety, and nothing about the choice ever enters saves.
		var sids: Array = _source_ids[block_id]
		var idx := 0
		if sids.size() > 1:
			idx = posmod(hash(Vector3i(cell.x, cell.y, world_seed)), sids.size())
		_tilemap.set_cell(cell, sids[idx], Vector2i.ZERO)
	_update_light(cell, block_id)


func _update_light(cell: Vector2i, block_id: String) -> void:
	var wants_light := block_id != "air" and BlockRegistry.emits_light(block_id)
	if wants_light and not _lights.has(cell):
		var light := PointLight2D.new()
		light.texture = _light_texture
		var radius := float(BlockRegistry.light_radius(block_id))
		light.texture_scale = (radius * 2.0) / float(_light_texture.width)
		light.energy = 1.3
		light.color = Color(1.0, 0.85, 0.6)
		light.shadow_enabled = true
		light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
		light.position = cell_center(cell)
		add_child(light)
		_lights[cell] = light
	elif not wants_light and _lights.has(cell):
		_lights[cell].queue_free()
		_lights.erase(cell)


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	var t := tile_size()
	ts.tile_size = Vector2i(t, t)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.add_occlusion_layer()
	var half := t / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	for block_id in BlockRegistry.blocks:
		if block_id == "air":
			continue
		# FQ-09V: one atlas source per variant texture (usually just one —
		# the single-image/fallback path). Every variant of a block carries
		# identical physics and occlusion, so variety can never change
		# collision, lighting, or shelter behavior.
		var sids: Array = []
		for tex: ImageTexture in _block_textures(block_id, t):
			var src := TileSetAtlasSource.new()
			src.texture = tex
			src.texture_region_size = Vector2i(t, t)
			src.create_tile(Vector2i.ZERO)
			sids.append(ts.add_source(src))
			var tile_data := src.get_tile_data(Vector2i.ZERO, 0)
			if BlockRegistry.is_solid(block_id):
				tile_data.add_collision_polygon(0)
				tile_data.set_collision_polygon_points(0, 0, square)
			if BlockRegistry.blocks_light(block_id):
				var occluder := OccluderPolygon2D.new()
				occluder.polygon = square
				if tile_data.has_method("add_occluder_polygon"):
					tile_data.add_occluder_polygon(0)
					tile_data.set_occluder_polygon(0, 0, occluder)
				else:
					tile_data.set_occluder(0, occluder)
		_source_ids[block_id] = sids
	return ts


## FQ-09V: the ordered textures a block renders with — its variant pool when
## one exists (each image normalized to tile size), else exactly the single
## image-or-fallback texture from _make_block_texture, unchanged.
func _block_textures(block_id: String, t: int) -> Array:
	var out: Array = []
	for variant: Texture2D in BlockRegistry.visual_variant_textures("blocks", block_id):
		out.append(_normalize_art(variant as ImageTexture, t))
	if out.is_empty():
		out.append(_make_block_texture(block_id, t))
	return out


## FQ-09V: rebuilds all tile sources from the art currently on disk (variant
## pools included) and redraws. A smoke/dev hook — gameplay builds the
## tileset once at _ready, matching the FQ-07 "art loads at world entry"
## rule. Also drops the crack-overlay opacity masks so they re-derive.
func rebuild_tileset() -> void:
	_source_ids.clear()
	_opaque_masks.clear()
	_tilemap.tile_set = _build_tileset()
	_redraw_all()


func _make_block_texture(block_id: String, t: int) -> ImageTexture:
	# FQ-07: image-first — a PNG at art/generated/blocks/<id>.png (or an
	# explicit visual_assets.json entry) wins; otherwise the generated
	# color/shape below is the fallback. Mismatched sizes are resized so a
	# stray art dimension can never corrupt the tileset.
	var art := BlockRegistry.visual_texture("blocks", block_id) as ImageTexture
	if art != null:
		return _normalize_art(art, t)
	var color: Color = BLOCK_COLORS.get(block_id, Color.MAGENTA)
	var img := Image.create(t, t, false, Image.FORMAT_RGBA8)
	if block_id == "tree_trunk":
		# FQ-09R: transparent tile with a bark-shaded trunk bar, slimmer than a
		# full wood block so the player visibly passes in front of it.
		img.fill(Color(0, 0, 0, 0))
		var bark := color.darkened(0.3)
		for y in range(t):
			for x in range(t / 2 - 3, t / 2 + 3):
				img.set_pixel(x, y, color)
			img.set_pixel(t / 2 - 3, y, bark)
			img.set_pixel(t / 2 + 2, y, bark)
	elif block_id == "tree_leaves":
		# FQ-09R: leafy blob — full square with clipped corners plus light flecks
		# so canopies read as foliage at 16px.
		img.fill(Color(0, 0, 0, 0))
		var fleck := color.lightened(0.25)
		for y in range(t):
			for x in range(t):
				var corner := mini(x, t - 1 - x) + mini(y, t - 1 - y)
				if corner > 2:
					img.set_pixel(x, y, fleck if (x * 7 + y * 3) % 11 == 0 else color)
	elif block_id == "berry_bush":
		# Transparent tile with a rounded bush and berries.
		img.fill(Color(0, 0, 0, 0))
		for y in range(t / 4, t):
			for x in range(2, t - 2):
				img.set_pixel(x, y, color)
		for dot in [Vector2i(4, 8), Vector2i(9, 6), Vector2i(12, 10), Vector2i(6, 12)]:
			img.set_pixel(dot.x, dot.y, Color(0.85, 0.15, 0.20))
	elif block_id == "lantern":
		# Hanging lamp: small bright housing on a short hook.
		img.fill(Color(0, 0, 0, 0))
		for y in range(2, 5):
			img.set_pixel(t / 2, y, Color(0.4, 0.4, 0.45))
		for y in range(5, 12):
			for x in range(t / 2 - 3, t / 2 + 3):
				img.set_pixel(x, y, color)
	elif block_id == "torch":
		# Transparent tile with a small stick + flame so torches read as objects.
		img.fill(Color(0, 0, 0, 0))
		for y in range(t / 2, t):
			for x in range(t / 2 - 1, t / 2 + 1):
				img.set_pixel(x, y, Color(0.45, 0.30, 0.15))
		for y in range(t / 4, t / 2):
			for x in range(t / 2 - 2, t / 2 + 2):
				img.set_pixel(x, y, color)
	elif block_id == "crop_seedling":
		# FQ-12: a small green sprout in the lower half of the tile.
		img.fill(Color(0, 0, 0, 0))
		var stem := color.darkened(0.15)
		for y in range(t / 2, t):
			img.set_pixel(t / 2, y, stem)
			img.set_pixel(t / 2 - 1, y, stem)
		for leaf in [Vector2i(t / 2 - 3, t / 2 + 1), Vector2i(t / 2 + 2, t / 2 + 1),
				Vector2i(t / 2 - 2, t / 2 + 3), Vector2i(t / 2 + 1, t / 2 + 3)]:
			img.set_pixel(leaf.x, leaf.y, color)
	elif block_id == "crop_ripe":
		# FQ-12: taller golden stalks with grain heads — visibly ready to harvest.
		img.fill(Color(0, 0, 0, 0))
		var stalk := Color(0.55, 0.45, 0.18)
		for sx in [t / 2 - 3, t / 2, t / 2 + 3]:
			for y in range(3, t):
				img.set_pixel(sx, y, stalk)
			for hy in range(3, 8):
				img.set_pixel(sx - 1, hy, color)
				img.set_pixel(sx + 1, hy, color)
	else:
		img.fill(color)
		# Slight edge shading for tile readability.
		var edge := color.darkened(0.25)
		for i in range(t):
			img.set_pixel(i, t - 1, edge)
			img.set_pixel(t - 1, i, edge)
	return ImageTexture.create_from_image(img)


## Nearest-neighbor resize guard shared by every block-art path, so a stray
## art dimension can never corrupt the tileset.
func _normalize_art(art: ImageTexture, t: int) -> ImageTexture:
	var art_img: Image = art.get_image()
	if art_img.get_width() != t or art_img.get_height() != t:
		art_img.resize(t, t, Image.INTERPOLATE_NEAREST)
		return ImageTexture.create_from_image(art_img)
	return art


func _make_light_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	return tex


func serialize_deltas() -> Dictionary:
	var out := {}
	for cell in deltas:
		out["%d,%d" % [cell.x, cell.y]] = deltas[cell]
	return out


func serialize_bush_regrow() -> Dictionary:
	var out := {}
	for cell in bush_regrow:
		out["%d,%d" % [cell.x, cell.y]] = bush_regrow[cell]
	return out


static func parse_bush_regrow(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = float(raw[key])
	return out


## FQ-12: crop growth timers persist exactly like bush regrowth.
func serialize_crop_growth() -> Dictionary:
	var out := {}
	for cell in crop_growth:
		out["%d,%d" % [cell.x, cell.y]] = crop_growth[cell]
	return out


static func parse_crop_growth(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = float(raw[key])
	return out


static func parse_deltas(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = str(raw[key])
	return out
