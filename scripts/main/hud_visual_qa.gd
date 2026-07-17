extends Node
## HUD-only visual QA capture. Runs when COHERONIA_HUD_QA=1, stages a
## deterministic normal gameplay scene, writes uncropped 1280x720 screenshots
## plus a small manifest to user://hud_qa, and quits. This is a visual review
## aid only; smoke remains the functional gate.

const QA_DIR := "user://hud_qa"

var _records: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var root: Node2D = get_parent()
	var world: Node2D = root.world
	var player: CharacterBody2D = root.player
	var hall: Node2D = root.town_hall
	var hud: CanvasLayer = root.hud

	DirAccess.make_dir_recursive_absolute(QA_DIR)
	DisplayServer.window_set_size(Vector2i(1280, 720))

	world.setup(4242)
	root._position_actors()
	player.get_node("Camera2D").reset_smoothing()
	_stage_settlement(root, world, player, hall)
	for i in range(40):
		await get_tree().physics_frame

	_prepare_hud(root, hud, false, true)
	_set_resources(player, hud, 1.0, 1.0)
	await _shot("01_resources_100", "HUD reset, edit off, crest/goal/events visible, health and attunement full.", hud)

	_prepare_hud(root, hud, false, true)
	_set_resources(player, hud, 0.5, 0.5)
	await _shot("02_resources_50", "HUD reset, health and attunement at 50 percent.", hud)

	_prepare_hud(root, hud, false, true)
	_set_resources(player, hud, 0.15, 0.15)
	await _shot("03_resources_low", "HUD reset, low health and low attunement state.", hud)

	_prepare_hud(root, hud, false, true)
	_set_resources(player, hud, 0.0, 0.0)
	await _shot("04_resources_0", "HUD reset, empty health and empty attunement masks.", hud)

	_prepare_hud(root, hud, true, false)
	_set_resources(player, hud, 0.5, 0.5)
	await _shot("05_map_open", "Map open, events closed, resources at 50 percent.", hud)

	_prepare_hud(root, hud, false, true)
	_set_resources(player, hud, 0.5, 0.5)
	await _shot("06_events_open", "Events open, map closed, resources at 50 percent.", hud)

	_prepare_hud(root, hud, true, true)
	_set_resources(player, hud, 0.15, 0.15)
	await _shot("07_map_events_open", "Map and events open together with low resource state.", hud)

	_write_manifest(hud)
	print("HUD_QA complete -> %s" % QA_DIR)
	get_tree().quit(0)


func _stage_settlement(root: Node2D, world: Node2D, player: CharacterBody2D, hall: Node2D) -> void:
	player.tool_tier = 2
	player.axe_tier = 1
	player.equip_item("weapon", "sword_crude")
	player.equip_item("helmet", "helmet_crude")
	player.equip_item("torso", "torso_crude")
	player.equip_item("feet", "feet_crude")
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
	root.time_of_day = 0.3
	root.is_night = false
	root.canvas_modulate.color = root.DAY_TINT
	if root._map_state != null:
		root._map_state.reveal_around(world.cell_of(player.global_position), root._scout_reveal_radius())


func _prepare_hud(root: Node2D, hud: CanvasLayer, map_open: bool, events_open: bool) -> void:
	if hud.is_hud_edit_mode():
		hud.toggle_hud_edit_mode()
	hud.reset_hud_layout()
	if not hud._top_left_box.visible:
		hud._toggle_top_left_module()
	if not hud.goal_panel_visible():
		hud._toggle_goal_module()
	hud.set_map_open(map_open)
	if map_open:
		hud.update_map(root.map_snapshot())
	if hud._event_panel.visible != events_open:
		hud._toggle_event_module()
	hud.set_interaction_prompt("")
	hud._sync_command_center()


func _set_resources(player: CharacterBody2D, hud: CanvasLayer,
		health_ratio: float, attunement_ratio: float) -> void:
	player.health = player.max_health * clampf(health_ratio, 0.0, 1.0)
	player.attunement = player.max_attunement() * clampf(attunement_ratio, 0.0, 1.0)
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())


func _shot(shot_name: String, note: String, hud: CanvasLayer) -> void:
	for i in range(20):
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [QA_DIR, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	_records.append({
		"name": shot_name,
		"path": path,
		"note": note,
		"hud_edit": hud.is_hud_edit_mode(),
		"map_open": hud.map_open(),
		"events_open": hud._event_panel.visible,
		"crest_open": hud._top_left_box.visible,
		"goal_visible": hud.goal_panel_visible(),
		"dock_rect": _rect_to_array(hud._bottom_dock.get_global_rect()),
		"module_toolbar_rect": _rect_to_array(hud._command_center_panel.get_global_rect()),
	})


func _write_manifest(hud: CanvasLayer) -> void:
	var layout: Dictionary = hud._load_hud_kit_layout()
	var trim_enabled := true
	for raw_layer in layout.get("decorative_layers", []):
		if raw_layer is Dictionary and str((raw_layer as Dictionary).get("role", "")) == "foreground_trim":
			trim_enabled = bool((raw_layer as Dictionary).get("enabled", true))
			break
	var manifest := {
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"hud_layout_version": hud.HUD_LAYOUT_VERSION,
		"hud_kit_active": hud._hud_kit_active,
		"foreground_trim_enabled": trim_enabled,
		"foreground_trim_node_present": hud._bottom_dock.find_child("DockForegroundTrim", true, false) != null,
		"shots": _records,
	}
	var file := FileAccess.open("%s/manifest.json" % QA_DIR, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))


func _rect_to_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
