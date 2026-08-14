extends Node
## S-07.3 smoke domain module - map / scouting / navigation (FQ-15).
## Order-preserving extraction from smoke_test.gd _run(); the harness owns the
## ledger + helpers (_check/_check_res_fixture/_skip/_find_button_with_text via
## harness.*). HudChrome/HudEditGeometry are class-local preload consts in the
## harness (not globals), so they are re-preloaded here (§11.4a category 4).

const HudChrome := preload("res://scripts/ui/hud/hud_chrome.gd")
const HudEditGeometry := preload("res://scripts/ui/hud/hud_edit_geometry.gd")


func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this cluster uses.
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player
	var hall = ctx.hall
	var settlement = ctx.settlement
	var hud = ctx.hud
	# --- FQ-15: map / scouting / navigation ---
	# pure map_state: revealing a cell marks its 3x3 band, not the far world, and
	# the compact save form round-trips.
	var _m15_script = preload("res://scripts/world/map_state.gd")
	var _m15 = _m15_script.new()
	var _m15_newly: bool = _m15.reveal_around(Vector2i(50, 30), 1)
	var _m15_ser: Array = _m15.serialize()
	var _m15_round = _m15_script.parse(_m15_ser)
	harness._check("fq15_reveal_bands",
		_m15_newly and _m15.revealed_count() == 9
		and _m15.cell_revealed(Vector2i(50, 30))
		and not _m15.cell_revealed(Vector2i(200, 30))
		and _m15_round.size() == 9,
		"count=%d here=%s far=%s round=%d" % [_m15.revealed_count(),
			str(_m15.cell_revealed(Vector2i(50, 30))),
			str(_m15.cell_revealed(Vector2i(200, 30))), _m15_round.size()])

	# game_root snapshot: has all fields, and the hall/player markers are real
	# cells; revealing under the player exposes them on the map.
	root._map_state.reveal_around(world.cell_of(player.global_position), 1)
	var _m15_snap: Dictionary = root.map_snapshot()
	var _m15_hall: Vector2i = world.hall_info.get("center_cell", Vector2i(-1, -1))
	harness._check("fq15_map_snapshot_markers",
		_m15_snap.has("width") and _m15_snap.has("height") and _m15_snap.has("region")
		and _m15_snap.has("revealed") and _m15_snap.has("ore") and _m15_snap.has("threats")
		and _m15_snap.get("hall") == _m15_hall
		and int(_m15_snap.get("width", 0)) == world.width,
		"hall=%s width=%d revealed=%d" % [str(_m15_snap.get("hall")),
			int(_m15_snap.get("width", 0)), (_m15_snap.get("revealed") as Array).size()])

	# discovered bands persist: the compact list round-trips through game_root.
	root._map_state.clear()
	root._map_state.reveal_around(Vector2i(100, 20), 1)
	var _m15_g_ser: Array = root.map_revealed_serialized()
	root._map_state.clear()
	root.apply_map_revealed(_m15_g_ser)
	harness._check("fq15_map_persists",
		root._map_state.revealed_count() == 9
		and root._map_state.cell_revealed(Vector2i(100, 20)),
		"restored=%d has_cell=%s" % [root._map_state.revealed_count(),
			str(root._map_state.cell_revealed(Vector2i(100, 20)))])

	# the map panel opens/closes, and the biome_reveal perk widens the scouted
	# band (the scouting hook for exploration perks).
	var _m15_open0: bool = hud.map_open()
	var _m15_toggled: bool = hud.toggle_map()
	var _m15_open1: bool = hud.map_open()
	hud.toggle_map()
	# Broad Horizon is a SURFACE reveal skill, so place the player clearly above
	# the sky line for a deterministic check of the context-scoped hook.
	var _m15_sx: int = world.width / 2
	var _m15_prev_pos: Vector2 = player.global_position
	player.global_position = world.cell_center(Vector2i(_m15_sx, world.sky_line(_m15_sx) - 3))
	var _m15_had_perk: bool = "broad_horizon" in root.purchased_perks
	if _m15_had_perk:
		root.purchased_perks.erase("broad_horizon")
	var _m15_r0: int = root._scout_reveal_radius()
	root.purchased_perks.append("broad_horizon")
	var _m15_r1: int = root._scout_reveal_radius()
	if not _m15_had_perk:
		root.purchased_perks.erase("broad_horizon")
	player.global_position = _m15_prev_pos
	harness._check("fq15_map_toggle_and_scout_hook",
		not _m15_open0 and _m15_toggled and _m15_open1 and not hud.map_open()
		and _m15_r0 == 1 and _m15_r1 == 2,
		"toggle=%s->%s r0=%d r1=%d" % [str(_m15_open0), str(_m15_open1), _m15_r0, _m15_r1])

	hud.set_map_open(false)
	var _m15_key := InputEventKey.new()
	_m15_key.physical_keycode = KEY_M
	_m15_key.pressed = true
	var _m15_prev_edit_mode: bool = GameState.hud_edit_mode
	GameState.hud_edit_mode = false
	root._unhandled_input(_m15_key)
	var _m15_key_opens: bool = hud.map_open()
	root._unhandled_input(_m15_key)
	var _m15_key_closes: bool = not hud.map_open()
	var _m15_echo_key := InputEventKey.new()
	_m15_echo_key.physical_keycode = KEY_M
	_m15_echo_key.pressed = true
	_m15_echo_key.echo = true
	root._unhandled_input(_m15_echo_key)
	var _m15_echo_blocked: bool = not hud.map_open()
	GameState.hud_edit_mode = true
	root._unhandled_input(_m15_key)
	var _m15_key_blocked_in_edit: bool = not hud.map_open()
	GameState.hud_edit_mode = _m15_prev_edit_mode
	harness._check("fq15_map_key_respects_ui_boundary",
		_m15_key_opens and _m15_key_closes and _m15_echo_blocked
		and _m15_key_blocked_in_edit,
		"opens=%s closes=%s echo_blocked=%s edit_blocked=%s" % [
			str(_m15_key_opens), str(_m15_key_closes), str(_m15_echo_blocked),
			str(_m15_key_blocked_in_edit)])

	# Map and Events are independent adjacent modules; either can toggle while
	# the other remains open, and contextual chips sit below the taller one.
	# Start these geometry checks from the default layout so a HUD size/position
	# a prior run persisted into the shell profile cannot skew the panel rects
	# (fq19 event bounds, fq21 map masking); the widgets restore their own state.
	hud.reset_hud_layout()
	await get_tree().process_frame
	var _fq19_events_before: bool = hud._event_panel != null and hud._event_panel.visible
	if hud._event_panel != null:
		hud._event_panel.visible = true
		hud._save_hud_layout()
	var _fq19_map_open: bool = hud.toggle_map()
	var _fq19_together: bool = _fq19_map_open and hud._event_panel.visible
	hud._toggle_event_module()
	var _fq19_event_off_map_on: bool = not hud._event_panel.visible and hud.map_open()
	hud._toggle_event_module()
	var _fq19_event_on_map_on: bool = hud._event_panel.visible and hud.map_open()
	var _fq19_event_rect: Rect2 = hud._event_panel.get_global_rect() if hud._event_panel != null else Rect2()
	var _fq19_map_rect: Rect2 = hud._map_panel.get_global_rect() if hud._map_panel != null else Rect2()
	hud._position_context_stack()
	var _fq19_stack_clear: bool = hud._context_stack.offset_top >= \
		maxf(_fq19_event_rect.end.y, _fq19_map_rect.end.y) + 8.0
	hud.toggle_map()
	var _fq19_event_survives_close: bool = hud._event_panel.visible and not hud.map_open()
	var _fq19_viewport: Vector2 = get_viewport().get_visible_rect().size
	if hud._event_panel != null:
		hud._event_panel.visible = _fq19_events_before
		hud._save_hud_layout()
	harness._check("fq19_map_events_coexist",
		_fq19_together and _fq19_event_off_map_on and _fq19_event_on_map_on
		and _fq19_event_survives_close and not _fq19_event_rect.intersects(_fq19_map_rect)
		and _fq19_stack_clear
		and hud._event_panel.custom_minimum_size.x >= 320.0
		and hud._event_panel.custom_minimum_size.y >= 120.0
		and _fq19_event_rect.position.x >= 8.0
		and _fq19_event_rect.end.x <= _fq19_viewport.x - 8.0
		and _fq19_event_rect.position.y >= 8.0
		and _fq19_event_rect.end.y <= _fq19_viewport.y - 8.0,
		"together=%s event_off=%s event_on=%s survives=%s event=%s map=%s stack=%.1f viewport=%s" % [
			str(_fq19_together), str(_fq19_event_off_map_on), str(_fq19_event_on_map_on),
			str(_fq19_event_survives_close),
			str(hud._event_panel.custom_minimum_size if hud._event_panel != null else Vector2.ZERO),
			str(_fq19_map_rect), hud._context_stack.offset_top, str(_fq19_viewport)])
	hud.update_time(5, true, 2)
	var _fq19_time_ok: bool = hud._time_label == null and hud._event_time_label != null \
		and hud._event_time_label.text.contains("Day 5") \
		and hud._event_time_label.text.contains("Night")
	harness._check("fq19_events_time_header_live", _fq19_time_ok,
		"crest_time=%s header=%s" % [str(hud._time_label != null),
			str(hud._event_time_label.text if hud._event_time_label != null else "missing")])

	# FQ-19: exact clock — the fraction maps onto the settlement clock
	# (day 06:00-20:00, night wraps 20:00-06:00) with dawn/day/dusk/night
	# phase words in the events header.
	hud.update_time(5, true, 0, 0.7)
	var _fq19c_night: String = hud._event_time_label.text
	hud.update_time(5, false, 0, 0.05)
	var _fq19c_dawn: String = hud._event_time_label.text
	hud.update_time(5, false, 0, 0.3)
	var _fq19c_day: String = hud._event_time_label.text
	hud.update_time(5, false, 0, 0.6)
	var _fq19c_dusk: String = hud._event_time_label.text
	hud.update_time(root.day_count, root.is_night, 0, root.time_of_day)
	harness._check("fq19_events_exact_clock",
		_fq19c_night.contains("• Night 21:2")
		and _fq19c_dawn.contains("• Dawn 07:0")
		and _fq19c_day.contains("• Day 12:2")
		and _fq19c_dusk.contains("• Dusk 18:5"),
		"night=%s dawn=%s day=%s dusk=%s" % [_fq19c_night, _fq19c_dawn,
			_fq19c_day, _fq19c_dusk])

	# FQ-19: framed crest and goal treatment — the crest is a framed panel
	# whose C/L/R rows carry numeric values, and the goal panel exposes the
	# milestone progress strip mirroring index/total.
	hud.update_settlement(72.4, 41.0, 58.0, {}, [])
	hud.update_progression(2, 10, 100, "Hamlet")
	var _fq19_crest_ok: bool = hud._top_left_box is PanelContainer \
		and hud._crest_title != null and hud._crest_title.text.contains("Hamlet") \
		and hud._crest_title.text.contains("Lv.2") \
		and hud._bar_values.size() == 3 \
		and (hud._bar_values["coherence"] as Label).text == "72"
	# Progress strip mirrors index/total from the live goal model (7 goals now),
	# not a hardcoded 5 — derive the total so the check tracks the real count.
	var _fq19_goal_total: int = int(root._goal_tracker.current().get("total", 0))
	hud.update_goal({"id": "light", "text": "Light the Town Hall",
		"hint": "Craft a torch.", "index": 1, "total": _fq19_goal_total, "all_done": false})
	var _fq19_goal_ok: bool = hud._goal_progress != null \
		and is_equal_approx(hud._goal_progress.value, 1.0) \
		and is_equal_approx(hud._goal_progress.max_value, float(_fq19_goal_total)) \
		and _fq19_goal_total == 7 \
		and hud._goal_label.text.contains("Light the Town Hall")
	hud.update_goal(root._goal_tracker.current())
	root._refresh_hud_progression()
	harness._check("fq19_crest_goal_blueprint",
		_fq19_crest_ok and _fq19_goal_ok,
		"crest=%s title=%s c_val=%s goal=%s" % [str(_fq19_crest_ok),
			str(hud._crest_title.text if hud._crest_title != null else "missing"),
			str((hud._bar_values["coherence"] as Label).text if hud._bar_values.has("coherence") else "missing"),
			str(_fq19_goal_ok)])

	# (The contextual-stack check lives at the end of the suite: its real-time
	# auto-hide waits must not shift the live music clip-switch timing.)

	# FQ-21 contract v2: the native layered kit spans the viewport, loads its
	# decorative layers from the manifest, and retains five runtime slots plus
	# four registered action controls.
	var _fq21_geometry: Dictionary = hud._load_hud_kit_layout()
	var _fq21_block: TextureRect = hud._bottom_dock.find_child("DockBackplate", true, false)
	var _fq21_trim_enabled := true
	for _fq21_layer_raw in _fq21_geometry.get("decorative_layers", []):
		if _fq21_layer_raw is Dictionary \
				and str((_fq21_layer_raw as Dictionary).get("role", "")) == "foreground_trim":
			_fq21_trim_enabled = bool((_fq21_layer_raw as Dictionary).get("enabled", true))
			break
	var _fq21_trim_node: Node = hud._bottom_dock.find_child(
		"DockForegroundTrim", true, false)
	var _fq21_trim_toggle_ok: bool = (_fq21_trim_enabled and _fq21_trim_node != null) \
		or (not _fq21_trim_enabled and _fq21_trim_node == null)
	var _fq21_pieces_ok: bool = hud._hud_kit_active and hud._dock_band_active \
		and _fq21_block != null and _fq21_block.texture != null \
		and _fq21_trim_toggle_ok \
		and hud._bottom_dock.find_child("HealthFrame", true, false) != null \
		and hud._bottom_dock.find_child("AttunementFrame", true, false) != null \
		and _fq21_block.texture.get_size().is_equal_approx(
			Vector2(float(_fq21_geometry.native_size[0]),
				float(_fq21_geometry.native_size[1])))
	var _fq21_full_width: bool = hud._bottom_dock.size.x >= \
		get_viewport().get_visible_rect().size.x - 1.0
	var _fq21_nav_found := 0
	var _fq21_child_names: Array[String] = []
	for _fq21_child in hud._bottom_dock.get_children():
		_fq21_child_names.append(str(_fq21_child.name))
	for _fq21_name in ["DockActionInventory", "DockActionCharacter",
			"DockActionSkills", "DockActionTownHall"]:
		var _fq21_btn: Node = hud._bottom_dock.find_child(_fq21_name, true, false)
		if _fq21_btn is Button and (_fq21_btn as Button).tooltip_text != "":
			_fq21_nav_found += 1
	harness._check("fq21_hud_kit_primary",
		_fq21_pieces_ok and _fq21_full_width and _fq21_nav_found == 4
		and hud._hotbar_slots.size() == 5,
		"pieces=%s trim_enabled=%s trim_toggle=%s full_width=%s nav=%d slots=%d children=%s" % [
			str(_fq21_pieces_ok), str(_fq21_trim_enabled), str(_fq21_trim_toggle_ok),
			str(_fq21_full_width), _fq21_nav_found, hud._hotbar_slots.size(),
			str(_fq21_child_names)])

	# Slice 4: the cursor can pick a dock slot — cells claim their clicks (STOP)
	# and are wired to the selection path (was number-keys only).
	var _dc_prev: int = player.selected_slot
	var _dc_target: int = 0 if player.selected_slot != 0 else 1
	var _dc_cells_ok: bool = hud._hotbar_cells.size() >= 5
	var _dc_stop_ok: bool = _dc_cells_ok \
		and (hud._hotbar_cells[0] as Control).mouse_filter == Control.MOUSE_FILTER_STOP
	var _dc_wired_ok: bool = _dc_cells_ok \
		and (hud._hotbar_cells[0] as Control).gui_input.get_connections().size() >= 1
	hud._select_dock_slot(_dc_target)   # the exact path a cell click invokes
	var _dc_selected_ok: bool = player.selected_slot == _dc_target \
		and hud.hotbar_selected_index() == _dc_target
	player.selected_slot = _dc_prev
	hud._refresh_dock_selection_styles()
	harness._check("hud_dock_click_selects",
		_dc_stop_ok and _dc_wired_ok and _dc_selected_ok,
		"stop=%s wired=%s selected=%s cells=%d" % [str(_dc_stop_ok), str(_dc_wired_ok),
			str(_dc_selected_ok), hud._hotbar_cells.size()])

	# Optional HUD themes resolve per static asset. Missing, unsafe-id, and
	# wrong-size candidates must all fall back to the required base PNG, while
	# a valid same-contract sibling is selected without changing gameplay data.
	var _fq21_theme_valid_path := \
		"res://art/generated/ui_painted/slot_normal__smoke_valid.png"
	var _fq21_theme_invalid_path := \
		"res://art/generated/ui_painted/slot_normal__smoke_invalid.png"
	for _fq21_theme_tmp in [_fq21_theme_valid_path, _fq21_theme_invalid_path]:
		if FileAccess.file_exists(_fq21_theme_tmp):
			DirAccess.remove_absolute(_fq21_theme_tmp)
	var _fq21_theme_base_before: Texture2D = BlockRegistry.visual_texture(
		"ui_painted", "slot_normal")
	var _fq21_theme_source: Image = _fq21_theme_base_before.get_image()
	_fq21_theme_source.save_png(_fq21_theme_valid_path)
	var _fq21_theme_bad := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_fq21_theme_bad.fill(Color.WHITE)
	_fq21_theme_bad.save_png(_fq21_theme_invalid_path)
	var _fq21_theme_base: Texture2D = BlockRegistry.visual_texture(
		"ui_painted", "slot_normal")
	var _fq21_theme_valid: Texture2D = hud._painted_texture_for_theme(
		"slot_normal", "smoke_valid")
	var _fq21_theme_missing: Texture2D = hud._painted_texture_for_theme(
		"slot_normal", "smoke_missing")
	var _fq21_theme_invalid: Texture2D = hud._painted_texture_for_theme(
		"slot_normal", "smoke_invalid")
	var _fq21_theme_unsafe: Texture2D = hud._painted_texture_for_theme(
		"slot_normal", "../outside")
	var _fq21_theme_contract_ok: bool = _fq21_theme_valid != _fq21_theme_base \
		and _fq21_theme_valid.get_size() == _fq21_theme_base.get_size() \
		and _fq21_theme_missing == _fq21_theme_base \
		and _fq21_theme_invalid == _fq21_theme_base \
		and _fq21_theme_unsafe == _fq21_theme_base \
		and not hud.hud_visual_theme_id().is_empty() \
		and hud.hud_visual_theme_id() == hud._normalize_hud_visual_theme(
			hud.hud_visual_theme_id())
	DirAccess.remove_absolute(_fq21_theme_valid_path)
	DirAccess.remove_absolute(_fq21_theme_invalid_path)
	harness._check_res_fixture("fq21_hud_theme_asset_fallback", _fq21_theme_contract_ok,
		"theme=%s valid=%s missing=%s invalid=%s unsafe=%s" % [
			hud.hud_visual_theme_id(), str(_fq21_theme_valid != _fq21_theme_base),
			str(_fq21_theme_missing == _fq21_theme_base),
			str(_fq21_theme_invalid == _fq21_theme_base),
			str(_fq21_theme_unsafe == _fq21_theme_base)])

	# R-06.1 seam: the chrome/theme resolver + slicer-geometry parsers now live
	# in HudChrome; hud.gd's facade must delegate identically (same result the
	# fq21 checks above already depend on, now sourced from the collaborator).
	var _r06_norm_ok: bool = HudChrome.normalize_hud_visual_theme("Ember Light") == "ember_light" \
		and hud._normalize_hud_visual_theme("Ember Light") == HudChrome.normalize_hud_visual_theme("Ember Light") \
		and HudChrome.normalize_hud_visual_theme("../bad") == "" \
		and hud._normalize_hud_visual_theme("../bad") == ""
	var _r06_rect_ok: bool = HudChrome.json_rect([3, 4, 5, 6]) == Rect2(3, 4, 5, 6) \
		and hud._json_rect([3, 4, 5, 6]) == HudChrome.json_rect([3, 4, 5, 6]) \
		and HudChrome.json_rect("nope") == Rect2()
	var _r06_vec_ok: bool = HudChrome.json_vec([7, 8]) == Vector2(7, 8) \
		and hud._json_vec([7, 8]) == HudChrome.json_vec([7, 8])
	var _r06_layout_ok: bool = hud._load_hud_kit_layout() == HudChrome.load_hud_kit_layout() \
		and hud._load_band_geometry() == HudChrome.load_band_geometry() \
		and not HudChrome.load_hud_kit_layout().is_empty()
	var _r06_theme_ok: bool = hud._painted_texture_for_theme("slot_normal", "") \
		== HudChrome.painted_texture_for_theme("slot_normal", "")
	harness._check("r06_chrome_resolver_delegates",
		_r06_norm_ok and _r06_rect_ok and _r06_vec_ok and _r06_layout_ok and _r06_theme_ok,
		"norm=%s rect=%s vec=%s layout=%s theme=%s" % [
			str(_r06_norm_ok), str(_r06_rect_ok), str(_r06_vec_ok),
			str(_r06_layout_ok), str(_r06_theme_ok)])

	# R-06.2 seam: the edit-mode geometry math now lives in HudEditGeometry;
	# hud.gd's facade (_hud_widget_size / _hud_grip_rect, driven by fq17/fq21)
	# must delegate identically, and the pure math holds on fixed inputs.
	var _r06g_widget: Control = hud._hud_widgets.get("crest")
	var _r06g_size_ok: bool = _r06g_widget != null \
		and hud._hud_widget_size(_r06g_widget) == HudEditGeometry.widget_size(_r06g_widget)
	# The wrapper returns Rect2() for a hidden widget, else the geometry rect --
	# assert delegation for whichever state the crest is in.
	var _r06g_grip_expected: Rect2 = HudEditGeometry.grip_rect(_r06g_widget.get_global_rect()) \
		if (_r06g_widget != null and _r06g_widget.visible) else Rect2()
	var _r06g_grip_ok: bool = _r06g_widget != null \
		and hud._hud_grip_rect("crest") == _r06g_grip_expected
	var _r06g_min_ok: bool = HudEditGeometry.min_size(Vector2(400.0, 200.0)) == Vector2(200.0, 100.0) \
		and HudEditGeometry.min_size(Vector2(10.0, 10.0)) == Vector2(120.0, 56.0)
	var _r06g_max_ok: bool = HudEditGeometry.max_size(Vector2(100.0, 100.0), Vector2(1280.0, 720.0)) \
		== Vector2(200.0, 200.0)
	var _r06g_clamp_slack_ok: bool = HudEditGeometry.clamp_position(
		Vector2(-50.0, -50.0), Vector2(100.0, 100.0), Vector2(1280.0, 720.0)) == Vector2(12.0, 12.0)
	# A full-width extent has no horizontal slack, so x is left untouched.
	var _r06g_clamp_noslack_ok: bool = HudEditGeometry.clamp_position(
		Vector2(0.0, 5.0), Vector2(1280.0, 40.0), Vector2(1280.0, 720.0)).x == 0.0
	harness._check("r06_edit_geometry_delegates",
		_r06g_size_ok and _r06g_grip_ok and _r06g_min_ok and _r06g_max_ok \
			and _r06g_clamp_slack_ok and _r06g_clamp_noslack_ok,
		"size=%s grip=%s min=%s max=%s clamp=%s noslack=%s" % [
			str(_r06g_size_ok), str(_r06g_grip_ok), str(_r06g_min_ok),
			str(_r06g_max_ok), str(_r06g_clamp_slack_ok), str(_r06g_clamp_noslack_ok)])

	# Slice 3: the settler info panel is a first-class editable HUD widget — it can
	# be moved and resized through the same edit path as the crest/goal/events.
	var _npce_registered: bool = hud._hud_widgets.get("npc") == hud._npc_panel \
		and hud._editable_hud_widget_ids().has("npc")
	# Populate the panel with a real settler so it has actual content (and thus a
	# non-zero laid-out size) — an empty panel could read a zero rect. Then reset
	# to default geometry so a persisted layout can't leave it off-screen/unsized.
	var _npce_subj = null
	for _npce_s in get_tree().get_nodes_in_group("subjects"):
		if is_instance_valid(_npce_s):
			_npce_subj = _npce_s
			break
	if _npce_subj != null:
		hud.open_npc_panel(_npce_subj)   # sets subject + refresh → real content/size
	else:
		hud._npc_panel.visible = true
	hud._npc_panel.position = hud._hud_default_positions.get("npc", hud._npc_panel.position)
	hud._npc_panel.reset_size()          # force the container to its content size now
	for _npce_f in range(3):
		await get_tree().process_frame       # let the container compute its size
	var _npce_grip: Rect2 = hud._hud_grip_rect("npc")   # non-empty only when visible
	var _npce_pos0: Vector2 = hud._npc_panel.position
	hud._hud_edit_selected = "npc"
	hud._nudge_hud_widget(Vector2(24, 12))
	var _npce_moved: bool = hud._npc_panel.position != _npce_pos0
	var _npce_size0: Vector2 = hud._hud_widget_size(hud._npc_panel)
	hud._resize_hud_widget_to_size("npc", _npce_size0 + Vector2(20, 20))
	var _npce_resized: bool = hud._hud_widget_size(hud._npc_panel) != _npce_size0
	hud.reset_hud_layout()
	hud._npc_panel.visible = false
	harness._check("hud_npc_panel_editable",
		_npce_registered and _npce_grip.size.x > 0.0 and _npce_moved and _npce_resized,
		"reg=%s grip=%s moved=%s resized=%s" % [str(_npce_registered),
			str(_npce_grip.size), str(_npce_moved), str(_npce_resized)])

	# Work-zone button: pressing "Set work zone" must actually BEGIN work-zone mode
	# for the clicked settler and close the panel. Regression: the handler called
	# close_npc_panel() (which nulls _npc_subject) BEFORE reading the id, so the
	# emit hit Nil, the signal never fired, and the panel closed with the action
	# dead. Presses the real in-panel button so the actual handler is exercised.
	if _npce_subj != null and not GameState.workzone_mode:
		hud.open_npc_panel(_npce_subj)
		var _wz_btn: Button = harness._find_button_with_text(hud._npc_panel, "Set work zone")
		if _wz_btn != null:
			_wz_btn.pressed.emit()
		var _wz_mode: bool = GameState.workzone_mode
		var _wz_target_ok: bool = str(root._workzone_target) == str(_npce_subj.subject_id)
		var _wz_panel_closed: bool = not hud.npc_panel_open()
		root._end_work_zone()   # cleanup so later sections aren't left in work-zone mode
		hud._npc_panel.visible = false
		harness._check("hud_workzone_button_begins_assignment",
			_wz_btn != null and _wz_mode and _wz_target_ok and _wz_panel_closed,
			"btn=%s mode=%s target_ok=%s panel_closed=%s" % [str(_wz_btn != null),
				str(_wz_mode), str(_wz_target_ok), str(_wz_panel_closed)])
	else:
		harness._check("hud_workzone_button_begins_assignment", false,
			"no settler available to exercise the work-zone button")

	# R-06.3 seam: vessel/chrome texture prep now builds in HudChrome; hud.gd
	# keeps the caches + source lookup. Textures are freshly built (not
	# identity-equal), so assert resulting dimensions + null-safety.
	var _r06t_mask_src: Texture2D = BlockRegistry.visual_texture("ui", "orb_fill_mask")
	var _r06t_mask: Texture2D = HudChrome.glass_mask_from(_r06t_mask_src, 40)
	var _r06t_mask_ok: bool = _r06t_mask != null and _r06t_mask.get_size() == Vector2(40, 40) \
		and hud._glass_mask_texture(40) != null \
		and hud._glass_mask_texture(40).get_size() == Vector2(40, 40) \
		and HudChrome.glass_mask_from(null, 40) == null
	var _r06t_scaled_src: Texture2D = hud._painted_texture("slot_normal")
	var _r06t_scaled: Texture2D = HudChrome.scaled_texture_from(_r06t_scaled_src, 0.5)
	var _r06t_scaled_ok: bool = _r06t_scaled_src != null and _r06t_scaled != null \
		and _r06t_scaled.get_size() == (_r06t_scaled_src.get_size() * 0.5).round() \
		and hud._scaled_texture("slot_normal", 0.5) != null \
		and hud._scaled_texture("slot_normal", 0.5).get_size() == _r06t_scaled.get_size() \
		and HudChrome.scaled_texture_from(null, 0.5) == null
	# S-07.0 (D1): this seam asserts pixel-exact scaled-texture dimensions, which
	# the headless dummy display server rounds differently than a real surface —
	# a renderer-dependent detail, not a regression. Windowed is the canonical run;
	# under --headless we record it as skipped (never a pass/fail)
	# rather than report a non-regression as a hard failure.
	# Authority: docs/WORK_ORDER_S07_STABILIZE_POLISH_DECOMPOSE.md §3 D1.
	if DisplayServer.get_name() == "headless":
		harness._skip("r06_texture_prep_delegates",
			"renderer-dependent texture scaling under the headless dummy display server; windowed is canonical (see WORK_ORDER_S07 D1)")
	else:
		harness._check("r06_texture_prep_delegates",
			_r06t_mask_ok and _r06t_scaled_ok,
			"mask=%s scaled=%s" % [str(_r06t_mask_ok), str(_r06t_scaled_ok)])

	# HUD v4: a legacy dock transform can never move/scale the anchored band.
	var _fq21_layout_before: Variant = GameState.profile.get("hud_layout", {}).duplicate(true)
	hud._bottom_dock.position += Vector2(60.0, 0.0)
	hud._bottom_dock.scale = Vector2.ONE * 1.4
	GameState.profile["hud_layout"] = {
		"version": 3,
		"dock": {"delta": [60.0, 0.0], "scale": 1.4, "visible": true},
	}
	hud._load_hud_layout()
	var _fq21_dock_rect := Rect2(hud._bottom_dock.global_position,
		hud._bottom_dock.size * hud._bottom_dock.scale)
	var _fq21_dock_invariant: bool = hud._bottom_dock.scale.is_equal_approx(Vector2.ONE) \
		and is_equal_approx(_fq21_dock_rect.position.x, 0.0) \
		and is_equal_approx(_fq21_dock_rect.end.x, get_viewport().get_visible_rect().size.x)
	GameState.profile["hud_layout"] = _fq21_layout_before
	harness._check("fq21_dock_layout_v5_invariant", _fq21_dock_invariant,
		"rect=%s scale=%s viewport=%s" % [_fq21_dock_rect, hud._bottom_dock.scale,
			get_viewport().get_visible_rect().size])

	# Frame-only chrome, padded map, and explicit uniform slot geometry guard
	# the masking/cushion regressions from the operator capture.
	var _fq21_plain_tex: Texture2D = hud._painted_texture("health_frame")
	var _fq21_plain_img: Image = _fq21_plain_tex.get_image() if _fq21_plain_tex != null else null
	var _fq21_frame_clear: bool = _fq21_plain_img != null and \
		_fq21_plain_img.get_pixel(int(_fq21_plain_img.get_width() / 2),
			int(_fq21_plain_img.get_height() / 2)).a <= 0.01
	var _fq21_slots: Array = _fq21_geometry.get("slots", [])
	var _fq21_slot_gap := 0.0
	if _fq21_slots.size() >= 2:
		_fq21_slot_gap = float(_fq21_slots[1][0]) - float(_fq21_slots[0][0]) \
			- float(_fq21_slots[0][2])
	var _fq21_slot_normal: Texture2D = hud._painted_texture("slot_normal")
	var _fq21_slot_selected: Texture2D = hud._painted_texture("slot_selected")
	var _fq21_slots_uniform: bool = _fq21_slot_normal != null and _fq21_slot_selected != null \
		and _fq21_slot_normal.get_size() == _fq21_slot_selected.get_size() \
		and _fq21_slot_gap >= 6.0
	var _fq21_map_padded: bool = hud._map_panel.custom_minimum_size.x >= 320.0 \
		and hud._map_panel.custom_minimum_size.y >= 168.0
	var _fq21_town_hit: Button = hud._bottom_dock.find_child(
		"DockActionTownHall", true, false) as Button
	var _fq21_full_nav_cell: bool = _fq21_town_hit != null \
		and _fq21_town_hit.size.y >= 80.0
	var _fq21_town_label: Label = _fq21_town_hit.find_child(
		"DockActionTownHallLabel", true, false) as Label if _fq21_town_hit != null else null
	var _fq21_visible_nav_label: bool = _fq21_town_label != null \
		and _fq21_town_label.text == "Town Hall"
	var _fq21_slot0: Control = hud._bottom_dock.find_child(
		"HotbarCell1", true, false) as Control
	var _fq21_slot_icon: TextureRect = _fq21_slot0.find_child(
		"RuntimeIcon", true, false) as TextureRect if _fq21_slot0 != null else null
	var _fq21_icon_rect: Rect2 = hud._json_rect(_fq21_geometry.slot_content.icon_rect)
	var _fq21_json_content: bool = int(_fq21_geometry.get("version", 0)) == 2 \
		and _fq21_slot_icon != null \
		and _fq21_slot_icon.position == _fq21_icon_rect.position \
		and _fq21_slot_icon.size == _fq21_icon_rect.size
	var _fq21_control_rail_y := float(_fq21_geometry.get("control_rail_y", -1))
	var _fq21_rail_aligned := _fq21_control_rail_y >= 0.0
	for _fq21_control_name in ["HotbarCell1", "HotbarCell2", "HotbarCell3",
			"HotbarCell4", "HotbarCell5", "DockActionInventory",
			"DockActionCharacter", "DockActionSkills", "DockActionTownHall"]:
		var _fq21_control: Control = hud._bottom_dock.find_child(
			_fq21_control_name, true, false) as Control
		if _fq21_control == null or not is_equal_approx(
				_fq21_control.position.y, _fq21_control_rail_y):
			_fq21_rail_aligned = false
			break
	var _fq21_trim_tex: Texture2D = hud._painted_texture("dock_foreground_trim")
	var _fq21_trim_img: Image = _fq21_trim_tex.get_image() if _fq21_trim_tex != null else null
	var _fq21_alpha_rules: Dictionary = _fq21_geometry.get("alpha_rules", {})
	var _fq21_trim_rule: Dictionary = _fq21_alpha_rules.get("dock_foreground_trim.png", {})
	var _fq21_trim_baseline_y := int(_fq21_trim_rule.get("alpha_baseline_y", -1))
	var _fq21_trim_used: Rect2i = _fq21_trim_img.get_used_rect() \
		if _fq21_trim_img != null else Rect2i()
	var _fq21_trim_on_upper_rail: bool = _fq21_trim_baseline_y >= 0 \
		and _fq21_trim_used.end.y == _fq21_trim_baseline_y
	var _fq21_trim_keepouts := _fq21_trim_img != null
	if _fq21_trim_img != null:
		for _fq21_vessel_name in ["health", "attunement"]:
			var _fq21_keepout: Rect2 = hud._json_rect(
				(_fq21_geometry[_fq21_vessel_name] as Dictionary).frame_rect)
			for _fq21_y in range(int(_fq21_keepout.position.y), int(_fq21_keepout.end.y)):
				for _fq21_x in range(int(_fq21_keepout.position.x), int(_fq21_keepout.end.x)):
					if _fq21_trim_img.get_pixel(_fq21_x, _fq21_y).a > 0.01:
						_fq21_trim_keepouts = false
						break
				if not _fq21_trim_keepouts:
					break
			if not _fq21_trim_keepouts:
				break
	var _fq21_native_integer: bool = _fq21_block != null \
		and _fq21_block.size == _fq21_block.texture.get_size() \
		and hud._bottom_dock.scale == Vector2.ONE
	harness._check("fq21_hud_masking_and_cushion_geometry",
		_fq21_frame_clear and _fq21_slots_uniform and _fq21_map_padded \
		and _fq21_full_nav_cell and _fq21_visible_nav_label \
		and _fq21_json_content and _fq21_rail_aligned \
		and _fq21_trim_on_upper_rail and _fq21_trim_keepouts \
		and _fq21_native_integer,
		"frame_clear=%s slot_size=%s selected=%s gap=%.1f map=%s nav_h=%.1f label=%s content=%s rail_y=%.1f aligned=%s trim_baseline=%d trim_end=%d trim=%s integer=%s" % [
			str(_fq21_frame_clear),
			_fq21_slot_normal.get_size() if _fq21_slot_normal != null else Vector2.ZERO,
			_fq21_slot_selected.get_size() if _fq21_slot_selected != null else Vector2.ZERO,
			_fq21_slot_gap, hud._map_panel.custom_minimum_size,
			_fq21_town_hit.size.y if _fq21_town_hit != null else 0.0,
			str(_fq21_visible_nav_label), str(_fq21_json_content),
			_fq21_control_rail_y, str(_fq21_rail_aligned),
			_fq21_trim_baseline_y, _fq21_trim_used.end.y,
			str(_fq21_trim_keepouts),
			str(_fq21_native_integer)])

	# FQ-21: vessel sockets — the future liquid mechanic's plug-in point.
	# Both sockets expose glass geometry + a Range fill, and a replacement
	# Range keeps receiving update_health values.
	var _fq21_health_socket: Dictionary = hud.vessel_socket("health")
	var _fq21_attune_socket: Dictionary = hud.vessel_socket("attunement")
	var _fq21_sockets_ok: bool = _fq21_health_socket.get("fill") is Range \
		and int(_fq21_health_socket.get("glass_diameter", 0)) > 0 \
		and _fq21_attune_socket.get("fill") is Range
	var _fq21_live_health := _fq21_health_socket.get("fill") as TextureProgressBar
	var _fq21_live_attune := _fq21_attune_socket.get("fill") as TextureProgressBar
	var _fq21_layered_vessels: bool = _fq21_live_health != null \
		and _fq21_live_health.texture_progress == hud._painted_texture("health_fill_mask") \
		and hud._bottom_dock.find_child("HealthGlass", true, false) != null \
		and _fq21_live_attune != null \
		and _fq21_live_attune.texture_under == hud._painted_texture("attunement_fill_mask") \
		and _fq21_live_attune.texture_progress == hud._painted_texture("attunement_fill_mask")
	var _fq21_stub := ProgressBar.new()
	_fq21_stub.show_percentage = false
	var _fq21_swap_ok: bool = hud.replace_vessel_fill("health", _fq21_stub)
	hud.update_health(41.0, 100.0)
	var _fq21_drive_ok: bool = is_equal_approx(_fq21_stub.value, 41.0)
	# Swap a fresh masked fill back in so later checks see the real vessel.
	var _fq21_restored := TextureProgressBar.new()
	var _fq21_mask: Texture2D = hud._painted_texture("health_fill_mask")
	_fq21_restored.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	_fq21_restored.texture_under = _fq21_mask
	_fq21_restored.tint_under = Color(0.02, 0.04, 0.08, 0.88)
	_fq21_restored.texture_progress = _fq21_mask
	_fq21_restored.tint_progress = Color(0.82, 0.12, 0.10)
	hud.replace_vessel_fill("health", _fq21_restored)
	hud.update_health(player.health, player.max_health)
	harness._check("fq21_vessel_socket",
		_fq21_sockets_ok and _fq21_layered_vessels \
		and _fq21_swap_ok and _fq21_drive_ok,
		"sockets=%s layered=%s swap=%s drive=%s" % [str(_fq21_sockets_ok),
			str(_fq21_layered_vessels), str(_fq21_swap_ok), str(_fq21_drive_ok)])

	# FQ-20: painted mockup chrome consumed elsewhere — painted module
	# frames on crest/events (distinct textures from the band pieces).
	var _fq20_crest_sb: StyleBox = (hud._top_left_box as PanelContainer).get_theme_stylebox("panel")
	var _fq20_events_sb: StyleBox = hud._event_panel.get_theme_stylebox("panel")
	var _fq20_map_single_frame := true
	for _fq20_map_child in hud._map_panel.get_children():
		if _fq20_map_child is NinePatchRect:
			_fq20_map_single_frame = false
			break
	var _fq22_corner: Control = hud._top_left_box.find_child(
		"CrestCornerOrnament", true, false) as Control
	var _fq22_corner_clean: bool = _fq22_corner != null \
		and _fq22_corner.position.x >= 0.0 and _fq22_corner.position.y >= 0.0 \
		and _fq22_corner.find_child("*", true, false) == null
	var _fq20_frames_ok: bool = _fq20_crest_sb is StyleBoxFlat \
		and _fq20_events_sb is StyleBoxFlat \
		and _fq20_map_single_frame \
		and _fq22_corner_clean
	harness._check("fq22_module_chrome_contract", _fq20_frames_ok,
		"crest=%s events=%s map_single_frame=%s corner_clean=%s" % [
			str(_fq20_crest_sb.get_class()), str(_fq20_events_sb.get_class()),
			str(_fq20_map_single_frame), str(_fq22_corner_clean)])

	# FQ-20: the dock is the command center — five module toggle chips live
	# inside the dock panel, drive the modules, and mirror external changes.
	var _fq20_module_rect: Rect2 = hud._command_center_panel.get_global_rect() \
		if hud._command_center_panel != null else Rect2()
	var _fq20_dock_rect: Rect2 = hud._bottom_dock.get_global_rect() \
		if hud._bottom_dock != null else Rect2()
	var _fq20_dock_owned: bool = hud._bottom_dock != null \
		and hud._command_center_panel != null \
		and hud._bottom_dock.is_ancestor_of(hud._command_center_panel) \
		and _fq20_dock_rect.encloses(_fq20_module_rect)
	var _fq20_module_clear := _fq20_module_rect.size.x > 0.0
	for _fq20_clear_name in ["HotbarCell1", "HotbarCell2", "HotbarCell3",
			"HotbarCell4", "HotbarCell5", "DockActionInventory",
			"DockActionCharacter", "DockActionSkills", "DockActionTownHall"]:
		var _fq20_clear_control: Control = hud._bottom_dock.find_child(
			_fq20_clear_name, true, false) as Control if hud._bottom_dock != null else null
		if _fq20_clear_control == null \
				or _fq20_module_rect.intersects(_fq20_clear_control.get_global_rect()):
			_fq20_module_clear = false
			break
	var _fq20_cc_ok: bool = hud._module_toolbar != null \
		and hud._command_center_panel != null \
		and hud._command_center_panel.is_ancestor_of(hud._module_toolbar) \
		and hud._bottom_dock.is_ancestor_of(hud._module_toolbar) \
		and _fq20_dock_owned \
		and _fq20_module_clear \
		and hud._command_toggles.size() == 5
	var _fq20_crest_chip: Button = hud._command_toggles.get("Crest")
	var _fq20_cc_before: bool = hud._top_left_box.visible
	_fq20_crest_chip.button_pressed = not _fq20_crest_chip.button_pressed
	var _fq20_cc_toggled: bool = hud._top_left_box.visible != _fq20_cc_before \
		and _fq20_crest_chip.button_pressed == hud._top_left_box.visible
	_fq20_crest_chip.button_pressed = not _fq20_crest_chip.button_pressed
	var _fq20_cc_restored: bool = hud._top_left_box.visible == _fq20_cc_before
	hud._toggle_goal_module()
	var _fq20_cc_synced: bool = (hud._command_toggles["Goal"] as Button).button_pressed \
		== hud._goal_panel.visible
	hud._toggle_goal_module()
	var _fq20_map_chip: Button = hud._command_toggles.get("Map") as Button
	hud.set_map_open(false)
	if _fq20_map_chip != null:
		_fq20_map_chip.set_pressed_no_signal(false)
		_fq20_map_chip.button_pressed = true
	var _fq20_map_chip_opens: bool = _fq20_map_chip != null \
		and hud.map_open() and _fq20_map_chip.button_pressed
	if _fq20_map_chip != null:
		_fq20_map_chip.button_pressed = false
	var _fq20_map_chip_closes: bool = _fq20_map_chip != null \
		and not hud.map_open() and not _fq20_map_chip.button_pressed
	if _fq20_map_chip != null:
		_fq20_map_chip.grab_focus()
	var _fq20_map_chip_no_focus: bool = _fq20_map_chip != null \
		and _fq20_map_chip.focus_mode == Control.FOCUS_NONE \
		and not _fq20_map_chip.has_focus()
	harness._check("fq20_docked_command_center",
		_fq20_cc_ok and _fq20_cc_toggled and _fq20_cc_restored and _fq20_cc_synced
		and _fq20_map_chip_opens and _fq20_map_chip_closes and _fq20_map_chip_no_focus,
		"dock_owned=%s clear=%s rect=%s toggled=%s restored=%s synced=%s map_chip=%s/%s no_focus=%s" % [
			str(_fq20_dock_owned), str(_fq20_module_clear), _fq20_module_rect,
			str(_fq20_cc_toggled), str(_fq20_cc_restored), str(_fq20_cc_synced),
			str(_fq20_map_chip_opens), str(_fq20_map_chip_closes),
			str(_fq20_map_chip_no_focus)])

	# FQ-19: resource vessels — masked liquid fill plus the damage / recovery /
	# zero / regeneration / use-pulse / full-core effect states. Overlay tints
	# are set synchronously by update_*, so each transition is observable.
	# The mask texture must be pre-sized to the control with nine-patch OFF:
	# nine-patch stretching squashes the disk instead of draining it (the
	# operator-caught "health never drops" bug).
	var _fq19v_hfill := hud._health_vessel_fill as TextureProgressBar
	var _fq19v_masked: bool = _fq19v_hfill != null \
		and hud._attunement_vessel_fill is TextureProgressBar \
		and not _fq19v_hfill.nine_patch_stretch \
		and _fq19v_hfill.texture_progress != null \
		and _fq19v_hfill.texture_progress.get_size().is_equal_approx(_fq19v_hfill.size)
	hud.update_health(80.0, 100.0)
	hud.update_health(40.0, 100.0)
	var _fq19v_damage: bool = hud._health_fx != null \
		and hud._health_fx.self_modulate.a > 0.5 \
		and hud._health_fx.self_modulate.r > hud._health_fx.self_modulate.g
	hud.update_health(60.0, 100.0)
	var _fq19v_recover: bool = hud._health_fx.self_modulate.a > 0.3 \
		and hud._health_fx.self_modulate.g > hud._health_fx.self_modulate.r
	hud.update_health(10.0, 100.0)
	var _fq19v_low: bool = hud._low_health_active
	hud.update_health(0.0, 100.0)
	var _fq19v_zero: bool = is_equal_approx(hud._health_vessel_fill.value, 0.0)
	hud.update_attunement(30.0, 50.0)
	hud.update_attunement(40.0, 50.0)
	var _fq19v_shimmer: bool = hud._attunement_fx != null \
		and hud._attunement_fx.self_modulate.a > 0.3
	hud.update_attunement(20.0, 50.0)
	var _fq19v_pulse: bool = hud._attunement_frame != null \
		and hud._attunement_frame.scale.x > 1.05
	var _fq19v_core_removed: bool = hud._attunement_core == null
	var _fq19v_constellation: bool = hud._attunement_constellation != null \
		and hud._attunement_constellation.visible
	hud.update_attunement(50.0, 50.0)
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())
	harness._check("fq19_vessel_liquid_and_effects",
		_fq19v_masked and _fq19v_damage and _fq19v_recover and _fq19v_low
		and _fq19v_zero and _fq19v_shimmer and _fq19v_pulse
		and _fq19v_core_removed and _fq19v_constellation,
		"masked=%s damage=%s recover=%s low=%s zero=%s shimmer=%s pulse=%s core_removed=%s constellation=%s" % [
			str(_fq19v_masked), str(_fq19v_damage), str(_fq19v_recover),
			str(_fq19v_low), str(_fq19v_zero), str(_fq19v_shimmer),
			str(_fq19v_pulse), str(_fq19v_core_removed), str(_fq19v_constellation)])
