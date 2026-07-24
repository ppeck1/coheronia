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

	print("SHOTS complete -> user://shots")
	get_tree().quit(0)


func _shot(shot_name: String) -> void:
	for i in range(20):
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % shot_name)
