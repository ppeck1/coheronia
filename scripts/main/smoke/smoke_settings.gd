extends Node
## S-07.3 smoke domain module - R-07 settings & UI: slice 1 (pause menu,
## settings, key rebinding), slice 2 (save management), slice 3 (build preview +
## reasoned invalid-placement feedback), slice 4 (unified crafting panel + Town
## Hall trim). Order-preserving; harness owns _check(). AudioSettings/InputSettings
## are harness class-local preload consts (§11.4a category 4), re-preloaded here.

const AudioSettings := preload("res://scripts/audio/audio_settings.gd")
const InputSettings := preload("res://scripts/shell/input_settings.gd")


func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this cluster uses.
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player
	var hall = ctx.hall
	var hud = ctx.hud
	# --- R-07 slice 1: pause menu, settings, key rebinding ---
	# (a) the pause menu genuinely freezes the simulation via get_tree().paused
	# (game_root is pausable; the menu + music run PROCESS_MODE_ALWAYS) and
	# cleanly resumes.
	var _r07_pm = root._pause_menu
	var _r07_tod0: float = root.time_of_day
	var _r07_day0: int = root.day_count
	_r07_pm.open()
	var _r07_paused_on: bool = get_tree().paused and _r07_pm.is_open()
	for _r07_i in range(20):
		await get_tree().process_frame
	var _r07_frozen: bool = is_equal_approx(root.time_of_day, _r07_tod0) \
		and root.day_count == _r07_day0
	_r07_pm.resume()
	var _r07_resumed: bool = not get_tree().paused and not _r07_pm.is_open()
	harness._check("r07_pause_freezes_and_resumes",
		_r07_paused_on and _r07_frozen and _r07_resumed,
		"paused=%s frozen=%s resumed=%s" % [str(_r07_paused_on), str(_r07_frozen),
			str(_r07_resumed)])

	# (b) a key rebind applies to the live InputMap and resets to default.
	var _r07_ev := InputEventKey.new()
	_r07_ev.keycode = KEY_T
	_r07_ev.physical_keycode = KEY_T
	InputSettings.rebind(GameState.profile, "jump", _r07_ev)
	var _r07_bound: bool = InputMap.action_has_event("jump", _r07_ev) \
		and InputSettings.is_changed("jump")
	InputSettings.reset(GameState.profile)
	var _r07_reset: bool = not InputSettings.is_changed("jump") \
		and not InputMap.action_has_event("jump", _r07_ev)
	harness._check("r07_keybind_applies_and_resets", _r07_bound and _r07_reset,
		"bound=%s reset=%s jump=%s" % [str(_r07_bound), str(_r07_reset),
			InputSettings.key_label("jump")])

	# (c) the menu rejects a duplicate key (already bound to another rebindable
	# action) and leaves the target action unchanged, with feedback. Uses two
	# keyboard-bound actions (jump=Space, toggle_goals); mine/place are mouse.
	var _r07_jump_key := InputSettings.primary_key_event("jump")
	var _r07_goals_before := InputSettings.key_label("toggle_goals")
	_r07_pm._begin_rebind("toggle_goals")
	_r07_pm._apply_rebind(_r07_jump_key)   # jump already uses this key -> reject
	var _r07_dup_ok: bool = InputSettings.key_label("toggle_goals") == _r07_goals_before \
		and not InputSettings.is_changed("toggle_goals") \
		and InputSettings.action_using_key(_r07_jump_key, "toggle_goals") == "jump"
	harness._check("r07_duplicate_rebind_rejected", _r07_dup_ok,
		"goals %s->%s clash=%s" % [_r07_goals_before,
			InputSettings.key_label("toggle_goals"),
			InputSettings.action_using_key(_r07_jump_key, "toggle_goals")])

	# (d) full persistence round-trip: save a rebind, wipe the live map, apply the
	# DESERIALIZED saved profile (as a fresh launch would after loading the shell),
	# and confirm the saved key is live again; then reset and confirm defaults plus
	# a cleared persisted override. Isolated smoke root, never the real profile.
	AudioSettings.set_music_volume(GameState.profile, 0.3)
	InputSettings.rebind(GameState.profile, "toggle_map", _r07_ev)   # KEY_T
	GameState.save_shell()
	var _r07_saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.shell_path()))
	var _r07_saved_prof: Dictionary = _r07_saved.get("profile", {}) if _r07_saved is Dictionary else {}
	var _r07_saved_ok: bool = is_equal_approx(float(_r07_saved_prof.get("music_volume", -1.0)), 0.3) \
		and (_r07_saved_prof.get("keybinds", {}) as Dictionary).has("toggle_map")
	InputSettings.reset(GameState.profile)               # live map back to defaults
	var _r07_after_reset: bool = not InputSettings.is_changed("toggle_map")
	InputSettings.apply(_r07_saved_prof)                 # deserialized dict -> live
	var _r07_reapplied: bool = InputMap.action_has_event("toggle_map", _r07_ev) \
		and InputSettings.is_changed("toggle_map")
	# final reset + persist -> defaults live and the override cleared on disk.
	InputSettings.reset(GameState.profile)
	AudioSettings.set_music_volume(GameState.profile, 1.0)
	AudioSettings.set_sfx_volume(GameState.profile, 1.0)
	GameState.save_shell()
	var _r07_disk2 = JSON.parse_string(FileAccess.get_file_as_string(GameState.shell_path()))
	var _r07_dp2: Dictionary = _r07_disk2.get("profile", {}) if _r07_disk2 is Dictionary else {}
	var _r07_cleared: bool = not (_r07_dp2.get("keybinds", {}) as Dictionary).has("toggle_map") \
		and not InputSettings.is_changed("toggle_map")
	harness._check("r07_settings_persist_then_reset_apply",
		_r07_saved_ok and _r07_after_reset and _r07_reapplied and _r07_cleared,
		"saved=%s reset=%s reapplied=%s cleared=%s" % [str(_r07_saved_ok),
			str(_r07_after_reset), str(_r07_reapplied), str(_r07_cleared)])

	# (e) Save & Quit leaves ONLY after a successful save. Force a failure (no
	# current world -> save_current_world_state returns false) and confirm the
	# menu stays paused and open with an error rather than exiting to the shell.
	var _r07_world := GameState.current_world_id
	GameState.current_world_id = ""
	_r07_pm.open()
	root._on_pause_save_and_quit()
	var _r07_still_paused := get_tree().paused
	var _r07_still_open: bool = _r07_pm.is_open()
	GameState.current_world_id = _r07_world
	_r07_pm.resume()
	harness._check("r07_save_and_quit_requires_success",
		_r07_still_paused and _r07_still_open,
		"still_paused=%s still_open=%s" % [str(_r07_still_paused), str(_r07_still_open)])

	# (f) the Settings content fits inside a 640x360 logical viewport; only the
	# key list scrolls, so Back/Reset stay reachable at the smallest supported
	# resolution.
	_r07_pm._show_settings()
	await get_tree().process_frame
	var _r07_fit_h: float = _r07_pm.settings_content_min_height()
	_r07_pm._show_main()
	harness._check("r07_settings_fits_640x360", _r07_fit_h > 0.0 and _r07_fit_h <= 360.0,
		"content_min_height=%.1f (<=360)" % _r07_fit_h)

	# Display settings: view-zoom default/clamp/nudge + fullscreen round-trip, all on
	# an isolated profile dict so the real profile is never touched. A null camera in
	# nudge_zoom must be safe (headless has no camera).
	var _ds = GameState.DisplaySettings
	var _ds_p: Dictionary = {}
	var _ds_default: float = _ds.view_zoom(_ds_p)                 # unset -> DEFAULT_ZOOM
	var _ds_hi: float = _ds.set_view_zoom(_ds_p, 99.0)           # clamps to MAX_ZOOM
	var _ds_lo: float = _ds.set_view_zoom(_ds_p, -5.0)           # clamps to MIN_ZOOM
	_ds.set_view_zoom(_ds_p, 1.5)
	var _ds_nudged: float = _ds.nudge_zoom(_ds_p, null, 1.0)     # +1 step, null cam safe
	var _ds_fs0: bool = _ds.fullscreen(_ds_p)
	_ds.set_fullscreen(_ds_p, true)
	var _ds_fs1: bool = _ds.fullscreen(_ds_p)
	harness._check("display_settings_zoom_and_fullscreen",
		_ds_default == _ds.DEFAULT_ZOOM and _ds_hi == _ds.MAX_ZOOM and _ds_lo == _ds.MIN_ZOOM
			and absf(_ds_nudged - (1.5 + _ds.ZOOM_STEP)) < 0.0001
			and _ds_fs0 == false and _ds_fs1 == true,
		"default=%.3f hi=%.3f lo=%.3f nudged=%.3f fs=%s->%s"
			% [_ds_default, _ds_hi, _ds_lo, _ds_nudged, str(_ds_fs0), str(_ds_fs1)])

	# S-07.1b (F6 taste): the modal dim-scrim strength is a persisted, clamped
	# preference that the live HUD scrim actually consumes (default/clamp on an
	# isolated dict; live consumption via a real modal open).
	var _sc_p: Dictionary = {}
	var _sc_default: float = _ds.scrim_strength(_sc_p)          # unset -> DEFAULT_SCRIM
	var _sc_hi: float = _ds.set_scrim_strength(_sc_p, 9.0)      # clamps to MAX_SCRIM
	var _sc_lo: float = _ds.set_scrim_strength(_sc_p, -9.0)     # clamps to MIN_SCRIM
	var _sc_saved: float = _ds.scrim_strength(GameState.profile)
	_ds.set_scrim_strength(GameState.profile, 0.70)
	var _sc_was_open: bool = hud.town_panel_open()
	if not _sc_was_open:
		hud.toggle_town_panel()
	var _sc_alpha: float = hud._modal_scrim.color.a
	var _sc_visible: bool = hud._modal_scrim.visible
	if not _sc_was_open:
		hud.toggle_town_panel()
	_ds.set_scrim_strength(GameState.profile, _sc_saved)        # restore real profile
	harness._check("s07_scrim_strength_knob",
		_sc_default == _ds.DEFAULT_SCRIM and _sc_hi == _ds.MAX_SCRIM and _sc_lo == _ds.MIN_SCRIM
			and _sc_visible and absf(_sc_alpha - 0.70) < 0.001,
		"default=%.2f hi=%.2f lo=%.2f live_alpha=%.3f vis=%s" % [
			_sc_default, _sc_hi, _sc_lo, _sc_alpha, str(_sc_visible)])

	# (g) InputSettings honors the REBINDABLE contract: rebind() ignores an action
	# outside the set, and apply() ignores a stored override for one.
	InputSettings.rebind(GameState.profile, "ui_cancel", _r07_ev)   # not rebindable
	var _r07_guard_rebind: bool = not (GameState.profile.get("keybinds", {}) as Dictionary).has("ui_cancel")
	var _r07_dbg_ev := InputSettings.primary_key_event("debug_overlay")
	var _r07_dbg_key: int = _r07_dbg_ev.physical_keycode if _r07_dbg_ev != null else 0
	InputSettings.apply({"keybinds": {"debug_overlay": {"keycode": KEY_T, "physical": KEY_T}}})
	var _r07_dbg_ev2 := InputSettings.primary_key_event("debug_overlay")
	var _r07_dbg_key2: int = _r07_dbg_ev2.physical_keycode if _r07_dbg_ev2 != null else 0
	var _r07_guard_apply: bool = _r07_dbg_key == _r07_dbg_key2 and _r07_dbg_key2 != KEY_T
	harness._check("r07_rebind_apply_respect_rebindable",
		_r07_guard_rebind and _r07_guard_apply,
		"rebind_ignored=%s apply_ignored=%s" % [str(_r07_guard_rebind), str(_r07_guard_apply)])

	# (h) mouse-bound actions (mine/place) show a fixed mouse label -- never
	# "(unset)" -- and are not key-rebindable.
	var _r07_mine_lbl := InputSettings.binding_label("mine")
	var _r07_place_lbl := InputSettings.binding_label("place")
	harness._check("r07_mouse_actions_show_fixed",
		not InputSettings.is_key_rebindable("mine") and _r07_mine_lbl.contains("Mouse") \
		and _r07_mine_lbl != "(unset)" \
		and not InputSettings.is_key_rebindable("place") and _r07_place_lbl.contains("Mouse"),
		"mine=%s place=%s" % [_r07_mine_lbl, _r07_place_lbl])

	# --- R-07 slice 2: save management ---
	# (i) a shell delete is armed by a confirm, not performed on the first click:
	# after _request_delete the target still exists; _perform_pending_delete (the
	# dialog's confirm) actually removes it. Driven off-tree (popup is guarded).
	var _r07s: Control = (load("res://scripts/shell/shell_ui.gd") as GDScript).new()
	_r07s._build_base()
	var _r07_wid: String = GameState.create_world({})
	_r07s._request_delete("world", _r07_wid, "SmokeDelete")
	var _r07_armed: bool = _r07_wid != "" \
		and not GameState.load_world_file(_r07_wid).is_empty() \
		and str(_r07s._pending_delete.get("id", "")) == _r07_wid
	_r07s._perform_pending_delete()
	var _r07_confirmed: bool = GameState.load_world_file(_r07_wid).is_empty()
	_r07s.free()
	harness._check("r07_shell_delete_requires_confirm", _r07_armed and _r07_confirmed,
		"armed=%s confirmed_deleted=%s" % [str(_r07_armed), str(_r07_confirmed)])

	# (j) in-game Restore reloads the last save (visible recovery, no hidden F9)
	# and is gated by a confirm: requesting it does not reload; confirming does,
	# reverting live state to the save and closing the menu.
	_r07_pm.open()
	root.save_manager.save_game()
	var _r07_day_saved: int = root.day_count
	root.day_count = _r07_day_saved + 7               # mutate live state
	_r07_pm._request_restore()                         # arms the confirm dialog only
	var _r07_gated: bool = root.day_count == _r07_day_saved + 7
	_r07_pm._confirm.hide()
	root._on_pause_restore()                            # dialog confirmed -> reload
	var _r07_restored: bool = root.day_count == _r07_day_saved and not _r07_pm.is_open()
	harness._check("r07_pause_restore_reloads_save", _r07_gated and _r07_restored,
		"gated=%s restored=%s day=%d" % [str(_r07_gated), str(_r07_restored),
			root.day_count])

	# --- R-07 slice 3: build preview + reasoned invalid-placement feedback ---
	# (k) place_reason is the single validity authority (valid -> ""), and a failed
	# try_place emits the reason (no silent fails). Mutations here are wiped by the
	# fq09w_world_restored load_game that follows this block.
	player.inventory.add("wood", 5)
	var _r07_pcell: Vector2i = world.cell_of(player.global_position)
	var _r07_valid: Vector2i = Vector2i(99999, 99999)
	for _r07_dy in range(-3, 2):
		for _r07_dx in range(-3, 4):
			var _r07_c: Vector2i = _r07_pcell + Vector2i(_r07_dx, _r07_dy)
			var _r07_rc: String = player.place_reason(_r07_c, "wood")
			if _r07_rc == "":
				_r07_valid = _r07_c
				break
		if _r07_valid.x != 99999:
			break
	var _r07_valid_ok: bool = _r07_valid.x != 99999
	# reach is reported before occupancy: a far cell reads out-of-reach.
	var _r07_far: String = player.place_reason(_r07_pcell + Vector2i(60, 0), "wood")
	# an AIR cell overlapping the body reports the standing-there reason for a
	# solid block. Find a body-overlapping cell and clear it to air first (the
	# feet cell is solid); the break is reverted by the fq09w reload below.
	var _r07_bodyr: String = "(none)"
	for _r07_by in range(-3, 3):
		for _r07_bx in range(-2, 3):
			var _r07_bc: Vector2i = _r07_pcell + Vector2i(_r07_bx, _r07_by)
			if player._cell_overlaps_body(_r07_bc):
				world.break_block(_r07_bc)   # guarantee air at a body cell
				_r07_bodyr = player.place_reason(_r07_bc, "wood")
				break
		if _r07_bodyr != "(none)":
			break
	# with zero stock the missing-block reason wins.
	var _r07_had: int = player.inventory.count("wood")
	while player.inventory.count("wood") > 0:
		player.inventory.remove("wood")
	var _r07_nostockr: String = player.place_reason(_r07_valid, "wood")
	player.inventory.add("wood", _r07_had)
	# a failed try_place emits the reason to player_event.
	var _r07_evt := {"m": ""}
	var _r07_cb := func(msg: String): _r07_evt["m"] = msg
	player.player_event.connect(_r07_cb)
	var _r07_placed: bool = player.try_place(_r07_valid, "wood") if _r07_valid_ok else false
	var _r07_occ: String = player.place_reason(_r07_valid, "wood")   # now occupied
	player.try_place(_r07_pcell + Vector2i(60, 0), "wood")           # invalid -> emits
	var _r07_fb: String = str(_r07_evt["m"])
	player.player_event.disconnect(_r07_cb)
	harness._check("r07_place_reason_feedback",
		_r07_valid_ok and _r07_placed and _r07_far.contains("reach") \
		and _r07_bodyr.contains("standing") and _r07_nostockr.begins_with("No ") \
		and _r07_occ.contains("already") and _r07_fb.contains("reach"),
		"valid=%s placed=%s far=[%s] body=[%s] nostock=[%s] occ=[%s] fb=[%s]" % [
			str(_r07_valid_ok), str(_r07_placed), _r07_far, _r07_bodyr,
			_r07_nostockr, _r07_occ, _r07_fb])

	# (l) the build preview shows only for a placeable selected item (a ghost for
	# a held block, nothing for a tool/consumable).
	var _r07_hb: Array = player.hotbar.duplicate()
	var _r07_slot: int = player.selected_slot
	player.hotbar.clear()
	player.hotbar.append("wood")
	player.selected_slot = 0
	var _r07_prev_wood: String = root._build_preview.active_item()
	player.hotbar.clear()
	player.hotbar.append("food")
	player.selected_slot = 0
	var _r07_prev_food: String = root._build_preview.active_item()
	player.hotbar.assign(_r07_hb)
	player.selected_slot = _r07_slot
	harness._check("r07_build_preview_active_for_placeable",
		_r07_prev_wood == "wood" and _r07_prev_food == "",
		"wood=[%s] food=[%s]" % [_r07_prev_wood, _r07_prev_food])

	# --- R-07 slice 4: unified crafting panel + Town Hall trim ---
	# (m) the panel routes by station: a hand recipe spends the player's inventory;
	# building a station spends the Town Hall stockpile. (Reverted by the fq09w
	# reload below.)
	var _cp = root._craft_panel
	player.inventory.add("wood", 2)
	player.inventory.add("stone", 2)
	var _cm_torch0: int = player.inventory.count("torch")
	root._on_craft_panel_craft("craft_torch")   # hand: 1 wood + 1 stone -> 3 torch
	var _cm_hand: bool = player.inventory.count("torch") >= _cm_torch0 + 3
	hall.stockpile["wood"] = int(hall.stockpile.get("wood", 0)) + 12
	hall.stockpile["stone"] = int(hall.stockpile.get("stone", 0)) + 6
	hall.stations_built["workbench"] = false   # earlier fq11 tests may have built it
	root._on_craft_panel_build("workbench")
	var _cm_build: bool = hall.station_built("workbench")
	# a Town Hall gear recipe routes to its special forge method (empty-output
	# craft_axe would do nothing via craft_from_stockpile), setting the tool tier.
	hall.stockpile["wood"] = int(hall.stockpile.get("wood", 0)) + 4
	hall.stockpile["stone"] = int(hall.stockpile.get("stone", 0)) + 2
	player.axe_tier = 0
	root._on_craft_panel_craft("craft_axe")
	var _cm_axe: bool = player.axe_tier >= 1
	harness._check("r07_craft_panel_routes_hand_town_and_build",
		_cp != null and _cm_hand and _cm_build and _cm_axe,
		"hand=%s build=%s axe=%s" % [str(_cm_hand), str(_cm_build), str(_cm_axe)])

	# (n) have/need gating: an unaffordable recipe reports a reason, and the input
	# source is correct -- inventory for hand, stockpile for stations.
	var _cn_short: String = _cp._short_reason("hand", {"wood": 99999})
	var _cn_inv: int = _cp._stock_of("hand", "wood")
	var _cn_stock: int = _cp._stock_of("furnace", "coal")
	harness._check("r07_craft_panel_gating_and_source",
		_cn_short.begins_with("Need more") \
		and _cn_inv == int(player.inventory.count("wood")) \
		and _cn_stock == int(hall.stockpile.get("coal", 0)),
		"short=[%s] inv=%d stock=%d" % [_cn_short, _cn_inv, _cn_stock])

	# (o) crafting/building ownership has transferred to CraftPanel: the Town Hall
	# panel's forge/lantern/station signals are gone (only Repair remains).
	harness._check("r07_town_panel_crafting_removed",
		root._craft_panel != null and hud.has_signal("repair_requested") \
		and not hud.has_signal("forge_requested") \
		and not hud.has_signal("lantern_requested") \
		and not hud.has_signal("build_station_requested") \
		and not hud.has_signal("craft_station_requested"),
		"craftpanel=%s repair_sig=%s forge_sig=%s build_sig=%s" % [
			str(root._craft_panel != null), str(hud.has_signal("repair_requested")),
			str(hud.has_signal("forge_requested")),
			str(hud.has_signal("build_station_requested"))])

	# (p) C-key entry point: toggle opens/closes, and while open the input-capture
	# flag is set so player gameplay (mine/place) is frozen -- no click-through.
	# (close() is what both the C toggle and Esc invoke.)
	var _cp2 = root._craft_panel
	_cp2.close()
	var _cm_base: bool = not _cp2.is_open() and not GameState.craft_panel_open
	_cp2.toggle()
	var _cm_open: bool = _cp2.is_open() and GameState.craft_panel_open
	_cp2.close()
	var _cm_reclosed: bool = not _cp2.is_open() and not GameState.craft_panel_open
	harness._check("r07_craft_panel_toggle_and_modal",
		_cm_base and _cm_open and _cm_reclosed,
		"base=%s open=%s reclosed=%s" % [str(_cm_base), str(_cm_open), str(_cm_reclosed)])

	# (q) icon contract: every visible craft row resolves to an item-specific icon
	# id (item_icon is always non-null, so an empty id would be a meaningless
	# shared swatch), OR carries an explicit `icon` key = a documented no-icon
	# state. The empty-output forge recipes (craft_axe/sword/armor_set) resolve via
	# `icon` metadata to REAL gear art (visual_texture, not a swatch fallback).
	var _ci_ok := true
	var _ci_bad := ""
	for _ci_st in ["hand", "town_hall", "workbench", "furnace", "anvil"]:
		for _ci_rec: Dictionary in BlockRegistry.recipes_for_station(_ci_st):
			var _ci_id: String = _cp2.recipe_icon_id(_ci_rec)
			if _ci_id == "" and not _ci_rec.has("icon"):
				_ci_ok = false
				_ci_bad += str(_ci_rec.get("recipe_id", "")) + " "
	var _ci_axe: bool = _cp2.recipe_icon_id(BlockRegistry.get_recipe("craft_axe")) == "axe" \
		and BlockRegistry.visual_texture("items", "axe") != null
	var _ci_sword: bool = _cp2.recipe_icon_id(BlockRegistry.get_recipe("craft_sword")) == "sword" \
		and BlockRegistry.visual_texture("items", "sword") != null
	var _ci_armor: bool = _cp2.recipe_icon_id(BlockRegistry.get_recipe("craft_armor_set")) == "armor" \
		and BlockRegistry.visual_texture("items", "armor") != null
	harness._check("r07_craft_rows_icon_contract",
		_ci_ok and _ci_axe and _ci_sword and _ci_armor,
		"ok=%s bad=[%s] axe=%s sword=%s armor=%s" % [str(_ci_ok), _ci_bad,
			str(_ci_axe), str(_ci_sword), str(_ci_armor)])

	# --- Slice 4.1: crafting panel LAYOUT CONTRACT at both target sizes ---
	# The redesigned panel must stay fully contained + usable at a full 1280x720
	# AND a minimum 640x360. This project stretches canvas_items/expand, so the
	# LOGICAL viewport (the space the UI lays out in, and what _refit + every
	# get_global_rect() read) is the design canvas, NOT the OS window pixels:
	# resizing the window merely rescales a fixed 1280x720 canvas, so a 640x360
	# window would test nothing new. The faithful lever for the min-resolution
	# case is content_scale_size, which genuinely shrinks the logical viewport to
	# 640x360 and reflows the panel into it. The detail pane is a single scroll
	# region above a PINNED action row, so the Craft/Build button (and the panel
	# footer) can never be pushed off-screen no matter how tall the content. Fully
	# self-contained: content_scale_size, inventory, built stations, panel open
	# state, and the live station/recipe selection are all captured and restored.
	var _cl_prev: Vector2i = get_window().content_scale_size
	var _cl_inv0: Dictionary = player.inventory.to_dict()
	var _cp3 = root._craft_panel
	var _cl_open0: bool = _cp3.is_open()
	var _cl_built0: Dictionary = hall.stations_built.duplicate(true)
	var _cl_stn0: String = _cp3.selected_station()
	var _cl_rid0: String = _cp3.selected_recipe_id()
	hall.stations_built["workbench"] = true    # so furnace/anvil prereqs read met
	hall.stations_built["furnace"] = false     # keep furnace locked for the build card
	player.inventory.from_dict({"wood": 6, "stone": 6})   # torch/platform/door OK; seeds short
	player.inventory_changed.emit()
	_cp3._selected_station = "hand"
	_cp3._selected_recipe_id = "craft_torch"
	_cp3.open()
	var _cl_fail := ""
	for _cl_sz: Vector2i in [Vector2i(1280, 720), Vector2i(640, 360)]:
		get_window().content_scale_size = _cl_sz
		await get_tree().process_frame
		await get_tree().process_frame
		_cp3._refit()
		_cp3.refresh()
		await get_tree().process_frame
		var _vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		# (0) the LOGICAL viewport actually REACHED the intended size (narrow
		# tolerance); otherwise "contained" is trivially true on a canvas that
		# never shrank, and the 640x360 case would prove nothing.
		if absf(_vp.size.x - float(_cl_sz.x)) > 2.0 or absf(_vp.size.y - float(_cl_sz.y)) > 2.0:
			_cl_fail += "vp_unreached@%s(got %dx%d) " % [_cl_sz, int(_vp.size.x), int(_vp.size.y)]
		# (1) entire outer panel (incl. its bottom border) within the viewport;
		# detail pane + station selector within the panel.
		if not _vp.grow(1.0).encloses(_cp3.panel_rect()):
			_cl_fail += "panel_oob@%s " % _cl_sz
		if not _cp3.panel_rect().grow(1.0).encloses(_cp3.detail_panel_rect()):
			_cl_fail += "detail_oob@%s " % _cl_sz
		if not _cp3.panel_rect().grow(1.0).encloses(_cp3.station_bar_rect()):
			_cl_fail += "stations_oob@%s " % _cl_sz
		# (2) the footer Close button is visible (non-degenerate) and within view.
		var _cbr: Rect2 = _cp3.close_button_rect()
		if _cbr.size.x < 1.0 or _cbr.size.y < 1.0 or not _vp.grow(1.0).encloses(_cbr):
			_cl_fail += "close_oob@%s " % _cl_sz
		# (3) Craft action VISIBLE within the viewport (a real on-screen rect, not
		# a clipped ghost) and correctly ENABLED (torch is affordable here).
		var _ab: Button = _cp3.action_button()
		if _ab == null or not _ab.is_visible_in_tree() \
				or not _vp.grow(1.0).encloses(_ab.get_global_rect()):
			_cl_fail += "action_oob@%s " % _cl_sz
		elif _ab.disabled:
			_cl_fail += "action_wrongdisabled@%s " % _cl_sz
		# (4) the pinned action row is a SIBLING BELOW the scroll, never inside it:
		# it starts at/after the scroll's bottom and the scroll never encloses it.
		var _dsr: Rect2 = _cp3.detail_scroll_rect()
		var _dar: Rect2 = _cp3.detail_action_rect()
		if _dsr.grow(1.0).encloses(_dar) or _dar.position.y < _dsr.end.y - 2.0:
			_cl_fail += "action_in_scroll@%s " % _cl_sz
		# (5) the detail pane has EXACTLY ONE scroll region (the outer authority);
		# a second nested scroll would fight it and could hide the action.
		if _cp3.detail_scroll_count() != 1:
			_cl_fail += "detail_scrolls=%d@%s " % [_cp3.detail_scroll_count(), _cl_sz]
		# (6) when the detail content is taller than its scroll viewport, the outer
		# scroll actually has range to reach the overflow (never a dead clip).
		if _cp3.detail_content_rect().size.y > _dsr.size.y + 2.0 and not _cp3.detail_scroll_has_range():
			_cl_fail += "overflow_no_range@%s " % _cl_sz
		# (7) compact status policy: every tile face is exactly Ready/Missing/Locked.
		for _st: String in _cp3.tile_status_texts():
			if _st not in ["Ready", "Missing", "Locked"]:
				_cl_fail += "status[%s]@%s " % [_st, _cl_sz]
		# (8) tiles clip their own children, never bleed horizontally out of the
		# grid viewport (vertical overflow is clipped by the scroll), never overlap.
		if not _cp3.grid_clips():
			_cl_fail += "grid_noclip@%s " % _cl_sz
		var _tiles: Array = _cp3.recipe_tiles()
		var _gv: Rect2 = _cp3.grid_viewport_rect()
		for _t in _tiles:
			var _tb := _t as Button
			if not _tb.clip_contents:
				_cl_fail += "tile_noclip@%s " % _cl_sz
			var _tr: Rect2 = _tb.get_global_rect()
			if _tr.position.x < _gv.position.x - 2.0 or _tr.end.x > _gv.end.x + 2.0:
				_cl_fail += "tile_hoob@%s " % _cl_sz
		for _i in range(_tiles.size()):
			for _j in range(_i + 1, _tiles.size()):
				if (_tiles[_i] as Button).get_global_rect().grow(-1.0).intersects(
						(_tiles[_j] as Button).get_global_rect().grow(-1.0)):
					_cl_fail += "overlap@%s " % _cl_sz
	# a short recipe correctly DISABLES the action (crop_seeds needs food we lack).
	_cp3._selected_recipe_id = "craft_seeds"
	_cp3.refresh()
	await get_tree().process_frame
	var _ab2: Button = _cp3.action_button()
	if _ab2 == null or not _ab2.disabled:
		_cl_fail += "short_action_not_disabled "
	# worst case at 640x360: a LOCKED station's Build card is the tallest content;
	# its Build action must stay reachable (on-screen + pinned outside the scroll),
	# and if the card overflows, the single scroll must have range to reach it.
	get_window().content_scale_size = Vector2i(640, 360)
	await get_tree().process_frame
	await get_tree().process_frame
	_cp3._refit()
	_cp3._selected_station = "furnace"
	_cp3.refresh()
	await get_tree().process_frame
	var _vp2 := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var _bb: Button = _cp3.action_button()
	if _bb == null or not _bb.is_visible_in_tree() or not _vp2.grow(1.0).encloses(_bb.get_global_rect()):
		_cl_fail += "build_action_oob "
	if _cp3.detail_scroll_rect().grow(1.0).encloses(_cp3.detail_action_rect()) \
			or _cp3.detail_action_rect().position.y < _cp3.detail_scroll_rect().end.y - 2.0:
		_cl_fail += "build_action_in_scroll "
	if _cp3.detail_content_rect().size.y > _cp3.detail_scroll_rect().size.y + 2.0 \
			and not _cp3.detail_scroll_has_range():
		_cl_fail += "build_overflow_no_range "
	# live resize + restore preserves the selected station/recipe.
	_cp3._selected_station = "hand"
	_cp3._selected_recipe_id = "craft_wood_platform"
	_cp3.refresh()
	get_window().content_scale_size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	_cp3._refit()
	_cp3.refresh()
	await get_tree().process_frame
	if _cp3.selected_station() != "hand" or _cp3.selected_recipe_id() != "craft_wood_platform":
		_cl_fail += "selection_lost "
	harness._check("r07_craft_panel_layout_contract", _cl_fail == "",
		("issues: " + _cl_fail.strip_edges()) if _cl_fail != "" else "contained + usable at 1280x720 and 640x360")
	# restore ALL captured harness state: built stations, inventory, logical
	# viewport (content_scale_size), selection, and panel open state; then settle.
	_cp3.close()
	hall.stations_built = _cl_built0
	player.inventory.from_dict(_cl_inv0)
	player.inventory_changed.emit()
	get_window().content_scale_size = _cl_prev
	await get_tree().process_frame
	await get_tree().process_frame
	_cp3._selected_station = _cl_stn0
	_cp3._selected_recipe_id = _cl_rid0
	if _cl_open0:
		_cp3.open()
		_cp3._refit()
		_cp3.refresh()
	await get_tree().process_frame

	# --- Slice 4.2: Craft joins the centered command tray (Goal | Craft | Map |
	# Edit). Prove the docked chip roster, that the chip and the C shortcut share
	# ONE toggle path (identical open/close), mutual exclusion with the other
	# panels, that the pressed state tracks every close route (chip, C, Escape,
	# Close), the four-button tray geometry/centering, and that the six-button
	# floating fallback is wide enough. Self-contained: every panel/craft state
	# touched is captured and restored. ---
	var _cc = root._craft_panel
	var _cc_fail := ""
	# Capture state to restore.
	var _cc_craft0: bool = _cc.is_open()
	var _cc_inv0: bool = hud.inventory_panel_open()
	var _cc_skill0: bool = hud.skill_panel_open()
	var _cc_char0: bool = hud.character_panel_open()
	var _cc_town0: bool = hud.town_panel_open()
	var _cc_docked: bool = hud._left_wing != null and hud._right_wing != null
	# The C-key route is fed through game_root._unhandled_input, which early-returns
	# under edit/workzone mode; force them off for the test and restore afterwards.
	var _cc_edit0: bool = GameState.hud_edit_mode
	var _cc_wz0: bool = GameState.workzone_mode
	GameState.hud_edit_mode = false
	GameState.workzone_mode = false
	var _craft_btn: Button = hud._command_toggles["Craft"] as Button

	# (a) docked roster: exactly Goal / Craft / Map / Edit; Crest + Events absent;
	# the Craft chip carries the discoverable tooltip. (Only asserted when docked —
	# the floating fallback legitimately keeps Crest/Events.)
	var _cc_labels: Array = hud.command_toggle_labels()
	if "Craft" not in _cc_labels:
		_cc_fail += "no_craft_chip "
	if hud.command_toggle_tooltip("Craft") != "Crafting (C)":
		_cc_fail += "craft_tooltip[%s] " % hud.command_toggle_tooltip("Craft")
	if _cc_docked:
		if _cc_labels != ["Goal", "Craft", "Map", "Edit"]:
			_cc_fail += "docked_labels=%s " % str(_cc_labels)
		if "Crest" in _cc_labels or "Events" in _cc_labels:
			_cc_fail += "crest_or_events_docked "

	# (b) the CHIP and the C KEY share one path. Prove it by driving the REAL
	# controls — flip the actual Craft toggle button (exercising its `toggled`
	# connection) and feed a real "craft" InputEventAction through game_root's
	# gameplay input handler — and require each to open AND close the panel while
	# the chip's pressed state follows.
	if _cc.is_open():
		_cc.close()
		await get_tree().process_frame
	_craft_btn.button_pressed = true                   # real button -> open
	await get_tree().process_frame
	if not _cc.is_open() or not hud.command_toggle_pressed("Craft") or not GameState.craft_panel_open:
		_cc_fail += "btn_open_failed "
	_craft_btn.button_pressed = false                  # real button -> close
	await get_tree().process_frame
	if _cc.is_open() or hud.command_toggle_pressed("Craft"):
		_cc_fail += "btn_close_failed "
	_drive_craft_action(root)                          # real C action -> open
	await get_tree().process_frame
	if not _cc.is_open() or not hud.command_toggle_pressed("Craft"):
		_cc_fail += "c_open_failed "
	_drive_craft_action(root)                          # real C action -> close
	await get_tree().process_frame
	if _cc.is_open() or hud.command_toggle_pressed("Craft"):
		_cc_fail += "c_close_failed "

	# (c) mutual exclusion, proven INDEPENDENTLY for each panel (they also close one
	# another, so a sequential open would leave only the last one open). For every
	# panel: close Craft + all modals, open just that panel, open Craft via the REAL
	# button, and assert THAT panel closed while Craft opened.
	var _excl_panels := [
		["Inventory", Callable(hud, "inventory_panel_open"), Callable(hud, "toggle_inventory_panel")],
		["Character", Callable(hud, "character_panel_open"), Callable(hud, "toggle_character_panel")],
		["Skills", Callable(hud, "skill_panel_open"), Callable(hud, "toggle_skill_panel")],
		["TownHall", Callable(hud, "town_panel_open"), Callable(hud, "toggle_town_panel")],
	]
	for _ep in _excl_panels:
		var _ep_name: String = _ep[0]
		var _ep_open: Callable = _ep[1]
		var _ep_toggle: Callable = _ep[2]
		if _cc.is_open():
			_cc.close()
		if hud.inventory_panel_open():
			hud.toggle_inventory_panel()
		if hud.character_panel_open():
			hud.toggle_character_panel()
		if hud.skill_panel_open():
			hud.toggle_skill_panel()
		if hud.town_panel_open():
			hud.toggle_town_panel()
		await get_tree().process_frame
		_ep_toggle.call()                              # open just this panel
		await get_tree().process_frame
		if not bool(_ep_open.call()):
			_cc_fail += "excl_%s_not_open " % _ep_name
		_craft_btn.button_pressed = true               # open Craft via the real button
		await get_tree().process_frame
		if not _cc.is_open() or bool(_ep_open.call()):
			_cc_fail += "excl_%s_transition[craft=%s panel=%s] " % [_ep_name,
				str(_cc.is_open()), str(bool(_ep_open.call()))]
		_craft_btn.button_pressed = false              # close Craft for the next case
		await get_tree().process_frame

	# (d) the chip pressed state tracks EVERY close route: the panel Close button,
	# Escape, the C action, and the chip itself. Each opens via the real button/C.
	if _cc.is_open():
		_cc.close()
		await get_tree().process_frame
	_craft_btn.button_pressed = true                   # open (button)
	await get_tree().process_frame
	if not hud.command_toggle_pressed("Craft"):
		_cc_fail += "pressed_missing_after_open "
	_cc._close_btn.pressed.emit()                      # close via the Close button
	await get_tree().process_frame
	if _cc.is_open() or hud.command_toggle_pressed("Craft"):
		_cc_fail += "close_btn_untracked "
	_craft_btn.button_pressed = true                   # reopen (button)
	await get_tree().process_frame
	var _cc_esc := InputEventAction.new()
	_cc_esc.action = "ui_cancel"
	_cc_esc.pressed = true
	_cc._input(_cc_esc)                                # close via Escape
	await get_tree().process_frame
	if _cc.is_open() or hud.command_toggle_pressed("Craft"):
		_cc_fail += "escape_untracked "
	_drive_craft_action(root)                          # reopen (C action)
	await get_tree().process_frame
	_drive_craft_action(root)                          # close via C action
	await get_tree().process_frame
	if _cc.is_open() or hud.command_toggle_pressed("Craft"):
		_cc_fail += "c_untracked "
	_craft_btn.button_pressed = true                   # reopen (button)
	await get_tree().process_frame
	_craft_btn.button_pressed = false                  # close via the chip itself
	await get_tree().process_frame
	if _cc.is_open() or hud.command_toggle_pressed("Craft"):
		_cc_fail += "chip_untracked "

	# (e) four-button tray geometry: each 58x24, all contained + centered, union
	# and tray centers agree within 1px, gaps balanced + compact, no overlap with
	# hotbar / orbs / wings.
	if _cc_docked:
		var _tray: Rect2 = hud.command_tray_rect()
		var _vpc := get_viewport().get_visible_rect().size
		var _rects: Array[Rect2] = []
		for _lbl in ["Goal", "Craft", "Map", "Edit"]:
			var _br: Rect2 = hud.command_button_rect(_lbl)
			_rects.append(_br)
			if absf(_br.size.x - 58.0) > 1.0 or absf(_br.size.y - 24.0) > 1.0:
				_cc_fail += "btn_size[%s=%s] " % [_lbl, _br.size]
			if not _tray.grow(2.0).encloses(_br):
				_cc_fail += "btn_oob[%s] " % _lbl
		if not Rect2(Vector2.ZERO, _vpc).grow(1.0).encloses(_tray):
			_cc_fail += "tray_oob "
		# centered on the viewport (native 640) and union-vs-tray agreement.
		var _tray_cx: float = _tray.position.x + _tray.size.x * 0.5
		if absf(_tray_cx - _vpc.x * 0.5) > 2.0:
			_cc_fail += "tray_offcenter[%.1f] " % _tray_cx
		var _union_l: float = _rects[0].position.x
		var _union_r: float = _rects[0].end.x
		for _r in _rects:
			_union_l = minf(_union_l, _r.position.x)
			_union_r = maxf(_union_r, _r.end.x)
		if absf((_union_l + _union_r) * 0.5 - _tray_cx) > 1.0:
			_cc_fail += "union_vs_tray[%.1f/%.1f] " % [(_union_l + _union_r) * 0.5, _tray_cx]
		# gaps between consecutive buttons: balanced (<=1px spread) and compact (~4px).
		var _gaps: Array[float] = []
		for _gi in range(3):
			_gaps.append(_rects[_gi + 1].position.x - _rects[_gi].end.x)
		var _gmin: float = _gaps[0]
		var _gmax: float = _gaps[0]
		for _g in _gaps:
			_gmin = minf(_gmin, _g)
			_gmax = maxf(_gmax, _g)
		if _gmax - _gmin > 1.0 or _gmax > 6.0 or _gmin < 2.0:
			_cc_fail += "gaps=%s " % str(_gaps)
		# no overlap with the hotbar slots, orbs, or wings.
		for _nb in hud.command_tray_neighbor_rects():
			if _tray.grow(-1.0).intersects((_nb as Rect2).grow(-1.0)):
				_cc_fail += "tray_overlap "
				break

	# (f) reset/restore uses the new authoritative rectangle (504,132,272,44), not
	# the stale [458,132,364,44]; the tray stays centered afterwards.
	var _kit_layout: Dictionary = hud._load_hud_kit_layout()
	var _auth_rect: Rect2 = hud._json_rect(_kit_layout.get("module_toolbar_rect"))
	if _auth_rect != Rect2(Vector2(504.0, 132.0), Vector2(272.0, 44.0)):
		_cc_fail += "authority_rect=%s " % str(_auth_rect)
	if _cc_docked:
		hud._restore_native_module_toolbar_rect()
		await get_tree().process_frame
		var _tray2: Rect2 = hud.command_tray_rect()
		var _vpc2 := get_viewport().get_visible_rect().size
		if absf(_tray2.position.x + _tray2.size.x * 0.5 - _vpc2.x * 0.5) > 2.0:
			_cc_fail += "restore_offcenter "

	# (g) the six-button floating fallback is wide enough to contain all six chips
	# (union = 6*54 + 5*4) with room for the frame — never a clipped width.
	var _fb_w: float = hud.fallback_command_center_width(6)
	if _fb_w < 6.0 * 54.0 + 5.0 * 4.0:
		_cc_fail += "fallback_clips6[%.1f] " % _fb_w

	harness._check("r07_craft_command_chip", _cc_fail == "",
		("issues: " + _cc_fail.strip_edges()) if _cc_fail != "" \
			else "Craft chip: docked roster, shared C/chip toggle, exclusion, all close paths tracked, tray centered, fallback fits 6")

	# restore panel/craft state touched above.
	if _cc.is_open():
		_cc.close()
	if hud.inventory_panel_open() != _cc_inv0:
		hud.toggle_inventory_panel()
	if hud.skill_panel_open() != _cc_skill0:
		hud.toggle_skill_panel()
	if hud.character_panel_open() != _cc_char0:
		hud.toggle_character_panel()
	if hud.town_panel_open() != _cc_town0:
		hud.toggle_town_panel()
	if _cc_craft0:
		_cc.open()
	GameState.hud_edit_mode = _cc_edit0
	GameState.workzone_mode = _cc_wz0
	await get_tree().process_frame

	# --- 2026-08-18: the mouse wheel must not re-zoom the world while a scrolling
	# menu is open (HUD editor / crafting / any inventory-class modal); it zooms only
	# in free play. Drive game_root._handle_view_input with a synthetic wheel event
	# under each menu flag, then with all closed. The camera zoom is derived from
	# GameState.profile["view_zoom"] (what _zoom_by actually mutates), so assert on
	# that — and force a mid-range baseline each time so a step can't clamp and the
	# check never depends on a value persisted from an earlier run. ---
	var _wz_ok := true
	var _wz_prof: Dictionary = GameState.profile
	var _wz_saved0: float = float(_wz_prof.get("view_zoom", 1.25))
	var _wz_edit0: bool = GameState.hud_edit_mode
	var _wz_craft0: bool = GameState.craft_panel_open
	var _wz_modal0: bool = GameState.modal_panel_open
	var _wz_evt := InputEventMouseButton.new()
	_wz_evt.button_index = MOUSE_BUTTON_WHEEL_UP
	_wz_evt.pressed = true
	for _wz_flag in ["hud_edit_mode", "craft_panel_open", "modal_panel_open"]:
		GameState.hud_edit_mode = false
		GameState.craft_panel_open = false
		GameState.modal_panel_open = false
		GameState.set(_wz_flag, true)
		_wz_prof["view_zoom"] = 2.0
		var _wz_handled: bool = root._handle_view_input(_wz_evt)
		# menu open: the wheel is swallowed (returns true) and view_zoom is untouched
		if not (_wz_handled and is_equal_approx(float(_wz_prof.get("view_zoom", 0.0)), 2.0)):
			_wz_ok = false
	# every menu closed: the same wheel event DOES zoom (one step up from 2.0, no clamp)
	GameState.hud_edit_mode = false
	GameState.craft_panel_open = false
	GameState.modal_panel_open = false
	_wz_prof["view_zoom"] = 2.0
	var _wz_free: bool = root._handle_view_input(_wz_evt)
	if not (_wz_free and float(_wz_prof.get("view_zoom", 0.0)) > 2.0):
		_wz_ok = false
	GameState.hud_edit_mode = _wz_edit0
	GameState.craft_panel_open = _wz_craft0
	GameState.modal_panel_open = _wz_modal0
	_wz_prof["view_zoom"] = _wz_saved0
	harness._check("s07_wheel_zoom_swallowed_in_menus", _wz_ok,
		"wheel swallowed under each menu flag + still zooms with all menus closed")

	# --- Above-ground jitter fix (2026-08-21) ---
	# The player moves in _physics_process; without 2D physics interpolation the body
	# only advanced at the physics tick while the smoothed Camera2D re-followed every
	# RENDER frame, so the character shimmered against the world (worst on the vertical
	# velocity swings of a jump). The systemic fix is engine-level physics interpolation,
	# which the whole presentation now leans on — so guard the invariant: it must stay ON,
	# the camera's position smoothing (the smooth follow the fix preserves rather than
	# disabling) must stay ON, and the player must expose an interpolation-safe teleport()
	# that repositions + clears velocity without the visible cross-world sweep a bare
	# `global_position =` now causes. (The interpolation snapshot reset is a visual-only op
	# that can't be sampled headless, but the reposition contract can, and a regression
	# that flips the setting off is caught.)
	var _pi_on: bool = bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))
	var _pi_cam: Camera2D = player.get_node_or_null("Camera2D")
	var _pi_smooth: bool = _pi_cam != null and _pi_cam.position_smoothing_enabled
	# The load-bearing pairing: with interpolation ON the camera MUST smooth on the
	# physics clock (CAMERA2D_PROCESS_PHYSICS = 0), else its smoothing runs on the render
	# clock over non-interpolated positions while the player renders interpolated — they
	# diverge and the character jitters, worst while jumping. Default IDLE is the bug.
	var _pi_cam_physics: bool = _pi_cam != null \
		and _pi_cam.process_callback == Camera2D.CAMERA2D_PROCESS_PHYSICS
	var _pi_has_teleport: bool = player.has_method("teleport")
	var _pi_prev_pos: Vector2 = player.global_position
	var _pi_prev_vel: Vector2 = player.velocity
	player.velocity = Vector2(123.0, -45.0)
	var _pi_dest: Vector2 = _pi_prev_pos + Vector2(200.0, -80.0)
	player.teleport(_pi_dest)
	# The fog-veil rim reads the INTERPOLATED render position; after a teleport its mirror
	# must be collapsed onto the destination (no cross-world sweep of the sight circle).
	var _pi_render_ok: bool = player.has_method("render_global_position") \
		and (player.render_global_position() as Vector2).is_equal_approx(_pi_dest)
	var _pi_moved: bool = player.global_position.is_equal_approx(_pi_dest) \
		and player.velocity == Vector2.ZERO
	player.teleport(_pi_prev_pos)        # restore prior position for later modules
	player.velocity = _pi_prev_vel
	harness._check("jitter_physics_interpolation_and_safe_teleport",
		_pi_on and _pi_smooth and _pi_cam_physics and _pi_has_teleport and _pi_moved \
			and _pi_render_ok,
		"interp=%s smoothing=%s cam_physics=%s teleport=%s moved=%s render=%s" % [str(_pi_on),
			str(_pi_smooth), str(_pi_cam_physics), str(_pi_has_teleport), str(_pi_moved),
			str(_pi_render_ok)])


## Slice 4.2: feed a real "craft" action through the SAME gameplay input handler
## the C key reaches (game_root._unhandled_input), proving the input mapping — not
## just the shared method — routes to the crafting toggle.
func _drive_craft_action(root) -> void:
	var ev := InputEventAction.new()
	ev.action = "craft"
	ev.pressed = true
	root._unhandled_input(ev)
