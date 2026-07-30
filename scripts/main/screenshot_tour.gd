extends Node
## README media tour. Runs when COHERONIA_SHOTS=1 (mirroring the smoke hook):
## stages a lived-in settlement, captures gameplay screenshots to
## user://shots/, and quits. Cosmetic staging only — never part of smoke or
## validation, and it never saves the staged state.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var root: Node2D = get_parent()
	var world: Node2D = root.world
	var player: CharacterBody2D = root.player
	var hall: Node2D = root.town_hall
	var hud: CanvasLayer = root.hud
	DirAccess.make_dir_recursive_absolute("user://shots")
	# Focused run: capture only the item-wiring shots and quit (fast, and avoids
	# the full tour's window-focus stall in an unattended run). Launch with
	# COHERONIA_SHOTS=1 (game_root's tour hook) + COHERONIA_SHOTS_FOCUS=iw.
	if OS.get_environment("COHERONIA_SHOTS_FOCUS") == "iw":
		await _shoot_item_wiring(root, world, player, hud)
		print("SHOTS complete (item-wiring) -> user://shots")
		get_tree().quit(0)
		return
	if OS.get_environment("COHERONIA_SHOTS_FOCUS") == "cel":
		await _shoot_celestial(root, world, player, hud)
		print("SHOTS complete (celestial) -> user://shots")
		get_tree().quit(0)
		return
	world.setup(4242)
	root._position_actors()
	player.get_node("Camera2D").reset_smoothing()

	# Stage a lived-in settlement: gear, supplies, stockpile, torch line.
	player.tool_tier = 2
	player.axe_tier = 1
	player.equip_item("weapon", "sword_crude")
	player.equip_item("helmet", "helmet_crude")
	player.equip_item("torso", "torso_crude")
	player.equip_item("feet", "feet_crude")
	player.equip_item("ring_2", "ring_band")
	player.equip_item("amulet", "amulet_focus")
	player.inventory.from_dict({"dirt": 24, "wood": 12, "stone": 8, "torch": 5, "food": 6})
	player.inventory_changed.emit()
	hall.stockpile = {"wood": 14, "stone": 9, "food": 12, "dirt": 6}
	hall.stockpile_changed.emit()
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	var ground_y: int = world.hall_info["ground_y"]
	for dx in [-8, -5, 5, 8]:
		var cell := Vector2i(hall_cell.x + dx, ground_y - 1)
		if world.block_at(cell) == "air":
			world.place_block(cell, "torch")
	for i in range(40):
		await get_tree().physics_frame

	await _shot("01_settlement_day")

	root.time_of_day = 0.72
	root.is_night = true
	root.canvas_modulate.color = root.NIGHT_TINT
	await _shot("02_night_torchlight")
	root.time_of_day = 0.3
	root.is_night = false
	root.canvas_modulate.color = root.DAY_TINT

	hud.toggle_inventory_panel()
	await _shot("03_inventory")
	hud.toggle_inventory_panel()

	hud.toggle_character_panel()
	await _shot("13_character")
	hud.toggle_character_panel()

	hud.refresh_town_panel()
	hud.toggle_town_panel()
	await _shot("04_town_hall")
	hud.toggle_town_panel()

	# R-09: directed contracts from the Town Hall. Stage a mixed list so the
	# public shot shows available, active, completed, and claimed rows.
	root.contracts.apply([])
	hall.stockpile["stone"] = 24
	hall.stations_built["workbench"] = true
	root.accept_contract("stone_reserve")
	root.accept_contract("workbench_charter")
	root.claim_contract("workbench_charter")
	root.accept_contract("first_hunt")
	root.contracts.evaluate()
	root._contracts_panel.open()
	await _shot("18_contracts_panel")
	root._contracts_panel.close()

	# R-07: the unified Crafting panel (C) -- every recipe grouped by source with
	# have/need gating and Build rows for unbuilt stations.
	root._craft_panel.open()
	await _shot("15_crafting")
	root._craft_panel.close()

	# R-08: the visible farmhand settler at work -- a mature crop by the hall, the
	# settler beside it (frozen for a clean compose), and the harvest in the event
	# log. The subject is a concrete actor over the unchanged abstract population.
	if not hud._event_panel.visible:
		hud._toggle_event_module()
	var _subjects: Array = get_tree().get_nodes_in_group("subjects")
	var farmhand: Node2D = null
	for _subj in _subjects:
		_subj.set_physics_process(false)          # freeze the whole crew for a clean compose
		if str(_subj.job) == "farmhand":
			farmhand = _subj
	if farmhand != null:
		# Right of the torch line (dx 5/8) so the settler + crop read cleanly. A
		# short row of tilled soil + ripe crops makes the "harvest" obviously a farm.
		var crop_cell := Vector2i(hall_cell.x + 12, ground_y - 1)
		for cx in range(crop_cell.x - 1, crop_cell.x + 3):
			var soil := Vector2i(cx, ground_y)
			if world.block_at(soil) != "air":
				world.break_block(soil)
			world.place_block(soil, "farm_soil")
			var top := Vector2i(cx, ground_y - 1)
			if world.block_at(top) != "air":
				world.break_block(top)
			world.place_block(top, "crop_ripe")
		farmhand.global_position = world.cell_center(Vector2i(crop_cell.x - 1, crop_cell.y))
		player.global_position = world.cell_center(Vector2i(crop_cell.x + 3, crop_cell.y))
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		root.log_event("The farmhand gathers a ripe crop for the stockpile.")
		await _shot("16_farmhand")

		# R-08 slice 3: loose ground item drops. They spawn in the air, fall under
		# gravity, and rest on the ground drawn with the SAME icons the inventory
		# uses; the "+N Item" pickup toast reports what was gathered.
		var _gd_base: Vector2 = world.cell_center(Vector2i(hall_cell.x + 17, ground_y - 2))
		for _gd in [["wood", 3, -34.0], ["stone", 2, -12.0], ["food", 1, 12.0], ["ore", 4, 34.0]]:
			world.spawn_item_drop(_gd_base + Vector2(_gd[2] as float, -30.0), str(_gd[0]), int(_gd[1]))
		player.global_position = _gd_base + Vector2(78.0, 0.0)   # outside pickup radius, keeps drops in frame
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		for i in range(34):
			await get_tree().physics_frame        # let them fall and settle on the ground
		hud.notify_pickup({"wood": 3, "stone": 2})
		root.log_event("Loose drops settle on the ground, ready to gather.")
		await _shot("17_ground_drops")
		for _d in get_tree().get_nodes_in_group("item_drops"):
			_d.queue_free()

	# Independent top modules: Map and Events remain visible together, with
	# the contextual stack positioned below the taller surface.
	if not hud._event_panel.visible:
		hud._toggle_event_module()
	hud.toggle_map()
	hud.update_map(root.map_snapshot())
	hud.set_interaction_prompt("[E] Town Hall")
	await _shot("14_map_events_together")
	hud.toggle_map()

	root.player_level = 4
	root.try_purchase_perk("stone_recovery")
	hud.toggle_skill_panel()
	hud.skill_panel().select_node("deep_sense")
	await _shot("05_skill_tree")
	hud.toggle_skill_panel()

	# FQ-20 polish: damage-state proof — both liquid pools visibly drained
	# (the nine-patch squash bug made "full" the only state a tour ever saw).
	player.health = player.max_health * 0.35
	player.attunement = player.max_attunement() * 0.3
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())
	await _shot("10_vessel_damage_states")
	player.health = player.max_health
	player.attunement = player.max_attunement()
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())

	# FQ-21 visual regressions: prove that the dock action treatment covers the
	# complete Town Hall cell, then prove that both vessel interiors drain
	# without exposing a square/circular placeholder layer.
	var town_button := hud.find_child("DockActionTownHall", true, false) as Button
	if town_button != null:
		# Apply the exact hover StyleBox as the normal state for a deterministic
		# capture; OS mouse warping is unreliable with stretched viewports.
		var normal_style := town_button.get_theme_stylebox("normal")
		var hover_style := town_button.get_theme_stylebox("hover")
		town_button.add_theme_stylebox_override("normal", hover_style)
		await _shot("11_town_hall_hover")
		town_button.add_theme_stylebox_override("normal", normal_style)
	var regen_mult: float = player.attunement_regen_mult
	player.attunement_regen_mult = 0.0
	player.health = 0.0
	player.attunement = 0.0
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())
	await _shot("12_vessels_empty")
	player.health = player.max_health
	player.attunement = player.max_attunement()
	player.attunement_regen_mult = regen_mult
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())

	# FQ-09W verification shot: a mined chamber at midday — backing walls
	# behind the air, dark cave ambient, one torch as the readable light.
	var shaft_x: int = hall_cell.x + 14
	var shaft_top: int = int(world.surface.get(shaft_x, 30))
	for y in range(shaft_top, shaft_top + 9):
		for x in range(shaft_x - 2, shaft_x + 3):
			if y > shaft_top + 2 or x == shaft_x:
				if world.block_at(Vector2i(x, y)) != "air":
					world.break_block(Vector2i(x, y))
	world.place_block(Vector2i(shaft_x - 1, shaft_top + 8), "torch")
	root.time_of_day = 0.5
	root.is_night = false
	player.global_position = world.cell_center(Vector2i(shaft_x + 1, shaft_top + 7))
	player.velocity = Vector2.ZERO
	root.canvas_modulate.color = root.ambient_target_color()
	player.get_node("Camera2D").reset_smoothing()
	await _shot("09_underground_midday_torch")

	# World Depths (WD-1..4): the deep world ends in a HELL biome. Stage a
	# readable pocket near the bottom of the descent -- hellstone walls, obsidian
	# accents, and a glowing lava pool (lava emits its own light) under the ember
	# ambient tint the deepest band drives. Hell now scales to every world size.
	var _hx: int = hall_cell.x
	var _hsurf: int = int(world.surface.get(_hx, 40))
	var _hcol: int = maxi(1, (world.height - 2) - _hsurf)
	var _hy: int = _hsurf + int(0.82 * float(_hcol))
	for _cy in range(_hy - 5, _hy + 5):
		for _cx in range(_hx - 9, _hx + 10):
			if world.block_at(Vector2i(_cx, _cy)) != "air":
				world.break_block(Vector2i(_cx, _cy))
	for _cx in range(_hx - 9, _hx + 10):
		for _fy in [_hy + 3, _hy + 4]:
			world.cells[Vector2i(_cx, _fy)] = "hellstone"
			world._set_tile(Vector2i(_cx, _fy), "hellstone")
	# A broad lava lake to the right; a raised hellstone ledge on the left.
	for _cx in range(_hx - 4, _hx + 10):
		world.cells[Vector2i(_cx, _hy + 2)] = "lava"
		world._set_tile(Vector2i(_cx, _hy + 2), "lava")
	for _cx in range(_hx - 9, _hx - 3):
		world.cells[Vector2i(_cx, _hy + 1)] = "hellstone"
		world._set_tile(Vector2i(_cx, _hy + 1), "hellstone")
	for _oc in [Vector2i(_hx - 9, _hy), Vector2i(_hx + 9, _hy - 1), Vector2i(_hx + 2, _hy + 3), Vector2i(_hx - 2, _hy + 3)]:
		world.cells[_oc] = "obsidian"
		world._set_tile(_oc, "obsidian")
	# Torches flank the player for readable light; the lava lake glows on its own.
	for _tx in [_hx - 7, _hx - 3, _hx + 8]:
		world.cells[Vector2i(_tx, _hy)] = "torch"
		world._set_tile(Vector2i(_tx, _hy), "torch")
	world.cells[Vector2i(_hx + 8, _hy - 3)] = "torch"
	world._set_tile(Vector2i(_hx + 8, _hy - 3), "torch")
	player.global_position = world.cell_center(Vector2i(_hx - 5, _hy))
	player.velocity = Vector2.ZERO
	player.get_node("Camera2D").reset_smoothing()
	# Cosmetic staging: a readable warm firelight tint (brighter than the true
	# full-ember gloom) so the hellstone, obsidian, and lava all read in the shot.
	root.canvas_modulate.color = Color(0.66, 0.38, 0.32)
	await _shot("19_hell_biome")

	# LQ-2 verification shots: leveled liquid physics + partial-fill rendering. A
	# stone basin with a metered lava pour that settles to a PARTIAL level, so the
	# bottom-anchored fill tiles read. The live tick is paused so the mid-pour frame
	# is a deterministic number of steps, not whatever the frame clock happened to
	# advance. Captured mid-cascade (thinning fill tiles) and once settled (a flat
	# partial pool). Cosmetic staging only — the tour never saves this state.
	world.fluid_paused = true
	var _fx: int = hall_cell.x - 30
	var _fy: int = int(world.surface.get(_fx, 30)) + 7
	for _cy in range(_fy - 8, _fy + 2):        # clear a chamber
		for _cx in range(_fx - 7, _fx + 8):
			if world.block_at(Vector2i(_cx, _cy)) != "air":
				world.break_block(Vector2i(_cx, _cy))
	for _cx in range(_fx - 4, _fx + 5):        # basin floor
		world.cells[Vector2i(_cx, _fy)] = "stone"; world._set_tile(Vector2i(_cx, _fy), "stone")
	for _cy in range(_fy - 5, _fy + 1):        # basin walls
		world.cells[Vector2i(_fx - 4, _cy)] = "stone"; world._set_tile(Vector2i(_fx - 4, _cy), "stone")
		world.cells[Vector2i(_fx + 4, _cy)] = "stone"; world._set_tile(Vector2i(_fx + 4, _cy), "stone")
	for _cy in range(_fy - 5, _fy - 1):        # a lava column high on the left, metered
		world.cells[Vector2i(_fx - 3, _cy)] = "lava"; world._set_tile(Vector2i(_fx - 3, _cy), "lava")
		world._fluid.wake(Vector2i(_fx - 3, _cy))
	player.global_position = world.cell_center(Vector2i(_fx, _fy - 3))
	player.velocity = Vector2.ZERO
	player.get_node("Camera2D").reset_smoothing()
	root.time_of_day = 0.5
	root.is_night = false
	root.canvas_modulate.color = Color(0.72, 0.52, 0.42)
	for _s in range(9):                        # mid-cascade: a fixed, small number of steps
		world.fluid_step()
	await _shot("20_lava_flow_midpour")
	world.fluid_settle(800)                     # settled: a flat partial pool
	await _shot("21_lava_flow_settled")

	# LQ-2c: rising-bubble overlay. A wide OPEN lava pool (top exposed) so bubbles
	# nucleate along the floor, drift slowly upward, and burst at the surface. The
	# fluid stays paused (a still, brim-full pool); we pump a stretch of idle
	# frames so the overlay populates a spread of bubbles at different heights for
	# the still. Cosmetic staging only — the tour never saves this state.
	var _bx: int = _fx
	var _by: int = _fy
	for _cy in range(_by - 8, _by + 1):        # carve a wider, taller chamber
		for _cx in range(_bx - 7, _bx + 8):
			if world.block_at(Vector2i(_cx, _cy)) != "air":
				world.break_block(Vector2i(_cx, _cy))
	for _cx in range(_bx - 7, _bx + 8):        # basin floor
		world.cells[Vector2i(_cx, _by)] = "stone"; world._set_tile(Vector2i(_cx, _by), "stone")
	for _cy in range(_by - 8, _by + 1):        # basin walls
		world.cells[Vector2i(_bx - 7, _cy)] = "stone"; world._set_tile(Vector2i(_bx - 7, _cy), "stone")
		world.cells[Vector2i(_bx + 7, _cy)] = "stone"; world._set_tile(Vector2i(_bx + 7, _cy), "stone")
	for _cy in range(_by - 5, _by):            # a deep OPEN lava pool (top exposed)
		for _cx in range(_bx - 6, _bx + 7):
			world.cells[Vector2i(_cx, _cy)] = "lava"; world._set_tile(Vector2i(_cx, _cy), "lava")
	player.global_position = world.cell_center(Vector2i(_bx, _by - 3))
	player.velocity = Vector2.ZERO
	player.get_node("Camera2D").reset_smoothing()
	for _f in range(120):                      # let the overlay populate rising bubbles
		await get_tree().process_frame
	await _shot("22_lava_bubbles")
	world.fluid_paused = false

	# LQ-3 water: regenerate a v3 world and frame a REAL generated surface pond.
	GameState.current_config = WorldConfig.new({"size": "medium", "seed": 2024, "gen_version": 3})
	world.setup(2024)
	root._position_actors()
	var pond := Vector2i(-1, -1)
	for wx in range(4, world.width - 4):
		var sy: int = int(world.surface.get(wx, 0))
		if world.block_at(Vector2i(wx, sy)) == "water":
			pond = Vector2i(wx, sy)
			break
	if pond.x >= 0:
		root.time_of_day = 0.4
		root.is_night = false
		root.canvas_modulate.color = root.DAY_TINT
		player.global_position = world.cell_center(pond + Vector2i(3, -2))
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		await _shot("23_water_surface_lake")

	# LQ-3 reaction: pour water onto a lava pool and watch obsidian crust form.
	world.fluid_paused = true
	var _rx := hall_cell.x - 30
	var _ry := int(world.surface.get(_rx, 30)) + 7
	for _cy in range(_ry - 9, _ry + 2):         # clear a chamber
		for _cx in range(_rx - 7, _rx + 8):
			if world.block_at(Vector2i(_cx, _cy)) != "air":
				world.break_block(Vector2i(_cx, _cy))
	for _cx in range(_rx - 5, _rx + 6):         # basin floor + a lava layer in it
		world.cells[Vector2i(_cx, _ry)] = "stone"; world._set_tile(Vector2i(_cx, _ry), "stone")
		world.cells[Vector2i(_cx, _ry - 1)] = "lava"; world._set_tile(Vector2i(_cx, _ry - 1), "lava")
	for _cy in range(_ry - 6, _ry + 1):         # basin walls
		world.cells[Vector2i(_rx - 5, _cy)] = "stone"; world._set_tile(Vector2i(_rx - 5, _cy), "stone")
		world.cells[Vector2i(_rx + 5, _cy)] = "stone"; world._set_tile(Vector2i(_rx + 5, _cy), "stone")
	for _cy in range(_ry - 5, _ry - 2):         # a water column above the lava
		world.cells[Vector2i(_rx, _cy)] = "water"; world._set_tile(Vector2i(_rx, _cy), "water")
		world._fluid.wake(Vector2i(_rx, _cy))
	player.global_position = world.cell_center(Vector2i(_rx + 3, _ry - 3))
	player.velocity = Vector2.ZERO
	player.get_node("Camera2D").reset_smoothing()
	root.canvas_modulate.color = Color(0.7, 0.55, 0.5)
	for _s in range(24):                        # let the water reach the lava
		world.fluid_step()
	await _shot("24_lava_water_obsidian")

	# Swim + breath: submerge the player deep inside a large water body so the
	# frame reads as underwater and the breath gauge is mid-drain (the HUD bar
	# only shows below full). Cosmetic staging — breath is set directly.
	world.fluid_paused = true
	var _wx0 := hall_cell.x + 30
	var _wtop := int(world.surface.get(_wx0, 30)) + 2   # waterline a touch below grade
	var _wbot := _wtop + 18
	var _whalf := 16
	for _cy in range(_wtop - 2, _wbot + 2):             # carve the basin (+ air above line)
		for _cx in range(_wx0 - _whalf - 1, _wx0 + _whalf + 2):
			if world.block_at(Vector2i(_cx, _cy)) != "air":
				world.break_block(Vector2i(_cx, _cy))
	for _cy in range(_wtop, _wbot + 1):                 # stone shell, water fill
		for _cx in range(_wx0 - _whalf, _wx0 + _whalf + 1):
			var _edge := _cx <= _wx0 - _whalf or _cx >= _wx0 + _whalf or _cy >= _wbot
			var _id := "stone" if _edge else "water"
			world.cells[Vector2i(_cx, _cy)] = _id
			world._set_tile(Vector2i(_cx, _cy), _id)
	root.time_of_day = 0.35
	root.is_night = false
	root.canvas_modulate.color = root.DAY_TINT
	player.global_position = world.cell_center(Vector2i(_wx0, _wtop + 6))
	player.velocity = Vector2.ZERO
	player.breath = player.max_breath() * 0.4
	hud.update_breath(player.breath, player.max_breath())
	if hud._goal_panel != null:                 # let the breath gauge read cleanly
		hud._goal_panel.visible = false
	player.get_node("Camera2D").reset_smoothing()
	await _shot("26_swim_breath")

	await _shoot_item_wiring(root, world, player, hud)

	print("SHOTS complete -> user://shots")
	get_tree().quit(0)


## Item-wiring shots (renewable tree loop + placeable deep blocks). Split out so a
## focused run (COHERONIA_SHOTS=iw) can capture just these two without the full
## 26-shot tour — the long tour can stall on window-focus in an unattended run.
func _shoot_item_wiring(root: Node2D, world: Node2D, player: CharacterBody2D, hud: CanvasLayer) -> void:
	# Fresh, undisturbed surface so the new content stages cleanly on hall grade.
	world.setup(4242)
	root._position_actors()
	root.time_of_day = 0.3
	root.is_night = false
	root.canvas_modulate.color = root.DAY_TINT
	if hud._goal_panel != null:
		hud._goal_panel.visible = true
	# Zoom in so the new content reads large in the frame (the camera rides the
	# player, so positioning the player on the subject centres it).
	var _iw_cam: Camera2D = player.get_node("Camera2D")
	_iw_cam.zoom = Vector2(2.4, 2.4)
	var _iw_hall: Vector2i = world.hall_info["center_cell"]
	var _iw_gy: int = world.hall_info["ground_y"]

	# Renewable trees: a full tree grown from a planted sapling, a second sapling
	# still growing beside it, and tree seeds in the pack (dropped from clearing
	# leaves). Left of the hall, on the flattened grass grade.
	var _tw0: int = _iw_hall.x - 6
	var _tw_row: int = _iw_gy - 1
	for _cx in range(_tw0 - 2, _tw0 + 7):
		for _cy in range(_tw_row - 9, _tw_row + 1):
			if world.block_at(Vector2i(_cx, _cy)) != "air":
				world.break_block(Vector2i(_cx, _cy))
	world.plant_sapling(Vector2i(_tw0, _tw_row))
	world._tick_tree_growth(1000.0)                # mature the first into a real tree
	world.plant_sapling(Vector2i(_tw0 + 4, _tw_row))   # the second stays a sapling
	player.tool_tier = 2
	player.axe_tier = 1
	player.inventory.from_dict({"tree_seed": 5, "wood": 9, "food": 4})
	player.inventory_changed.emit()
	root.log_event("Clearing leaves drops tree seeds — plant them to regrow the forest.")
	player.global_position = world.cell_center(Vector2i(_tw0 + 2, _tw_row - 2))
	player.velocity = Vector2.ZERO
	_iw_cam.reset_smoothing()
	await _shot("27_renewable_tree")

	# Placeable deep blocks: hellstone + obsidian now build as structural blocks
	# (their only missing connection was is_placeable). A short checker wall on the
	# right of the hall, with the blocks in the pack.
	var _db0: int = _iw_hall.x + 3
	var _db_w: int = 6
	var _db_h: int = 4
	for _i in range(_db_w):
		var _bx: int = _db0 + _i
		for _cy in range(_iw_gy - _db_h - 1, _iw_gy):
			if world.block_at(Vector2i(_bx, _cy)) != "air":
				world.break_block(Vector2i(_bx, _cy))
		for _r in range(_db_h):
			var _checker: bool = (_i + _r) % 2 == 0
			world.place_block(Vector2i(_bx, _iw_gy - 1 - _r),
				"hellstone" if _checker else "obsidian")
	player.inventory.from_dict({"hellstone": 8, "obsidian": 8, "tree_seed": 3})
	player.inventory_changed.emit()
	root.log_event("Hellstone and obsidian now place as structural, defensive blocks.")
	player.global_position = world.cell_center(Vector2i(_db0 + 2, _iw_gy - 3))
	player.velocity = Vector2.ZERO
	_iw_cam.reset_smoothing()
	await _shot("28_deep_block_build")

	# Tall doors: a DOOR_HEIGHT-tall doorway in a short wall, one leaf open and one
	# closed, with the player standing in an opening to show a character fits through.
	var _dr0: int = _iw_hall.x - 3
	for _dx in [-1, 3]:
		for _cy in range(_iw_gy - world.DOOR_HEIGHT - 1, _iw_gy):
			if world.block_at(Vector2i(_dr0 + _dx, _cy)) != "air":
				world.break_block(Vector2i(_dr0 + _dx, _cy))
		for _r in range(world.DOOR_HEIGHT + 1):
			world.place_block(Vector2i(_dr0 + _dx, _iw_gy - 1 - _r), "stone")
	for _dcol in [0, 2]:
		for _cy in range(_iw_gy - world.DOOR_HEIGHT, _iw_gy):
			if world.block_at(Vector2i(_dr0 + _dcol, _cy)) != "air":
				world.break_block(Vector2i(_dr0 + _dcol, _cy))
		world.place_door_stack(Vector2i(_dr0 + _dcol, _iw_gy - 1))
	world.toggle_door(Vector2i(_dr0, _iw_gy - 1))          # open the left door
	root.log_event("Doors are full-height now — settlers and the player walk through.")
	player.global_position = world.cell_center(Vector2i(_dr0, _iw_gy - 2))
	player.velocity = Vector2.ZERO
	_iw_cam.reset_smoothing()
	await _shot("34_tall_doors")

	# Block gravity: cut the standing tree (shot 27) mid-trunk — the severed top and
	# canopy lose their footing and fall as wood/leaf drops, while the base stays.
	world.break_block(Vector2i(_tw0, _tw_row - 3))
	root.log_event("Cut a trunk and everything above it falls — free-standing blocks obey gravity.")
	player.global_position = world.cell_center(Vector2i(_tw0 + 1, _tw_row - 1))
	player.velocity = Vector2.ZERO
	_iw_cam.reset_smoothing()
	await _shot("35_tree_gravity")


## Celestial shots: verify the enlarged sun/moon, radiated light, and the
## lit-crescent moon (dark side transparent → blends into the night sky).
func _shoot_celestial(root: Node2D, world: Node2D, player: CharacterBody2D, hud: CanvasLayer) -> void:
	world.setup(4242)
	root._position_actors()
	hud.visible = false            # clear the sky so the sun/moon read unobstructed
	var cam: Camera2D = player.get_node("Camera2D")
	cam.zoom = Vector2(1.0, 1.0)   # widen the frame so the sky arc is in view
	cam.reset_smoothing()
	var cel: Node2D = root._celestial
	cel.set_sky_baseline(root._sky_baseline_y())   # world regenerated → refresh the arc altitude
	cel.set_sky_visible(true)

	# Midday sun: high, radiating warm light + flares.
	root.time_of_day = 0.3
	root.is_night = false
	root.canvas_modulate.color = root.DAY_TINT
	cel.set_time(root.time_of_day)
	cel._redraw_sky()
	cam.reset_smoothing()
	await _shot("29_sun_radiant")

	# Mid-night moon at several phases so the crescent/gibbous/crater shapes read.
	root.time_of_day = 0.5 * (1.0 + cel.NIGHT_START)   # peak of the night arc
	root.is_night = true
	root.canvas_modulate.color = root.NIGHT_TINT
	cel.set_time(root.time_of_day)
	for _phase_shot in [[0.16, "30_moon_crescent"], [0.34, "31_moon_gibbous"], [0.5, "32_moon_full"]]:
		cel._phase_f = float(_phase_shot[0])
		cel._rebuild_moon_texture()
		cel._redraw_sky()
		await _shot(str(_phase_shot[1]))

	# Underground: the sky must NOT draw over rock (gate fed by the player's depth).
	root.time_of_day = 0.3
	root.is_night = false
	var _uc: Vector2i = world.hall_info["center_cell"]
	var _ugy: int = world.hall_info["ground_y"]
	player.global_position = world.cell_center(Vector2i(_uc.x, _ugy + 10))
	player.velocity = Vector2.ZERO
	cam.reset_smoothing()
	root.canvas_modulate.color = root.ambient_target_color()
	cel.set_time(root.time_of_day)
	cel.set_sky_visible(root._sky_visible_now())
	cel._redraw_sky()
	await _shot("33_underground_no_sky")


func _shot(shot_name: String) -> void:
	for i in range(20):
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % shot_name)
