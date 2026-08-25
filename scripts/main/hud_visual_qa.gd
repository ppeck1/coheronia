extends Node
## HUD-only visual QA capture. Runs when COHERONIA_HUD_QA=1, stages a
## deterministic normal gameplay scene, writes uncropped 1280x720 screenshots
## plus a small manifest to user://hud_qa, and quits. This is a visual review
## aid only; smoke remains the functional gate.

const QA_DIR := "user://hud_qa"
const DisplaySettings := preload("res://scripts/shell/display_settings.gd")
const ActionFxScript := preload("res://scripts/fx/action_fx.gd")

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

	# PR-06: the Character panel, rebuilt on runtime children. Equip some gear
	# first so the composed figure (shared render path) and the equipment slots
	# read from live state. Captured at two viewport sizes.
	_prepare_hud(root, hud, false, true)
	player.apply_equipment({"weapon": "sword_crude", "helmet": "helmet_crude",
		"torso": "torso_crude", "feet": "feet_crude"})
	_set_resources(player, hud, 0.7, 0.6)
	hud.toggle_character_panel()
	await _shot("08_character_panel",
		"Character panel: composed figure through the shared render path, live identity/status, and all 13 equipment slots from runtime state.", hud)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	for i in range(12):
		await get_tree().process_frame
	await _shot("09_character_panel_wide", "Character panel at a 1600x900 viewport.", hud)
	hud.toggle_character_panel()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in range(12):
		await get_tree().process_frame

	# PR-08: the Skill panel, now viewport-relative. Captured at 1280x720 and at
	# a 640x360 window (the same-aspect layout scaled down) to show it fits both.
	hud.toggle_skill_panel()
	await _shot("10_skill_panel", "Skill panel (viewport-relative) at a 1280x720 viewport.", hud)
	DisplayServer.window_set_size(Vector2i(640, 360))
	for i in range(12):
		await get_tree().process_frame
	await _shot("11_skill_panel_small", "Skill panel at a 640x360 window (same-aspect layout scaled to fit).", hud)
	hud.toggle_skill_panel()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in range(12):
		await get_tree().process_frame

	# S-07.1b: Town Hall panel (density pass) with a populated roster. Opening it
	# also shows the dim modal scrim behind the panel.
	hud.toggle_town_panel()
	await _shot("12_town_hall",
		"Town Hall (S-07.1b): trimmed stockpile instruction, reserved settler-roster space, dim modal scrim behind.", hud)
	DisplayServer.window_set_size(Vector2i(640, 360))
	for i in range(12):
		await get_tree().process_frame
	await _shot("13_town_hall_small", "Town Hall at 640x360 (legibility check).", hud)
	hud.toggle_town_panel()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in range(12):
		await get_tree().process_frame

	# S-07.1b (F6 taste): the modal dim-scrim strength knob — capture its min and
	# max behind an open modal so the operator can judge the range. Restore after.
	var _scrim_had: bool = GameState.profile.has("modal_scrim_strength")
	var _scrim_saved: float = DisplaySettings.scrim_strength(GameState.profile)
	hud.toggle_town_panel()
	DisplaySettings.set_scrim_strength(GameState.profile, DisplaySettings.MIN_SCRIM)
	hud._refresh_modal_presentation()
	await _shot("14_scrim_min", "Modal dim at MIN (%.2f) behind the Town Hall." % DisplaySettings.MIN_SCRIM, hud)
	DisplaySettings.set_scrim_strength(GameState.profile, DisplaySettings.MAX_SCRIM)
	hud._refresh_modal_presentation()
	await _shot("15_scrim_max", "Modal dim at MAX (%.2f) behind the Town Hall." % DisplaySettings.MAX_SCRIM, hud)
	hud.toggle_town_panel()
	if _scrim_had:
		DisplaySettings.set_scrim_strength(GameState.profile, _scrim_saved)
	else:
		GameState.profile.erase("modal_scrim_strength")

	# S-07.1b (F10): the directional swing-arc action FX, staged at the player and
	# captured on its first (widest) step before it self-frees.
	for i in range(8):
		await get_tree().process_frame
	ActionFxScript.spawn(world, "swing_arc",
		player.global_position + Vector2(11, -6), Color.TRANSPARENT, Vector2(1.0, -0.25))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/16_swing_arc.png" % QA_DIR)
	_records.append({"name": "16_swing_arc", "path": "%s/16_swing_arc.png" % QA_DIR,
		"note": "Directional swing-arc FX (F10) sweeping right at the player."})

	# Phase C visual slice: freeze the sim (so the live clock cannot overwrite the forced
	# readout), then drive the docked wings with deterministic worst-case data — 3-digit
	# gauge values, the widest 3-digit-day compact clock, and three long event lines that
	# each ellipsise independently.
	get_tree().paused = true
	# Mixed gauge values prove the bottom-to-top fill reaches distinct heights (the
	# all-100 containment case is covered by the automated smoke contract instead).
	hud.update_settlement(80.0, 13.0, 77.0, {}, [])
	hud.update_time(999, false, 5, 0.789)   # -> "Day 999, 2358" (widest 3-digit day)
	# Full messages persist for the popup/tooltip; the wing shows the authored summaries.
	hud.log_event("A caravan of weary traders reaches the north gate seeking shelter",
		"Caravan at north gate")
	hud.log_event("Storm clouds gather over the eastern ridge — secure every roof now",
		"Storm approaching")
	hud.log_event("Raiders are massing at the far eastern gate — brace every wall now",
		"Raiders massing east")
	# (Exact target-example summaries above, to prove they fit without ellipsis.)

	# Crop each wooden wing (+ its neighbouring orb/button) at every target size so fit and
	# overlap can be judged at native pixels, and after a live resize.
	for _wsz in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1000), Vector2i(640, 360)]:
		DisplayServer.window_set_size(_wsz)
		for _wi in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var _img := get_viewport().get_texture().get_image()
		# The captured texture is at the PHYSICAL window resolution while control global
		# rects are in LOGICAL (stretch) space, so map by the physical/logical ratio.
		var _logical: Vector2 = get_viewport().get_visible_rect().size
		var _sc := Vector2(float(_img.get_width()), float(_img.get_height())) \
			/ Vector2(maxf(1.0, _logical.x), maxf(1.0, _logical.y))
		for _pair in [["left", hud.find_child("LeftWing", true, false)],
				["right", hud.find_child("RightWing", true, false)]]:
			var _n = _pair[1]
			if _n == null:
				continue
			var _gr: Rect2 = (_n as Control).get_global_rect()
			var _px: Vector2 = _gr.position * _sc
			var _pz: Vector2 = _gr.size * _sc
			var _crop := Rect2i(int(_px.x) - 64, int(_px.y) - 24, int(_pz.x) + 128, int(_pz.y) + 48)
			_crop = _crop.intersection(Rect2i(Vector2i.ZERO, _img.get_size()))
			if _crop.size.x <= 0 or _crop.size.y <= 0:
				continue
			_img.get_region(_crop).save_png("%s/wing_%s_%dx%d.png" % [QA_DIR, _pair[0], _wsz.x, _wsz.y])
	DisplayServer.window_set_size(Vector2i(1280, 720))
	get_tree().paused = false

	_write_manifest(hud)
	print("HUD_QA complete -> %s" % QA_DIR)
	get_tree().quit(0)


func _stage_settlement(root: Node2D, world: Node2D, player: CharacterBody2D, hall: Node2D) -> void:
	player.tool_tier = 2
	player.axe_tier = 1
	player.attunement_regen_mult = 0.0
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
	# S-07.1b: populate the settler roster so the Town Hall density shot is real.
	if root.has_method("_spawn_starting_crew"):
		root._spawn_starting_crew()
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
	var _ev: Control = hud._events_module()
	if _ev != null and _ev.visible != events_open:
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
		"events_open": hud._events_module() != null and hud._events_module().visible,
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
