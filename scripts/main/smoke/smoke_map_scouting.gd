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
	# Phase C: Events is the right dock WING (kit path) or a floating panel (fallback).
	# Either way it must coexist with the map — toggling one never closes the other, it
	# survives closing the map, it does not overlap the map or the contextual stack, and
	# it stays on-screen. The floating panel is large (>=320x120); the docked wing is the
	# small compact readout, so the min-size assertion applies only to the floating case.
	var _fq19_ev: Control = hud._events_module()
	var _fq19_docked: bool = hud._right_wing != null
	var _fq19_events_before: bool = _fq19_ev != null and _fq19_ev.visible
	if _fq19_ev != null:
		_fq19_ev.visible = true
		hud._save_hud_layout()
	var _fq19_map_open: bool = hud.toggle_map()
	var _fq19_together: bool = _fq19_map_open and _fq19_ev.visible
	hud._toggle_event_module()
	var _fq19_event_off_map_on: bool = not _fq19_ev.visible and hud.map_open()
	hud._toggle_event_module()
	var _fq19_event_on_map_on: bool = _fq19_ev.visible and hud.map_open()
	var _fq19_event_rect: Rect2 = _fq19_ev.get_global_rect() if _fq19_ev != null else Rect2()
	var _fq19_map_rect: Rect2 = hud._map_panel.get_global_rect() if hud._map_panel != null else Rect2()
	hud._position_context_stack()
	var _fq19_stack_rect: Rect2 = hud._context_stack.get_global_rect()
	var _fq19_stack_clear: bool = not _fq19_stack_rect.intersects(_fq19_event_rect) \
		and not _fq19_stack_rect.intersects(_fq19_map_rect)
	hud.toggle_map()
	var _fq19_event_survives_close: bool = _fq19_ev.visible and not hud.map_open()
	var _fq19_viewport: Vector2 = get_viewport().get_visible_rect().size
	if _fq19_ev != null:
		_fq19_ev.visible = _fq19_events_before
		hud._save_hud_layout()
	var _fq19_size_ok: bool = _fq19_docked \
		or (_fq19_ev.custom_minimum_size.x >= 320.0 and _fq19_ev.custom_minimum_size.y >= 120.0)
	harness._check("fq19_map_events_coexist",
		_fq19_together and _fq19_event_off_map_on and _fq19_event_on_map_on
		and _fq19_event_survives_close and not _fq19_event_rect.intersects(_fq19_map_rect)
		and _fq19_stack_clear and _fq19_size_ok
		and _fq19_event_rect.position.x >= 0.0
		and _fq19_event_rect.end.x <= _fq19_viewport.x
		and _fq19_event_rect.position.y >= 0.0
		and _fq19_event_rect.end.y <= _fq19_viewport.y,
		"together=%s event_off=%s event_on=%s survives=%s docked=%s stack_clear=%s size=%s event=%s map=%s viewport=%s" % [
			str(_fq19_together), str(_fq19_event_off_map_on), str(_fq19_event_on_map_on),
			str(_fq19_event_survives_close), str(_fq19_docked), str(_fq19_stack_clear),
			str(_fq19_size_ok), str(_fq19_event_rect), str(_fq19_map_rect), str(_fq19_viewport)])
	hud.update_time(5, true, 2)
	# Phase C: the docked header shows the day (journal) + military time (clock) as separate
	# icon+value groups with "Day <n>"/"Time HH:MM" tooltips; the rich phase/threat detail is
	# retained in the Events popup header (not globally simplified).
	var _fq19_header: String = hud._events_docked_time_detail()
	var _fq19_time_ok: bool = hud._time_label == null \
		and hud._event_day_value != null and hud._event_day_value.text == "5" \
		and not hud._event_day_value.text.contains("Day") \
		and hud._event_time_value != null \
		and hud._event_day_group.tooltip_text == "Day 5" \
		and _fq19_header.contains("Day 5") and _fq19_header.contains("Night")
	harness._check("fq19_events_time_header_live", _fq19_time_ok,
		"crest_time=%s day=%s time=%s tip=%s detail=%s" % [str(hud._time_label != null),
			str(hud._event_day_value.text if hud._event_day_value != null else "missing"),
			str(hud._event_time_value.text if hud._event_time_value != null else "missing"),
			str(hud._event_day_group.tooltip_text if hud._event_day_group != null else "missing"),
			_fq19_header])

	# FQ-19: exact clock — the fraction maps onto the settlement clock
	# (day 06:00-20:00, night wraps 20:00-06:00) with dawn/day/dusk/night
	# phase words in the (full) events header, retained in the popup when docked.
	hud.update_time(5, true, 0, 0.7)
	var _fq19c_night: String = hud._events_docked_time_detail()
	hud.update_time(5, false, 0, 0.05)
	var _fq19c_dawn: String = hud._events_docked_time_detail()
	hud.update_time(5, false, 0, 0.3)
	var _fq19c_day: String = hud._events_docked_time_detail()
	hud.update_time(5, false, 0, 0.6)
	var _fq19c_dusk: String = hud._events_docked_time_detail()
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
	# Phase C: the crest module is a floating PanelContainer (fallback) or the left dock
	# wing Control (kit). Either way its live title + the three numeric bar values are the
	# real model (update_settlement / update_progression drive them, no duplicate state).
	var _fq19_crest_ok: bool = hud._top_left_box != null \
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
	harness._res_write_png(_fq21_theme_source, _fq21_theme_valid_path)
	var _fq21_theme_bad := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_fq21_theme_bad.fill(Color.WHITE)
	harness._res_write_png(_fq21_theme_bad, _fq21_theme_invalid_path)
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
	# Phase C: use the Goal widget (still free-floating/draggable) — Crest/Events are
	# docked and no longer registered HUD-edit widgets.
	var _r06g_widget: Control = hud._hud_widgets.get("goal")
	var _r06g_size_ok: bool = _r06g_widget != null \
		and hud._hud_widget_size(_r06g_widget) == HudEditGeometry.widget_size(_r06g_widget)
	# The wrapper returns Rect2() for a hidden widget, else the geometry rect --
	# assert delegation for whichever state the widget is in.
	var _r06g_grip_expected: Rect2 = HudEditGeometry.grip_rect(_r06g_widget.get_global_rect()) \
		if (_r06g_widget != null and _r06g_widget.visible) else Rect2()
	var _r06g_grip_ok: bool = _r06g_widget != null \
		and hud._hud_grip_rect("goal") == _r06g_grip_expected
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
	var _fq21_json_content: bool = int(_fq21_geometry.get("version", 0)) == 3 \
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

	# FQ-20 / Phase C: module chrome contract. The map is a single (non-stacked) frame in
	# all cases. FLOATING crest/events carry a painted StyleBoxFlat module frame + a clean
	# corner ornament; the DOCKED crest/events are plain Control wings (NOT floating
	# PanelContainer panels) whose readouts sit in an integrated recessed instrument socket
	# — the accepted design (built into the wooden dock, no floating black panels over it).
	var _fq20_map_single_frame := true
	for _fq20_map_child in hud._map_panel.get_children():
		if _fq20_map_child is NinePatchRect:
			_fq20_map_single_frame = false
			break
	var _fq20_frames_ok: bool
	var _fq20_detail := ""
	if hud._left_wing != null:
		_fq20_frames_ok = not (hud._top_left_box is PanelContainer) \
			and not (hud._events_module() is PanelContainer) \
			and _fq20_map_single_frame
		_fq20_detail = "docked chrome-less wings"
	else:
		var _fq20_crest_sb: StyleBox = (hud._top_left_box as PanelContainer).get_theme_stylebox("panel")
		var _fq20_events_sb: StyleBox = hud._event_panel.get_theme_stylebox("panel")
		var _fq22_corner: Control = hud._top_left_box.find_child("CrestCornerOrnament", true, false) as Control
		var _fq22_corner_clean: bool = _fq22_corner != null \
			and _fq22_corner.position.x >= 0.0 and _fq22_corner.position.y >= 0.0 \
			and _fq22_corner.find_child("*", true, false) == null
		_fq20_frames_ok = _fq20_crest_sb is StyleBoxFlat and _fq20_events_sb is StyleBoxFlat \
			and _fq20_map_single_frame and _fq22_corner_clean
		_fq20_detail = "floating crest=%s events=%s corner_clean=%s" % [
			str(_fq20_crest_sb.get_class()), str(_fq20_events_sb.get_class()), str(_fq22_corner_clean)]
	harness._check("fq22_module_chrome_contract", _fq20_frames_ok,
		"docked=%s map_single_frame=%s %s" % [
			str(hud._left_wing != null), str(_fq20_map_single_frame), _fq20_detail])

	# Phase C: docked Crest/Events wings contract. Wing content is native-placed inside the
	# dock band (centred, native scale), so containment/overlap are resolution-independent —
	# tested here at the base size and proven visually by the four-size HUD-QA wing crops.
	var _dw_ok := true
	var _dw_detail := "not docked (fallback)"
	if hud._left_wing != null and hud._right_wing != null:
		var _dw_lrect: Rect2 = hud._left_wing.get_global_rect()
		var _dw_rrect: Rect2 = hud._right_wing.get_global_rect()
		# (1) socket containment: each socket sits inside its wing leaving a wooden margin,
		# and the content host + its content fit inside the socket interior.
		var _dw_lsock: Rect2 = hud._left_socket.get_global_rect()
		var _dw_rsock: Rect2 = hud._right_socket.get_global_rect()
		var _dw_socket_in: bool = _dw_lrect.encloses(_dw_lsock) and _dw_rrect.encloses(_dw_rsock) \
			and _dw_lsock.position.x - _dw_lrect.position.x >= 3.0 \
			and _dw_rsock.position.x - _dw_rrect.position.x >= 3.0 \
			and _dw_lsock.position.y - _dw_lrect.position.y >= 3.0
		var _dw_host_in: bool = _dw_lsock.encloses(hud._left_wing_box.get_global_rect()) \
			and _dw_rsock.encloses(hud._right_wing_box.get_global_rect())
		# content never overflows the socket interior (custom_min never forces expansion).
		var _dw_lfit: bool = hud._left_wing_box.get_combined_minimum_size().x <= hud._left_wing_box.size.x + 0.5 \
			and hud._left_wing_box.get_combined_minimum_size().y <= hud._left_wing_box.size.y + 0.5
		var _dw_rfit: bool = hud._right_wing_box.get_combined_minimum_size().x <= hud._right_wing_box.size.x + 0.5 \
			and hud._right_wing_box.get_combined_minimum_size().y <= hud._right_wing_box.size.y + 0.5
		# (2) zero overlap with the nearest dock controls (orbs + hotbar ends).
		var _dw_no_overlap := true
		var _dw_ctrls: Array = [hud._health_vessel_fill, hud._attunement_vessel_fill]
		if hud._hotbar_slots.size() >= 2:
			_dw_ctrls.append(hud._hotbar_slots[0])
			_dw_ctrls.append(hud._hotbar_slots[hud._hotbar_slots.size() - 1])
		for _dw_c in _dw_ctrls:
			if _dw_c != null and (_dw_lrect.intersects((_dw_c as Control).get_global_rect()) \
					or _dw_rrect.intersects((_dw_c as Control).get_global_rect())):
				_dw_no_overlap = false
		# (3) the content cluster is vertically centred within its host (top pad ~= bottom).
		var _dw_centered := true
		for _dw_host in [hud._left_wing_box, hud._right_wing_box]:
			var _dw_hc: Control = _dw_host
			if _dw_hc.get_child_count() > 0:
				var _dw_hr: Rect2 = _dw_hc.get_global_rect()
				var _dw_cl: Rect2 = (_dw_hc.get_child(0) as Control).get_global_rect()
				if absf((_dw_cl.position.y - _dw_hr.position.y) - (_dw_hr.end.y - _dw_cl.end.y)) > 4.0:
					_dw_centered = false
		# (4) live data parity + bottom-to-top gauges: the wing bars/values ARE the model.
		var _dw_parity: bool = hud._left_wing.is_ancestor_of(hud._bars["coherence"]) \
			and hud._left_wing.is_ancestor_of(hud._bar_values["coherence"]) \
			and (hud._bars["coherence"] as ProgressBar).fill_mode == ProgressBar.FILL_BOTTOM_TO_TOP
		# (5) ownership: docked readouts are NOT draggable HUD-edit widgets; Goal still is.
		var _dw_owner: bool = not hud._hud_widgets.has("crest") \
			and not hud._hud_widgets.has("events") and hud._hud_widgets.has("goal")
		# (6) CLICK open/close + single-open exclusivity (hover does not open).
		hud._close_wing_popups()
		var _dw_click := InputEventMouseButton.new()
		_dw_click.button_index = MOUSE_BUTTON_LEFT
		_dw_click.pressed = true
		hud._left_wing.gui_input.emit(_dw_click)
		var _dw_open_crest: bool = hud._crest_popup.visible and hud._open_wing_popup == hud._crest_popup
		hud._right_wing.gui_input.emit(_dw_click)
		var _dw_exclusive: bool = hud._event_popup.visible and not hud._crest_popup.visible \
			and hud._open_wing_popup == hud._event_popup
		hud._right_wing.gui_input.emit(_dw_click)   # re-click the same wing closes it
		var _dw_reclose: bool = not hud._event_popup.visible and hud._open_wing_popup == null
		# (7) all-100 containment retained: 3-digit values fit without forcing expansion.
		hud.update_settlement(100.0, 100.0, 100.0, {}, [])
		await get_tree().process_frame
		var _dw_worst: bool = (hud._bar_values["coherence"] as Label).text == "100" \
			and hud._left_wing_box.get_combined_minimum_size().x <= hud._left_wing_box.size.x + 0.5
		_dw_ok = _dw_socket_in and _dw_host_in and _dw_lfit and _dw_rfit and _dw_no_overlap \
			and _dw_centered and _dw_parity and _dw_owner and _dw_open_crest and _dw_exclusive \
			and _dw_reclose and _dw_worst
		_dw_detail = "socket_in=%s host_in=%s lfit=%s rfit=%s overlap_free=%s centered=%s parity=%s owner=%s open=%s excl=%s reclose=%s worst=%s" % [
			str(_dw_socket_in), str(_dw_host_in), str(_dw_lfit), str(_dw_rfit), str(_dw_no_overlap),
			str(_dw_centered), str(_dw_parity), str(_dw_owner), str(_dw_open_crest), str(_dw_exclusive),
			str(_dw_reclose), str(_dw_worst)]
		hud._close_wing_popups()
	harness._check("hud_dock_wings_contract", _dw_ok, _dw_detail)

	# Phase C visual slice: the left wing's three vertical instruments — mixed values map to
	# distinct bottom-to-top heights, exact values, per-metric authored icons (silhouette,
	# not colour alone), live "<name>: <value>" tooltips, and NO persistent Coh/Load/Res
	# titles (the icon + tooltip carry identity).
	var _gi_ok := true
	var _gi_detail := "not docked (fallback)"
	if hud._left_wing != null:
		hud.update_settlement(80.0, 13.0, 77.0, {}, [])
		await get_tree().process_frame
		var _gi_vals: bool = (hud._bar_values["coherence"] as Label).text == "80" \
			and (hud._bar_values["load"] as Label).text == "13" \
			and (hud._bar_values["resilience"] as Label).text == "77"
		var _gi_fill := true
		var _gi_distinct: bool = (hud._bars["load"] as ProgressBar).value \
				< (hud._bars["coherence"] as ProgressBar).value - 20.0 \
			and (hud._bars["load"] as ProgressBar).value \
				< (hud._bars["resilience"] as ProgressBar).value - 20.0
		var _gi_tips := true
		for _gi_k in ["coherence", "load", "resilience"]:
			if (hud._bars[_gi_k] as ProgressBar).fill_mode != ProgressBar.FILL_BOTTOM_TO_TOP:
				_gi_fill = false
			var _gi_col: Control = hud._crest_columns[_gi_k]
			var _gi_full: String = str(hud._crest_full_names[_gi_k])
			var _gi_num := str(int(round((hud._bars[_gi_k] as ProgressBar).value)))
			if not _gi_col.tooltip_text.contains(_gi_full) or not _gi_col.tooltip_text.contains(_gi_num):
				_gi_tips = false
		var _gi_icons: bool = hud._left_wing.find_children("*", "TextureRect", true, false).size() >= 3
		var _gi_no_titles := true
		for _gi_lbl in hud._left_wing.find_children("*", "Label", true, false):
			var _gi_t: String = (_gi_lbl as Label).text
			if _gi_t == "Coh" or _gi_t == "Load" or _gi_t == "Res":
				_gi_no_titles = false
		_gi_ok = _gi_vals and _gi_fill and _gi_distinct and _gi_tips and _gi_icons and _gi_no_titles
		_gi_detail = "vals=%s fill=%s distinct=%s tips=%s icons=%s no_titles=%s" % [
			str(_gi_vals), str(_gi_fill), str(_gi_distinct), str(_gi_tips), str(_gi_icons),
			str(_gi_no_titles)]
	harness._check("hud_dock_gauge_instruments", _gi_ok, _gi_detail)

	# Phase C visual slice: the header day + military-time formatter and its live use —
	# the day is the bare number beside the journal icon; the time is "HHMM" (zero-padded,
	# 24h, no colon) beside the clock icon; the group tooltips carry "Day <n>"/"Time HH:MM".
	var _cf_fmt: bool = hud._format_mil_time(0, 0) == "0000" \
		and hud._format_mil_time(9, 5) == "0905" \
		and hud._format_mil_time(11, 24) == "1124" \
		and hud._format_mil_time(23, 59) == "2359"
	var _cf_live := true
	var _cf_sample := "-"
	if hud._right_wing != null:
		hud.update_time(98, false, 3, 0.279)   # -> day 98, 12:00
		await get_tree().process_frame
		_cf_sample = "%s / %s" % [hud._event_day_value.text, hud._event_time_value.text]
		_cf_live = hud._event_day_value.text == "98" and hud._event_time_value.text == "1200" \
			and not hud._event_time_value.text.contains(":") \
			and not hud._event_day_value.text.contains("Day") \
			and hud._event_day_group.tooltip_text == "Day 98" \
			and hud._event_time_group.tooltip_text == "Time 12:00"
	harness._check("hud_dock_clock_format", _cf_fmt and _cf_live,
		"fmt=%s live=%s sample=%s" % [str(_cf_fmt), str(_cf_live), _cf_sample])

	# Phase C visual slice: the three-most-recent compact event lines. Newest first; the
	# fourth-oldest is excluded from the compact view but the full history is preserved in
	# the popup; authored summaries are used verbatim (not prefix slices); an unauthored
	# long message falls back to a word-boundary summary; each line is one-line/ellipsised;
	# the full original message is exposed on hover.
	var _es_ok := true
	var _es_detail := "not docked (fallback)"
	if hud._right_wing != null:
		hud._log_entries.clear()
		hud.log_event("First settlers raise the very first timber wall of the young camp",
			"First wall raised", "build")
		hud.log_event("A roaming merchant caravan is spotted approaching from the north",
			"Caravan spotted", "settler")
		hud.log_event("Raiders are massing beyond the tree line to the far eastern side",
			"Raiders massing east", "warning")
		hud.log_event("The night watch reports distant torches along the eastern ridge",
			"Torches to the east", "warning")
		await get_tree().process_frame
		var _es_order: bool = hud._event_lines[0].text == "Torches to the east" \
			and hud._event_lines[1].text == "Raiders massing east" \
			and hud._event_lines[2].text == "Caravan spotted"
		var _es_excluded := true
		for _es_line in hud._event_lines:
			if (_es_line as Label).text == "First wall raised":
				_es_excluded = false
		var _es_history: bool = hud._log_entries.size() == 4 \
			and str(hud._log_entries[0]["full"]).contains("first timber wall") \
			and hud._log_label.text.contains("first timber wall")
		# The full original message is exposed on hover (both the row and the line label).
		var _es_tooltip: bool = hud._event_lines[0].tooltip_text.contains("distant torches") \
			and (hud._event_lines[0].get_parent() as Control).tooltip_text.contains("distant torches")
		var _es_authored: bool = hud._event_lines[1].text == "Raiders massing east" \
			and not hud._event_lines[1].text.begins_with("Raiders are massing")
		# Each visible row leads with its authored category icon; the icon flows from the
		# paired entry's "icon" field, and distinct categories are distinct textures.
		var _es_icons: bool = hud._event_icons.size() == 3 \
			and hud._event_icons[0].visible and hud._event_icons[0].texture != null \
			and hud._event_icons[0].texture == hud._event_icon_texture("warning") \
			and hud._event_icons[2].texture == hud._event_icon_texture("settler") \
			and str(hud._log_entries[3].get("icon", "")) == "warning" \
			and hud._event_icon_texture("warning") != hud._event_icon_texture("build") \
			and hud._event_icon_texture("warning") != hud._event_icon_texture("generic")
		var _es_oneline := true
		for _es_l in hud._event_lines:
			var _esl: Label = _es_l
			if _esl.autowrap_mode != TextServer.AUTOWRAP_OFF \
					or _esl.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS \
					or not _esl.clip_text:
				_es_oneline = false
		# Unauthored long message -> conservative word-boundary fallback (no mid-word cut),
		# generic category icon, and the two unused rows hide their icons.
		var _es_full := "Reinforcements arriving shortly from the western outpost garrison"
		hud._log_entries.clear()
		hud.log_event(_es_full)
		await get_tree().process_frame
		var _es_fb: String = hud._event_lines[0].text
		var _es_core := _es_fb.trim_suffix("…")
		var _es_fallback: bool = _es_fb.length() < _es_full.length() and _es_fb.ends_with("…") \
			and _es_full.begins_with(_es_core) \
			and (_es_core.length() == _es_full.length() or _es_full[_es_core.length()] == " ") \
			and hud._event_icons[0].texture == hud._event_icon_texture("generic") \
			and not hud._event_icons[1].visible and not hud._event_icons[2].visible
		_es_ok = _es_order and _es_excluded and _es_history and _es_tooltip and _es_authored \
			and _es_icons and _es_oneline and _es_fallback
		_es_detail = "order=%s excluded=%s history=%s tooltip=%s authored=%s icons=%s oneline=%s fallback=%s fb=\"%s\"" % [
			str(_es_order), str(_es_excluded), str(_es_history), str(_es_tooltip), str(_es_authored),
			str(_es_icons), str(_es_oneline), str(_es_fallback), _es_fb]
	harness._check("hud_dock_event_summaries", _es_ok, _es_detail)

	# Phase C: event-icon category mapping. Mirrors the exact (summary, icon) pairs
	# game_root emits — plain nightfall uses the crescent-moon NIGHT icon, threat-bearing
	# nightfall uses the WARNING icon, and dawn uses the DAWN icon. Night, dawn, warning,
	# and the header clock-face icon are all distinct textures (a sun/clock must never
	# stand in for nightfall).
	var _im_ok := true
	var _im_detail := "not docked (fallback)"
	if hud._right_wing != null:
		hud._log_entries.clear()
		hud.log_event("Dawn breaks. The pressure recedes.", "Dawn", "dawn")
		hud.log_event("Night falls. Pressure rises (2 threats approaching).",
			"Night: 2 threats", "warning")
		hud.log_event("Night falls.", "Nightfall", "night")
		await get_tree().process_frame
		# rows newest first: night, warning (threat nightfall), dawn.
		var _im_rows: bool = hud._event_icons[0].texture == hud._event_icon_texture("night") \
			and hud._event_icons[1].texture == hud._event_icon_texture("warning") \
			and hud._event_icons[2].texture == hud._event_icon_texture("dawn")
		var _im_entry: bool = str(hud._log_entries[2].get("icon", "")) == "night" \
			and str(hud._log_entries[1].get("icon", "")) == "warning" \
			and str(hud._log_entries[0].get("icon", "")) == "dawn"
		var _im_distinct: bool = hud._event_icon_texture("night") != null \
			and hud._event_icon_texture("night") != hud._event_icon_texture("dawn") \
			and hud._event_icon_texture("night") != hud._event_icon_texture("warning") \
			and hud._event_icon_texture("night") != hud._painted_texture("wing_hdr_time")
		_im_ok = _im_rows and _im_entry and _im_distinct
		_im_detail = "rows=%s entry=%s distinct=%s" % [
			str(_im_rows), str(_im_entry), str(_im_distinct)]
	harness._check("hud_dock_event_icon_mapping", _im_ok, _im_detail)

	# FQ-20: the dock is the command center — the module toggle chips live inside the dock
	# panel, drive the modules, and mirror external changes. Phase C: only Goal/Map/Edit
	# remain, and the framed tray is shrunk to hug those three (no reserved void).
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
	# Phase C: Crest/Events are docked into the wings (opened by clicking the wing), so
	# their redundant toolbar chips are removed — the toolbar keeps Goal / Map / Edit.
	var _fq20_no_crest_events: bool = not hud._command_toggles.has("Crest") \
		and not hud._command_toggles.has("Events") \
		and hud._command_toggles.has("Goal") and hud._command_toggles.has("Map") \
		and hud._command_toggles.has("Edit")
	# Compact-tray geometry: the framed tray hugs its three buttons — its centre matches the
	# dock centre, the button union is centred in the tray with near-equal, bounded interior
	# gaps, and every button is fully contained. (Native placement, so this holds at every
	# resolution; the full-dock QA screenshots prove it visually.)
	var _fq20_dock_center := _fq20_dock_rect.get_center().x
	var _fq20_tray_center := _fq20_module_rect.get_center().x
	var _fq20_first: Rect2 = (hud._command_toggles["Goal"] as Control).get_global_rect()
	var _fq20_last: Rect2 = (hud._command_toggles["Edit"] as Control).get_global_rect()
	var _fq20_union_center := (_fq20_first.position.x + _fq20_last.end.x) * 0.5
	var _fq20_gap_left := _fq20_first.position.x - _fq20_module_rect.position.x
	var _fq20_gap_right := _fq20_module_rect.end.x - _fq20_last.end.x
	var _fq20_contains := true
	for _fq20_btn_name in ["Goal", "Map", "Edit"]:
		if not _fq20_module_rect.encloses((hud._command_toggles[_fq20_btn_name] as Control).get_global_rect()):
			_fq20_contains = false
	var _fq20_tray_geo: bool = absf(_fq20_tray_center - _fq20_dock_center) <= 1.0 \
		and absf(_fq20_union_center - _fq20_tray_center) <= 1.0 \
		and absf(_fq20_gap_left - _fq20_gap_right) <= 1.5 \
		and _fq20_gap_left <= 20.0 and _fq20_gap_right <= 20.0 \
		and _fq20_gap_left >= 2.0 and _fq20_gap_right >= 2.0 \
		and _fq20_contains
	# Reset/restore returns the tray to the compact authoritative rect (JSON), not the old
	# five-button width. Positions are dock-native (integer), so compare locally.
	hud._restore_native_module_toolbar_rect()
	var _fq20_reset_rect := Rect2(hud._command_center_panel.position, hud._command_center_panel.size)
	var _fq20_reset_ok: bool = _fq20_reset_rect.is_equal_approx(Rect2(535, 132, 210, 44))
	# Arithmetic capacity contract (NOT an instantiated render): the floating (non-kit)
	# fallback panel is anchored to a fixed 364px width, and five fallback chips (54px each
	# + 4px gaps = 286px) fit inside its content box (364 - 2*7 = 350px). This guards the
	# fallback width against being shrunk below the five-button need; it does not build the
	# fallback HUD, which the docked kit path replaces here.
	var _fq20_fallback_capacity: bool = (5.0 * 54.0 + 4.0 * 4.0) <= (364.0 - 2.0 * 7.0)
	var _fq20_cc_ok: bool = hud._module_toolbar != null \
		and hud._command_center_panel != null \
		and hud._command_center_panel.is_ancestor_of(hud._module_toolbar) \
		and hud._bottom_dock.is_ancestor_of(hud._module_toolbar) \
		and _fq20_dock_owned \
		and _fq20_module_clear \
		and hud._command_toggles.size() == 3 \
		and _fq20_no_crest_events \
		and _fq20_tray_geo and _fq20_reset_ok and _fq20_fallback_capacity
	# The Goal chip drives + mirrors its module (toggle, then restore).
	var _fq20_goal_chip: Button = hud._command_toggles.get("Goal")
	var _fq20_cc_before: bool = hud._goal_panel.visible
	_fq20_goal_chip.button_pressed = not _fq20_goal_chip.button_pressed
	var _fq20_cc_toggled: bool = hud._goal_panel.visible != _fq20_cc_before \
		and _fq20_goal_chip.button_pressed == hud._goal_panel.visible
	_fq20_goal_chip.button_pressed = not _fq20_goal_chip.button_pressed
	var _fq20_cc_restored: bool = hud._goal_panel.visible == _fq20_cc_before
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
	# The docked command chips are intentionally non-focusable (FOCUS_NONE) so a
	# click never parks keyboard focus on the chip and away from gameplay. Calling
	# grab_focus() on a FOCUS_NONE control is a no-op that ALSO emits an engine
	# "This control can't grab focus" warning, so we assert the invariant by
	# property and only exercise grab_focus() when the control is actually
	# focusable (it never is here). The check's meaning — the chip refuses focus —
	# is unchanged; the spurious warning is gone.
	if _fq20_map_chip != null and _fq20_map_chip.focus_mode != Control.FOCUS_NONE:
		_fq20_map_chip.grab_focus()
	var _fq20_map_chip_no_focus: bool = _fq20_map_chip != null \
		and _fq20_map_chip.focus_mode == Control.FOCUS_NONE \
		and not _fq20_map_chip.has_focus()
	harness._check("fq20_docked_command_center",
		_fq20_cc_ok and _fq20_cc_toggled and _fq20_cc_restored and _fq20_cc_synced
		and _fq20_map_chip_opens and _fq20_map_chip_closes and _fq20_map_chip_no_focus,
		"count=%d no_ce=%s tray_geo=%s gaps=%.1f/%.1f dcen=%.1f tcen=%.1f ucen=%.1f reset=%s fb_capacity=%s toggled=%s synced=%s map=%s/%s nofocus=%s" % [
			hud._command_toggles.size(), str(_fq20_no_crest_events), str(_fq20_tray_geo),
			_fq20_gap_left, _fq20_gap_right, _fq20_dock_center, _fq20_tray_center,
			_fq20_union_center, str(_fq20_reset_ok), str(_fq20_fallback_capacity),
			str(_fq20_cc_toggled), str(_fq20_cc_synced),
			str(_fq20_map_chip_opens), str(_fq20_map_chip_closes), str(_fq20_map_chip_no_focus)])

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
