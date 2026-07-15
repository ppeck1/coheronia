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

	hud.refresh_town_panel()
	hud.toggle_town_panel()
	await _shot("04_town_hall")
	hud.toggle_town_panel()

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
