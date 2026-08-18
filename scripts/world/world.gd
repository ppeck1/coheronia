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
# Item-wiring (Phase 3): the renewable tree loop. A planted tree_sapling matures
# into a full tree after this many seconds (obstructed saplings wait the retry
# interval, exactly like crops); clearing tree_leaves drops one tree_seed with
# this chance. All three are PROVISIONAL balance values — named here, not tuned.
const SAPLING_GROW_SECONDS := 90.0
const SAPLING_RETRY_SECONDS := 5.0
const LEAF_SEED_DROP_CHANCE := 0.35
# LQ-2: number of discrete fill heights a liquid tile quantizes into (16px tile
# => 2px per bucket). A cell's level maps to a bottom-anchored tile of this many.
const LIQUID_FILL_LEVELS := 8
# LQ-3 (bucket): a scoop draws up to one bucketful (a full cell's worth) from the
# connected pool, needs at least this much liquid reachable to succeed (so a
# near-dry sliver still can't fill a bucket), and never scans more than this many
# cells while gathering (bounds the flood fill on huge sheets).
const SCOOP_BUCKET_UNIT := 1.0
const SCOOP_MIN_MASS := 0.5
const SCOOP_MAX_SCAN := 256
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
var tree_growth: Dictionary = {}    # Item-wiring: Vector2i -> float seconds until a sapling matures
# LQ-1: parallel per-cell liquid fill level (Vector2i -> float in (0,1]). A
# liquid cell absent here reads as 1.0 (a generated-at-rest pool). Saved
# alongside deltas; driven by the fluid sim.
var liquid_level: Dictionary = {}
var fluid_paused := false           # LQ-1: pauses the live tick (pinned-baseline smoke)
var _lava_glow_phase := 0.0         # LQ-2b: shared flicker phase for molten light

var _tilemap: TileMapLayer
var _fluid: RefCounted              # LQ-1: FluidSim, owns the active/sleep set + step logic
var _lava_bubbles: Node2D          # LQ-2c: presentation-only rising-bubble overlay
var _source_ids: Dictionary = {}    # block_id -> Array of tileset source ids (FQ-09V: one per variant)
# LQ-2: liquid block_id -> Array of LIQUID_FILL_LEVELS bottom-anchored fill-tile
# source-id pools (bucket 1 = thinnest .. last = full). Each fill level retains
# all authored variants so _set_tile can pick by fill level and deterministic cell hash.
var _liquid_source_ids: Dictionary = {}
# Parallel pool for liquids that declare a surface sheen (water): identical to
# _liquid_source_ids but with the true-surface row lightened. _set_tile draws
# from here for a cell exposed to air above, and from _liquid_source_ids for a
# submerged cell — so the waterline glints while the depth stays uniform.
var _liquid_surface_source_ids: Dictionary = {}
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
# Underground-lighting rework: the per-column depth shader shared across the
# Blocks / BackgroundWalls / lava-bubble layers, and the one-texel-per-column
# sky-line texture that feeds it. Rebuilt (dirty flag) whenever a block change
# moves a column's sky line — the same trigger that invalidates `_sky_line`.
var _cave_material: ShaderMaterial
var _sky_img: Image
var _sky_tex: ImageTexture
var _sky_tex_dirty := true

const BackdropScript := preload("res://scripts/world/world_backdrop.gd")
const ItemDropScript := preload("res://scripts/entities/item_drop.gd")   # R-08 slice 3
const FluidSimScript := preload("res://scripts/world/fluid_sim.gd")      # LQ-1 liquid physics
const LavaBubblesScript := preload("res://scripts/world/lava_bubbles.gd") # LQ-2c rising-bubble overlay
const LightingScript := preload("res://scripts/world/lighting.gd")        # shared soft-glow authoring
const CaveDepthShader := preload("res://shaders/cave_depth.gdshader")      # per-column depth darkening
const WALL_MATERIALS := {"dirt_wall": "dirt", "stone_wall": "stone"}

const BLOCK_COLORS := {
	"dirt": Color(0.47, 0.33, 0.18),
	"grass": Color(0.30, 0.62, 0.25),
	"wood": Color(0.62, 0.45, 0.22),
	"stone": Color(0.45, 0.46, 0.50),
	"deepstone": Color(0.28, 0.30, 0.37),
	"bedrock": Color(0.14, 0.14, 0.17),
	"hellstone": Color(0.34, 0.15, 0.15),
	"obsidian": Color(0.16, 0.12, 0.20),
	"lava": Color(0.95, 0.42, 0.12),
	"water": Color(0.18, 0.42, 0.80),
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
	"tree_sapling": Color(0.36, 0.56, 0.24),
	"tree_trunk": Color(0.48, 0.35, 0.20),
	"tree_leaves": Color(0.22, 0.44, 0.19),
	"door": Color(0.54, 0.36, 0.18),
	"door_open": Color(0.54, 0.36, 0.18),
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
	# S-07.1c-fix: rear walls DO receive 2D light (light_mask 1). An earlier pass
	# set this to 0 to kill a "bright purple under light" look, but with an unlit,
	# near-black wall a torch's illuminated area could not READ against the black
	# background underground (operator: "hard to see where the torches are
	# lighting"). The albedo is now a desaturated dark-cool rock (wall_tint), so a
	# warm torch/lava light pools on it as lit rock, not purple. They still cast no
	# shadow and have no collision (0 occlusion/physics layers on the tileset), so
	# lighting them changes only their appearance, never shelter/collision/saves.
	_walls.light_mask = 1
	_walls.tile_set = _build_wall_tileset()
	add_child(_walls)
	_tilemap = TileMapLayer.new()
	_tilemap.name = "Blocks"
	_tilemap.tile_set = _build_tileset()
	add_child(_tilemap)
	# LQ-2c: bubble overlay is added AFTER the Blocks layer so it draws over the
	# lava tiles at the same z; it only decorates and never mutates world state.
	_lava_bubbles = LavaBubblesScript.new()
	_lava_bubbles.name = "LavaBubbles"
	add_child(_lava_bubbles)
	_lava_bubbles.setup(self)
	_fluid = FluidSimScript.new(self)


func _process(delta: float) -> void:
	_tick_bush_regrowth(delta)
	_tick_crop_growth(delta)
	_tick_tree_growth(delta)
	# LQ-1: advance the liquid sim (self-idles while no liquid is awake).
	if not fluid_paused and _fluid != null:
		_fluid.tick(delta)
	_tick_lava_glow(delta)   # LQ-2b: slow flicker on molten lights
	if _cave_material != null and _sky_tex_dirty:
		_rebuild_sky_texture()   # refresh the depth shader's per-column sky line
	if _lava_bubbles != null:
		_lava_bubbles.tick(delta)   # LQ-2c: rising/bursting lava bubbles


## LQ-2b: advances the shared lava flicker phase and refreshes each liquid
## light's energy so a lake glows with a slow living pulse (and tracks fill
## level). Cheap: only touches the existing liquid lights.
func _tick_lava_glow(delta: float) -> void:
	if _lights.is_empty():
		return
	_lava_glow_phase = fmod(_lava_glow_phase + delta * 2.2, TAU)
	for cell in _lights:
		if BlockRegistry.is_liquid(block_at(cell)):
			_lights[cell].energy = _lava_light_energy(liquid_level.get(cell, 1.0))


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


## Item-wiring (Phase 3): matures planted saplings after their timer, mirroring
## crop growth. A sapling only matures while it is still a tree_sapling standing on
## solid ground with its tree footprint clear; if the cell was mined/replaced the
## timer is dropped, if its support is gone it falls (returning nothing — the seed
## was already spent), and if the canopy space is blocked it simply waits and
## retries (fails safely without swallowing terrain).
func _tick_tree_growth(delta: float) -> void:
	for cell in tree_growth.keys():
		tree_growth[cell] -= delta
		if tree_growth[cell] > 0.0:
			continue
		if block_at(cell) != "tree_sapling":
			tree_growth.erase(cell)
		elif not _is_supported(cell):
			cells.erase(cell)
			deltas[cell] = "air"
			_set_tile(cell, "air")
			block_changed.emit(cell, "air")
			tree_growth.erase(cell)
		elif _mature_sapling(cell):
			tree_growth.erase(cell)
		else:
			tree_growth[cell] = SAPLING_RETRY_SECONDS


## Item-wiring (Phase 3): grows a mature tree from a sapling cell using the ONE
## canonical tree rule (WorldGen.tree_layout), so a planted tree is the same shape
## world-gen produces and yields the existing tree_trunk/tree_leaves/wood behavior.
## The trunk column must be clear (air, or the sapling cell itself) or the growth
## fails safely and retries; canopy cells that are occupied are skipped, exactly as
## world-gen never overwrites terrain. Returns true when the tree was stamped.
func _mature_sapling(cell: Vector2i) -> bool:
	var trunk_h: int = WorldGen.TREE_MIN_H + (absi(hash(cell)) \
		% (WorldGen.TREE_MAX_H - WorldGen.TREE_MIN_H + 1))
	var layout: Array = WorldGen.tree_layout(trunk_h, cell.x, cell.y + 1)
	# Validate the trunk column is clear before placing anything (fail safely).
	for entry in layout:
		var pos: Vector2i = entry[0]
		if str(entry[1]) == "tree_trunk" and pos != cell and block_at(pos) != "air":
			return false
	for entry in layout:
		var pos: Vector2i = entry[0]
		var id: String = str(entry[1])
		# Skip an occupied canopy cell (never swallow terrain); the trunk column is
		# already verified clear above, and the sapling cell is overwritten by trunk.
		if pos != cell and block_at(pos) != "air":
			continue
		cells[pos] = id
		deltas[pos] = id
		_set_tile(pos, id)
		block_changed.emit(pos, id)
	return true


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
		saved_crop: Dictionary = {}, saved_liquid: Dictionary = {},
		saved_tree: Dictionary = {}) -> void:
	world_seed = new_seed
	deltas = saved_deltas.duplicate()
	bush_regrow = saved_regrow.duplicate()
	crop_growth = saved_crop.duplicate()
	tree_growth = saved_tree.duplicate()   # Item-wiring: restore sapling growth timers
	# LQ-1: restore saved liquid fill levels (disturbed cells only; generated
	# pools carry no entry and read as full). The wake below re-settles anything
	# saved mid-flow; a fresh/undisturbed world stays asleep (empty active set).
	liquid_level = saved_liquid.duplicate()
	for cell in _lights.keys():
		_lights[cell].queue_free()
	_lights.clear()
	if _lava_bubbles != null:
		_lava_bubbles.clear()   # LQ-2c: drop stale bubbles before regen
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
			tree_growth.erase(sweep_cell)   # Item-wiring: unsupported sapling drops its timer
			if sbid == "berry_bush" and not bush_regrow.has(sweep_cell):
				bush_regrow[sweep_cell] = BUSH_REGROW_SECONDS
	_redraw_all()
	# LQ-1: generated pools boot asleep; only cells saved mid-flow (a
	# liquid_level entry that is still a live liquid cell) wake to re-settle.
	if _fluid != null:
		_fluid.active.clear()
		for lc in liquid_level.keys():
			_fluid.wake(lc)


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


## The id of the liquid actually covering `world_pos`, or "" when the point is
## in air/solid or ABOVE the liquid's settled surface. Uses liquid_level so a
## partially filled cell's true waterline is respected — a point in the empty
## top of a half-full cell reads as uncovered, matching what the player sees.
## This is the "actual level, not the block" query the swim/breath code needs.
func liquid_covering(world_pos: Vector2) -> String:
	var cell := cell_of(world_pos)
	var id := block_at(cell)
	if not BlockRegistry.is_liquid(id):
		return ""
	var t := float(tile_size())
	var level: float = clampf(float(liquid_level.get(cell, 1.0)), 0.0, 1.0)
	# Liquid settles to the bottom of the cell; its surface sits `level` up from
	# the floor, i.e. (1 - level) down from the cell top (cell.y * t).
	var surface_y := float(cell.y) * t + (1.0 - level) * t
	return id if world_pos.y >= surface_y else ""


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
## `seed_return_mult` (Calling: Seedkeeper / Careful Harvest) scales the chance
## that clearing leaves returns a tree seed — it modifies the actual roll below,
## not a post-hoc duplication. 1.0 = unchanged.
func break_block(cell: Vector2i, seed_return_mult: float = 1.0) -> Dictionary:
	var block_id := block_at(cell)
	if block_id == "air":
		return {}
	# A multi-tile door is mined as one unit: breaking any cell removes the whole
	# vertical run and returns a single door item (it was placed as one door).
	if block_id in DOOR_IDS:
		for c in _door_run(cell):
			cells.erase(c)
			deltas[c] = "air"
			liquid_level.erase(c)
			_set_tile(c, "air")
			block_changed.emit(c, "air")
			if _fluid != null:
				_fluid.wake_neighbours(c)
		return {"door": 1}
	var block_drops := BlockRegistry.drops(block_id)
	cells.erase(cell)
	deltas[cell] = "air"
	liquid_level.erase(cell)   # LQ-1: mining a liquid cell clears its fill level
	_set_tile(cell, "air")
	if block_id == "berry_bush":
		bush_regrow[cell] = BUSH_REGROW_SECONDS
	crop_growth.erase(cell)   # FQ-12: harvesting/removing a crop clears its timer
	tree_growth.erase(cell)   # Item-wiring: removing a sapling clears its growth timer
	# Item-wiring (Phase 3): clearing leaves has a chance to drop one tree_seed,
	# closing the finite-tree loop. block_drops is a fresh copy from the registry.
	if block_id == "tree_leaves" and randf() < LEAF_SEED_DROP_CHANCE * maxf(1.0, seed_return_mult):
		block_drops = block_drops.duplicate()
		block_drops["tree_seed"] = int(block_drops.get("tree_seed", 0)) + 1
	block_changed.emit(cell, "air")
	# LQ-1: breaching a wall wakes any adjacent liquid so a pool starts pouring.
	if _fluid != null:
		_fluid.wake_neighbours(cell)
	# Wave E: check the cell directly above; if it requires support it's now floating.
	var above := Vector2i(cell.x, cell.y - 1)
	var above_id := block_at(above)
	if above_id != "air" and BlockRegistry.requires_support(above_id):
		var above_drops := BlockRegistry.drops(above_id)
		cells.erase(above)
		deltas[above] = "air"
		_set_tile(above, "air")
		crop_growth.erase(above)
		tree_growth.erase(above)   # Item-wiring: a sapling that lost its support falls too
		# Only berry bushes reschedule; FQ-12 crops just fall (no auto-regrow).
		if above_id == "berry_bush":
			bush_regrow[above] = BUSH_REGROW_SECONDS
		block_changed.emit(above, "air")
		for item_id in above_drops:
			block_drops[item_id] = int(block_drops.get(item_id, 0)) + int(above_drops[item_id])
	# Gravity: mining can leave a free-standing cluster of gravity blocks (a tree, or
	# its severed top) with no footing on solid ground — it collapses, its blocks
	# falling as ground drops. Cohesive terrain (no has_gravity) is untouched, so
	# mining under stone/dirt costs nothing here.
	for n in [Vector2i(cell.x, cell.y - 1), Vector2i(cell.x, cell.y + 1),
			Vector2i(cell.x - 1, cell.y), Vector2i(cell.x + 1, cell.y)]:
		_collapse_if_floating(n, seed_return_mult)
	return block_drops


## The connected 4-neighbour cluster of has_gravity cells reachable from `start`
## (empty if `start` is not a gravity block). Capped so a pathological forest can't
## stall the frame.
func _gravity_component(start: Vector2i) -> Array:
	var comp: Array = []
	if not BlockRegistry.has_gravity(block_at(start)):
		return comp
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty() and comp.size() < 512:
		var c: Vector2i = stack.pop_back()
		comp.append(c)
		for n in [Vector2i(c.x, c.y - 1), Vector2i(c.x, c.y + 1),
				Vector2i(c.x - 1, c.y), Vector2i(c.x + 1, c.y)]:
			if not seen.has(n) and BlockRegistry.has_gravity(block_at(n)):
				seen[n] = true
				stack.append(n)
	return comp


## A gravity cluster is grounded if ANY of its cells sits directly on a solid,
## non-gravity block (dirt/stone/etc.) — that footing holds the whole cluster up.
func _component_grounded(comp: Array) -> bool:
	for c in comp:
		var below: Vector2i = Vector2i(c.x, c.y + 1)
		var bid := block_at(below)
		if bid != "air" and BlockRegistry.is_solid(bid) and not BlockRegistry.has_gravity(bid):
			return true
	return false


## If the gravity cluster at `start` has lost its footing, collapse it: remove every
## cell and drop its items as falling ground drops (leaves keep their tree_seed roll).
## `seed_return_mult` (Calling: Seedkeeper / Careful Harvest) scales the collapsing-
## leaf seed roll the same way as a directly-broken leaf, since cutting a trunk and
## letting its canopy fall is ordinary tree harvesting.
func _collapse_if_floating(start: Vector2i, seed_return_mult: float = 1.0) -> void:
	if not BlockRegistry.has_gravity(block_at(start)):
		return
	var comp := _gravity_component(start)
	if comp.is_empty() or _component_grounded(comp):
		return
	for c in comp:
		var here := block_at(c)
		var drops := BlockRegistry.drops(here)
		var seed_roll := here == "tree_leaves" \
			and randf() < LEAF_SEED_DROP_CHANCE * maxf(1.0, seed_return_mult)
		cells.erase(c)
		deltas[c] = "air"
		tree_growth.erase(c)
		_set_tile(c, "air")
		block_changed.emit(c, "air")
		var pos := cell_center(c)
		for item_id in drops:
			spawn_item_drop(pos, str(item_id), int(drops[item_id]))
		if seed_roll:
			spawn_item_drop(pos, "tree_seed", 1)


func place_block(cell: Vector2i, block_id: String) -> bool:
	if block_at(cell) != "air":
		return false
	if not BlockRegistry.is_placeable(block_id):
		return false
	cells[cell] = block_id
	deltas[cell] = block_id
	_set_tile(cell, block_id)
	block_changed.emit(cell, block_id)
	# LQ-1: placing (e.g. damming a channel) wakes adjacent liquid to re-settle.
	if _fluid != null:
		_fluid.wake_neighbours(cell)
	return true


# A door is a DOOR_HEIGHT-tall, 1-wide unit so a full-height character (≈2 tiles)
# fits through the opening — a 1-tile door could never be walked through. The cells
# open/close together as one door.
const DOOR_HEIGHT := 3
const DOOR_IDS := ["door", "door_open"]


## The contiguous vertical run of door cells through `cell` (top-to-bottom), so a
## multi-tile door opens/closes and is mined as one unit. Empty if `cell` is no door.
func _door_run(cell: Vector2i) -> Array:
	if block_at(cell) not in DOOR_IDS:
		return []
	var top := cell
	while block_at(Vector2i(top.x, top.y - 1)) in DOOR_IDS:
		top = Vector2i(top.x, top.y - 1)
	var run: Array = []
	var c := top
	while block_at(c) in DOOR_IDS:
		run.append(c)
		c = Vector2i(c.x, c.y + 1)
	return run


## Door art is assembled from a vertical run of tiles. Variant selection must use
## one shared anchor so every segment shows the same left- or right-parked leaf.
func _visual_variant_anchor(cell: Vector2i, block_id: String) -> Vector2i:
	if block_id not in DOOR_IDS:
		return cell
	var run := _door_run(cell)
	if not run.is_empty():
		return Vector2i(run[0])
	return cell


## Place a DOOR_HEIGHT-tall door with its base at `bottom`, growing upward. Every
## target cell must be air. Saved as deltas like any placed block. Returns success.
func place_door_stack(bottom: Vector2i) -> bool:
	var targets: Array = []
	for i in range(DOOR_HEIGHT):
		var c := Vector2i(bottom.x, bottom.y - i)
		if block_at(c) != "air":
			return false
		targets.append(c)
	for c in targets:
		cells[c] = "door"
		deltas[c] = "door"
	# Populate the full run before rendering so every segment resolves the same
	# top-cell variant anchor.
	for c in targets:
		_set_tile(c, "door")
		block_changed.emit(c, "door")
		if _fluid != null:
			_fluid.wake_neighbours(c)
	return true


## Settlement Coherence (M2-B): toggle a door between closed (`door`, solid, blocks
## light) and open (`door_open`, passable, lets light through). Flips the WHOLE
## vertical run together (a partly-open door fully opens). The swap is a saved delta
## and retiles/relights exactly like a mined/placed block, so a door opened before a
## save reopens on load. Returns true if a door was toggled.
func toggle_door(cell: Vector2i) -> bool:
	var run := _door_run(cell)
	if run.is_empty():
		return false
	# Open if ANY cell is currently closed, else close the whole run.
	var opening := false
	for c in run:
		if block_at(c) == "door":
			opening = true
			break
	var next := "door_open" if opening else "door"
	for c in run:
		cells[c] = next
		deltas[c] = next
		_set_tile(c, next)
		block_changed.emit(c, next)
		# Opening/closing changes solidity + light occlusion; wake adjacent liquid so a
		# dammed channel re-settles, mirroring place_block/break_block.
		if _fluid != null:
			_fluid.wake_neighbours(c)
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


## Item-wiring (Phase 3): plants a tree sapling in an air cell sitting directly on
## dirt or grass, and schedules its growth. Returns false if the target is occupied
## or not on natural ground (so saplings can never float or root in stone/structures).
## The caller consumes one tree_seed on success. Growth reuses the crop-style timer.
func plant_sapling(cell: Vector2i) -> bool:
	if block_at(cell) != "air":
		return false
	if block_at(cell + Vector2i(0, 1)) not in ["dirt", "grass"]:
		return false
	cells[cell] = "tree_sapling"
	deltas[cell] = "tree_sapling"
	_set_tile(cell, "tree_sapling")
	tree_growth[cell] = SAPLING_GROW_SECONDS
	block_changed.emit(cell, "tree_sapling")
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
	# Perf: scan only the Chebyshev radius box around `from` (bounded), not the whole
	# grid — this runs every physics frame for each crop-eating threat.
	for cy in range(from.y - radius, from.y + radius + 1):
		for cx in range(from.x - radius, from.x + radius + 1):
			var cell := Vector2i(cx, cy)
			if not (cells.get(cell, "air") in CROP_IDS):
				continue
			var d: int = maxi(absi(cx - from.x), absi(cy - from.y))
			if d < best_d:
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


## Work-zone variants: the nearest ripe crop / plantable soil INSIDE a cell rect
## (the settler's work_bounds), tie-broken by distance to `from` (home). Empty rect
## → nothing found. Used so a per-NPC work zone can steer where each settler works.
## Perf: iterate the (small, bounded) work rect rather than the whole cell grid.
## A settler runs this every physics frame; scanning all ~10^5 world cells to keep
## the handful inside its ~44x44 zone was the dominant per-frame cost. The rect is a
## strict subset of the world, so this is always cheaper and never larger. Fixed
## (y, then x) scan order keeps the equidistant tie-break deterministic.
func nearest_ripe_crop_in(rect: Rect2i, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cy in range(rect.position.y, rect.position.y + rect.size.y):
		for cx in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(cx, cy)
			if cells.get(cell, "air") != "crop_ripe":
				continue
			var d: int = maxi(absi(cx - from.x), absi(cy - from.y))
			if d < best_d:
				best_d = d
				best = cell
	return best


func nearest_plantable_soil_in(rect: Rect2i, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	# `above` (the air planting cell) must lie in the rect, so scan the rect for the
	# air cell and test the farm_soil directly beneath it.
	for cy in range(rect.position.y, rect.position.y + rect.size.y):
		for cx in range(rect.position.x, rect.position.x + rect.size.x):
			var above := Vector2i(cx, cy)
			if cells.get(above, "air") != "air":
				continue
			if cells.get(Vector2i(cx, cy + 1), "air") != "farm_soil":
				continue
			var d: int = maxi(absi(cx - from.x), absi(cy - from.y))
			if d < best_d:
				best_d = d
				best = above
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
## Item-wiring: also refuses a UI-only surrogate id (pick/axe/sword/armor) so a
## data slip can never spawn one as loot.
func spawn_item_drop(pos: Vector2, item_id: String, count: int = 1) -> Node:
	if item_id == "" or count <= 0:
		return null
	if BlockRegistry.is_ui_only(item_id):
		return null
	var drop := ItemDropScript.new()
	add_child(drop)
	drop.setup(self, item_id, count, pos)
	return drop


## R-08 slice 3: the nearest live ground item drop within `radius` cells
## (Chebyshev) of `from`, or null. Skips drops already queued for deletion so a
## just-collected drop is never chased. Used by the hauler to pick a target, so it
## also skips stockpile-ineligible drops (e.g. a mined torch) — a hauler only
## carries material/loot the stockpile actually accepts, and so never walks to a
## drop it would then refuse to deposit.
func nearest_item_drop(from: Vector2i, radius: int) -> Node:
	var best: Node = null
	var best_d: int = radius + 1
	for d in get_tree().get_nodes_in_group("item_drops"):
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		if not BlockRegistry.is_stockpile_material(str(d.item_id)):
			continue
		var c: Vector2i = cell_of(d.global_position)
		var dist: int = maxi(absi(c.x - from.x), absi(c.y - from.y))
		if dist <= radius and dist < best_d:
			best_d = dist
			best = d
	return best


## Work-zone variant of nearest_item_drop: nearest depositable ground drop INSIDE a
## cell rect (the hauler's work_bounds), tie-broken by distance to `from`.
func nearest_item_drop_in(rect: Rect2i, from: Vector2i) -> Node:
	var best: Node = null
	var best_d := 1 << 30
	for d in get_tree().get_nodes_in_group("item_drops"):
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		if not BlockRegistry.is_stockpile_material(str(d.item_id)):
			continue
		var c: Vector2i = cell_of(d.global_position)
		if not rect.has_point(c):
			continue
		var dist: int = maxi(absi(c.x - from.x), absi(c.y - from.y))
		if dist < best_d:
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

## Fills the BackgroundWalls layer: a dirt wall band for the configured dirt depth,
## stone wall below. The band starts at the first **solid** cell of the column
## (skipping air AND surface water/lava), so:
##  - mining the top solid block digs INTO the hillside and reveals a wall, not the
##    dark under-earth backdrop (`world_backdrop.UNDER_COL`) — the black-gap fix;
##  - a wall never sits behind a surface pond, so the tinted wall does not show
##    through translucent water above the horizon (`surface[x]` is unreliable here
##    — `_carve_surface_lake` overwrites it with the water top, not the ground).
## Cells above the first solid row stay wall-free so open sky/water reads clean.
func _rebuild_walls(config: WorldConfig) -> void:
	_walls.clear()
	var dirt_depth := int(config.gen("dirt_depth"))
	for x in range(width):
		var sy := 0
		while sy < height and not BlockRegistry.is_solid(cells.get(Vector2i(x, sy), "air")):
			sy += 1
		if sy >= height:
			continue   # column has no solid ground (all sky/water) — nothing to back
		for y in range(sy, height):
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


## Underground-lighting rework: build the shared per-column depth-darkening
## material and hand it to every world plane that should read dark below the
## surface (foreground blocks, backing walls, the lava-bubble overlay). Called
## once by game_root after the world is generated/loaded, with the same CAVE_TINT
## and fade band the global CanvasModulate uses, so the two models stay in step.
func enable_cave_depth_shading(cave_tint: Color, fade_cells: float) -> void:
	if OS.get_environment("COHERONIA_NO_CAVE_SHADER") == "1":
		return   # A/B verification gate: render the legacy global-tint-only model
	_cave_material = ShaderMaterial.new()
	_cave_material.shader = CaveDepthShader
	_cave_material.set_shader_parameter("tile_size", float(tile_size()))
	_cave_material.set_shader_parameter("world_width", float(width))
	_cave_material.set_shader_parameter("cave_fade_cells", maxf(fade_cells, 0.001))
	_cave_material.set_shader_parameter("cave_tint", cave_tint)
	_cave_material.set_shader_parameter("viewer_darkness", 0.0)
	_rebuild_sky_texture()
	if _tilemap != null:
		_tilemap.material = _cave_material
	if _walls != null:
		_walls.material = _cave_material
	if _lava_bubbles != null:
		_lava_bubbles.material = _cave_material


## True once the depth shader is live — used by the smoke suite as evidence.
func cave_depth_shading_enabled() -> bool:
	return _cave_material != null


## The per-column sky-line texture the depth shader samples (smoke evidence).
func cave_sky_texture() -> Texture2D:
	return _sky_tex


## Push the player's own 0..1 depth factor into the shader each frame. The shader
## only darkens terrain DEEPER than this, so it never double-darkens what the
## global CanvasModulate already dimmed at the viewer's depth.
func set_viewer_darkness(f: float) -> void:
	if _cave_material != null:
		_cave_material.set_shader_parameter("viewer_darkness", clampf(f, 0.0, 1.0))


## Feed the depth shader the current sun/moon admission ray: `dir` is the world-space
## direction (normalized, +y down) from a terrain cell TOWARD the celestial body, and
## `strength` (0..1) how strongly a clear slant path re-admits ambient light (0 = off,
## e.g. a new moon). The shader marches this ray over the per-column sky-line texture
## so a window / doorway / cave mouth with an unobstructed path to the body stays lit,
## not just a vertical shaft. Presentation-only; nothing here touches gameplay/save.
func set_sky_admission(dir: Vector2, strength: float) -> void:
	if _cave_material == null:
		return
	var d := dir.normalized() if dir.length() > 0.0 else Vector2(0.0, -1.0)
	_cave_material.set_shader_parameter("sky_dir", d)
	_cave_material.set_shader_parameter("sky_admit_strength", clampf(strength, 0.0, 1.0))


## Repaint the one-texel-per-column sky-line texture (R = first solid y in tiles)
## the depth shader samples. Cheap: width texels, only when a dig moved a column.
func _rebuild_sky_texture() -> void:
	_sky_tex_dirty = false
	if _cave_material == null:
		return
	if _sky_img == null or _sky_img.get_width() != width:
		_sky_img = Image.create(maxi(width, 1), 1, false, Image.FORMAT_RF)
	for x in range(width):
		_sky_img.set_pixel(x, 0, Color(float(sky_line(x)), 0.0, 0.0, 1.0))
	if _sky_tex == null:
		_sky_tex = ImageTexture.create_from_image(_sky_img)
	else:
		_sky_tex.update(_sky_img)
	_cave_material.set_shader_parameter("sky_tex", _sky_tex)


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


## S-07.1c: the cool, quiet tint an underground rear wall takes when it is derived
## from a foreground material (no authored back_wall art). Desaturates the
## material's own hue, lowers its contrast, and pushes it darker with a purple-blue
## bias, so a cave's rear wall reads as receding rock — clearly distinct from the
## solid foreground and never as flat foreground or black void. Purely visual: the
## wall layer has no physics/occlusion, so nothing here can change collision,
## lighting, shelter, or settlement math. Exposed static so a smoke check can
## assert the foreground-vs-wall distinction against the same transform.
static func wall_tint(c: Color) -> Color:
	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	# desaturate strongly toward the material's own luminance so the warm foreground
	# hue is neutralised (a dirt wall reads apart from a dirt block by being flat and
	# recessed, NOT by a loud colour) — the purple is only a whisper now.
	var r := lerpf(c.r, lum, 0.85)
	var g := lerpf(c.g, lum, 0.85)
	var b := lerpf(c.b, lum, 0.85)
	# lower contrast: pull each channel toward mid-grey
	r = lerpf(r, 0.5, 0.2)
	g = lerpf(g, 0.5, 0.2)
	b = lerpf(b, 0.5, 0.2)
	# darken to a quiet, receding backdrop with only a faint cool bias (green quietest,
	# blue a touch highest). Dark but NOT near-black: an unlit wall stays visibly
	# recessed rock rather than a black void (operator: surface/underground walls
	# "almost too dark"), and — now that the wall layer receives light again — a
	# torch/lava light can lift it into a legible warm pool. TUNING KNOB.
	return Color(r * 0.52, g * 0.48, b * 0.60, 1.0)


## Back-wall tile: the authored art at art/generated/back_walls/<wall_id>.png when
## present, else the matching foreground block texture — and EITHER way pushed
## through wall_tint() so every rear wall is desaturated, lower-contrast, cool
## purple-blue and fully opaque. This is what makes a background wall read clearly
## apart from the solid foreground of the SAME material (a dirt wall vs a mineable
## dirt block); a pure layer multiply could not, since it cannot desaturate the
## material's own warm hue. Presentation only — the wall layer has no
## physics/occlusion, so nothing here touches collision/lighting/shelter/saves.
func _make_wall_texture(wall_id: String, base_block: String, t: int) -> ImageTexture:
	var art := BlockRegistry.visual_texture("back_walls", wall_id) as ImageTexture
	var img: Image = _normalize_art(art, t).get_image() if art != null \
		else _make_block_texture(base_block, t).get_image()
	for y in range(t):
		for x in range(t):
			img.set_pixel(x, y, wall_tint(img.get_pixel(x, y)))
	return ImageTexture.create_from_image(img)


func _set_tile(cell: Vector2i, block_id: String) -> void:
	_sky_line.erase(cell.x)   # FQ-09W: any block change re-derives that column's skylight
	_sky_tex_dirty = true     # ...and the depth-shader's sky-line texture with it
	# _block_textures guarantees at least one source per known block; the
	# is_empty guard makes that invariant explicit rather than an index crash.
	if block_id == "air" or (_source_ids.get(block_id, []) as Array).is_empty():
		_tilemap.erase_cell(cell)
	elif BlockRegistry.is_liquid(block_id) and _liquid_source_ids.has(block_id):
		# LQ-2: a bottom-anchored fill tile chosen by level. A SUBMERGED cell (the
		# same liquid directly above, in the flow direction) renders FULL so a
		# column / falling stream reads as one continuous body; only a surface cell
		# shows its partial level. Without this a falling column looks like a choppy
		# ladder of bottom-anchored slivers. ceil => any liquid shows >= 1 sliver.
		var above := cell - Vector2i(0, BlockRegistry.liquid_flow_dir(block_id))
		var submerged := block_at(above) == block_id
		# A submerged cell renders FULL and uniform; a surface cell (air above)
		# shows its partial level and, for a sheened liquid, the lightened top row.
		var lsids: Array = _liquid_source_ids[block_id]
		if not submerged and _liquid_surface_source_ids.has(block_id):
			lsids = _liquid_surface_source_ids[block_id]
		var lvl: float = 1.0 if submerged else float(liquid_level.get(cell, 1.0))
		var bucket := clampi(int(ceil(lvl * lsids.size())), 1, lsids.size())
		var fill_sids: Array = lsids[bucket - 1]
		var idx := 0
		if fill_sids.size() > 1:
			idx = posmod(hash(Vector3i(cell.x, cell.y, world_seed)), fill_sids.size())
		_tilemap.set_cell(cell, fill_sids[idx], Vector2i.ZERO)
	else:
		# FQ-09V: blocks with a variant pool pick one deterministically from
		# world seed + cell position — the same world always renders the same
		# variety, and nothing about the choice ever enters saves.
		var sids: Array = _source_ids[block_id]
		var idx := 0
		if sids.size() > 1:
			var variant_cell := _visual_variant_anchor(cell, block_id)
			idx = posmod(hash(Vector3i(variant_cell.x, variant_cell.y, world_seed)), sids.size())
		_tilemap.set_cell(cell, sids[idx], Vector2i.ZERO)
	_update_light(cell, block_id)


## S-07.1c-fix: which lava (liquid) cells own their own light — a sparse 2x2
## representative grid. Each lava light is broad (~3-tile radius) and shadowless,
## so a lake still washes continuously from ~1/4 the lights; off-grid lava cells
## are covered by their neighbouring grid lights. Torches/lanterns are never
## thinned. This kills the over-bright, unstable stacking a lava lake's many
## per-cell lights produced where they competed with (shadowed) torch lights.
static func lava_light_cell(cell: Vector2i) -> bool:
	return posmod(cell.x, 2) == 0 and posmod(cell.y, 2) == 0


func _update_light(cell: Vector2i, block_id: String) -> void:
	var wants_light := block_id != "air" and BlockRegistry.emits_light(block_id)
	# Thin lava lights to the sparse grid (see lava_light_cell). Non-liquid
	# emitters (torch/lantern) light every cell as before.
	if wants_light and BlockRegistry.is_liquid(block_id) and not lava_light_cell(cell):
		wants_light = false
	if not wants_light:
		if _lights.has(cell):
			_lights[cell].queue_free()
			_lights.erase(cell)
		return
	var light: PointLight2D = _lights.get(cell)
	if light == null:
		light = PointLight2D.new()
		light.texture = _light_texture
		light.position = cell_center(cell)
		add_child(light)
		_lights[cell] = light
	var radius := float(BlockRegistry.light_radius(block_id))
	if BlockRegistry.is_liquid(block_id):
		# LQ-2b: molten glow. A shadowed, tile-sized per-cell disc is what made a
		# lava lake read as a grid of circles — so a liquid light is broad, soft,
		# and shadowless (neighbouring cells blend into one continuous wash) and its
		# energy scales with the cell's fill level (a thin film glows faintly, a
		# brim-full pool glows fully). _tick_lava_glow adds a slow flicker.
		light.texture_scale = (radius * float(tile_size()) * 1.6) / float(_light_texture.width)
		light.color = Color(1.0, 0.5, 0.2)
		light.shadow_enabled = false
		light.energy = _lava_light_energy(liquid_level.get(cell, 1.0))
	else:
		light.texture_scale = (radius * 2.0) / float(_light_texture.width)
		light.energy = 1.3
		light.color = Color(1.0, 0.85, 0.6)
		# S-07.1c-fix: a torch/lantern is a SHADOWLESS soft glow (like lava). With
		# shadows on, the solid blocks the torch is carved into occlude its own light:
		# a torch in a mined passage lit only a tiny unshadowed sliver and one against
		# a wall was "cut off" on that side (operator screenshot). The sun/moon keep
		# their shadows (the tileset occluders still exist), so daylight still stops at
		# the surface; only these local emitters now glow evenly through the rock they
		# sit in, the way a stylised side-view torch should.
		light.shadow_enabled = false


## LQ-2b: a lava cell's light energy for a given fill level, modulated by the
## shared flicker phase. Level-scaled (a faint film .. a full glow) with a soft
## floor so even a sliver still reads as molten.
func _lava_light_energy(level: float) -> float:
	var by_level := 0.5 * clampf(level, 0.25, 1.0)
	return by_level * (0.9 + 0.1 * sin(_lava_glow_phase))


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
		# LQ-2: every liquid fill level retains the authored variant pool. Liquids
		# are non-solid and don't block light, so no collision/occluder is attached.
		if BlockRegistry.is_liquid(block_id):
			var lsids: Array = _add_liquid_pool(ts, block_id, t, false)
			_liquid_source_ids[block_id] = lsids
			_source_ids[block_id] = lsids[-1]   # full-tile pool for generic lookups/masks
			# A sheened liquid (water) also gets a surface pool: same fills with the
			# exposed top row lightened, drawn only where the pool meets air.
			if BlockRegistry.liquid_surface_sheen(block_id) > 0.0:
				_liquid_surface_source_ids[block_id] = _add_liquid_pool(ts, block_id, t, true)
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


## Adds one liquid fill-level pool (every bucket's per-variant tile sources) to
## the tileset and returns the Array-of-Arrays of source ids. `surface` builds
## the sheened variant used for cells exposed to air.
func _add_liquid_pool(ts: TileSet, block_id: String, t: int, surface: bool) -> Array:
	var lsids: Array = []
	for fill_textures: Array in _liquid_fill_textures(block_id, t, surface):
		var fill_sids: Array = []
		for tex: ImageTexture in fill_textures:
			var lsrc := TileSetAtlasSource.new()
			lsrc.texture = tex
			lsrc.texture_region_size = Vector2i(t, t)
			lsrc.create_tile(Vector2i.ZERO)
			fill_sids.append(ts.add_source(lsrc))
		lsids.append(fill_sids)
	return lsids


## LQ-2: the ordered bottom-anchored partial-fill textures for a liquid block —
## bucket 1 (thinnest) .. LIQUID_FILL_LEVELS (full). Every authored full-tile
## variant is cropped directly to the bottom bucket/N of the tile. The depth of a
## pool keeps the material's own uniform values; only when `surface` is set does
## the single exposed top row of each fill get lightened toward white by the
## liquid's surface sheen, so the waterline glints without striping the depth.
func _liquid_fill_textures(block_id: String, t: int, surface: bool = false) -> Array:
	var bases: Array = []
	for variant: Texture2D in BlockRegistry.visual_variant_textures("blocks", block_id):
		bases.append(_normalize_art(variant as ImageTexture, t).get_image())
	if bases.is_empty():
		bases.append(_make_block_texture(block_id, t).get_image())
	var sheen := BlockRegistry.liquid_surface_sheen(block_id) if surface else 0.0
	var out: Array = []
	for bucket in range(1, LIQUID_FILL_LEVELS + 1):
		var fill_textures: Array = []
		for base: Image in bases:
			var top := 0
			var img: Image
			if bucket == LIQUID_FILL_LEVELS:
				# Full tile: copy only if we need to modify it, else reuse as-is.
				if sheen <= 0.0:
					fill_textures.append(ImageTexture.create_from_image(base))
					continue
				img = base.duplicate()
			else:
				var fill_h := clampi(roundi(float(bucket) / float(LIQUID_FILL_LEVELS) * float(t)), 1, t)
				top = t - fill_h
				img = Image.create(t, t, false, Image.FORMAT_RGBA8)
				img.fill(Color(0, 0, 0, 0))
				for y in range(top, t):
					for x in range(t):
						img.set_pixel(x, y, base.get_pixel(x, y))
			if sheen > 0.0:
				for x in range(t):
					var c := img.get_pixel(x, top)
					img.set_pixel(x, top, c.lerp(Color(1, 1, 1, c.a), sheen))
			fill_textures.append(ImageTexture.create_from_image(img))
		out.append(fill_textures)
	return out


## FQ-09V: rebuilds all tile sources from the art currently on disk (variant
## pools included) and redraws. A smoke/dev hook — gameplay builds the
## tileset once at _ready, matching the FQ-07 "art loads at world entry"
## rule. Also drops the crack-overlay opacity masks so they re-derive.
func rebuild_tileset() -> void:
	_source_ids.clear()
	_liquid_source_ids.clear()   # LQ-2: rebuilt with fresh fill-tile sources below
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
	elif block_id == "tree_sapling":
		# Item-wiring (Phase 3): a young stem with a couple of small leaves in the
		# lower-middle of the tile — reads as a planted tree not yet grown.
		# Placeholder shape; a dedicated sapling PNG is a later-art requirement.
		img.fill(Color(0, 0, 0, 0))
		var stem_c := Color(0.42, 0.30, 0.18)
		for y in range(t / 2, t):
			img.set_pixel(t / 2, y, stem_c)
			img.set_pixel(t / 2 - 1, y, stem_c)
		for leaf in [Vector2i(t / 2 - 2, t / 2), Vector2i(t / 2 + 1, t / 2 - 1),
				Vector2i(t / 2 - 3, t / 2 + 2), Vector2i(t / 2 + 2, t / 2 + 1)]:
			img.set_pixel(leaf.x, leaf.y, color)
			img.set_pixel(leaf.x, leaf.y - 1, color.lightened(0.15))
	elif block_id == "door":
		# M2-B / tall door: a closed wooden door segment — full-height vertical planks
		# with side posts and NO horizontal borders, so a DOOR_HEIGHT stack merges into
		# one continuous door. A knob rides the right plank so it reads as a door.
		img.fill(color)
		var frame := color.darkened(0.35)
		var seam := color.darkened(0.18)
		for y in range(t):
			img.set_pixel(0, y, frame)
			img.set_pixel(1, y, frame)          # left post
			img.set_pixel(t - 1, y, frame)
			img.set_pixel(t - 2, y, frame)      # right post
			img.set_pixel(t / 3, y, seam)       # plank seams
			img.set_pixel(2 * t / 3, y, seam)
		img.set_pixel(t - 4, t / 2, Color(0.85, 0.78, 0.45))       # brass knob
		img.set_pixel(t - 4, t / 2 - 1, Color(0.85, 0.78, 0.45))
	elif block_id == "door_open":
		# M2-B / tall door: an open door segment — just the jamb posts, the middle a
		# walk-through gap (transparent). Stacked DOOR_HEIGHT tall it reads as a clear,
		# character-height opening framed by posts.
		img.fill(Color(0, 0, 0, 0))
		var post := color.darkened(0.25)
		for y in range(t):
			img.set_pixel(0, y, post)
			img.set_pixel(1, y, post)
			img.set_pixel(t - 1, y, post)
			img.set_pixel(t - 2, y, post)
			img.set_pixel(2, y, color)          # the swung-aside leaf hinted against
			img.set_pixel(3, y, color.darkened(0.12))   # the left jamb → reads as a door
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
	elif block_id == "lava":
		# LQ-2b: molten liquid — a red-orange body with brighter mottled flecks and
		# a hotter top skin, so it reads as glowing liquid rather than a flat block.
		# The pattern is deterministic (position hash), so there is no per-frame cost
		# and the fill-tile crops (_liquid_fill_textures) inherit the same look.
		var hot := Color(1.0, 0.72, 0.26)
		var deep := color.darkened(0.30)
		for y in range(t):
			for x in range(t):
				var n := (x * 5 + y * 9 + x * y) % 13
				var c := color
				if n < 2:
					c = hot
				elif n > 10:
					c = deep
				img.set_pixel(x, y, c)
		for x in range(t):   # hotter surface skin along the top of the cell
			img.set_pixel(x, 0, hot)
	elif block_id == "water":
		# LQ-3: a translucent blue liquid — cells behind read through (alpha < 1),
		# with lighter ripple flecks and a brighter surface skin. The fill-tile
		# crops inherit this so partial water is translucent too.
		var body := Color(color.r, color.g, color.b, 0.60)
		var ripple := Color(0.52, 0.74, 0.95, 0.66)
		for y in range(t):
			for x in range(t):
				var n := (x * 3 + y * 7 + x * y) % 13
				img.set_pixel(x, y, ripple if n < 2 else body)
		for x in range(t):   # cooler bright surface skin along the top of the cell
			img.set_pixel(x, 0, Color(0.72, 0.86, 1.0, 0.72))
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
	# Shared soft-glow authoring: torches/lava now cast the same source-weighted,
	# gently-feathered light as the sun/moon (was a hard linear centre->edge ramp).
	return LightingScript.glow_texture()


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


## Item-wiring (Phase 3): sapling growth timers persist exactly like crops/bushes.
func serialize_tree_growth() -> Dictionary:
	var out := {}
	for cell in tree_growth:
		out["%d,%d" % [cell.x, cell.y]] = tree_growth[cell]
	return out


static func parse_tree_growth(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = float(raw[key])
	return out


## LQ-1: liquid fill levels persist exactly like the other sparse per-cell dicts.
## Only disturbed cells appear here (generated pools carry no entry = full), so an
## undisturbed world serializes an empty map and reloads byte-identically.
func serialize_liquid_level() -> Dictionary:
	var out := {}
	for cell in liquid_level:
		out["%d,%d" % [cell.x, cell.y]] = liquid_level[cell]
	return out


static func parse_liquid_level(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = float(raw[key])
	return out


# ---------- LQ-1: fluid sim access (smoke/deterministic stepping) ----------

## Runs one deterministic fluid step; returns the number of cells that moved.
func fluid_step() -> int:
	return _fluid.step() if _fluid != null else 0


## Pumps the fluid sim to rest (or `max_steps`); returns the steps run.
func fluid_settle(max_steps: int = 256) -> int:
	return _fluid.settle(max_steps) if _fluid != null else 0


## Cells currently awake in the fluid sim (0 => settled/asleep).
func fluid_active_count() -> int:
	return _fluid.active_count() if _fluid != null else 0


## LQ-3 (bucket): scoop up to a bucketful of liquid, drawn from the connected
## pool starting at `cell`, and return its liquid id (or "" if the target isn't a
## liquid or too little is reachable). A single cell need NOT be near-full: water
## spreads into thin films, so the scoop floods outward through same-liquid cells
## (aimed cell + downward first) draining each until a bucket's worth is gathered.
## It still refuses a near-dry sliver (needs SCOOP_MIN_MASS reachable) and removes
## a whole bucketful at once, so it can't dredge a puddle a hair at a time.
func scoop_liquid(cell: Vector2i) -> String:
	var id := block_at(cell)
	if not BlockRegistry.is_liquid(id):
		return ""
	# Phase 1: plan a bucketful without mutating, so we can bail cleanly when the
	# reachable pool is too small (no half-scooped puddle left behind).
	var need := SCOOP_BUCKET_UNIT
	var plan: Array = []                  # [cell, amount_to_take]
	var frontier: Array = [cell]
	var visited := {cell: true}
	var scanned := 0
	while need > 0.0001 and not frontier.is_empty() and scanned < SCOOP_MAX_SCAN:
		var c: Vector2i = frontier.pop_front()
		scanned += 1
		if block_at(c) != id:
			continue
		var lvl := float(liquid_level.get(c, 1.0))
		var take := minf(lvl, need)
		if take > 0.0:
			plan.append([c, take])
			need -= take
		# Spread through the pool: downhill first (that is where liquid pools),
		# then sideways, then up.
		for n in [c + Vector2i(0, 1), c + Vector2i(-1, 0),
				c + Vector2i(1, 0), c + Vector2i(0, -1)]:
			if not visited.has(n) and block_at(n) == id:
				visited[n] = true
				frontier.append(n)
	if (SCOOP_BUCKET_UNIT - need) < SCOOP_MIN_MASS:
		return ""
	# Phase 2: apply the drain.
	for entry in plan:
		var c: Vector2i = entry[0]
		var remain := float(liquid_level.get(c, 1.0)) - float(entry[1])
		if remain <= 0.0001:
			cells.erase(c)
			liquid_level.erase(c)
			deltas[c] = "air"
			_set_tile(c, "air")
			block_changed.emit(c, "air")
		else:
			liquid_level[c] = remain
			deltas[c] = id
			_set_tile(c, id)               # re-tile to the lower fill level
			block_changed.emit(c, id)
		if _fluid != null:
			_fluid.wake_neighbours(c)
	return id


## LQ-3 (bucket): pour a full liquid cell into `cell`. Succeeds into air or a
## non-solid decoration (flooded), fails on solids, protected structures, or a
## different liquid. Wakes the sim so the poured liquid immediately settles/flows.
func place_liquid(cell: Vector2i, liquid_id: String) -> bool:
	if not BlockRegistry.is_liquid(liquid_id):
		return false
	var here := block_at(cell)
	if here != "air" and (BlockRegistry.is_solid(here) or BlockRegistry.is_liquid(here)
			or BlockRegistry.has_tag(here, "protected")):
		return false
	cells[cell] = liquid_id
	deltas[cell] = liquid_id
	liquid_level[cell] = 1.0
	_set_tile(cell, liquid_id)
	block_changed.emit(cell, liquid_id)
	if _fluid != null:
		_fluid.wake_neighbours(cell)
	return true


## Total liquid mass in the world (sum of fill levels; a liquid cell with no
## explicit entry counts as 1.0). Used by smoke to assert conservation.
func liquid_mass() -> float:
	var total := 0.0
	for cell in cells:
		if BlockRegistry.is_liquid(cells[cell]):
			total += float(liquid_level.get(cell, 1.0))
	return total


static func parse_deltas(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = str(raw[key])
	return out
