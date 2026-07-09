extends Node2D
## Owns the block grid, the TileMapLayer presentation, torch lights,
## and the terrain delta record used by save/load.

signal block_changed(cell: Vector2i, block_id: String)

const BUSH_REGROW_SECONDS := 90.0
const BUSH_RETRY_SECONDS := 10.0

var width := 240
var height := 80

var world_seed: int = 0
var cells: Dictionary = {}          # Vector2i -> block_id (air cells absent)
var deltas: Dictionary = {}         # Vector2i -> block_id ("air" = mined out)
var surface: Dictionary = {}        # int x -> int y of surface
var hall_info: Dictionary = {}
var bush_regrow: Dictionary = {}    # Vector2i -> float seconds until regrowth

var _tilemap: TileMapLayer
var _source_ids: Dictionary = {}    # block_id -> tileset source id
var _lights: Dictionary = {}        # Vector2i -> PointLight2D
var _light_texture: GradientTexture2D
var _opaque_masks: Dictionary = {}  # block_id -> BitMap of the tile's opaque pixels

const BLOCK_COLORS := {
	"dirt": Color(0.47, 0.33, 0.18),
	"grass": Color(0.30, 0.62, 0.25),
	"wood": Color(0.62, 0.45, 0.22),
	"stone": Color(0.45, 0.46, 0.50),
	"ore": Color(0.72, 0.62, 0.35),
	"torch": Color(1.0, 0.75, 0.25),
	"lantern": Color(0.95, 0.90, 0.55),
	"berry_bush": Color(0.20, 0.45, 0.18),
	"tree_trunk": Color(0.48, 0.35, 0.20),
	"tree_leaves": Color(0.22, 0.44, 0.19),
	"town_hall_core": Color(0.42, 0.30, 0.55),
}


func _ready() -> void:
	_light_texture = _make_light_texture()
	_tilemap = TileMapLayer.new()
	_tilemap.name = "Blocks"
	_tilemap.tile_set = _build_tileset()
	add_child(_tilemap)


func _process(delta: float) -> void:
	_tick_bush_regrowth(delta)


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


func setup(new_seed: int, saved_deltas: Dictionary = {}, saved_regrow: Dictionary = {}) -> void:
	world_seed = new_seed
	deltas = saved_deltas.duplicate()
	bush_regrow = saved_regrow.duplicate()
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
	for cell in deltas:
		var block_id: String = deltas[cell]
		if block_id == "air":
			cells.erase(cell)
		else:
			cells[cell] = block_id
	# Wave E: sweep for requires_support blocks that lost their support via deltas.
	# No drops during load-time cleanup; just convert to scheduled regrowth.
	for sweep_cell in cells.keys():
		var sbid: String = cells[sweep_cell]
		if BlockRegistry.requires_support(sbid) and not _is_supported(sweep_cell):
			cells.erase(sweep_cell)
			deltas[sweep_cell] = "air"
			if not bush_regrow.has(sweep_cell):
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
	block_changed.emit(cell, "air")
	# Wave E: check the cell directly above; if it requires support it's now floating.
	var above := Vector2i(cell.x, cell.y - 1)
	var above_id := block_at(above)
	if above_id != "air" and BlockRegistry.requires_support(above_id):
		var above_drops := BlockRegistry.drops(above_id)
		cells.erase(above)
		deltas[above] = "air"
		_set_tile(above, "air")
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


func _set_tile(cell: Vector2i, block_id: String) -> void:
	if block_id == "air" or not _source_ids.has(block_id):
		_tilemap.erase_cell(cell)
	else:
		_tilemap.set_cell(cell, _source_ids[block_id], Vector2i.ZERO)
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
		var src := TileSetAtlasSource.new()
		src.texture = _make_block_texture(block_id, t)
		src.texture_region_size = Vector2i(t, t)
		src.create_tile(Vector2i.ZERO)
		var sid := ts.add_source(src)
		_source_ids[block_id] = sid
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
	return ts


func _make_block_texture(block_id: String, t: int) -> ImageTexture:
	# FQ-07: image-first — a PNG at art/generated/blocks/<id>.png (or an
	# explicit visual_assets.json entry) wins; otherwise the generated
	# color/shape below is the fallback. Mismatched sizes are resized so a
	# stray art dimension can never corrupt the tileset.
	var art := BlockRegistry.visual_texture("blocks", block_id) as ImageTexture
	if art != null:
		var art_img: Image = art.get_image()
		if art_img.get_width() != t or art_img.get_height() != t:
			art_img.resize(t, t, Image.INTERPOLATE_NEAREST)
			return ImageTexture.create_from_image(art_img)
		return art
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
	else:
		img.fill(color)
		# Slight edge shading for tile readability.
		var edge := color.darkened(0.25)
		for i in range(t):
			img.set_pixel(i, t - 1, edge)
			img.set_pixel(t - 1, i, edge)
	return ImageTexture.create_from_image(img)


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


static func parse_deltas(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = str(raw[key])
	return out
