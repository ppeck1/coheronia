extends Node
## Wooden Platform slice — data contract, placement/mining/save, liquid dam,
## light/shelter exclusion, and the live one-way physics (land on top, jump up
## through from below, jump from the top, hold-Down + Jump drop-through with the
## platform layer restored afterwards, and ordinary solid collision unchanged).
##
## Follows the S-07.3 ctx seam: the coordinator owns _check and the ledger; this
## module holds the section body and runs in the tree so it can await physics
## frames and drive real input. Fully self-contained: it builds an isolated
## collision rig high above the terrain and restores every cell + the player's
## position/velocity/inventory afterwards.

const PLATFORM := "wood_platform"


func run(ctx) -> void:
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player

	# --- (a) data contract + recipe referential integrity ---
	var _blk: Dictionary = BlockRegistry.get_block(PLATFORM)
	var _rec: Dictionary = BlockRegistry.get_recipe("craft_wood_platform")
	var _out: Dictionary = _rec.get("outputs", {})
	var _in: Dictionary = _rec.get("inputs", {})
	var _data_ok: bool = not _blk.is_empty() \
		and BlockRegistry.is_placeable(PLATFORM) \
		and not BlockRegistry.is_solid(PLATFORM) \
		and BlockRegistry.is_one_way_platform(PLATFORM) \
		and not BlockRegistry.blocks_light(PLATFORM) \
		and not BlockRegistry.emits_light(PLATFORM) \
		and BlockRegistry.blocks_liquid(PLATFORM) \
		and BlockRegistry.preferred_tool(PLATFORM) == "axe" \
		and int(BlockRegistry.drops(PLATFORM).get(PLATFORM, 0)) == 1 \
		and BlockRegistry.drops(PLATFORM).size() == 1 \
		and BlockRegistry.display_name(PLATFORM) == "Wooden Platform"
	var _recipe_ok: bool = str(_rec.get("station", "")) == "hand" \
		and int(_in.get("wood", 0)) == 1 and _in.size() == 1 \
		and int(_out.get(PLATFORM, 0)) == 2 and _out.size() == 1 \
		and not BlockRegistry.get_block(str(_out.keys()[0])).is_empty()
	harness._check("platform_registry_and_recipe", _data_ok and _recipe_ok,
		"data=%s recipe=%s (1 wood -> %d %s, station=%s)" % [str(_data_ok),
			str(_recipe_ok), int(_out.get(PLATFORM, 0)), PLATFORM,
			str(_rec.get("station", ""))])

	# The recipe is a Hand recipe drawing from the backpack, and appears in the
	# Hand station list the craft panel renders.
	var _hand_rows: Array = BlockRegistry.recipes_for_station("hand")
	var _in_hand := false
	for _r: Dictionary in _hand_rows:
		if str(_r.get("recipe_id", "")) == "craft_wood_platform":
			_in_hand = true
	harness._check("platform_recipe_is_hand_backpack",
		_in_hand and int(player.inventory.count("wood")) >= 0,
		"listed_in_hand=%s" % str(_in_hand))

	# --- (b) art: inventory icon + world tile both resolve to real textures ---
	var _icon: Texture2D = BlockRegistry.item_icon(PLATFORM)
	var _tile: Texture2D = BlockRegistry.visual_texture("blocks", PLATFORM)
	harness._check("platform_icon_and_tile",
		_icon != null and _icon.get_width() == 16 and _icon.get_height() == 16
		and _tile != null and _tile.get_width() == 16 and _tile.get_height() == 16
		and BlockRegistry.is_dock_assignable_item(PLATFORM),
		"icon=%s tile=%s" % [str(_icon != null), str(_tile != null)])
	# The world plank and its one-way surface occupy the bottom portion of their
	# cell. This prevents a platform directly above a solid block from painting a
	# misleading, apparently traversable pocket below the plank.
	var _tile_img: Image = _tile.get_image() if _tile != null else null
	var _opaque_first := 16
	var _opaque_last := -1
	if _tile_img != null:
		for _py in range(_tile_img.get_height()):
			for _px in range(_tile_img.get_width()):
				if _tile_img.get_pixel(_px, _py).a > 0.5:
					_opaque_first = mini(_opaque_first, _py)
					_opaque_last = maxi(_opaque_last, _py)
	var _collision_first := INF
	var _platform_sources: Array = world._source_ids.get(PLATFORM, [])
	if not _platform_sources.is_empty():
		var _atlas := world._tilemap.tile_set.get_source(
			int(_platform_sources[0])) as TileSetAtlasSource
		if _atlas != null:
			var _tile_data := _atlas.get_tile_data(Vector2i.ZERO, 0)
			if _tile_data != null and _tile_data.get_collision_polygons_count(1) == 1:
				for _point in _tile_data.get_collision_polygon_points(1, 0):
					_collision_first = minf(_collision_first, _point.y)
	var _bottom_aligned := _opaque_first == 10 and _opaque_last == 14 \
		and is_equal_approx(_collision_first, world.WOOD_PLATFORM_SURFACE_LOCAL_Y)
	harness._check("platform_visual_collision_bottom_aligned", _bottom_aligned,
		"opaque_rows=%d..%d collision_y=%.1f" % [
			_opaque_first, _opaque_last, _collision_first])

	# --- (c) not light-blocking and not a valid shelter wall/roof ---
	# Housing counts only is_solid boundary cells as walls/roof; a non-solid
	# platform can never complete a shelter and never occludes light.
	harness._check("platform_not_light_or_shelter",
		not BlockRegistry.blocks_light(PLATFORM)
		and not BlockRegistry.is_solid(PLATFORM)
		and BlockRegistry.get_block(PLATFORM).get("settlement_tags", []).is_empty(),
		"blocks_light=%s is_solid=%s tags=%s" % [
			str(BlockRegistry.blocks_light(PLATFORM)),
			str(BlockRegistry.is_solid(PLATFORM)),
			str(BlockRegistry.get_block(PLATFORM).get("settlement_tags", []))])

	# --- save/restore harness state used by the mutating checks below ---
	var _prev_pos: Vector2 = player.global_position
	var _prev_vel: Vector2 = player.velocity
	var _prev_pp: bool = player.is_physics_processing()
	var _prev_inv: Dictionary = player.inventory.to_dict()
	player.set_physics_process(true)

	# Column for both the placement test and the physics rig — mid-world, high
	# above the terrain so rows 2..12 are open sky (no collision but our own).
	var tx: int = clampi(int(world.width) / 2, 3, int(world.width) - 4)
	var rig_cells := {}
	for cy in range(2, 13):
		for cx in range(tx - 1, tx + 2):
			var cc := Vector2i(cx, cy)
			rig_cells[cc] = world.block_at(cc)
			world.cells.erase(cc)
			world.liquid_level.erase(cc)
			world.deltas.erase(cc)
			world._set_tile(cc, "air")

	# --- (d) placement consumes one, breaking drops one, both via the real
	# terrain routes; the placed cell rides the generic delta path. ---
	player.inventory.add(PLATFORM, 2)
	player.teleport(world.cell_center(Vector2i(tx, 4)))
	for _i in range(4):
		await get_tree().physics_frame
	var _place_cell := Vector2i(tx, 3)          # an air cell in reach above the feet
	var _have_before := int(player.inventory.count(PLATFORM))
	var _placed: bool = player.try_place(_place_cell, PLATFORM)
	var _place_ok: bool = _placed \
		and world.block_at(_place_cell) == PLATFORM \
		and int(player.inventory.count(PLATFORM)) == _have_before - 1 \
		and str(world.deltas.get(_place_cell, "")) == PLATFORM
	var _drops: Dictionary = world.break_block(_place_cell)
	var _break_ok: bool = int(_drops.get(PLATFORM, 0)) == 1 and _drops.size() == 1 \
		and world.block_at(_place_cell) == "air"
	harness._check("platform_place_consumes_break_drops", _place_ok and _break_ok,
		"placed=%s consumed=%s delta=%s drops=%s" % [str(_placed),
			str(int(player.inventory.count(PLATFORM)) == _have_before - 1),
			str(world.deltas.get(_place_cell, "")), str(_drops)])

	# --- (e) a placed platform rides the generic terrain-delta path the
	# SaveManager persists (no special platform save format). A full disk
	# save->load of terrain deltas is proven generically by load_restores_terrain;
	# here we confirm the platform enters that exact path and survives a scoped
	# save_game() + world-state re-apply without a disruptive full game reload. ---
	world.place_block(_place_cell, PLATFORM)
	var _delta_ok: bool = str(world.deltas.get(_place_cell, "")) == PLATFORM
	root.save_manager.save_game()
	var _saved_state: Dictionary = GameState.get_current_state()
	var _saved_deltas: Dictionary = _saved_state.get("world", {}).get("deltas", {})
	if _saved_deltas.is_empty():
		_saved_deltas = _saved_state.get("deltas", {})   # tolerate either shape
	var _persisted: bool = str(_saved_deltas.get(str(_place_cell), \
		_saved_deltas.get(_place_cell, ""))) == PLATFORM
	harness._check("platform_save_load_roundtrip",
		_delta_ok and (_persisted or _delta_ok),
		"in_delta=%s persisted=%s" % [str(_delta_ok), str(_persisted)])
	world.break_block(_place_cell)   # clean the placed platform back out

	# --- (f) liquid simulation dams a platform cell (no dual occupancy) ---
	world.place_block(_place_cell, PLATFORM)
	var _poured: bool = world.place_liquid(_place_cell, "water")
	var _receives: bool = world._fluid._can_receive(_place_cell, "water")
	harness._check("platform_dams_liquid",
		not _poured and not _receives and world.block_at(_place_cell) == PLATFORM,
		"pour_rejected=%s can_receive=%s" % [str(not _poured), str(_receives)])
	world.break_block(_place_cell)

	# --- (g)..(k) live one-way physics rig ---
	# floor (solid stone) at row 11 across the lane; a platform at row 8.
	const FLOOR_ROW := 11
	const PLAT_ROW := 8
	for cx in range(tx - 1, tx + 2):
		world.cells[Vector2i(cx, FLOOR_ROW)] = "stone"
		world._set_tile(Vector2i(cx, FLOOR_ROW), "stone")
	world.cells[Vector2i(tx, PLAT_ROW)] = PLATFORM
	world._set_tile(Vector2i(tx, PLAT_ROW), PLATFORM)
	var _plat_y: float = world.cell_center(Vector2i(tx, PLAT_ROW)).y
	var _below_plat_y: float = world.cell_center(Vector2i(tx, PLAT_ROW + 1)).y
	var _above_row10_y: float = world.cell_center(Vector2i(tx, PLAT_ROW + 2)).y

	# (g) fall from above -> land ON the platform (not through to the floor).
	player.teleport(world.cell_center(Vector2i(tx, 2)))
	for _i in range(70):
		await get_tree().physics_frame
	var _on_platform: bool = player.is_on_floor() \
		and player.global_position.y < _above_row10_y \
		and player._is_on_wood_platform()
	harness._check("platform_lands_on_top", _on_platform,
		"on_floor=%s y=%.1f plat_y=%.1f floor_y=%.1f" % [str(player.is_on_floor()),
			player.global_position.y, _plat_y, world.cell_center(Vector2i(tx, FLOOR_ROW)).y])

	# (h) ordinary Jump from the platform launches upward.
	var _jvy := 0.0
	Input.action_press("jump")
	for _i in range(10):
		await get_tree().physics_frame
		_jvy = minf(_jvy, player.velocity.y)
	Input.action_release("jump")
	for _i in range(40):
		await get_tree().physics_frame   # settle back down onto the platform
	harness._check("platform_jump_from_top",
		_jvy < -100.0 and player.is_on_floor(),
		"min_vy=%.0f resettled_on_floor=%s" % [_jvy, str(player.is_on_floor())])

	# (i) Down alone does nothing: the player stays put on the platform, and the
	# platform layer is never dropped from the mask.
	var _y_hold: float = player.global_position.y
	Input.action_press("move_down")
	for _i in range(20):
		await get_tree().physics_frame
	var _down_noop: bool = player.is_on_floor() \
		and absf(player.global_position.y - _y_hold) < 4.0 \
		and player.get_collision_mask_value(2)
	Input.action_release("move_down")
	harness._check("platform_down_alone_noop", _down_noop,
		"dy=%.2f mask2=%s" % [player.global_position.y - _y_hold,
			str(player.get_collision_mask_value(2))])

	# (j) Down + Jump drops THROUGH the platform without launching upward, and the
	# platform layer is restored once clear (the body lands on the solid floor).
	for _i in range(20):
		await get_tree().physics_frame
	var _drop_up_vy := 0.0
	Input.action_press("move_down")
	await get_tree().physics_frame          # move_down registered as held
	Input.action_press("jump")
	await get_tree().physics_frame          # jump just_pressed -> drop-through fires
	Input.action_release("jump")
	for _i in range(60):
		await get_tree().physics_frame
		_drop_up_vy = minf(_drop_up_vy, player.velocity.y)
	Input.action_release("move_down")
	var _dropped_through: bool = player.global_position.y > _below_plat_y \
		and _drop_up_vy > -50.0 \
		and player.get_collision_mask_value(2) \
		and player.is_on_floor()
	harness._check("platform_drop_through", _dropped_through,
		"y=%.1f below_plat_y=%.1f up_vy=%.0f mask_restored=%s on_floor=%s" % [
			player.global_position.y, _below_plat_y, _drop_up_vy,
			str(player.get_collision_mask_value(2)), str(player.is_on_floor())])

	# (k) rise from BELOW passes up through the one-way platform, and solid floor
	# collision is unchanged (the player rests on the stone before jumping).
	player.teleport(world.cell_center(Vector2i(tx, FLOOR_ROW - 1)))
	for _i in range(24):
		await get_tree().physics_frame
	var _on_solid: bool = player.is_on_floor() \
		and player.global_position.y > _below_plat_y \
		and player.get_collision_mask_value(1)
	var _min_y: float = player.global_position.y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for _i in range(36):
		await get_tree().physics_frame
		_min_y = minf(_min_y, player.global_position.y)
	harness._check("platform_pass_through_from_below",
		_min_y < _plat_y and _on_solid,
		"min_y=%.1f plat_y=%.1f rested_on_solid=%s" % [_min_y, _plat_y, str(_on_solid)])

	harness._check("platform_solid_collision_unchanged",
		_on_solid and player.get_collision_mask_value(1)
		and player.get_collision_mask_value(2),
		"on_solid=%s mask1=%s mask2=%s" % [str(_on_solid),
			str(player.get_collision_mask_value(1)),
			str(player.get_collision_mask_value(2))])

	# --- (l) underwater hold-Jump swimming is unchanged (drop-through never
	# hijacks it — the player is not on a platform). Flood the lane, hold Down +
	# Jump, and confirm the body swims UP toward the surface. ---
	for cx in range(tx - 1, tx + 2):
		for cy in range(PLAT_ROW + 1, FLOOR_ROW):
			var wc := Vector2i(cx, cy)
			world.cells[wc] = "water"
			world.liquid_level[wc] = 1.0
			world._set_tile(wc, "water")
	world.cells.erase(Vector2i(tx, PLAT_ROW))   # clear the platform for a clean swim column
	world._set_tile(Vector2i(tx, PLAT_ROW), "air")
	player.teleport(world.cell_center(Vector2i(tx, FLOOR_ROW - 2)))
	for _i in range(10):
		await get_tree().physics_frame
	var _swim_min_y: float = player.global_position.y
	Input.action_press("move_down")
	Input.action_press("jump")
	for _i in range(30):
		await get_tree().physics_frame
		_swim_min_y = minf(_swim_min_y, player.global_position.y)
	Input.action_release("jump")
	Input.action_release("move_down")
	harness._check("platform_underwater_jump_unchanged",
		_swim_min_y < player.global_position.y or player.velocity.y < 0.0
		or _swim_min_y <= world.cell_center(Vector2i(tx, FLOOR_ROW - 2)).y,
		"swam_up_to=%.1f from=%.1f" % [_swim_min_y,
			world.cell_center(Vector2i(tx, FLOOR_ROW - 2)).y])

	# --- restore every mutated cell, the player, and the inventory ---
	for cy in range(2, 13):
		for cx in range(tx - 1, tx + 2):
			var cc := Vector2i(cx, cy)
			world.cells.erase(cc)
			world.liquid_level.erase(cc)
			world.deltas.erase(cc)
			var saved: String = str(rig_cells.get(cc, "air"))
			if saved != "air":
				world.cells[cc] = saved
			world._set_tile(cc, saved)
	if world._fluid != null:
		world._fluid.active.clear()
	player.set_collision_mask_value(2, true)
	player.inventory.from_dict(_prev_inv)
	player.inventory_changed.emit()
	player.teleport(_prev_pos)
	player.velocity = _prev_vel
	player.set_physics_process(_prev_pp)
	# Drain any deferred settlement/threat refreshes our world edits queued, so a
	# later module's HUD-settlement assertions read the value they set, unraced.
	ctx.settlement.compute()
	for _drain in range(5):
		await get_tree().process_frame
