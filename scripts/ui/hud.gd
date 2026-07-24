extends CanvasLayer
## HUD: health, C/L/R bars, status labels, day/night, hotbar/inventory,
## event log, Town Hall panel, and an F3 debug overlay. Built in code to
## keep scene files minimal.

signal deposit_requested
signal repair_requested
signal contracts_requested
signal subject_job_cycle_requested(id: String)   # R-08 slice 2: settler job assignment

## Low-health fraction mirrors player._low_health_fraction (data-driven
## default 0.25); the HUD does not read player state directly so it keeps a
## small local const matching the documented default for the tint threshold.
const LOW_HEALTH_TINT_FRACTION := 0.25
const HUD_VISUAL_THEME_SEPARATOR := "__"
const HUD_VISUAL_THEME_MAX_LENGTH := 48

var player: CharacterBody2D
var town_hall: Node2D
var _hud_visual_theme := ""

var _health_label: Label
var _health_bar: ProgressBar
var _attunement_label: Label
var _attunement_bar: ProgressBar
var _low_health_active := false
var _bars: Dictionary = {}       # "coherence"/"load"/"resilience" -> ProgressBar
var _status_label: Label
# FQ-19: framed crest — title row plus per-bar numeric value labels.
var _crest_title: Label
var _bar_values: Dictionary = {}  # "coherence"/"load"/"resilience" -> Label
var _time_label: Label
var _stock_label: Label
var _progression_label: Label
var _hotbar_label: Label
var _mine_bar: ProgressBar
var _log_label: Label
var _event_panel: PanelContainer
var _event_time_label: Label
var _log_lines: Array[String] = []
var _town_panel: PanelContainer
var _town_info: Label
var _repair_button: Button
var _settler_box: VBoxContainer   # R-08 slice 2: per-settler job-assignment rows
var _stock_empty_label: Label
var _save_label: Label   # no longer built (FQ-19); kept for the null-guarded setter
var _has_save_hint := false
var _debug_label: Label
var _top_left_box: Control
# FQ-21 contract v2: the primary dock is one native-size layered kit whose
# decorative chrome and runtime-content rectangles come from JSON. The sliced
# FQ-21 band and FQ-19 modular orb/panel/orb construction remain fallbacks.
var _bottom_dock: Control          # the whole band (registered HUD widget)
var _dock_panel: Control           # the central block (band) / plate panel (fallback)
var _dock_band_active := false
var _hud_kit_active := false
# FQ-21 vessel sockets: future liquid mechanics plug in here — each socket
# exposes the glass geometry plus the swappable fill node (any Range works;
# update_health/update_attunement only ever drive the Range interface).
var _vessel_sockets: Dictionary = {}
# FQ-19: Range covers both fill implementations — the masked liquid
# TextureProgressBar when orb_fill_mask art exists, else the code-drawn
# ProgressBar fallback.
var _health_vessel_fill: Range
var _attunement_vessel_fill: Range
var _health_vessel_label: Label
var _attunement_vessel_label: Label
# FQ-19/FQ-21: vessel effect state — flash/glow overlays, the attunement frame
# for the outward use-pulse, a runtime constellation canvas, and last-seen
# values so damage/recovery/regeneration transitions can be detected.
var _health_fx: TextureRect
var _attunement_fx: TextureRect
var _attunement_frame: Control
var _attunement_core: Control
var _attunement_constellation: Control
var _last_health := -1.0
var _last_attunement := -1.0
var _vessel_fx_tweens: Dictionary = {}   # TextureRect -> Tween
var _vessel_pulse_tween: Tween
var _module_toolbar: Control
var _command_center_panel: PanelContainer
# FQ-14: compact, state-driven current-goal panel (top-center; toggle_goals hides it).
var _goal_panel: PanelContainer
var _goal_label: Label
var _goal_hint: Label
var _goal_progress: ProgressBar   # FQ-19: milestone strip (index/total)
var _goal_visible := true
# Wave C: openable full inventory panel.
var _inv_panel: PanelContainer
var _inv_content: Label
var _character_panel: PanelContainer
# PR-06: the Character panel is rebuilt on runtime children each open. The body
# host is cleared+repopulated by _refresh_character_panel; the figure is the
# shared PlayerVisual render path (apply_preview_character), never duplicated art.
var _character_body: VBoxContainer
var _character_figure = null   # the preview PlayerVisual (Node2D), else null
# FQ-06: skill tree panel (K); preloaded script, no class_name (cache-safe).
const SkillTreePanelScript := preload("res://scripts/ui/skill_tree_panel.gd")
# PR-06: shared character render path reused for the Character panel figure.
const PlayerVisualScript := preload("res://scripts/player/player_visual.gd")
const InventorySlotCellScript := preload("res://scripts/ui/inventory_slot_cell.gd")
var _skill_panel: PanelContainer
# FQ-15: map/minimap panel (M); hidden until opened, fed a snapshot by game_root.
const MapPanelScript := preload("res://scripts/ui/map_panel.gd")
var _map_panel: Control
var _map_open := false
# FQ-07/FQ-09: toolbelt slot tiles — always-visible item icons (real art or
# the FQ-07 fallback swatch), per-slot counts, and a selected-slot highlight.
var _hotbar_icons: Array[TextureRect] = []
var _hotbar_slots: Array[PanelContainer] = []
var _hotbar_counts: Array[Label] = []
# Native-kit wrappers own JSON-positioned runtime children. Legacy
# MarginContainer wrappers retain the raised-selected fallback treatment.
var _hotbar_cells: Array[Control] = []
var _hotbar_selected := -1
# FQ-13P2: StyleBox (texture placeholder when art/generated/ui art exists, else
# the code-drawn flat fallback) — either subclass assigns to a slot panel.
var _slot_normal_sb: StyleBox
var _slot_selected_sb: StyleBox
# FQ-09: inventory panel item grid and town stockpile grid.
var _inv_grid: GridContainer
var _inv_grid_counts: Dictionary = {}    # item_id -> displayed count
var _backpack_grid: GridContainer
var _backpack_grid_counts: Dictionary = {}  # item_id -> displayed count on the board
var _backpack_cell_total := 0
var _equipment_grid: GridContainer
var _equipment_slot_items: Dictionary = {}  # slot_id -> item_id on the board
var _dock_assignment_row: HBoxContainer
var _selected_item_detail: Label
var _stock_grid: GridContainer
var _stock_grid_counts: Dictionary = {}  # item_id -> displayed count
# FQ-19: contextual right-band stack — entries appear only when relevant
# (blueprint: selected item, save toast, interaction prompt), auto-hide, and
# stack in fixed priority order so they can never overlap each other.
var _context_stack: VBoxContainer
var _ctx_item_panel: PanelContainer
var _ctx_item_label: Label
var _ctx_save_panel: PanelContainer
var _ctx_interact_panel: PanelContainer
var _ctx_interact_label: Label
var _ctx_pickup_panel: PanelContainer          # R-08 slice 3: "+N Item" pickup toast
var _ctx_pickup_label: Label
var _ctx_pickup_counts: Dictionary = {}         # item_id -> running total while the toast shows
var _ctx_tweens: Dictionary = {}   # PanelContainer -> Tween
var _ctx_last_item := ""
var _hud_widgets: Dictionary = {}
var _hud_default_positions: Dictionary = {}
var _hud_edit_panel: PanelContainer
var _hud_edit_select: OptionButton
var _hud_edit_status: Label
var _hud_edit_mode := false
var _hud_edit_selected := "crest"
var _hud_drag_widget := ""
var _hud_drag_pointer := Vector2.ZERO
var _hud_drag_origin := Vector2.ZERO
# FQ-20: corner-grip resize state + the edit overlay that draws widget
# outlines and grips, and the dock command-center toggle chips.
var _hud_resize_widget := ""
var _hud_resize_origin_size := Vector2.ZERO
var _hud_edit_overlay: Control
var _command_toggles: Dictionary = {}   # label -> Button
var _hud_default_sizes: Dictionary = {}
const HUD_WIDGET_IDS := ["crest", "goal", "events", "map", "modules", "dock"]
const HUD_EDITABLE_WIDGET_IDS := ["crest", "goal", "events", "map", "modules"]
# FQ-20/FQ-22 direct manipulation: continuous resize via panel size, never
# Control.scale. Fractional transforms blur HUD chrome and expose nine-slice seams.
const HUD_MIN_SIZE_FACTOR := 0.5
const HUD_MAX_SIZE_FACTOR := 2.0
const HUD_SIZE_STEP := 0.1
const HUD_SAFE_MARGIN := 12.0
const HUD_GRIP_SIZE := 18.0
# Layouts saved before the canvas_items stretch + split dock band (v2) or
# before locks were retired for direct manipulation (v3), before the
# full-width dock became transform-invariant (v4), before Map and Events
# gained independent non-overlapping defaults (v5), or before module controls
# became dock-owned (v6), or before editable modules stopped persisting
# fractional Control.scale transforms (v7), were recorded against different
# geometry. A mismatch falls back to the blueprint defaults.
const HUD_LAYOUT_VERSION := 7


func _ready() -> void:
	_hud_visual_theme = _initial_hud_visual_theme()
	_build_top_left()
	_build_bottom_left()
	_build_command_center_widget()
	_build_log()
	_build_context_stack()
	_build_town_panel()
	_build_inventory_panel()
	_build_character_panel()
	_skill_panel = SkillTreePanelScript.new()
	add_child(_skill_panel)
	_build_goal_panel()
	_build_map_panel()
	_build_debug_overlay()
	_register_hud_widgets()
	_build_hud_edit_panel()
	_build_hud_edit_overlay()
	_load_hud_layout()
	_sync_command_center()


func _process(_delta: float) -> void:
	if player != null:
		_mine_bar.visible = player.mine_progress_ratio() > 0.0
		_mine_bar.value = player.mine_progress_ratio() * 100.0
	# FQ-19: low-health heartbeat pulse on the vessel overlay (only when no
	# one-shot flash/glow tween owns it). The attunement constellation redraws
	# every frame so its small stars can twinkle out of phase.
	if _low_health_active and _health_fx != null and not _vessel_fx_active(_health_fx):
		var wave := 0.28 + 0.18 * sin(Time.get_ticks_msec() / 160.0)
		_health_fx.self_modulate = Color(1.0, 0.25, 0.2, wave)
	if _attunement_core != null:
		_attunement_core.rotation += _delta * 0.8
	if _attunement_constellation != null:
		_attunement_constellation.queue_redraw()
	if _hud_edit_mode:
		# FQ-20: keep the outlines/grips tracking live drags and resizes.
		if _hud_edit_overlay != null:
			_hud_edit_overlay.queue_redraw()
		return
	if Input.is_action_just_pressed("debug_overlay"):
		_debug_label.visible = not _debug_label.visible
	if Input.is_action_just_pressed("toggle_goals"):
		_toggle_goal_module()


## FQ-20: the dock IS the command center — what is open or closed is managed
## from toggle chips in the central panel, not a separate screen-corner
## toolbar. `_module_toolbar` keeps its name as the row's identity.
func _build_command_center(parent: Control) -> void:
	if _hud_kit_active:
		_module_toolbar = Control.new()
		_module_toolbar.custom_minimum_size = Vector2(340, 32)
		_module_toolbar.size = Vector2(340, 32)
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		_module_toolbar = row
	parent.add_child(_module_toolbar)
	_add_command_toggle("Crest", func(): _toggle_top_left_module())
	_add_command_toggle("Goal", func(): _toggle_goal_module())
	_add_command_toggle("Events", func(): _toggle_event_module())
	_add_command_toggle_with_state("Map", func(pressed: bool): set_map_open(pressed))
	_add_command_toggle("Edit", func(): toggle_hud_edit_mode())


## Module visibility controls belong to the bottom dock when the native HUD kit
## is active, so old saved profile positions cannot strand them in the playfield.
func _build_command_center_widget() -> void:
	_command_center_panel = PanelContainer.new()
	_command_center_panel.name = "HudModuleControls"
	_command_center_panel.add_theme_stylebox_override("panel", _command_chip_style())
	if _hud_kit_active and _bottom_dock != null:
		var layout := _load_hud_kit_layout()
		var rect := _json_rect(layout.get("module_toolbar_rect"))
		if rect == Rect2():
			rect = Rect2(Vector2(458.0, 132.0), Vector2(364.0, 44.0))
		_place(_command_center_panel, rect)
		_command_center_panel.z_index = 6
		_bottom_dock.add_child(_command_center_panel)
	else:
		_command_center_panel.anchor_left = 0.5
		_command_center_panel.anchor_right = 0.5
		_command_center_panel.anchor_top = 0.0
		_command_center_panel.anchor_bottom = 0.0
		_command_center_panel.offset_left = -182.0
		_command_center_panel.offset_right = 182.0
		_command_center_panel.offset_top = 100.0
		_command_center_panel.offset_bottom = 134.0
		add_child(_command_center_panel)
	_build_command_center(_command_center_panel)


func _add_command_toggle(text: String, action: Callable) -> void:
	_add_command_toggle_with_state(text, func(_pressed_state: bool): action.call())


func _add_command_toggle_with_state(text: String, action: Callable) -> void:
	var button := Button.new()
	button.name = "CommandToggle" + text
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(54, 18)
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_stylebox_override("normal", _command_chip_style(Color(0.72, 0.72, 0.72)))
	button.add_theme_stylebox_override("hover", _command_chip_style())
	button.add_theme_stylebox_override("pressed", _command_chip_style(Color(1.3, 1.12, 0.75)))
	# These are HUD mouse/touch chips; keeping focus after a click lets ui_accept
	# repeat through the focused Button and can reopen/close toggled panels.
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "Show/hide %s" % text
	button.toggled.connect(func(pressed_state: bool):
		action.call(pressed_state)
		_sync_command_center())
	_module_toolbar.add_child(button)
	_command_toggles[text] = button
	_layout_command_toolbar()


func _layout_command_toolbar() -> void:
	if _module_toolbar == null or _module_toolbar is HBoxContainer:
		return
	var button_size := Vector2(58, 24)
	var gap := 4.0
	var count := _module_toolbar.get_child_count()
	var total_width := button_size.x * count + gap * maxf(float(count - 1), 0.0)
	var start_x := maxf((_module_toolbar.custom_minimum_size.x - total_width) * 0.5, 0.0)
	for i in range(count):
		var button := _module_toolbar.get_child(i) as Button
		if button == null:
			continue
		button.position = Vector2(start_x + float(i) * (button_size.x + gap), 4.0)
		button.size = button_size


## Mirror the live open/closed state onto the toggle chips (no signals).
func _sync_command_center() -> void:
	if _command_toggles.is_empty():
		return
	var states := {
		"Crest": _top_left_box != null and _top_left_box.visible,
		"Goal": _goal_panel != null and _goal_panel.visible,
		"Events": _event_panel != null and _event_panel.visible,
		"Map": map_open(),
		"Edit": _hud_edit_mode,
	}
	for key in _command_toggles:
		(_command_toggles[key] as Button).set_pressed_no_signal(bool(states.get(key, false)))


func _register_hud_widgets() -> void:
	_hud_widgets = {
		"crest": _top_left_box,
		"goal": _goal_panel,
		"events": _event_panel if _event_panel != null else _log_label,
		"map": _map_panel,
		"modules": _command_center_panel,
		"dock": _bottom_dock,
	}
	for widget_id in HUD_WIDGET_IDS:
		var control: Control = _hud_widgets.get(widget_id)
		if control == null:
			continue
		_hud_default_positions[widget_id] = control.position
		_hud_default_sizes[widget_id] = _hud_natural_size(control)
		control.scale = Vector2.ONE
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _editable_hud_widget_ids() -> Array[String]:
	var ids: Array[String] = []
	for widget_id in HUD_EDITABLE_WIDGET_IDS:
		if widget_id == "modules" and _hud_kit_active:
			continue
		ids.append(widget_id)
	# The modular FQ-19 fallback remains a movable panel. Only FQ-21's
	# anchored viewport band must be transform-invariant.
	if not _dock_band_active:
		ids.append("dock")
	return ids


func _hud_layout_locked(widget_id: String) -> bool:
	return (widget_id == "dock" and _dock_band_active) \
		or (widget_id == "modules" and _hud_kit_active)


func _restore_native_module_toolbar_rect() -> void:
	if not _hud_kit_active or _command_center_panel == null:
		return
	var layout := _load_hud_kit_layout()
	var rect := _json_rect(layout.get("module_toolbar_rect"))
	if rect == Rect2():
		rect = Rect2(Vector2(458.0, 132.0), Vector2(364.0, 44.0))
	_command_center_panel.custom_minimum_size = Vector2.ZERO
	_place(_command_center_panel, rect)


func _build_hud_edit_panel() -> void:
	_hud_edit_panel = PanelContainer.new()
	_hud_edit_panel.anchor_left = 0.5
	_hud_edit_panel.anchor_right = 0.5
	_hud_edit_panel.anchor_top = 1.0
	_hud_edit_panel.anchor_bottom = 1.0
	_hud_edit_panel.offset_left = -220.0
	_hud_edit_panel.offset_right = 220.0
	_hud_edit_panel.offset_top = -400.0
	_hud_edit_panel.offset_bottom = -190.0
	_hud_edit_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_hud_edit_panel.add_child(box)
	var title := _label(box, "HUD EDIT - drag to move, corner grip to resize")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	_hud_edit_select = OptionButton.new()
	for widget_id in _editable_hud_widget_ids():
		_hud_edit_select.add_item(widget_id.capitalize())
		_hud_edit_select.set_item_metadata(_hud_edit_select.item_count - 1, widget_id)
	_hud_edit_select.item_selected.connect(func(index: int):
		_hud_edit_selected = str(_hud_edit_select.get_item_metadata(index))
		_update_hud_edit_status())
	box.add_child(_hud_edit_select)
	var move_row := HBoxContainer.new()
	_add_edit_button(move_row, "←", func(): _nudge_hud_widget(Vector2(-8, 0)))
	_add_edit_button(move_row, "→", func(): _nudge_hud_widget(Vector2(8, 0)))
	_add_edit_button(move_row, "↑", func(): _nudge_hud_widget(Vector2(0, -8)))
	_add_edit_button(move_row, "↓", func(): _nudge_hud_widget(Vector2(0, 8)))
	box.add_child(move_row)
	var scale_row := HBoxContainer.new()
	_add_edit_button(scale_row, "Size -", func(): _scale_hud_widget(-HUD_SIZE_STEP))
	_add_edit_button(scale_row, "Size +", func(): _scale_hud_widget(HUD_SIZE_STEP))
	box.add_child(scale_row)
	var action_row := HBoxContainer.new()
	_add_edit_button(action_row, "Reset", func(): reset_hud_layout())
	_add_edit_button(action_row, "Done", func(): toggle_hud_edit_mode())
	box.add_child(action_row)
	_hud_edit_status = _label(box, "")
	_hud_edit_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hud_edit_panel)


func _add_edit_button(row: HBoxContainer, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(64, 24)
	button.pressed.connect(action)
	row.add_child(button)


func toggle_hud_edit_mode() -> void:
	_hud_edit_mode = not _hud_edit_mode
	GameState.hud_edit_mode = _hud_edit_mode
	if _hud_edit_panel != null:
		_hud_edit_panel.visible = _hud_edit_mode
	if _hud_edit_overlay != null:
		_hud_edit_overlay.visible = _hud_edit_mode
	for widget_id in _editable_hud_widget_ids():
		var control: Control = _hud_widgets.get(widget_id)
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_STOP if _hud_edit_mode else Control.MOUSE_FILTER_IGNORE
	if _hud_edit_mode:
		_hud_edit_selected = "crest"
		_hud_edit_select.select(0)
		_update_hud_edit_status()
	else:
		_hud_drag_widget = ""
		_hud_resize_widget = ""
		_save_hud_layout()
	_sync_command_center()


func is_hud_edit_mode() -> bool:
	return _hud_edit_mode


func _update_hud_edit_status() -> void:
	if _hud_edit_status == null:
		return
	var control: Control = _hud_widgets.get(_hud_edit_selected)
	var size := Vector2.ZERO if control == null else _hud_widget_size(control)
	_hud_edit_status.text = "%s - %dx%d\nDrag any panel to move it; drag a corner grip to resize." % [
		_hud_edit_selected.capitalize(), int(size.x), int(size.y)]


## FQ-20: locks are gone — edit mode itself is the gate; everything drags.
func _nudge_hud_widget(delta: Vector2) -> void:
	var control: Control = _hud_widgets.get(_hud_edit_selected)
	if control == null:
		return
	control.position += delta
	_clamp_hud_widget(control)
	_update_hud_edit_status()


func _scale_hud_widget(delta: float) -> void:
	var control: Control = _hud_widgets.get(_hud_edit_selected)
	if control == null:
		return
	_set_hud_widget_size(_hud_edit_selected, _hud_widget_size(control) * (1.0 + delta))
	_clamp_hud_widget(control)
	_update_hud_edit_status()


## FQ-20/FQ-22: apply an absolute size factor against the widget default.
func _resize_hud_widget(widget_id: String, next_factor: float) -> void:
	var control: Control = _hud_widgets.get(widget_id)
	if control == null:
		return
	var base_size: Vector2 = _hud_default_sizes.get(widget_id, _hud_widget_size(control))
	_set_hud_widget_size(widget_id, base_size * next_factor)
	_clamp_hud_widget(control)
	_update_hud_edit_status()


func _resize_hud_widget_to_size(widget_id: String, next_size: Vector2) -> void:
	var control: Control = _hud_widgets.get(widget_id)
	if control == null:
		return
	_set_hud_widget_size(widget_id, next_size)
	_clamp_hud_widget(control)
	_update_hud_edit_status()


## The corner-grip zone of a widget (bottom-right, in screen coordinates).
func _hud_grip_rect(widget_id: String) -> Rect2:
	var control: Control = _hud_widgets.get(widget_id)
	if control == null or not control.visible:
		return Rect2()
	var rect := control.get_global_rect()
	return Rect2(rect.end - Vector2(HUD_GRIP_SIZE, HUD_GRIP_SIZE),
		Vector2(HUD_GRIP_SIZE, HUD_GRIP_SIZE))


func _hud_widget_size(control: Control) -> Vector2:
	var measured := control.size
	var minimum := control.custom_minimum_size
	if minimum.x > measured.x:
		measured.x = minimum.x
	if minimum.y > measured.y:
		measured.y = minimum.y
	if measured.x <= 0.0:
		measured.x = 160.0
	if measured.y <= 0.0:
		measured.y = 80.0
	return measured.round()


## The content-driven default size of a widget. `_register_hud_widgets` runs in
## `_ready` before containers have laid out, so `control.size` is still a stub;
## the combined minimum size gives the real natural extent synchronously. This
## is the size `reset_hud_layout` restores to, so it must match the widget's
## live size once its content has settled.
func _hud_natural_size(control: Control) -> Vector2:
	var natural := control.get_combined_minimum_size()
	var minimum := control.custom_minimum_size
	natural.x = maxf(natural.x, maxf(minimum.x, control.size.x))
	natural.y = maxf(natural.y, maxf(minimum.y, control.size.y))
	if natural.x <= 0.0:
		natural.x = 160.0
	if natural.y <= 0.0:
		natural.y = 80.0
	return natural.round()


func _hud_min_size(widget_id: String, control: Control) -> Vector2:
	var base: Vector2 = _hud_default_sizes.get(widget_id, _hud_widget_size(control))
	return Vector2(maxf(base.x * HUD_MIN_SIZE_FACTOR, 120.0),
		maxf(base.y * HUD_MIN_SIZE_FACTOR, 56.0)).round()


func _hud_max_size(widget_id: String, control: Control) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var base: Vector2 = _hud_default_sizes.get(widget_id, _hud_widget_size(control))
	return Vector2(minf(base.x * HUD_MAX_SIZE_FACTOR, viewport_size.x - HUD_SAFE_MARGIN * 2.0),
		minf(base.y * HUD_MAX_SIZE_FACTOR, viewport_size.y - HUD_SAFE_MARGIN * 2.0)).round()


func _set_hud_widget_size(widget_id: String, next_size: Vector2) -> void:
	var control: Control = _hud_widgets.get(widget_id)
	if control == null:
		return
	var min_size := _hud_min_size(widget_id, control)
	var max_size := _hud_max_size(widget_id, control)
	var clamped := Vector2(
		clampf(next_size.x, min_size.x, max_size.x),
		clampf(next_size.y, min_size.y, max_size.y)).round()
	control.scale = Vector2.ONE
	control.custom_minimum_size = clamped
	control.size = clamped


func _clamp_hud_widget(control: Control) -> void:
	control.scale = Vector2.ONE
	# The FQ-21 dock is an anchored viewport band, not a floating panel.
	# Canonicalizing its parent transform prevents saved/editor transforms
	# from scaling its full-width anchors and clipping either vessel.
	if _dock_band_active and control == _bottom_dock:
		control.position = _hud_default_positions.get("dock", control.position)
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var widget_size := _hud_widget_size(control)
	var max_position := viewport_size - widget_size - Vector2.ONE * HUD_SAFE_MARGIN
	# A full-width widget (the FQ-21 band) has no horizontal slack; clamping
	# with min > max would snap it to the margin.
	if max_position.x >= HUD_SAFE_MARGIN:
		control.position.x = clampf(control.position.x, HUD_SAFE_MARGIN, max_position.x)
	if max_position.y >= HUD_SAFE_MARGIN:
		control.position.y = clampf(control.position.y, HUD_SAFE_MARGIN, max_position.y)


func _input(event: InputEvent) -> void:
	if not _hud_edit_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		toggle_hud_edit_mode()
		get_viewport().set_input_as_handled()
		return
	# Only mouse events carry a position; a key press while editing must not
	# reach the base-InputEvent property (review finding, FQ-19 closeout).
	if not (event is InputEventMouse):
		return
	var point: Vector2 = (event as InputEventMouse).position
	# Button-up ALWAYS settles an in-flight drag/resize, even over the edit
	# panel or the command chips — otherwise releasing inside an exemption
	# zone leaks the drag state onto the next motion (review finding, FQ-20).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		if _hud_drag_widget != "" or _hud_resize_widget != "":
			_save_hud_layout()
			_hud_drag_widget = ""
			_hud_resize_widget = ""
			get_viewport().set_input_as_handled()
		return
	if _hud_edit_panel != null and _hud_edit_panel.get_global_rect().has_point(point):
		return
	# The module-controls widget must stay clickable while editing (that is
	# where Edit is toggled back off).
	if _command_center_panel != null \
			and _command_center_panel.get_global_rect().has_point(point):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Corner grip first: resize wins over move when both hit.
			_hud_resize_widget = ""
			for widget_id in _editable_hud_widget_ids():
				if _hud_grip_rect(widget_id).has_point(point):
					_hud_resize_widget = widget_id
					break
			if _hud_resize_widget != "":
				_hud_edit_selected = _hud_resize_widget
				_hud_edit_select.select(_editable_hud_widget_ids().find(_hud_resize_widget))
				_hud_drag_pointer = point
				_hud_resize_origin_size = _hud_widget_size(_hud_widgets[_hud_resize_widget])
				_update_hud_edit_status()
			else:
				_hud_drag_widget = _hud_widget_at(point)
				if _hud_drag_widget != "":
					_hud_edit_selected = _hud_drag_widget
					_hud_edit_select.select(_editable_hud_widget_ids().find(_hud_drag_widget))
					_hud_drag_pointer = point
					_hud_drag_origin = (_hud_widgets[_hud_drag_widget] as Control).position
					_update_hud_edit_status()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _hud_resize_widget != "":
		# Continuous resize follows pointer distance as explicit widget size.
		var control: Control = _hud_widgets[_hud_resize_widget]
		var origin: Vector2 = control.global_position
		var start_span: float = maxf((_hud_drag_pointer - origin).length(), 1.0)
		var now_span: float = (point - origin).length()
		_resize_hud_widget_to_size(_hud_resize_widget,
			(_hud_resize_origin_size * snappedf(now_span / start_span, 0.01)).round())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _hud_drag_widget != "":
		var control: Control = _hud_widgets[_hud_drag_widget]
		control.position = _hud_drag_origin + (point - _hud_drag_pointer)
		_clamp_hud_widget(control)
		_update_hud_edit_status()
		get_viewport().set_input_as_handled()


func _hud_widget_at(point: Vector2) -> String:
	for widget_id in _editable_hud_widget_ids():
		var control: Control = _hud_widgets.get(widget_id)
		if control != null and control.visible and control.get_global_rect().has_point(point):
			return widget_id
	return ""


## FQ-20: full-screen edit overlay — gold outlines and corner grips over
## every visible widget while edit mode is on (drawn, not interactive).
func _build_hud_edit_overlay() -> void:
	_hud_edit_overlay = Control.new()
	_hud_edit_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_edit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_edit_overlay.visible = false
	_hud_edit_overlay.draw.connect(_draw_hud_edit_overlay)
	add_child(_hud_edit_overlay)


func _draw_hud_edit_overlay() -> void:
	for widget_id in _editable_hud_widget_ids():
		var control: Control = _hud_widgets.get(widget_id)
		if control == null or not control.visible:
			continue
		var rect := control.get_global_rect()
		var selected: bool = widget_id == _hud_edit_selected
		var line := Color(0.95, 0.8, 0.35, 0.95) if selected else Color(0.7, 0.6, 0.35, 0.55)
		_hud_edit_overlay.draw_rect(rect, line, false, 2.0 if selected else 1.0)
		var grip := _hud_grip_rect(widget_id)
		_hud_edit_overlay.draw_rect(grip, Color(0.95, 0.8, 0.35, 0.9 if selected else 0.6))
		_hud_edit_overlay.draw_rect(grip, Color(0.1, 0.08, 0.05, 0.9), false, 1.0)


func _load_hud_layout() -> void:
	var saved: Variant = GameState.profile.get("hud_layout", {})
	if not saved is Dictionary:
		_clamp_hud_widget(_bottom_dock)
		return
	if int(saved.get("version", 0)) != HUD_LAYOUT_VERSION:
		_clamp_hud_widget(_bottom_dock)
		return
	for widget_id in HUD_WIDGET_IDS:
		var record: Variant = saved.get(widget_id, {})
		if not record is Dictionary:
			continue
		var control: Control = _hud_widgets.get(widget_id)
		if control == null:
			continue
		if _hud_layout_locked(widget_id):
			if widget_id == "modules":
				_restore_native_module_toolbar_rect()
			_clamp_hud_widget(control)
			continue
		control.scale = Vector2.ONE
		var delta_value: Variant = record.get("delta", [0.0, 0.0])
		if delta_value is Array and delta_value.size() >= 2:
			control.position = _hud_default_positions[widget_id] + Vector2(float(delta_value[0]), float(delta_value[1]))
		var saved_size: Variant = record.get("size", [])
		if saved_size is Array and saved_size.size() >= 2:
			_set_hud_widget_size(widget_id,
				Vector2(float(saved_size[0]), float(saved_size[1])))
		var saved_visible: Variant = record.get("visible", true)
		if widget_id in ["crest", "goal", "events"] and saved_visible is bool:
			control.visible = saved_visible
			if widget_id == "goal":
				_goal_visible = control.visible
		_clamp_hud_widget(control)


func _save_hud_layout() -> void:
	var layout := {"version": HUD_LAYOUT_VERSION}
	for widget_id in HUD_WIDGET_IDS:
		var control: Control = _hud_widgets.get(widget_id)
		if control == null:
			continue
		if _hud_layout_locked(widget_id):
			if widget_id == "modules":
				_restore_native_module_toolbar_rect()
			_clamp_hud_widget(control)
			continue
		control.scale = Vector2.ONE
		var delta: Vector2 = control.position - _hud_default_positions[widget_id]
		var saved_visible := control.visible if widget_id in ["crest", "goal", "events"] else true
		var saved_size := _hud_widget_size(control)
		layout[widget_id] = {
			"delta": [snappedf(delta.x, 1.0), snappedf(delta.y, 1.0)],
			"size": [snappedf(saved_size.x, 1.0), snappedf(saved_size.y, 1.0)],
			"visible": saved_visible,
		}
	GameState.profile["hud_layout"] = layout
	GameState.save_shell()


func reset_hud_layout() -> void:
	for widget_id in HUD_WIDGET_IDS:
		var control: Control = _hud_widgets.get(widget_id)
		if control == null:
			continue
		control.position = _hud_default_positions[widget_id]
		if _hud_layout_locked(widget_id):
			if widget_id == "modules":
				_restore_native_module_toolbar_rect()
			_clamp_hud_widget(control)
			continue
		_set_hud_widget_size(widget_id,
			_hud_default_sizes.get(widget_id, _hud_widget_size(control)))
		control.scale = Vector2.ONE
		if widget_id in ["crest", "goal", "events"]:
			control.visible = true
	_goal_visible = true
	_save_hud_layout()
	_update_hud_edit_status()
	_sync_command_center()


func _toggle_top_left_module() -> void:
	if _top_left_box != null:
		_top_left_box.visible = not _top_left_box.visible
		_save_hud_layout()
	_sync_command_center()


func _toggle_goal_module() -> void:
	_goal_visible = not _goal_visible
	if _goal_panel != null:
		_goal_panel.visible = _goal_visible
		_save_hud_layout()
	_sync_command_center()


func _toggle_event_module() -> void:
	if _event_panel != null:
		_event_panel.visible = not _event_panel.visible
		_save_hud_layout()
	_sync_command_center()


## Static painted UI supports optional per-theme siblings named
## `<asset>__<theme>.png`. Every lookup is asset-local: a missing, unreadable,
## wrong-size, or wrong-format themed PNG falls back to the required base PNG.
## Runtime-owned item icons, values, fills, counts, and labels never pass
## through this presentation-only resolver.
func _painted_texture(id: String) -> Texture2D:
	return _painted_texture_for_theme(id, _hud_visual_theme)


func _painted_texture_for_theme(id: String, theme_id: String) -> Texture2D:
	var fallback: Texture2D = BlockRegistry.visual_texture("ui_painted", id)
	if fallback == null:
		return null
	var safe_theme := _normalize_hud_visual_theme(theme_id)
	if safe_theme.is_empty():
		return fallback
	var themed: Texture2D = BlockRegistry.visual_texture(
		"ui_painted", "%s%s%s" % [id, HUD_VISUAL_THEME_SEPARATOR, safe_theme])
	if not _themed_texture_matches_fallback(themed, fallback):
		return fallback
	return themed


func _themed_texture_matches_fallback(themed: Texture2D,
		fallback: Texture2D) -> bool:
	if themed == null or fallback == null or themed.get_size() != fallback.get_size():
		return false
	var themed_image: Image = themed.get_image()
	var fallback_image: Image = fallback.get_image()
	return themed_image != null and fallback_image != null \
		and not themed_image.is_empty() and not fallback_image.is_empty() \
		and themed_image.get_format() == fallback_image.get_format()


func _initial_hud_visual_theme() -> String:
	GameState.ensure_play_context()
	var character: Dictionary = GameState.current_character
	var explicit := str(character.get("hud_visual_theme", ""))
	if not explicit.is_empty():
		return _normalize_hud_visual_theme(explicit)
	return _normalize_hud_visual_theme(str(character.get("species", "")))


func _normalize_hud_visual_theme(raw_id: String) -> String:
	var raw := raw_id.strip_edges().to_lower()
	var normalized := ""
	for index in range(raw.length()):
		var code := raw.unicode_at(index)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) \
				or code == 95:
			normalized += raw[index]
		elif code == 32 or code == 45:
			normalized += "_"
		else:
			return ""
	if normalized.length() > HUD_VISUAL_THEME_MAX_LENGTH:
		return ""
	return normalized


func hud_visual_theme_id() -> String:
	return _hud_visual_theme


## Framed-module look: crisp runtime chrome, not stretched mockup crops.
## The outer panel owns the border only; _module_content_host adds a separate
## padded background layer for live text/bars/content.
func _module_panel_style(kind: String = "plain") -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.021, 0.032, 0.84)
	sb.border_color = Color(0.62, 0.53, 0.34, 0.96) if kind == "ornate" \
		else Color(0.36, 0.47, 0.54, 0.92)
	sb.set_border_width_all(3 if kind == "ornate" else 2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(8 if kind == "ornate" else 6)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.anti_aliasing = false
	return sb


func _module_background_style() -> StyleBoxFlat:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.035, 0.052, 0.88)
	background.border_color = Color(0.11, 0.16, 0.20, 0.9)
	background.set_border_width_all(1)
	background.set_corner_radius_all(2)
	background.set_content_margin_all(8)
	background.anti_aliasing = false
	return background


func _module_content_host(panel: PanelContainer, kind: String = "plain") -> PanelContainer:
	panel.add_theme_stylebox_override("panel", _module_panel_style(kind))
	var host := PanelContainer.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_theme_stylebox_override("panel", _module_background_style())
	panel.add_child(host)
	return host


## FQ-20: small chip framing (contextual entries, command-center toggles) —
## the painted mockup chip when present, else the code-drawn strip.
func _chip_style(tint: Color = Color.WHITE) -> StyleBox:
	var painted: Texture2D = _painted_texture("chip_frame")
	if painted != null:
		var psb := StyleBoxTexture.new()
		psb.texture = painted
		psb.set_texture_margin_all(6)
		psb.content_margin_left = 12
		psb.content_margin_right = 12
		psb.content_margin_top = 7
		psb.content_margin_bottom = 7
		psb.modulate_color = tint
		return psb
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.86)
	sb.border_color = Color(0.55, 0.42, 0.24, 0.9) * tint
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(5)
	return sb


## The module toggles live inside a 44px dock rail. Keep this compact so the
## controls do not grow past the native kit rectangle and clip at the viewport.
func _command_chip_style(tint: Color = Color.WHITE) -> StyleBox:
	var painted: Texture2D = _painted_texture("chip_frame")
	if painted != null:
		var psb := StyleBoxTexture.new()
		psb.texture = painted
		psb.set_texture_margin_all(4)
		psb.content_margin_left = 7
		psb.content_margin_right = 7
		psb.content_margin_top = 3
		psb.content_margin_bottom = 3
		psb.modulate_color = tint
		return psb
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.86)
	sb.border_color = Color(0.55, 0.42, 0.24, 0.9) * tint
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


## FQ-22: code-drawn crest corner ornament. The old painted crop carried
## leftover alpha/masking debris outside the panel edge; keep this contained.
func _add_corner_medallion(panel: Control) -> void:
	var holder := Control.new()
	holder.name = "CrestCornerOrnament"
	holder.position = Vector2(5, 5)
	holder.size = Vector2(24, 24)
	holder.custom_minimum_size = holder.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.draw.connect(func() -> void:
		var center := Vector2(10, 10)
		var diamond := PackedVector2Array([
			center + Vector2(0, -6),
			center + Vector2(6, 0),
			center + Vector2(0, 6),
			center + Vector2(-6, 0),
		])
		var outline := PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]])
		holder.draw_colored_polygon(diamond, Color(0.82, 0.66, 0.32, 0.98))
		holder.draw_polyline(outline, Color(0.12, 0.10, 0.06, 0.95), 1.0)
		holder.draw_line(Vector2(2, 2), Vector2(18, 2), Color(0.62, 0.53, 0.34, 0.8), 1.0)
		holder.draw_line(Vector2(2, 2), Vector2(2, 18), Color(0.62, 0.53, 0.34, 0.8), 1.0)
	)
	panel.add_child(holder)


func _build_top_left() -> void:
	# FQ-19 blueprint crest: one framed settlement panel — name/level title,
	# a chip+bar+value row per C/L/R resource, then status/stores/XP lines.
	var crest := PanelContainer.new()
	_top_left_box = crest
	crest.position = Vector2(16, 14)
	crest.custom_minimum_size = Vector2(250, 0)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crest_content := _module_content_host(crest, "ornate")
	_add_corner_medallion(crest)
	add_child(crest)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	crest_content.add_child(box)
	_crest_title = Label.new()
	_crest_title.text = "◆ Camp · Lv.1"
	_crest_title.add_theme_font_size_override("font_size", 14)
	_crest_title.add_theme_color_override("font_color", Color(0.89, 0.75, 0.43))
	box.add_child(_crest_title)
	_bars["coherence"] = _crest_bar(box, "Coherence", Color(0.35, 0.75, 0.40))
	_bars["load"] = _crest_bar(box, "Load", Color(0.85, 0.45, 0.30))
	_bars["resilience"] = _crest_bar(box, "Resilience", Color(0.35, 0.55, 0.85))
	_status_label = _label(box, "Status: —")
	_status_label.add_theme_font_size_override("font_size", 11)
	_stock_label = _label(box, "Town Hall: empty")
	_stock_label.add_theme_font_size_override("font_size", 11)
	_progression_label = _label(box, "Lv.1 Camp  XP: 0/100")
	_progression_label.add_theme_font_size_override("font_size", 11)
	_progression_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))


## FQ-19 crest resource row: color chip, name, slim bar, right-aligned value.
func _crest_bar(parent: Control, title: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var chip := ColorRect.new()
	chip.color = color
	chip.custom_minimum_size = Vector2(7, 7)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.rotation = PI / 4.0
	chip.pivot_offset = Vector2(3.5, 3.5)
	row.add_child(chip)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(70, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(100, 10)
	bar.max_value = 100.0
	bar.value = 50.0
	bar.show_percentage = false
	bar.modulate = color
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value := Label.new()
	value.text = "50"
	value.custom_minimum_size = Vector2(24, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 12)
	row.add_child(value)
	_bar_values[title.to_lower()] = value
	return bar


## FQ-14: a small top-center panel showing the current objective and a one-line
## hint. Unobtrusive (compact, semi-transparent) and hideable with toggle_goals.
func _build_goal_panel() -> void:
	# FQ-19 blueprint treatment: framed panel, objective headline, subgoal
	# line, and a slim milestone strip showing progress through the arc.
	_goal_panel = PanelContainer.new()
	_goal_panel.anchor_left = 0.5
	_goal_panel.anchor_right = 0.5
	_goal_panel.offset_left = -180.0
	_goal_panel.offset_right = 180.0
	_goal_panel.offset_top = 8.0
	_goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goal_content := _module_content_host(_goal_panel)
	add_child(_goal_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	goal_content.add_child(col)
	_goal_label = Label.new()
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.add_theme_font_size_override("font_size", 14)
	_goal_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	col.add_child(_goal_label)
	_goal_hint = Label.new()
	_goal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_hint.add_theme_font_size_override("font_size", 11)
	_goal_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_goal_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_goal_hint)
	_goal_progress = ProgressBar.new()
	_goal_progress.custom_minimum_size = Vector2(0, 5)
	_goal_progress.show_percentage = false
	_goal_progress.modulate = Color(0.89, 0.75, 0.43)
	col.add_child(_goal_progress)


## FQ-14: reflect the goal model. `goal` is the goal_tracker.current() dict.
func update_goal(goal: Dictionary) -> void:
	if _goal_label == null:
		return
	var idx := int(goal.get("index", 0))
	var total := int(goal.get("total", 5))
	if _goal_progress != null:
		_goal_progress.max_value = float(maxi(total, 1))
		_goal_progress.value = float(idx)
	if bool(goal.get("all_done", false)):
		_goal_label.text = "✓ " + str(goal.get("text", "All goals complete."))
		_goal_hint.text = ""
		_goal_hint.visible = false
	else:
		_goal_label.text = "Goal %d/%d: %s" % [idx + 1, total, str(goal.get("text", ""))]
		_goal_hint.text = str(goal.get("hint", ""))
		_goal_hint.visible = true


func goal_panel_visible() -> bool:
	return _goal_panel != null and _goal_panel.visible


## FQ-15/FQ-16: a compact, hidden-by-default schematic mini-map placeholder.
func _build_map_panel() -> void:
	_map_panel = MapPanelScript.new()
	_map_panel.custom_minimum_size = Vector2(320, 168)
	_map_panel.size = Vector2(320, 168)
	_map_panel.anchor_left = 1.0
	_map_panel.anchor_right = 1.0
	_map_panel.anchor_top = 0.0
	_map_panel.anchor_bottom = 0.0
	# Map and Events are independent modules. Keep a fixed 12px gutter between
	# their defaults so both can remain visible without state-dependent jumps.
	_map_panel.offset_left = -704.0
	_map_panel.offset_right = -384.0
	_map_panel.offset_top = 96.0
	_map_panel.offset_bottom = 264.0
	_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.visible = false
	add_child(_map_panel)


## FQ-15: flip the map panel; returns the new visibility so game_root can decide
## whether to push a fresh snapshot.
func toggle_map() -> bool:
	return set_map_open(not map_open())


func set_map_open(open: bool) -> bool:
	if _map_panel == null:
		_map_open = false
		_sync_command_center()
		return false
	_map_open = open
	_map_panel.visible = _map_open
	_sync_command_center()
	return _map_open


func update_map(snapshot: Dictionary) -> void:
	if _map_panel != null:
		_map_panel.set_snapshot(snapshot)


func map_open() -> bool:
	return _map_open and _map_panel != null and _map_panel.visible


## Native-size layered HUD kit. Every positioned rectangle comes from
## hud_dock_layout.json; the only runtime-authored visuals are live content.
func _build_hud_kit(layout: Dictionary) -> void:
	_hud_kit_active = true
	_dock_band_active = true
	var native_size := _json_vec(layout.get("native_size"))
	var dock_geo: Dictionary = layout.get("dock", {})
	var dock_rect := _json_rect(dock_geo.get("rect"))
	if native_size == Vector2.ZERO:
		native_size = dock_rect.size
	var band := Control.new()
	band.name = "HudDockKit"
	_bottom_dock = band
	band.anchor_left = 0.5
	band.anchor_right = 0.5
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_left = -native_size.x / 2.0
	band.offset_right = native_size.x / 2.0
	band.offset_top = -native_size.y
	band.offset_bottom = 0.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	# Decorative chrome is manifest-driven. New non-interactive layers can be
	# added to JSON without another hud.gd branch; gameplay controls remain
	# explicitly registered below.
	var decorative_by_role: Dictionary = {}
	for raw_layer in layout.get("decorative_layers", []):
		if not raw_layer is Dictionary:
			continue
		var layer_def: Dictionary = raw_layer
		if not bool(layer_def.get("enabled", true)):
			continue
		var asset_file := str(layer_def.get("asset", ""))
		var asset_id := asset_file.trim_suffix(".png")
		var layer := _kit_layer(band, str(layer_def.get("name", asset_id)),
			asset_id, _json_rect(layer_def.get("rect")),
			int(layer_def.get("z", 0)))
		decorative_by_role[str(layer_def.get("role", ""))] = layer
	var backplate: TextureRect = decorative_by_role.get("backplate") as TextureRect
	_dock_panel = backplate

	var health_geo: Dictionary = layout.get("health", {})
	var health_fill_rect := _json_rect(health_geo.get("fill_rect"))
	var health_mask: Texture2D = _painted_texture("health_fill_mask")
	var health_fill := TextureProgressBar.new()
	health_fill.name = "HealthFill"
	health_fill.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	health_fill.texture_under = health_mask
	health_fill.tint_under = Color(0.025, 0.035, 0.05, 0.94)
	health_fill.texture_progress = health_mask
	health_fill.tint_progress = Color(0.82, 0.11, 0.09)
	health_fill.max_value = 100.0
	health_fill.value = 100.0
	_place(health_fill, health_fill_rect)
	health_fill.z_index = 1
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(health_fill)
	_health_vessel_fill = health_fill

	var attune_geo: Dictionary = layout.get("attunement", {})
	var attune_fill_rect := _json_rect(attune_geo.get("fill_rect"))
	var attune_mask: Texture2D = _painted_texture("attunement_fill_mask")
	var attune_fill := TextureProgressBar.new()
	attune_fill.name = "AttunementFill"
	attune_fill.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	attune_fill.texture_under = attune_mask
	attune_fill.tint_under = Color(0.01, 0.03, 0.07, 0.96)
	attune_fill.texture_progress = attune_mask
	attune_fill.tint_progress = Color(0.24, 0.72, 1.0, 0.94)
	attune_fill.max_value = 100.0
	attune_fill.value = 100.0
	_place(attune_fill, attune_fill_rect)
	attune_fill.z_index = 1
	attune_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(attune_fill)
	_attunement_vessel_fill = attune_fill

	var health_frame := _kit_layer(band, "HealthFrame", "health_frame",
		_json_rect(health_geo.get("frame_rect")), 2)
	var health_glass := _kit_layer(band, "HealthGlass",
		"health_glass_overlay", _json_rect(health_geo.get("glass_rect")), 2)
	var attune_frame := _kit_layer(band, "AttunementFrame",
		"attunement_frame", _json_rect(attune_geo.get("frame_rect")), 2)
	attune_frame.pivot_offset = attune_frame.size / 2.0
	_attunement_frame = attune_frame
	var attune_glass := _kit_layer(band, "AttunementGlass",
		"attunement_glass_overlay", _json_rect(attune_geo.get("glass_rect")), 2)
	_attunement_constellation = _add_attunement_constellation(
		band, _json_rect(attune_geo.get("glass_rect")))
	# Keep explicit references alive for the layer contract and smoke hooks.
	health_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attune_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_normal_sb = _texture_style("slot_normal")
	_slot_selected_sb = _texture_style("slot_selected")
	var slot_rects: Array = layout.get("slots", [])
	var slot_content: Dictionary = layout.get("slot_content", {})
	for i in range(mini(5, slot_rects.size())):
		var rect := _json_rect(slot_rects[i])
		var cell := Control.new()
		cell.name = "HotbarCell%d" % (i + 1)
		_place(cell, rect)
		cell.z_index = 4
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(cell)
		var slot := PanelContainer.new()
		slot.name = "HotbarSlot%d" % (i + 1)
		slot.add_theme_stylebox_override("panel", _slot_normal_sb)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(slot, Rect2(Vector2.ZERO, rect.size))
		cell.add_child(slot)
		var icon := TextureRect.new()
		icon.name = "RuntimeIcon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(icon, _json_rect(slot_content.get("icon_rect")))
		cell.add_child(icon)
		var count := Label.new()
		count.name = "RuntimeCount"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 11)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(count, _json_rect(slot_content.get("count_rect")))
		cell.add_child(count)
		var key_tag := Label.new()
		key_tag.name = "RuntimeHotkey"
		key_tag.text = str(i + 1)
		key_tag.add_theme_font_size_override("font_size", 9)
		key_tag.add_theme_color_override("font_color", Color(0.89, 0.75, 0.43))
		key_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(key_tag, _json_rect(slot_content.get("hotkey_rect")))
		cell.add_child(key_tag)
		_hotbar_cells.append(cell)
		_hotbar_slots.append(slot)
		_hotbar_icons.append(icon)
		_hotbar_counts.append(count)

	var buttons: Dictionary = layout.get("buttons", {})
	var button_content: Dictionary = layout.get("button_content", {})
	_add_kit_button(band, buttons.get("inventory"), "Inventory",
		"button_icon_inventory", button_content, func(): toggle_inventory_panel())
	_add_kit_button(band, buttons.get("character"), "Character",
		"button_icon_character", button_content, func(): toggle_character_panel())
	_add_kit_button(band, buttons.get("skills"), "Skills",
		"button_icon_skills", button_content, func(): toggle_skill_panel())
	_add_kit_button(band, buttons.get("town_hall"), "Town Hall",
		"button_icon_town_hall", button_content, func(): toggle_town_panel())

	var summary := PanelContainer.new()
	summary.name = "SelectedItemChip"
	summary.add_theme_stylebox_override("panel", _chip_style())
	_place(summary, _json_rect(layout.get("selected_item_chip_rect")))
	summary.z_index = 5
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(summary)
	_hotbar_label = Label.new()
	_hotbar_label.add_theme_font_size_override("font_size", 11)
	_hotbar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.add_child(_hotbar_label)
	_mine_bar = ProgressBar.new()
	_mine_bar.name = "MiningProgress"
	_mine_bar.show_percentage = false
	_mine_bar.visible = false
	_place(_mine_bar, _json_rect(layout.get("mining_progress_rect")))
	_mine_bar.z_index = 5
	band.add_child(_mine_bar)

	_health_vessel_label = _vessel_value_label(band)
	_place(_health_vessel_label, _json_rect(health_geo.get("label_rect")))
	_health_vessel_label.z_index = 5
	_health_label = _health_vessel_label
	_attunement_vessel_label = _vessel_value_label(band)
	_place(_attunement_vessel_label, _json_rect(attune_geo.get("label_rect")))
	_attunement_vessel_label.z_index = 5
	_attunement_label = _attunement_vessel_label
	_health_fx = _kit_fx(band, "HealthFx", health_mask, health_fill_rect)
	_attunement_fx = _kit_fx(band, "AttunementFx", attune_mask, attune_fill_rect)
	_vessel_sockets = {
		"health": {"glass_center": health_fill_rect.get_center(),
			"glass_diameter": int(health_fill_rect.size.x), "fill": health_fill},
		"attunement": {"crystal_center": attune_fill_rect.get_center(),
			"crystal_diameter": int(attune_fill_rect.size.x), "fill": attune_fill},
	}


func _kit_layer(parent: Control, node_name: String, asset_id: String,
		rect: Rect2, layer: int) -> TextureRect:
	var control := TextureRect.new()
	control.name = node_name
	control.texture = _painted_texture(asset_id)
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP
	_place(control, rect)
	control.z_index = layer
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control


func _kit_fx(parent: Control, node_name: String, texture: Texture2D,
		rect: Rect2) -> TextureRect:
	var fx := TextureRect.new()
	fx.name = node_name
	fx.texture = texture
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.stretch_mode = TextureRect.STRETCH_KEEP
	_place(fx, rect)
	fx.self_modulate = Color(1, 1, 1, 0)
	fx.z_index = 6
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fx)
	return fx


func _add_attunement_constellation(parent: Control, rect: Rect2) -> Control:
	var canvas := Control.new()
	canvas.name = "AttunementConstellation"
	_place(canvas, rect)
	canvas.clip_contents = true
	canvas.z_index = 3
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(func() -> void: _draw_attunement_constellation(canvas))
	parent.add_child(canvas)
	return canvas


func _draw_attunement_constellation(canvas: Control) -> void:
	var charge_ratio := 1.0
	if _attunement_vessel_fill != null and _attunement_vessel_fill.max_value > 0.0:
		charge_ratio = clampf(
			_attunement_vessel_fill.value / _attunement_vessel_fill.max_value, 0.0, 1.0)
	var stars := [
		Vector2(33, 58), Vector2(47, 36), Vector2(61, 28),
		Vector2(78, 50), Vector2(57, 73), Vector2(39, 74),
	]
	var links := [[0, 1], [1, 2], [2, 3], [1, 4]]
	var base_alpha := lerpf(0.40, 0.90, charge_ratio)
	var t := Time.get_ticks_msec() / 1000.0
	for link in links:
		var a: Vector2 = stars[int(link[0])]
		var b: Vector2 = stars[int(link[1])]
		canvas.draw_line(a, b, Color(0.04, 0.23, 0.36, 0.28 + 0.14 * charge_ratio), 3.0)
		canvas.draw_line(a, b, Color(0.75, 0.94, 1.0, 0.18 + 0.24 * charge_ratio), 1.5)
	for i in range(stars.size()):
		var p: Vector2 = stars[i]
		var wave := 0.5 + 0.5 * sin(t * (1.7 + float(i) * 0.19) + float(i) * 1.31)
		var alpha := clampf(base_alpha * (0.48 + 0.52 * wave), 0.18, 0.95)
		var arm := 3.0 + (1.0 if wave > 0.76 else 0.0)
		var shadow_color := Color(0.03, 0.20, 0.34, 0.34 + 0.22 * charge_ratio)
		var star_color := Color(0.82, 0.96, 1.0, alpha)
		var core_color := Color(0.98, 1.0, 1.0, minf(1.0, alpha + 0.12))
		canvas.draw_line(p + Vector2(-arm - 1.0, 0), p + Vector2(arm + 1.0, 0), shadow_color, 3.0)
		canvas.draw_line(p + Vector2(0, -arm - 1.0), p + Vector2(0, arm + 1.0), shadow_color, 3.0)
		canvas.draw_line(p + Vector2(-arm, 0), p + Vector2(arm, 0), star_color, 2.0)
		canvas.draw_line(p + Vector2(0, -arm), p + Vector2(0, arm), star_color, 2.0)
		canvas.draw_circle(p, 2.0, Color(0.70, 0.91, 1.0, minf(0.58, alpha)))
		canvas.draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), core_color)


func _add_kit_button(parent: Control, rect_value: Variant, text: String,
		icon_id: String, content: Dictionary, action: Callable) -> void:
	var button := Button.new()
	button.name = "DockAction" + text.replace(" ", "")
	button.tooltip_text = "Open %s panel" % text
	button.focus_mode = Control.FOCUS_ALL
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _texture_style("button_frame_normal"))
	button.add_theme_stylebox_override("hover", _texture_style("button_frame_hover"))
	button.add_theme_stylebox_override("pressed", _texture_style("button_frame_pressed"))
	button.add_theme_stylebox_override("focus", _texture_style("button_frame_hover"))
	_place(button, _json_rect(rect_value))
	button.z_index = 4
	button.pressed.connect(action)
	parent.add_child(button)
	var icon := TextureRect.new()
	icon.name = button.name + "Icon"
	icon.texture = _painted_texture(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(icon, _json_rect(content.get("icon_rect")))
	button.add_child(icon)
	var label := Label.new()
	label.name = button.name + "Label"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, _json_rect(content.get("label_rect")))
	button.add_child(label)


func _build_bottom_left() -> void:
	# Primary path: a native-size layered HUD kit plus one integer geometry
	# contract. The sliced blueprint composition remains below as fallback.
	var kit_layout := _load_hud_kit_layout()
	if _hud_kit_available(kit_layout):
		_build_hud_kit(kit_layout)
		return
	# FQ-21: the one-piece full-width painted band when its pieces and the
	# geometry sidecar exist; the FQ-19 modular construction is the fallback.
	var band_geometry := _load_band_geometry()
	if not band_geometry.is_empty() \
			and _painted_texture("dock_left_cap") != null \
			and _painted_texture("dock_right_cap") != null \
			and _painted_texture("dock_center_block") != null \
			and _painted_texture("dock_mid_tile") != null:
		_build_dock_band(band_geometry)
		return
	# FQ-19 blueprint band (Photo 1/2): the two resource orbs are their own
	# flanking objects beside ONE central hotbar/nav panel — not decorations
	# inside a single wide plate. The whole band is the movable "dock" widget;
	# the backplate spans only the central panel.
	var band := HBoxContainer.new()
	_bottom_dock = band
	band.anchor_left = 0.5
	band.anchor_right = 0.5
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_left = -410
	band.offset_right = 410
	band.offset_top = -200
	band.offset_bottom = -24
	band.alignment = BoxContainer.ALIGNMENT_CENTER
	band.add_theme_constant_override("separation", 6)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var health_vessel := _make_resource_vessel("orb_health_frame", Color(0.82, 0.12, 0.10))
	health_vessel.name = "HealthVessel"
	_health_vessel_fill = health_vessel.get_node("Fill") as Range
	_health_vessel_label = health_vessel.get_node("Value") as Label
	_health_fx = health_vessel.get_node("Fx") as TextureRect
	_health_label = _health_vessel_label
	health_vessel.size_flags_vertical = Control.SIZE_SHRINK_END
	band.add_child(health_vessel)
	var panel := PanelContainer.new()
	_dock_panel = panel
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# FQ-20: the painted riveted bar strip from the mockup; then the FQ-19
	# generated backplate; then the code-drawn plate.
	var plate: Texture2D = _painted_texture("dock_plate")
	var backplate: Texture2D = BlockRegistry.visual_texture("ui", "dock_backplate")
	if plate != null:
		var plate_art := StyleBoxTexture.new()
		plate_art.texture = plate
		# TILE horizontally: stretching a 24px strip across the whole dock
		# smeared the wood grain into streaks (operator polish loop 2).
		plate_art.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		plate_art.texture_margin_top = 18
		plate_art.texture_margin_bottom = 18
		plate_art.texture_margin_left = 6
		plate_art.texture_margin_right = 6
		# Rails are 18px of art; content clears them plus air on every side.
		plate_art.content_margin_top = 26
		plate_art.content_margin_bottom = 24
		plate_art.content_margin_left = 22
		plate_art.content_margin_right = 22
		panel.add_theme_stylebox_override("panel", plate_art)
	elif backplate != null:
		var dock_art := StyleBoxTexture.new()
		dock_art.texture = backplate
		dock_art.set_texture_margin_all(8)   # 9-slice: rivets stay in the corners
		dock_art.set_content_margin_all(10)
		panel.add_theme_stylebox_override("panel", dock_art)
	else:
		var dock_style := StyleBoxFlat.new()
		dock_style.bg_color = Color(0.035, 0.045, 0.065, 0.94)
		dock_style.border_color = Color(0.55, 0.42, 0.24, 0.95)
		dock_style.set_border_width_all(2)
		dock_style.set_corner_radius_all(8)
		dock_style.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", dock_style)
	band.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	_mine_bar = ProgressBar.new()
	_mine_bar.custom_minimum_size = Vector2(180, 10)
	_mine_bar.show_percentage = false
	_mine_bar.visible = false
	box.add_child(_mine_bar)
	# FQ-09: the toolbelt is a row of slot tiles — icon (art or FQ-07
	# fallback swatch), count, and a gold border on the selected slot. The
	# text line below keeps the tool/extras summary.
	# Intentionally SHARED StyleBox instances across all five slots (Godot
	# reads them without mutating) — clone before mutating per slot.
	_slot_normal_sb = _make_slot_style("slot_inventory", Color(0.35, 0.35, 0.4))
	_slot_selected_sb = _make_slot_style("slot_inventory_selected", Color(0.95, 0.8, 0.25))
	var dock_row := HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 8)
	box.add_child(dock_row)
	# FQ-19 blueprint order inside the panel: Inventory/Character · five
	# slots · Skills/Town Hall (the orbs flank the panel outside it).
	var nav_left := HBoxContainer.new()
	nav_left.add_theme_constant_override("separation", 3)
	nav_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dock_row.add_child(nav_left)
	_add_dock_action_button(nav_left, "Inventory", "button_inventory",
		func(): toggle_inventory_panel())
	_add_dock_action_button(nav_left, "Character", "button_character",
		func(): toggle_character_panel())
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 2)
	# Blueprint slots stay compact squares centered on the orb axis instead of
	# stretching to the vessel height.
	slot_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dock_row.add_child(slot_row)
	for i in range(5):
		# The MarginContainer wrapper reserves 3px of travel so selecting a
		# slot raises it without shifting its neighbors (blueprint treatment).
		var cell := MarginContainer.new()
		cell.add_theme_constant_override("margin_top", 3)
		cell.add_theme_constant_override("margin_bottom", 0)
		slot_row.add_child(cell)
		var slot := PanelContainer.new()
		# FQ-20: blueprint-proportioned slots (38-44 design px ~= 56 at the
		# 1280 logical width) wearing the painted mockup frames.
		slot.custom_minimum_size = Vector2(56, 60)
		slot.add_theme_stylebox_override("panel", _slot_normal_sb)
		cell.add_child(slot)
		# Blueprint corners (operator polish pass): LARGE icon centered in
		# the cell, count in the bottom-right corner, key number in the
		# top-left — overlapping full-rect children, no dead bottom band.
		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_center)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_center.add_child(icon)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.size_flags_vertical = Control.SIZE_SHRINK_END
		count.add_theme_font_size_override("font_size", 11)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)
		var key_tag := Label.new()
		key_tag.text = str(i + 1)
		key_tag.add_theme_font_size_override("font_size", 9)
		key_tag.add_theme_color_override("font_color", Color(0.89, 0.75, 0.43, 0.9))
		key_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Label defaults to SHRINK_CENTER vertically; pin the tag to the
		# slot's top corner (blueprint key-number position).
		key_tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		key_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key_tag)
		_hotbar_cells.append(cell)
		_hotbar_slots.append(slot)
		_hotbar_icons.append(icon)
		_hotbar_counts.append(count)
	var nav_right := HBoxContainer.new()
	nav_right.add_theme_constant_override("separation", 3)
	nav_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dock_row.add_child(nav_right)
	_add_dock_action_button(nav_right, "Skills", "button_skills",
		func(): toggle_skill_panel())
	_add_dock_action_button(nav_right, "Town Hall", "button_town_hall",
		func(): toggle_town_panel())
	_hotbar_label = _label(box, "")
	_hotbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar_label.add_theme_font_size_override("font_size", 12)
	var hint := _label(box, "LMB mine · RMB place · E town hall · C craft · O goals · M map · F5 save · F9 load")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	# FQ-20: the command center row — module open/close chips live here.
	var attunement_vessel := _make_resource_vessel("orb_attunement_frame",
		Color(0.08, 0.60, 0.95), true)
	attunement_vessel.name = "AttunementVessel"
	_attunement_vessel_fill = attunement_vessel.get_node("Fill") as Range
	_attunement_vessel_label = attunement_vessel.get_node("Value") as Label
	_attunement_fx = attunement_vessel.get_node("Fx") as TextureRect
	_attunement_frame = attunement_vessel.get_node("Frame") as Control
	_attunement_core = attunement_vessel.get_node("Core") as Control
	_attunement_label = _attunement_vessel_label
	attunement_vessel.size_flags_vertical = Control.SIZE_SHRINK_END
	band.add_child(attunement_vessel)


## FQ-19/20: glyph nav button — the painted mockup button (frame + glyph
## baked) when present, else the generated glyph, else the text fallback. The
## stable node name is the machine-readable identity either way.
func _add_dock_action_button(row: HBoxContainer, text: String, ui_id: String,
		action: Callable) -> void:
	var button := Button.new()
	button.name = "DockAction" + text.replace(" ", "")
	var glyph: Texture2D = _painted_texture(ui_id)
	if glyph == null:
		glyph = BlockRegistry.visual_texture("ui", ui_id)
	if glyph != null:
		button.icon = glyph
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		# Aspect-true to the painted 48x52 glyphs so the frame never crops.
		button.custom_minimum_size = Vector2(42, 46)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		# The plate is baked into the glyph art, so state feedback rides on
		# the icon tint instead of a stylebox.
		button.add_theme_color_override("icon_normal_color", Color(0.92, 0.92, 0.9))
		button.add_theme_color_override("icon_hover_color", Color.WHITE)
		button.add_theme_color_override("icon_pressed_color", Color(0.75, 0.72, 0.62))
	else:
		button.text = text
		button.custom_minimum_size = Vector2(76 if text != "Town Hall" else 86, 22)
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "Open %s panel" % text
	button.pressed.connect(action)
	row.add_child(button)


# FQ-20: painted orb geometry measured by scripts/art/slice_hud_chrome.py —
# the slicer prints these values ("health orb: cx=98 cy=102 glass_r=56" + the
# punch offsets) on every run; re-slicing the mockup means re-checking them.
# All values in texture pixels: glass center and punched radius.
# "overlay" vessels keep their baked crystal art and render charge as a
# luminous bottom-up brightener instead of an opaque liquid over a punched
# hole (the attunement crystal is not a liquid — operator polish loop).
const PAINTED_ORB_GEOMETRY := {
	# Radius follows the punch's SHORT axis (the fill disk is a circle; a
	# disk sized to the long axis overlapped the ring bevels top/bottom).
	"orb_health_frame": {"tex": Vector2(180, 196), "center": Vector2(98, 102), "radius": 60.0},
	"orb_attunement_frame": {"tex": Vector2(188, 216), "center": Vector2(82, 81), "radius": 48.0, "overlay": true},
}
const PAINTED_ORB_WIDTH := 112.0
const DOCK_BAND_SCALE := 0.8   # band display px per mockup art px
const DOCK_BOTTOM_CUSHION := 8.0
var _glass_mask_cache: Dictionary = {}   # diameter -> ImageTexture
var _scaled_tex_cache: Dictionary = {}   # "id@scale" -> ImageTexture


## FQ-21: slicer-measured band geometry — hud.gd never hand-syncs mockup
## coordinates again (that was the source of the masking misalignments).
func _load_band_geometry() -> Dictionary:
	var raw := FileAccess.get_file_as_string(
		"res://art/generated/ui_painted/dock_band_geometry.json")
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func _load_hud_kit_layout() -> Dictionary:
	var raw := FileAccess.get_file_as_string(
		"res://art/generated/ui_painted/hud_dock_layout.json")
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


func _hud_kit_available(layout: Dictionary) -> bool:
	if int(layout.get("version", 0)) < 2:
		return false
	var required_assets: Array = layout.get("required_assets", [])
	if required_assets.is_empty():
		return false
	for asset_file in required_assets:
		var asset_id := str(asset_file).trim_suffix(".png")
		if _painted_texture(asset_id) == null:
			return false
	var roles: Dictionary = {}
	for raw_layer in layout.get("decorative_layers", []):
		if raw_layer is Dictionary:
			roles[str((raw_layer as Dictionary).get("role", ""))] = true
	if not roles.has("backplate") or not roles.has("foreground_trim"):
		return false
	return true


func _json_rect(value: Variant) -> Rect2:
	if value is Array and (value as Array).size() >= 4:
		return Rect2(float(value[0]), float(value[1]),
			float(value[2]), float(value[3]))
	return Rect2()


func _place(control: Control, rect: Rect2) -> void:
	# HUD-kit coordinates are native integer pixels. No per-asset scale or
	# fractional resizing is introduced by the runtime assembler.
	control.position = rect.position.round()
	control.size = rect.size.round()


func _texture_style(asset_id: String, draw_center: bool = true) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _painted_texture(asset_id)
	style.draw_center = draw_center
	return style


func _json_vec(pair: Variant) -> Vector2:
	if pair is Array and (pair as Array).size() >= 2:
		return Vector2(float(pair[0]), float(pair[1]))
	return Vector2.ZERO


## A texture pre-resized on the CPU (TextureRect STRETCH_TILE tiles at the
## texture's native size, so the tile must be baked at display scale).
func _scaled_texture(id: String, factor: float) -> Texture2D:
	var key := "%s@%f" % [id, factor]
	if _scaled_tex_cache.has(key):
		return _scaled_tex_cache[key]
	var src: Texture2D = _painted_texture(id)
	if src == null:
		return null
	var img: Image = src.get_image()
	img.resize(int(round(img.get_width() * factor)),
		int(round(img.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_scaled_tex_cache[key] = tex
	return tex


## FQ-20 polish: the 32px disk mask cropped to its disk (art px 5..26) and
## resized to the exact glass diameter. TextureProgressBar can then crop the
## liquid natively (nine-patch stretching SQUASHES the disk instead of
## draining it — the "health never drops" bug the operator caught).
func _glass_mask_texture(diameter: int) -> Texture2D:
	if _glass_mask_cache.has(diameter):
		return _glass_mask_cache[diameter]
	var src: Texture2D = BlockRegistry.visual_texture("ui", "orb_fill_mask")
	if src == null:
		return null
	var disk: Image = src.get_image().get_region(Rect2i(5, 5, 22, 22))
	disk.resize(diameter, diameter, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(disk)
	_glass_mask_cache[diameter] = tex
	return tex


## One flanking resource orb — its own object (Photo 1/2) with the numeric
## value beneath. FQ-20: the painted mockup ring when present (glass geometry
## from PAINTED_ORB_GEOMETRY); else the FQ-19 generated ring, where the
## transparent hole is art px 5..26 of 32, so at 3x the liquid disk sits at
## (15,15) with diameter 66.
func _make_resource_vessel(ui_id: String, fill_color: Color,
		with_core: bool = false) -> Control:
	# Resolve the frame art and the glass geometry it dictates.
	var painted: Texture2D = _painted_texture(ui_id)
	var frame_tex: Texture2D
	var frame_size: Vector2
	var glass_center: Vector2
	var glass_radius: float
	var charge_overlay := false
	if painted != null and PAINTED_ORB_GEOMETRY.has(ui_id):
		var geometry: Dictionary = PAINTED_ORB_GEOMETRY[ui_id]
		var art_scale: float = PAINTED_ORB_WIDTH / (geometry.tex as Vector2).x
		frame_tex = painted
		frame_size = (geometry.tex as Vector2) * art_scale
		glass_center = (geometry.center as Vector2) * art_scale
		glass_radius = float(geometry.radius) * art_scale
		charge_overlay = bool(geometry.get("overlay", false))
	else:
		frame_tex = BlockRegistry.visual_texture("ui", ui_id)
		frame_size = Vector2(96, 96)
		glass_center = Vector2(48, 48)
		glass_radius = 33.0
	# The liquid disk spans the punched hole exactly; the punch already
	# clears the ring's inner bevel (operator polish finding).
	var glass_d: int = int(round(glass_radius * 2.0))
	var fill_rect := Rect2(glass_center - Vector2(glass_d, glass_d) / 2.0,
		Vector2(glass_d, glass_d))
	var vessel := Control.new()
	vessel.name = "ResourceVessel"
	vessel.custom_minimum_size = Vector2(frame_size.x, frame_size.y + 16)
	vessel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Masked bottom-up liquid when the disk mask exists — the fluid is
	# clipped to the orb interior so it can never bleed under the ring frame.
	# The original code-drawn ProgressBar stays as the validated fallback.
	var mask: Texture2D = _glass_mask_texture(glass_d)
	var fill: Range
	if mask != null:
		# nine_patch_stretch stays OFF: the texture is pre-sized to the
		# control, so FILL_BOTTOM_TO_TOP truly crops and the pool drains.
		var liquid := TextureProgressBar.new()
		liquid.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
		liquid.texture_under = mask
		liquid.texture_progress = mask
		if charge_overlay:
			# Crystal charge: dim the uncharged art, brighten the charged
			# part — the baked crystal stays visible either way.
			liquid.tint_under = Color(0.0, 0.02, 0.1, 0.62)
			liquid.tint_progress = Color(0.5, 0.9, 1.0, 0.42)
		else:
			liquid.tint_under = Color(0.02, 0.04, 0.08, 0.88)
			liquid.tint_progress = fill_color
		liquid.position = fill_rect.position
		liquid.size = fill_rect.size
		fill = liquid
	else:
		# Code-drawn fallback: a rounded square inset to the glass interior.
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		var empty_style := StyleBoxFlat.new()
		empty_style.bg_color = Color(0.02, 0.04, 0.08, 0.88)
		empty_style.set_corner_radius_all(int(glass_radius))
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.set_corner_radius_all(int(glass_radius))
		bar.add_theme_stylebox_override("background", empty_style)
		bar.add_theme_stylebox_override("fill", fill_style)
		bar.position = glass_center - Vector2(glass_radius, glass_radius)
		bar.size = Vector2(glass_radius, glass_radius) * 2.0
		fill = bar
	fill.name = "Fill"
	fill.min_value = 0.0
	fill.max_value = 100.0
	fill.value = 100.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.position = Vector2.ZERO
	frame.size = frame_size
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = frame_tex
	frame.pivot_offset = frame_size / 2.0   # use-pulse scales around center
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Liquid vessels: fluid UNDER the ring (punched glass shows it).
	# Charge overlays: brightener OVER the baked crystal art.
	if charge_overlay:
		vessel.add_child(frame)
		vessel.add_child(fill)
	else:
		vessel.add_child(fill)
		vessel.add_child(frame)
	if with_core:
		# Blueprint "bright geometric core": a rotating diamond, dim while
		# charging and bright at full attunement.
		var core := ColorRect.new()
		core.name = "Core"
		core.color = Color(0.82, 0.96, 1.0)
		core.position = glass_center - Vector2(7, 7)
		core.size = Vector2(14, 14)
		core.pivot_offset = Vector2(7, 7)
		core.rotation = PI / 4.0
		core.self_modulate = Color(0.4, 0.65, 0.85, 0.5)
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vessel.add_child(core)
	# Effect overlay — damage flash / recovery glow / regeneration shimmer
	# land here as a tinted disk that tweens back to transparent. Shares the
	# fill rect so the mask's disk aligns with the glass hole.
	var fx := TextureRect.new()
	fx.name = "Fx"
	fx.position = fill_rect.position
	fx.size = fill_rect.size
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.texture = mask
	fx.self_modulate = Color(1, 1, 1, 0)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vessel.add_child(fx)
	var value := Label.new()
	value.name = "Value"
	value.position = Vector2(0, frame_size.y + 1)
	value.size = Vector2(frame_size.x, 14)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vessel.add_child(value)
	return vessel


## FQ-21: the one-piece full-width dock band. Everything painted comes from
## four native-aspect pieces (nothing 9-sliced, nothing color-keyed); only
## the clean plate strip TILES to span the width. All coordinates come from
## the slicer's geometry sidecar, scaled by DOCK_BAND_SCALE.
func _build_dock_band(geometry: Dictionary) -> void:
	_dock_band_active = true
	var s := DOCK_BAND_SCALE
	var left_geo: Dictionary = geometry.get("left_cap", {})
	var right_geo: Dictionary = geometry.get("right_cap", {})
	var block_geo: Dictionary = geometry.get("center_block", {})
	var tile_geo: Dictionary = geometry.get("mid_tile", {})
	var left_size: Vector2 = _json_vec(left_geo.get("size")) * s
	var right_size: Vector2 = _json_vec(right_geo.get("size")) * s
	var block_size: Vector2 = _json_vec(block_geo.get("size")) * s
	var left_y: float = float(left_geo.get("y_offset", 0)) * s
	var right_y: float = float(right_geo.get("y_offset", 0)) * s
	var plate_y: float = float(block_geo.get("y_offset", 0)) * s
	var band_h: float = maxf(left_y + left_size.y,
		maxf(right_y + right_size.y, plate_y + block_size.y)) \
		+ DOCK_BOTTOM_CUSHION

	var band := Control.new()
	_bottom_dock = band
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_left = 0.0
	band.offset_right = 0.0
	band.offset_top = -band_h
	band.offset_bottom = 0.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	# --- health liquid UNDER the left cap (shows through the punched glass).
	var health_glass_center: Vector2 = _json_vec(left_geo.get("glass_center")) * s
	var health_glass_d: int = int(round(float(left_geo.get("glass_radius", 40)) * s * 2.0))
	var health_mask: Texture2D = _glass_mask_texture(health_glass_d)
	var health_fill := TextureProgressBar.new()
	health_fill.name = "HealthFill"
	health_fill.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	health_fill.texture_under = health_mask
	health_fill.tint_under = Color(0.02, 0.04, 0.08, 0.88)
	var health_liquid_tex: Texture2D = _scaled_texture("health_liquid", s)
	health_fill.texture_progress = health_liquid_tex if health_liquid_tex != null else health_mask
	health_fill.tint_progress = Color.WHITE if health_liquid_tex != null \
		else Color(0.82, 0.12, 0.10)
	health_fill.max_value = 100.0
	health_fill.value = 100.0
	health_fill.position = Vector2(0, left_y) + health_glass_center \
		- Vector2(health_glass_d, health_glass_d) / 2.0
	health_fill.size = Vector2(health_glass_d, health_glass_d)
	health_fill.z_index = 1
	health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(health_fill)
	_health_vessel_fill = health_fill

	# --- the four painted pieces.
	var left_cap := TextureRect.new()
	left_cap.name = "BandLeftCap"
	left_cap.texture = _painted_texture("dock_left_cap")
	left_cap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_cap.stretch_mode = TextureRect.STRETCH_SCALE
	left_cap.position = Vector2(0, left_y)
	left_cap.size = left_size
	left_cap.z_index = 2
	left_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(left_cap)

	var tile_tex: Texture2D = _scaled_texture("dock_mid_tile", s)
	var tile_h: float = _json_vec(tile_geo.get("size")).y * s
	var tile_y: float = float(tile_geo.get("y_offset", 0)) * s
	var tile_left := TextureRect.new()
	tile_left.name = "BandTileLeft"
	tile_left.texture = tile_tex
	tile_left.stretch_mode = TextureRect.STRETCH_TILE
	tile_left.anchor_left = 0.0
	tile_left.anchor_right = 0.5
	tile_left.offset_left = left_size.x - 1.0
	tile_left.offset_right = -block_size.x / 2.0 + 1.0
	tile_left.offset_top = tile_y
	tile_left.offset_bottom = tile_y + tile_h
	tile_left.z_index = 0
	tile_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(tile_left)

	var tile_right := TextureRect.new()
	tile_right.name = "BandTileRight"
	tile_right.texture = tile_tex
	tile_right.stretch_mode = TextureRect.STRETCH_TILE
	tile_right.anchor_left = 0.5
	tile_right.anchor_right = 1.0
	tile_right.offset_left = block_size.x / 2.0 - 1.0
	tile_right.offset_right = -right_size.x + 1.0
	tile_right.offset_top = tile_y
	tile_right.offset_bottom = tile_y + tile_h
	tile_right.z_index = 0
	tile_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(tile_right)

	var block := TextureRect.new()
	block.name = "BandCenterBlock"
	_dock_panel = block
	block.texture = _painted_texture("dock_center_block")
	block.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	block.stretch_mode = TextureRect.STRETCH_SCALE
	block.anchor_left = 0.5
	block.anchor_right = 0.5
	block.offset_left = -block_size.x / 2.0
	block.offset_right = block_size.x / 2.0
	block.offset_top = plate_y
	block.offset_bottom = plate_y + block_size.y
	block.z_index = 0
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(block)

	var right_cap := TextureRect.new()
	right_cap.name = "BandRightCap"
	right_cap.texture = _painted_texture("dock_right_cap")
	right_cap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right_cap.stretch_mode = TextureRect.STRETCH_SCALE
	right_cap.anchor_left = 1.0
	right_cap.anchor_right = 1.0
	right_cap.offset_left = -right_size.x
	right_cap.offset_right = 0.0
	right_cap.offset_top = right_y
	right_cap.offset_bottom = right_y + right_size.y
	right_cap.pivot_offset = right_size / 2.0
	right_cap.z_index = 2
	right_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(right_cap)
	_attunement_frame = right_cap

	# --- attunement charge follows the crystal facets; no circular matte.
	var crystal_center: Vector2 = _json_vec(right_geo.get("crystal_center")) * s
	var crystal_d: int = int(round(float(right_geo.get("crystal_radius", 40)) * s * 2.0))
	var crystal_mask: Texture2D = _scaled_texture("attunement_charge", s)
	if crystal_mask == null:
		crystal_mask = _glass_mask_texture(crystal_d)
	var charge := TextureProgressBar.new()
	charge.name = "AttunementFill"
	charge.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	charge.texture_under = crystal_mask
	charge.tint_under = Color(0.08, 0.12, 0.20, 0.42)
	charge.texture_progress = crystal_mask
	charge.tint_progress = Color.WHITE
	charge.max_value = 100.0
	charge.value = 100.0
	charge.anchor_left = 1.0
	charge.anchor_right = 1.0
	charge.offset_left = -right_size.x + crystal_center.x - crystal_d / 2.0
	charge.offset_right = charge.offset_left + crystal_d
	charge.offset_top = right_y + crystal_center.y - crystal_d / 2.0
	charge.offset_bottom = charge.offset_top + crystal_d
	charge.pivot_offset = Vector2(crystal_d, crystal_d) / 2.0
	charge.z_index = 1
	charge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(charge)
	_attunement_vessel_fill = charge
	var core := TextureRect.new()
	core.name = "Core"
	core.texture = _scaled_texture("attunement_core", s)
	core.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	core.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var core_size := Vector2(27, 27)
	if core.texture != null:
		core_size = core.texture.get_size()
	var core_center := Vector2(crystal_center.x, right_y + crystal_center.y)
	core.anchor_left = 1.0
	core.anchor_right = 1.0
	core.offset_left = -right_size.x + core_center.x - core_size.x / 2.0
	core.offset_right = core.offset_left + core_size.x
	core.offset_top = core_center.y - core_size.y / 2.0
	core.offset_bottom = core.offset_top + core_size.y
	core.pivot_offset = core_size / 2.0
	core.self_modulate = Color(0.4, 0.65, 0.85, 0.5)
	core.z_index = 3
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(core)
	_attunement_core = core

	# --- effect overlays (flash/glow/shimmer) above each vessel.
	var health_fx := TextureRect.new()
	health_fx.name = "HealthFx"
	health_fx.texture = health_mask
	health_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	health_fx.position = health_fill.position
	health_fx.size = health_fill.size
	health_fx.z_index = 3
	health_fx.self_modulate = Color(1, 1, 1, 0)
	health_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(health_fx)
	_health_fx = health_fx
	var attune_fx := TextureRect.new()
	attune_fx.name = "AttunementFx"
	attune_fx.texture = crystal_mask
	attune_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	attune_fx.anchor_left = 1.0
	attune_fx.anchor_right = 1.0
	attune_fx.offset_left = charge.offset_left
	attune_fx.offset_right = charge.offset_right
	attune_fx.offset_top = charge.offset_top
	attune_fx.offset_bottom = charge.offset_bottom
	attune_fx.z_index = 3
	attune_fx.self_modulate = Color(1, 1, 1, 0)
	attune_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(attune_fx)
	_attunement_fx = attune_fx
	# Persistent glass/refraction sits above liquid and transient FX, while
	# the punched iron cap remains the physical foreground rim.
	var health_glass_tex: Texture2D = _scaled_texture("health_glass", s)
	if health_glass_tex != null:
		var health_glass := TextureRect.new()
		health_glass.name = "HealthGlass"
		health_glass.texture = health_glass_tex
		health_glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		health_glass.stretch_mode = TextureRect.STRETCH_SCALE
		health_glass.position = health_fill.position
		health_glass.size = health_fill.size
		health_glass.z_index = 3
		health_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(health_glass)

	# --- numeric values ON the glass (blueprint: "83 / 100" on the orb).
	_health_vessel_label = _vessel_value_label(band)
	_health_vessel_label.position = Vector2(0, left_y) \
		+ health_glass_center - Vector2(40, 8)
	_health_vessel_label.z_index = 4
	_health_label = _health_vessel_label
	_attunement_vessel_label = _vessel_value_label(band)
	_attunement_vessel_label.anchor_left = 1.0
	_attunement_vessel_label.anchor_right = 1.0
	_attunement_vessel_label.offset_left = -right_size.x + crystal_center.x - 40.0
	_attunement_vessel_label.offset_right = _attunement_vessel_label.offset_left + 80.0
	_attunement_vessel_label.offset_top = right_y + crystal_center.y - 8.0
	_attunement_vessel_label.offset_bottom = right_y + crystal_center.y + 8.0
	_attunement_vessel_label.z_index = 4
	_attunement_label = _attunement_vessel_label

	# --- FQ-21 vessel sockets: the future liquid mechanic swaps the fill
	# node here; update_health/update_attunement only drive Range.
	_vessel_sockets = {
		"health": {"glass_center": Vector2(0, left_y) + health_glass_center,
			"glass_diameter": health_glass_d, "fill": health_fill},
		"attunement": {"crystal_center": Vector2(crystal_center.x,
			right_y + crystal_center.y),
			"crystal_diameter": crystal_d, "fill": charge},
	}

	# --- slot overlays on the block: icon centered, count bottom-right,
	# key number top-left; selection = gold border stylebox over the frame.
	# Content margins keep the key tag / count clear of the baked frame's
	# corner hinges.
	var empty_sb := StyleBoxEmpty.new()
	empty_sb.set_content_margin_all(7)
	_slot_normal_sb = empty_sb
	var gold: Texture2D = _painted_texture("slot_frame_selected")
	if gold != null:
		var gsb := StyleBoxTexture.new()
		gsb.texture = gold
		gsb.set_texture_margin_all(14)
		gsb.set_content_margin_all(7)
		gsb.draw_center = false
		_slot_selected_sb = gsb
	else:
		var gfb := StyleBoxFlat.new()
		gfb.border_color = Color(0.95, 0.8, 0.25)
		gfb.set_border_width_all(2)
		gfb.draw_center = false
		_slot_selected_sb = gfb
	var slot_rects: Array = block_geo.get("slots", [])
	for i in range(mini(5, slot_rects.size())):
		var r: Array = slot_rects[i]
		var slot := PanelContainer.new()
		slot.position = Vector2(float(r[0]), float(r[1])) * s
		slot.size = Vector2(float(r[2]), float(r[3])) * s
		slot.add_theme_stylebox_override("panel", _slot_normal_sb)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(slot)
		var icon_center := CenterContainer.new()
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_center)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_center.add_child(icon)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.size_flags_vertical = Control.SIZE_SHRINK_END
		count.add_theme_font_size_override("font_size", 11)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)
		var key_tag := Label.new()
		key_tag.text = str(i + 1)
		key_tag.add_theme_font_size_override("font_size", 9)
		key_tag.add_theme_color_override("font_color", Color(0.89, 0.75, 0.43, 0.9))
		key_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		key_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key_tag)
		_hotbar_slots.append(slot)
		_hotbar_icons.append(icon)
		_hotbar_counts.append(count)

	# --- invisible click zones over the baked nav buttons (labels baked).
	var buttons: Dictionary = block_geo.get("buttons", {})
	_add_band_button(block, buttons.get("inventory"), s, "Inventory",
		func(): toggle_inventory_panel())
	_add_band_button(block, buttons.get("character"), s, "Character",
		func(): toggle_character_panel())
	_add_band_button(block, buttons.get("skills"), s, "Skills",
		func(): toggle_skill_panel())
	_add_band_button(block, buttons.get("town_hall"), s, "Town Hall",
		func(): toggle_town_panel())

	# --- command center chips between the pedestals, under the plate.

	# --- floating summary chip above the plate (mockup floating-chip style).
	var summary_chip := PanelContainer.new()
	summary_chip.add_theme_stylebox_override("panel", _chip_style())
	summary_chip.position = Vector2(left_size.x + 8.0, 2.0)
	summary_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(summary_chip)
	_hotbar_label = Label.new()
	_hotbar_label.add_theme_font_size_override("font_size", 11)
	summary_chip.add_child(_hotbar_label)

	# --- mining progress floats above the band center (blueprint position).
	_mine_bar = ProgressBar.new()
	_mine_bar.custom_minimum_size = Vector2(180, 10)
	_mine_bar.show_percentage = false
	_mine_bar.visible = false
	_mine_bar.anchor_left = 0.5
	_mine_bar.anchor_right = 0.5
	_mine_bar.offset_left = -90.0
	_mine_bar.offset_right = 90.0
	_mine_bar.offset_top = plate_y - 16.0
	_mine_bar.offset_bottom = plate_y - 6.0
	band.add_child(_mine_bar)


func _vessel_value_label(parent: Control) -> Label:
	var value := Label.new()
	value.size = Vector2(80, 16)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	value.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	value.add_theme_constant_override("shadow_offset_x", 1)
	value.add_theme_constant_override("shadow_offset_y", 1)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(value)
	return value


## Full nav-cell click zone over a baked button (glyph + label + pedestal).
func _add_band_button(block: Control, zone: Variant, s: float, text: String,
		action: Callable) -> void:
	if not (zone is Array) or (zone as Array).size() < 4:
		return
	var button := Button.new()
	button.name = "DockAction" + text.replace(" ", "")
	button.position = Vector2(float(zone[0]), float(zone[1])) * s
	button.size = Vector2(float(zone[2]), float(zone[3])) * s
	button.tooltip_text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var sheen := StyleBoxFlat.new()
	sheen.bg_color = Color(0.95, 0.78, 0.35, 0.16)
	sheen.border_color = Color(0.95, 0.78, 0.35, 0.72)
	sheen.set_border_width_all(1)
	sheen.set_corner_radius_all(3)
	button.add_theme_stylebox_override("hover", sheen)
	var pressed := sheen.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.95, 0.72, 0.25, 0.28)
	pressed.set_border_width_all(2)
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(0.95, 0.8, 0.4, 0.9)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(3)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	block.add_child(button)


## FQ-21 socket API for the future liquid mechanic: read the glass geometry
## and the current fill, or swap in a custom fill (any Range-derived Control;
## the HUD keeps driving it purely through value/max_value).
func vessel_socket(kind: String) -> Dictionary:
	return _vessel_sockets.get(kind, {})


func replace_vessel_fill(kind: String, replacement: Range) -> bool:
	var socket: Dictionary = _vessel_sockets.get(kind, {})
	var current: Range = socket.get("fill")
	if current == null or replacement == null:
		return false
	replacement.min_value = current.min_value
	replacement.max_value = current.max_value
	replacement.value = current.value
	current.add_sibling(replacement)
	replacement.position = current.position
	replacement.size = current.size
	current.queue_free()
	socket["fill"] = replacement
	if kind == "health":
		_health_vessel_fill = replacement
	elif kind == "attunement":
		_attunement_vessel_fill = replacement
	return true


## FQ-13P2: a slot frame from the best available art — the FQ-20 painted
## mockup frame, else the reserved UI placeholder (art/generated/ui/<id>.png),
## else the original code-drawn flat fallback. A missing image is never an
## error.
func _make_slot_style(ui_id: String, border: Color) -> StyleBox:
	var painted_id := ""
	if ui_id == "slot_inventory":
		painted_id = "slot_frame"
	elif ui_id == "slot_inventory_selected":
		painted_id = "slot_frame_selected"
	if painted_id != "":
		var ptex: Texture2D = _painted_texture(painted_id)
		if ptex != null:
			var psb := StyleBoxTexture.new()
			psb.texture = ptex
			psb.set_texture_margin_all(14 if painted_id == "slot_frame_selected" else 12)
			psb.set_content_margin_all(8)
			return psb
	var tex := BlockRegistry.visual_texture("ui", ui_id)
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.set_texture_margin_all(6)   # 9-slice the frame corners
		sbt.set_content_margin_all(3)
		return sbt
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14, 0.85)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(3)
	return sb


## FQ-09: one icon+count tile for the item grids. Descriptor arrives on hover
## via the tooltip (display name + items.json description when present).
func _make_item_tile(parent: Control, item_id: String, count: int) -> void:
	var col := VBoxContainer.new()
	var tip := BlockRegistry.display_name(item_id)
	var desc := BlockRegistry.item_description(item_id)
	if desc != "":
		tip += "\n" + desc
	col.tooltip_text = tip
	parent.add_child(col)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = BlockRegistry.item_icon(item_id)
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(icon)
	var count_label := Label.new()
	count_label.text = "×%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 11)
	col.add_child(count_label)


## FQ-19: contextual information stack — right band, top pinned just below the
## Map/Events zone (their default bottom is 236) so the three surfaces can
## never collide. Fixed child order is the display priority: selected item,
## save toast, interaction prompt. Every entry autowraps and auto-hides.
func _build_context_stack() -> void:
	_context_stack = VBoxContainer.new()
	_context_stack.anchor_left = 1.0
	_context_stack.anchor_right = 1.0
	_context_stack.offset_left = -252.0
	_context_stack.offset_right = -12.0
	_context_stack.offset_top = 244.0
	_context_stack.add_theme_constant_override("separation", 4)
	_context_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_context_stack)
	_ctx_item_panel = _make_context_entry()
	_ctx_item_label = _ctx_item_panel.get_child(0) as Label
	_ctx_save_panel = _make_context_entry()
	(_ctx_save_panel.get_child(0) as Label).text = "✓ Game saved"
	_ctx_interact_panel = _make_context_entry()
	_ctx_interact_label = _ctx_interact_panel.get_child(0) as Label
	_ctx_interact_label.add_theme_color_override("font_color", Color(0.89, 0.75, 0.43))
	# R-08 slice 3: the pickup toast is appended last so the fixed FQ-19 priority
	# order (item, save, interact) at the top of the stack is unchanged.
	_ctx_pickup_panel = _make_context_entry()
	_ctx_pickup_label = _ctx_pickup_panel.get_child(0) as Label
	_ctx_pickup_label.add_theme_color_override("font_color", Color(0.60, 0.86, 0.52))


func _make_context_entry() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _chip_style())
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	panel.add_child(label)
	_context_stack.add_child(panel)
	return panel


## The events panel grows with its log content, so the stack top is pinned
## dynamically just below whichever of Map/Events is currently visible.
func _position_context_stack() -> void:
	if _context_stack == null:
		return
	var top := 244.0
	if _event_panel != null and _event_panel.visible:
		top = maxf(top, _event_panel.get_global_rect().end.y + 8.0)
	if _map_panel != null and _map_panel.visible:
		top = maxf(top, _map_panel.get_global_rect().end.y + 8.0)
	_context_stack.offset_top = top
	_context_stack.offset_bottom = top


## Show a contextual entry; when hold_seconds > 0 it fades out and hides after
## the hold (one-shot toast), otherwise it stays until explicitly hidden.
func _show_context_entry(panel: PanelContainer, hold_seconds: float) -> void:
	_position_context_stack()
	var running: Tween = _ctx_tweens.get(panel)
	if running != null and running.is_valid():
		running.kill()
	panel.modulate = Color(1, 1, 1, 1)
	panel.visible = true
	if hold_seconds > 0.0:
		var tween := create_tween()
		tween.tween_interval(hold_seconds)
		tween.tween_property(panel, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func(): panel.visible = false)
		_ctx_tweens[panel] = tween


## FQ-19: one-shot save toast (fired by the actual F5 save, not boot state).
func notify_saved() -> void:
	if _ctx_save_panel != null:
		_show_context_entry(_ctx_save_panel, 2.2)


## R-08 slice 3: a "+N Item" pickup toast, fired when the player sweeps loose
## items off the ground (player.items_picked_up). While the toast is still
## showing, further pickups accumulate into it -- walking across a scattered pile
## reads as one growing "+12 Stone" rather than a flicker of separate toasts. The
## tally resets once the toast has faded and a fresh pickup arrives.
func notify_pickup(items: Dictionary) -> void:
	if _ctx_pickup_panel == null or items.is_empty():
		return
	if not _ctx_pickup_panel.visible:
		_ctx_pickup_counts.clear()
	for id in items:
		_ctx_pickup_counts[id] = int(_ctx_pickup_counts.get(id, 0)) + int(items[id])
	var parts: Array[String] = []
	for id in _ctx_pickup_counts:
		parts.append("+%d %s" % [int(_ctx_pickup_counts[id]), BlockRegistry.display_name(str(id))])
	_ctx_pickup_label.text = ", ".join(parts)
	_show_context_entry(_ctx_pickup_panel, 1.9)


## FQ-19: contextual interaction prompt; empty text hides it.
func set_interaction_prompt(text: String) -> void:
	if _ctx_interact_panel == null:
		return
	if text == "":
		_ctx_interact_panel.visible = false
		return
	if _ctx_interact_label.text != text or not _ctx_interact_panel.visible:
		_ctx_interact_label.text = text
		_show_context_entry(_ctx_interact_panel, 0.0)


func _build_log() -> void:
	_event_panel = PanelContainer.new()
	_event_panel.anchor_left = 1.0
	_event_panel.anchor_right = 1.0
	_event_panel.offset_left = -372
	_event_panel.offset_right = -12
	_event_panel.offset_top = 96
	_event_panel.offset_bottom = 236
	_event_panel.custom_minimum_size = Vector2(360, 140)
	_event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# FQ-19: same framed-module language as the crest/goal panels.
	var event_content := _module_content_host(_event_panel)
	add_child(_event_panel)
	var event_box := VBoxContainer.new()
	event_box.add_theme_constant_override("separation", 4)
	event_content.add_child(event_box)
	var event_title := _label(event_box, "EVENTS")
	event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_event_time_label = _label(event_box, "Day 1 · Day")
	_event_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_event_time_label.add_theme_color_override("font_color", Color(0.80, 0.72, 0.48))
	_log_label = Label.new()
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_log_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	_log_label.add_theme_font_size_override("font_size", 12)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_box.add_child(_log_label)


func _build_town_panel() -> void:
	_town_panel = PanelContainer.new()
	_town_panel.anchor_left = 0.5
	_town_panel.anchor_right = 0.5
	_town_panel.anchor_top = 0.5
	_town_panel.anchor_bottom = 0.5
	_town_panel.offset_left = -160
	_town_panel.offset_top = -180
	_town_panel.custom_minimum_size = Vector2(320, 360)
	_town_panel.visible = false
	add_child(_town_panel)
	var town_content := _module_content_host(_town_panel, "ornate")
	# FQ-11: the station chain grows the panel past a fixed height — scroll it.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	town_content.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title := _label(box, "TOWN HALL")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_town_info = _label(box, "")
	# FQ-09: visual stockpile grid between the status text and the stations.
	_label(box, "Stockpile:")
	_stock_empty_label = _label(box, "  (empty)")
	_stock_grid = GridContainer.new()
	_stock_grid.columns = 6
	box.add_child(_stock_grid)
	# FQ-09: station buttons carry item icons (re-resolved on every panel
	# refresh so late-arriving art shows up); disabled states keep the
	# engine's dimming plus the crafted-state text set in refresh_town_panel.
	var deposit := Button.new()
	deposit.text = "Deposit all resources"
	deposit.pressed.connect(func() -> void: deposit_requested.emit())
	box.add_child(deposit)
	_repair_button = Button.new()
	_repair_button.text = "Repair (2 stone → -25 damage)"
	_repair_button.pressed.connect(func() -> void: repair_requested.emit())
	box.add_child(_repair_button)
	var contracts := Button.new()
	contracts.text = "Contracts"
	contracts.pressed.connect(func() -> void: contracts_requested.emit())
	box.add_child(contracts)
	# R-07: crafting and station building moved to the unified Crafting panel (C);
	# the Town Hall panel keeps deposit, status, and Repair.
	_refresh_station_icons()
	# R-08 slice 2: settler roster with a per-settler job-cycle button. Rows are
	# (re)built in refresh_town_panel from the live "subjects" group.
	_label(box, "Settlers:")
	_settler_box = VBoxContainer.new()
	box.add_child(_settler_box)
	_label(box, "Press E to close")


## FQ-09: station icons resolve through item_icon so cleared caches / new
## art are picked up on the next panel refresh.
func _refresh_station_icons() -> void:
	_repair_button.icon = BlockRegistry.item_icon("stone")


## Wave C: openable inventory panel (I to toggle). Shows all carried stacks
## and current tool tier. No drag-drop in v0.6; Wave F will extend tool display.
func _build_inventory_panel() -> void:
	_inv_panel = PanelContainer.new()
	_inv_panel.anchor_left = 0.5
	_inv_panel.anchor_right = 0.5
	_inv_panel.anchor_top = 0.5
	_inv_panel.anchor_bottom = 0.5
	_inv_panel.offset_left = -430
	_inv_panel.offset_top = -300
	_inv_panel.custom_minimum_size = Vector2(860, 560)
	_inv_panel.visible = false
	add_child(_inv_panel)
	var inventory_content := _module_content_host(_inv_panel, "ornate")
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(820, 520)
	box.add_theme_constant_override("separation", 8)
	inventory_content.add_child(box)
	var title := _label(box, "INVENTORY")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary := _label(box, "")
	summary.name = "InventoryBoardSummary"
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inv_content = summary
	_inv_content.visible = false
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var loadout := VBoxContainer.new()
	loadout.custom_minimum_size = Vector2(310, 0)
	loadout.add_theme_constant_override("separation", 6)
	body.add_child(loadout)
	var loadout_title := _label(loadout, "LOADOUT")
	loadout_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equipment_grid = GridContainer.new()
	_equipment_grid.columns = 3
	_equipment_grid.add_theme_constant_override("h_separation", 8)
	_equipment_grid.add_theme_constant_override("v_separation", 8)
	loadout.add_child(_equipment_grid)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(490, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	var backpack_header := HBoxContainer.new()
	backpack_header.alignment = BoxContainer.ALIGNMENT_CENTER
	backpack_header.add_theme_constant_override("separation", 8)
	right.add_child(backpack_header)
	var backpack_title := _label(backpack_header, "BACKPACK")
	backpack_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sort_button := Button.new()
	sort_button.text = "Sort"
	sort_button.custom_minimum_size = Vector2(58, 24)
	sort_button.focus_mode = Control.FOCUS_NONE
	sort_button.tooltip_text = "Sort carried stacks by type and name"
	sort_button.pressed.connect(func() -> void: _sort_inventory_board())
	backpack_header.add_child(sort_button)
	_inv_grid = GridContainer.new()
	_inv_grid.columns = 7
	_inv_grid.add_theme_constant_override("h_separation", 6)
	_inv_grid.add_theme_constant_override("v_separation", 6)
	_backpack_grid = _inv_grid
	right.add_child(_backpack_grid)
	_selected_item_detail = _label(right, "")
	_selected_item_detail.custom_minimum_size = Vector2(0, 78)
	_selected_item_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dock_title := _label(right, "DOCK")
	dock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_assignment_row = HBoxContainer.new()
	_dock_assignment_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dock_assignment_row.add_theme_constant_override("separation", 8)
	right.add_child(_dock_assignment_row)


func toggle_inventory_panel() -> void:
	var opening := not _inv_panel.visible
	if opening:
		_close_open_modal_panels("inventory")
	_inv_panel.visible = opening
	_set_dock_visible(not _any_modal_panel_open())
	if opening:
		_refresh_inventory_panel()


func inventory_panel_open() -> bool:
	return _inv_panel.visible


func _set_dock_visible(visible: bool) -> void:
	if _bottom_dock != null:
		_bottom_dock.visible = visible


func _any_modal_panel_open() -> bool:
	return (_inv_panel != null and _inv_panel.visible) \
		or (_character_panel != null and _character_panel.visible) \
		or (_skill_panel != null and _skill_panel.visible) \
		or (_town_panel != null and _town_panel.visible)


func _close_open_modal_panels(except_id: String) -> void:
	if except_id != "inventory" and _inv_panel != null:
		_inv_panel.visible = false
	if except_id != "character" and _character_panel != null:
		_character_panel.visible = false
	if except_id != "skills" and _skill_panel != null:
		_skill_panel.visible = false
	if except_id != "town" and _town_panel != null:
		_town_panel.visible = false


## Compact read-only character summary. Character data remains authoritative in
## GameState/player; this panel only formats the live values for inspection.
func _build_character_panel() -> void:
	_character_panel = PanelContainer.new()
	_character_panel.anchor_left = 0.5
	_character_panel.anchor_right = 0.5
	_character_panel.anchor_top = 0.5
	_character_panel.anchor_bottom = 0.5
	_character_panel.offset_left = -230
	_character_panel.offset_top = -215
	_character_panel.custom_minimum_size = Vector2(460, 430)
	_character_panel.visible = false
	add_child(_character_panel)
	var character_content := _module_content_host(_character_panel, "ornate")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	character_content.add_child(box)
	var title := _label(box, "CHARACTER")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# PR-06: dynamic body rebuilt from runtime state on every open (no baked
	# values). The figure and every field/slot below live here.
	_character_body = VBoxContainer.new()
	_character_body.add_theme_constant_override("separation", 6)
	_character_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_character_body)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): toggle_character_panel())
	box.add_child(close)


func toggle_character_panel() -> void:
	if _character_panel == null:
		return
	var opening := not _character_panel.visible
	if opening:
		_close_open_modal_panels("character")
	_character_panel.visible = opening
	_set_dock_visible(not _any_modal_panel_open())
	if opening:
		_refresh_character_panel()


func character_panel_open() -> bool:
	return _character_panel != null and _character_panel.visible


## PR-06: the shared render path snapshot of the panel's composed figure, or {}
## when the panel has no figure. Lets the smoke prove the panel draws the live
## character through the same PlayerVisual the world uses.
func character_figure_snapshot() -> Dictionary:
	if _character_figure != null and is_instance_valid(_character_figure):
		return _character_figure.presentation_snapshot()
	return {}


## PR-06: a Character-panel figure drawn through the shared PlayerVisual render
## path (no live Player parent), framed and magnified. Mirrors the creation/
## select preview (PR-05); the character dict is assembled from live runtime
## state, so the panel figure can never drift from the in-world character.
func _make_character_figure(character: Dictionary, draw_scale: float) -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var host := Control.new()
	host.custom_minimum_size = Vector2(16.0 * draw_scale, 32.0 * draw_scale)
	host.clip_contents = true
	frame.add_child(host)
	var visual = PlayerVisualScript.new()
	visual.position = Vector2(8.0 * draw_scale, 16.0 * draw_scale)
	visual.scale = Vector2(draw_scale, draw_scale)
	host.add_child(visual)
	visual.apply_preview_character(character)
	_character_figure = visual
	return frame


func _refresh_character_panel() -> void:
	if _character_body == null:
		return
	_character_figure = null
	_clear_children(_character_body)
	var character: Dictionary = GameState.current_character if GameState.current_character is Dictionary else {}
	var char_name := str(character.get("name", "Wanderer"))
	var species := str(player.species_id if player != null else character.get("species", "human"))
	var body := BlockRegistry.normalize_body_variant(
		str(player.body_variant if player != null else character.get("body_variant", "masculine")))
	var look := int(player.visual_variant if player != null else character.get("visual_variant", 0))
	var appearance := str(character.get("appearance", "tan"))
	var role := str(character.get("role", "homesteader"))
	var equipped: Dictionary = player.equipped_dict() if player != null else {}

	# Top row: composed figure (shared render path, live gear) beside identity.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_character_body.add_child(top)
	var figure_char := {
		"species": species,
		"body_variant": body,
		"visual_variant": look,
		"appearance": appearance,
		"equipment": equipped,
	}
	top.add_child(_make_character_figure(figure_char, 5.0))
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 2)
	top.add_child(identity)
	_label(identity, char_name.capitalize()).add_theme_font_size_override("font_size", 18)
	var look_text := "Default look" if look <= 0 else "Look %d" % look
	_label(identity, "%s  ·  %s" % [species.capitalize(), body.capitalize()])
	_label(identity, "%s  ·  %s" % [appearance.capitalize(), look_text])
	_label(identity, "Role: %s" % role.capitalize())
	var trait_ids: Array = character.get("traits", [])
	var trait_names: Array[String] = []
	for trait_id in trait_ids:
		trait_names.append(str(trait_id).capitalize())
	_label(identity, "Traits: %s" % ("None" if trait_names.is_empty() else ", ".join(trait_names)))
	if player != null:
		var max_attunement: float = player.max_attunement() if player.has_method("max_attunement") else 0.0
		_label(identity, "Health: %d / %d" % [int(round(player.health)), int(round(player.max_health))])
		_label(identity, "Attunement: %d / %d" % [int(round(player.attunement)), int(round(max_attunement))])
		_label(identity, "Attack: %d  ·  Carried: %d items" % [
			player.attack_damage(), player.inventory.total()])

	# Equipment: every slot from runtime state, empty slots shown as em dash.
	var equip_title := _label(_character_body, "EQUIPMENT")
	equip_title.add_theme_color_override("font_color", Color(0.82, 0.7, 0.42))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_character_body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid)
	for slot in _equipment_board_slots():
		var slot_id := str(slot.get("id", ""))
		var item_id := str(equipped.get(slot_id, ""))
		var slot_label := _label(grid, str(slot.get("display_name", slot_id)))
		slot_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
		slot_label.custom_minimum_size = Vector2(150, 0)
		var value := _label(grid,
			BlockRegistry.equipment_item_display_name(item_id) if item_id != "" else "—")
		value.tooltip_text = _equipment_tooltip(slot, item_id)


## FQ-06: skill tree panel plumbing (game_root wires itself in at boot).
func setup_skill_panel(root: Node) -> void:
	_skill_panel.setup(root)
	_skill_panel.purchase_requested.connect(root._on_perk_purchase_requested)


func toggle_skill_panel() -> void:
	var opening := not _skill_panel.visible
	if opening:
		_close_open_modal_panels("skills")
	_skill_panel.visible = opening
	_set_dock_visible(not _any_modal_panel_open())
	if opening:
		_skill_panel.refresh()


func skill_panel_open() -> bool:
	return _skill_panel.visible


func refresh_skill_panel() -> void:
	_skill_panel.refresh()


func skill_panel() -> PanelContainer:
	return _skill_panel


## FQ-07/FQ-09 smoke hook: whether slot i currently shows REAL art (as
## opposed to the generated fallback swatch, which is always present).
func hotbar_icon_is_art(i: int) -> bool:
	if player == null or i < 0 or i >= _hotbar_icons.size() \
			or i >= player.hotbar.size():
		return false
	var art: Texture2D = BlockRegistry.visual_texture("items", player.hotbar[i])
	return art != null and _hotbar_icons[i].texture == art


## FQ-09 smoke hooks: what the visual grids/slots currently display.
func hotbar_slot_count(i: int) -> int:
	if i < 0 or i >= _hotbar_counts.size() or not _hotbar_counts[i].text.is_valid_int():
		return -1
	return int(_hotbar_counts[i].text)


func hotbar_slot_empty(i: int) -> bool:
	if player == null or i < 0 or i >= player.hotbar.size() \
			or i >= _hotbar_icons.size() or i >= _hotbar_counts.size():
		return false
	return str(player.hotbar[i]) == "" \
		and _hotbar_icons[i].texture == null \
		and _hotbar_counts[i].text == ""


func hotbar_selected_index() -> int:
	return _hotbar_selected


func inventory_grid_count(item_id: String) -> int:
	return int(_inv_grid_counts.get(item_id, 0))


func stockpile_grid_count(item_id: String) -> int:
	return int(_stock_grid_counts.get(item_id, 0))


## Returns the current text of the inventory panel content label.
## Used by smoke tests to verify content after an inventory change.
func get_inventory_panel_text() -> String:
	return _inv_content.text


func backpack_cell_count(item_id: String) -> int:
	return int(_backpack_grid_counts.get(item_id, 0))


func backpack_cell_total() -> int:
	return _backpack_cell_total


func equipment_slot_item(slot_id: String) -> String:
	return str(_equipment_slot_items.get(slot_id, ""))


func equipment_slot_count() -> int:
	return _equipment_slot_items.size()


func dock_slot_item(i: int) -> String:
	if player == null or i < 0 or i >= player.hotbar.size():
		return ""
	return player.hotbar[i]


func dock_slot_count(i: int) -> int:
	var item_id: String = dock_slot_item(i)
	return 0 if item_id == "" or player == null else player.inventory.count(item_id)


func dock_selected_index() -> int:
	return _hotbar_selected


func selected_item_detail_text() -> String:
	return _selected_item_detail.text if _selected_item_detail != null else ""


func inventory_board_visible() -> bool:
	return _inv_panel != null and _inv_panel.visible and _backpack_grid != null


func _refresh_inventory_panel() -> void:
	if player == null:
		return
	_refresh_inventory_board()
	return
	# FQ-09: rebuild the icon grid from the live counts.
	for tile in _inv_grid.get_children():
		tile.queue_free()
	_inv_grid_counts = {}
	var sorted_ids: Array = player.inventory.counts.keys()
	sorted_ids.sort()
	for item_id in sorted_ids:
		var n: int = player.inventory.counts[item_id]
		_inv_grid_counts[item_id] = n
		_make_item_tile(_inv_grid, item_id, n)
	var lines: Array[String] = []
	if player.inventory.counts.is_empty():
		lines.append("  (empty)")
	else:
		for item_id in player.inventory.counts:
			lines.append("  %s ×%d" % [
				BlockRegistry.display_name(item_id),
				player.inventory.counts[item_id]])
	lines.append("")
	var _axe_inv_str := ("tier %d" % player.axe_tier) if player.axe_tier > 0 else "(none)"
	lines.append("  Pick tier %d · Axe %s" % [player.tool_tier, _axe_inv_str])
	# FQ-03: read-only gear slots. Empty slots are valid and shown as (empty);
	# the pickaxe/axe rows always mirror the live tool tiers.
	lines.append("")
	lines.append("  — EQUIPMENT —")
	# FQ-04: combat summary derived from the equipped gear.
	lines.append("  Attack %d · Armor %d" % [player.attack_damage(), int(player.armor_total())])
	var equipped: Dictionary = player.equipped_dict()
	for slot in BlockRegistry.equipment_slots():
		var slot_id := str(slot.get("id", ""))
		var item_id: String = str(equipped.get(slot_id, ""))
		var item_name := "(empty)"
		if item_id != "":
			item_name = BlockRegistry.equipment_item_display_name(item_id)
		lines.append("  %s: %s" % [str(slot.get("display_name", slot_id)), item_name])
	_inv_content.text = "\n".join(lines)


func _refresh_inventory_board() -> void:
	player.set_dock_assignments(player.dock_assignments_to_array())
	_clear_children(_backpack_grid)
	_clear_children(_equipment_grid)
	_clear_children(_dock_assignment_row)
	_inv_grid_counts = {}
	_backpack_grid_counts = {}
	_backpack_cell_total = 0
	player.inventory.ensure_layout()
	var backpack_layout: Array = player.inventory.layout_to_array()
	for backpack_index in range(backpack_layout.size()):
		var raw_item_id: Variant = backpack_layout[backpack_index]
		var item_id: String = str(raw_item_id)
		if item_id == "":
			_make_backpack_cell(_backpack_grid, backpack_index, "", 0)
			continue
		var count: int = player.inventory.count(item_id)
		_backpack_cell_total += 1
		_backpack_grid_counts[item_id] = count
		_inv_grid_counts[item_id] = count
		_make_backpack_cell(_backpack_grid, backpack_index, item_id, count)
	var equipped: Dictionary = player.equipped_dict()
	_equipment_slot_items = {}
	for slot in _equipment_board_slots():
		var slot_id: String = str(slot.get("id", ""))
		var gear_id: String = str(equipped.get(slot_id, ""))
		_equipment_slot_items[slot_id] = gear_id
		_make_equipment_cell(_equipment_grid, slot, gear_id)
	for i in range(player.hotbar.size()):
		_make_dock_assignment_cell(_dock_assignment_row, i)
	var selected_id: String = ""
	if player.selected_slot >= 0 and player.selected_slot < player.hotbar.size():
		selected_id = str(player.hotbar[player.selected_slot])
	_refresh_selected_item_detail(selected_id)
	var sorted_ids: Array = player.inventory.counts.keys()
	sorted_ids.sort()
	for item_id in sorted_ids:
		if not _inv_grid_counts.has(item_id):
			_inv_grid_counts[item_id] = player.inventory.count(item_id)
	_inv_content.text = _inventory_summary_text(sorted_ids, equipped)


func _inventory_summary_text(sorted_ids: Array, equipped: Dictionary) -> String:
	var lines: Array[String] = []
	if player.inventory.counts.is_empty():
		lines.append("  (empty)")
	else:
		for item_id in sorted_ids:
			lines.append("  %s x%d" % [
				BlockRegistry.display_name(item_id),
				player.inventory.counts[item_id]])
	lines.append("")
	var axe_text := ("tier %d" % player.axe_tier) if player.axe_tier > 0 else "(none)"
	lines.append("  Pick tier %d / Axe %s" % [player.tool_tier, axe_text])
	lines.append("")
	lines.append("  -- EQUIPMENT --")
	lines.append("  Attack %d / Armor %d" % [player.attack_damage(), int(player.armor_total())])
	for slot in BlockRegistry.equipment_slots():
		var slot_id: String = str(slot.get("id", ""))
		var item_id: String = str(equipped.get(slot_id, ""))
		var item_name := "(empty)"
		if item_id != "":
			item_name = BlockRegistry.equipment_item_display_name(item_id)
		lines.append("  %s: %s" % [str(slot.get("display_name", slot_id)), item_name])
	return "\n".join(lines)


func _clear_children(parent: Control) -> void:
	if parent == null:
		return
	# Remove from the tree immediately, not just queue_free(): a deferred free
	# leaves the old cell in the tree when the rebuild re-adds a cell with the
	# same node name (e.g. InventoryDockSlot1), so Godot renames the fresh cell
	# to avoid the collision and name-based lookups then miss it.
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _make_backpack_cell(parent: Control, index: int, item_id: String, count: int) -> void:
	var cell = InventorySlotCellScript.new()
	cell.setup(self, "backpack", index, item_id, count)
	cell.custom_minimum_size = Vector2(56, 52)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.add_theme_stylebox_override("panel", _slot_normal_sb)
	parent.add_child(cell)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	if item_id == "":
		cell.tooltip_text = "Empty backpack cell"
		cell.gui_input.connect(func(event: InputEvent) -> void:
			if _is_left_click(event):
				_set_selected_detail(["Empty backpack cell"]))
		return
	cell.tooltip_text = _item_tooltip(item_id)
	cell.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_click(event):
			_select_inventory_item(item_id))
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 26)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = BlockRegistry.item_icon(item_id)
	box.add_child(icon)
	var count_label := Label.new()
	count_label.text = "x%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_size_override("font_size", 11)
	box.add_child(count_label)


func _make_equipment_cell(parent: Control, slot: Dictionary, item_id: String) -> void:
	var slot_id: String = str(slot.get("id", ""))
	var accepts: String = str(slot.get("accepts", ""))
	var cell = InventorySlotCellScript.new()
	cell.setup(self, "equipment", -1, item_id, 1 if item_id != "" else 0, slot_id)
	cell.custom_minimum_size = Vector2(88, 62)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.add_theme_stylebox_override("panel", _slot_selected_sb if item_id != "" else _slot_normal_sb)
	parent.add_child(cell)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _equipment_icon(item_id, accepts)
	icon.self_modulate = Color(1, 1, 1, 1) if item_id != "" else Color(0.55, 0.58, 0.62, 0.72)
	box.add_child(icon)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	label.text = _equipment_short_label(slot_id, item_id)
	box.add_child(label)
	cell.tooltip_text = _equipment_tooltip(slot, item_id)
	cell.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_click(event):
			_select_equipment_slot(slot, item_id))


func _make_dock_assignment_cell(parent: Control, index: int) -> void:
	var item_id: String = str(player.hotbar[index])
	var count_value: int = player.inventory.count(item_id)
	var cell = InventorySlotCellScript.new()
	cell.name = "InventoryDockSlot%d" % index
	cell.setup(self, "dock", index, item_id, count_value)
	cell.custom_minimum_size = Vector2(66, 54)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.add_theme_stylebox_override("panel", _slot_selected_sb if index == player.selected_slot else _slot_normal_sb)
	cell.tooltip_text = "[%d] Empty dock slot" % (index + 1) if item_id == "" \
		else "[%d] %s" % [index + 1, BlockRegistry.display_name(item_id)]
	cell.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_release(event):
			_select_dock_slot(index))
	parent.add_child(cell)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = BlockRegistry.item_icon(item_id)
	box.add_child(icon)
	if item_id == "":
		icon.texture = null
		icon.custom_minimum_size = Vector2(26, 18)
		icon.self_modulate = Color(0.45, 0.48, 0.52, 0.5)
	var count := Label.new()
	count.text = "%d  Empty" % (index + 1) if item_id == "" \
		else "%d  x%d" % [index + 1, count_value]
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override("font_size", 10)
	box.add_child(count)


func _is_left_click(event: InputEvent) -> bool:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	return mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT \
		and mouse_event.pressed


func _is_left_release(event: InputEvent) -> bool:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	return mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT \
		and not mouse_event.pressed


func _select_inventory_item(item_id: String) -> void:
	if item_id == "":
		_set_selected_detail(["Empty backpack cell"])
		return
	var lines: Array[String] = [
		"%s x%d" % [BlockRegistry.display_name(item_id), player.inventory.count(item_id)]
	]
	var desc: String = BlockRegistry.item_description(item_id)
	if desc != "":
		lines.append(desc)
	_set_selected_detail(lines)


func _select_equipment_slot(slot: Dictionary, item_id: String) -> void:
	var slot_name: String = str(slot.get("display_name", slot.get("id", "")))
	if item_id == "":
		var accepts: String = str(slot.get("accepts", "gear"))
		var lines: Array[String] = [slot_name, "Empty", "Accepts: %s" % accepts.capitalize()]
		if _is_tool_slot(str(slot.get("id", ""))):
			lines.append("Drag a tool here to set the active tier.")
		_set_selected_detail(lines)
		return
	var item: Dictionary = BlockRegistry.equipment_item(item_id)
	var lines: Array[String] = [
		slot_name,
		BlockRegistry.equipment_item_display_name(item_id),
	]
	var desc: String = str(item.get("description", ""))
	if desc != "":
		lines.append(desc)
	var effects: Dictionary = item.get("effects", {})
	if not effects.is_empty():
		var parts: Array[String] = []
		for key in effects:
			parts.append("%s %+d" % [str(key).capitalize().replace("_", " "), int(effects[key])])
		lines.append(", ".join(parts))
	if _is_tool_slot(str(slot.get("id", ""))):
		lines.append("Drag to backpack to stow this tool.")
	_set_selected_detail(lines)


func _select_dock_slot(index: int) -> void:
	if player == null or index < 0 or index >= player.hotbar.size():
		return
	player.selected_slot = index
	if _inv_panel != null and _inv_panel.visible:
		_refresh_dock_selection_styles()
	else:
		update_inventory()
	var item_id: String = str(player.hotbar[index])
	if item_id == "":
		_set_selected_detail(["Dock %d" % (index + 1), "Empty"])
	else:
		_refresh_selected_item_detail(item_id)


func _refresh_dock_selection_styles() -> void:
	if player == null:
		return
	_hotbar_selected = player.selected_slot
	for i in range(_hotbar_slots.size()):
		var selected: bool = i == player.selected_slot
		_hotbar_slots[i].add_theme_stylebox_override("panel",
			_slot_selected_sb if selected else _slot_normal_sb)
		if i < _hotbar_cells.size():
			_hotbar_cells[i].add_theme_constant_override("margin_top", 0 if selected else 3)
			_hotbar_cells[i].add_theme_constant_override("margin_bottom", 3 if selected else 0)
	if _dock_assignment_row == null:
		return
	for child in _dock_assignment_row.get_children():
		var cell: Control = child as Control
		if cell == null or cell.is_queued_for_deletion():
			continue
		var name_text := str(cell.name)
		if not name_text.begins_with("InventoryDockSlot"):
			continue
		var index_text := name_text.trim_prefix("InventoryDockSlot")
		if not index_text.is_valid_int():
			continue
		var slot_index: int = int(index_text)
		cell.add_theme_stylebox_override("panel",
			_slot_selected_sb if slot_index == player.selected_slot else _slot_normal_sb)


func can_drop_inventory_slot(target_kind: String, target_index: int, data: Variant,
		target_slot_id: String = "") -> bool:
	if player == null or not (data is Dictionary):
		return false
	var payload: Dictionary = data
	if str(payload.get("source", "")) != "inventory_board":
		return false
	var source_kind: String = str(payload.get("kind", ""))
	var item_id: String = str(payload.get("item_id", ""))
	if item_id == "":
		return false
	var source_has_item := source_kind == "equipment"
	if source_kind == "backpack":
		source_has_item = player.inventory.count(item_id) > 0
	elif source_kind == "dock":
		source_has_item = _valid_dock_index(int(payload.get("index", -1))) \
			and str(player.hotbar[int(payload.get("index", -1))]) == item_id
	if not source_has_item:
		return false
	match target_kind:
		"backpack":
			return _valid_backpack_index(target_index) \
				and (source_kind == "backpack" or source_kind == "equipment" \
					or source_kind == "dock")
		"dock":
			return _valid_dock_index(target_index) \
				and (source_kind == "dock" or (source_kind == "backpack" \
					and _can_assign_dock_item(item_id)))
		"equipment":
			if target_slot_id == "":
				return false
			if source_kind == "backpack":
				return _can_equip_backpack_item(target_slot_id, item_id)
			if source_kind == "equipment":
				var source_slot_id: String = str(payload.get("slot_id", ""))
				return _can_swap_equipment_slots(source_slot_id, target_slot_id, item_id)
	return false


func drop_inventory_slot(target_kind: String, target_index: int, data: Variant,
		target_slot_id: String = "") -> void:
	if not can_drop_inventory_slot(target_kind, target_index, data, target_slot_id):
		return
	var payload: Dictionary = data
	var source_kind: String = str(payload.get("kind", ""))
	var source_index: int = int(payload.get("index", -1))
	var item_id: String = str(payload.get("item_id", ""))
	if target_kind == "backpack" and source_kind == "backpack":
		_swap_backpack_slots(source_index, target_index)
	elif target_kind == "backpack" and source_kind == "equipment":
		_unequip_to_backpack(str(payload.get("slot_id", "")), item_id, target_index)
	elif target_kind == "backpack" and source_kind == "dock":
		_clear_dock_slot(source_index)
	elif target_kind == "dock" and source_kind == "dock":
		_swap_dock_slots(source_index, target_index)
	elif target_kind == "dock" and source_kind == "backpack":
		_assign_dock_item(target_index, item_id)
	elif target_kind == "equipment" and source_kind == "backpack":
		_equip_from_backpack(target_slot_id, item_id, source_index)
	elif target_kind == "equipment" and source_kind == "equipment":
		_swap_equipment_slots(str(payload.get("slot_id", "")), target_slot_id, item_id)


func _swap_backpack_slots(source_index: int, target_index: int) -> void:
	if not _valid_backpack_index(source_index) or not _valid_backpack_index(target_index) \
			or source_index == target_index:
		return
	var layout: Array = player.inventory.layout_to_array()
	var source_item: String = str(layout[source_index])
	layout[source_index] = str(layout[target_index])
	layout[target_index] = source_item
	player.inventory.set_layout(layout)
	update_inventory()
	if source_item != "":
		_select_inventory_item(source_item)


func _swap_dock_slots(source_index: int, target_index: int) -> void:
	if not _valid_dock_index(source_index) or not _valid_dock_index(target_index) \
			or source_index == target_index:
		return
	var source_item: String = str(player.hotbar[source_index])
	player.hotbar[source_index] = str(player.hotbar[target_index])
	player.hotbar[target_index] = source_item
	player.selected_slot = target_index
	update_inventory()
	_refresh_selected_item_detail(source_item)


func _clear_dock_slot(source_index: int) -> void:
	if not _valid_dock_index(source_index):
		return
	player.hotbar[source_index] = ""
	player.selected_slot = source_index
	update_inventory()
	_set_selected_detail(["Dock %d" % (source_index + 1), "Empty"])


func _assign_dock_item(target_index: int, item_id: String) -> void:
	if not _valid_dock_index(target_index) or not _can_assign_dock_item(item_id):
		return
	var previous_item: String = str(player.hotbar[target_index])
	var existing_index: int = player.hotbar.find(item_id)
	if existing_index >= 0 and existing_index != target_index:
		player.hotbar[existing_index] = previous_item
	player.hotbar[target_index] = item_id
	player.selected_slot = target_index
	update_inventory()
	_refresh_selected_item_detail(item_id)


func _can_assign_dock_item(item_id: String) -> bool:
	return item_id != "" and player.inventory.count(item_id) > 0 \
		and BlockRegistry.is_dock_assignable_item(item_id)


func _can_equip_backpack_item(slot_id: String, item_id: String) -> bool:
	return item_id != "" and player.inventory.count(item_id) > 0 \
		and BlockRegistry.item_fits_slot(item_id, slot_id)


func _can_swap_equipment_slots(source_slot_id: String, target_slot_id: String,
		item_id: String) -> bool:
	if source_slot_id == "" or target_slot_id == "" or source_slot_id == target_slot_id:
		return false
	if _is_tool_slot(source_slot_id) or _is_tool_slot(target_slot_id):
		return false
	if not BlockRegistry.item_fits_slot(item_id, target_slot_id):
		return false
	var target_item: String = str(player.equipped_dict().get(target_slot_id, ""))
	return BlockRegistry.item_fits_slot(target_item, source_slot_id)


func _equip_from_backpack(slot_id: String, item_id: String, source_index: int) -> void:
	if not _can_equip_backpack_item(slot_id, item_id):
		return
	var previous_item: String = str(player.equipped_dict().get(slot_id, ""))
	var layout: Array = player.inventory.layout_to_array()
	if _valid_layout_index(source_index, layout) and str(layout[source_index]) == item_id:
		layout[source_index] = ""
	if not player.inventory.remove(item_id):
		return
	if not player.equip_item(slot_id, item_id):
		player.inventory.add(item_id)
		return
	if previous_item != "":
		player.inventory.add(previous_item)
		_place_item_in_backpack_layout(previous_item, source_index, layout)
	update_inventory()
	_select_equipment_slot(BlockRegistry.equipment_slot(slot_id), item_id)


func _unequip_to_backpack(slot_id: String, item_id: String, target_index: int) -> void:
	if slot_id == "" or item_id == "":
		return
	if str(player.equipped_dict().get(slot_id, "")) != item_id:
		return
	if not player.equip_item(slot_id, ""):
		return
	player.inventory.add(item_id)
	_place_item_in_backpack_layout(item_id, target_index)
	update_inventory()
	_select_inventory_item(item_id)


func _swap_equipment_slots(source_slot_id: String, target_slot_id: String,
		item_id: String) -> void:
	if not _can_swap_equipment_slots(source_slot_id, target_slot_id, item_id):
		return
	var equipped: Dictionary = player.equipped_dict()
	var target_item: String = str(equipped.get(target_slot_id, ""))
	player.equipment[source_slot_id] = target_item
	player.equipment[target_slot_id] = item_id
	player.inventory_changed.emit()
	update_inventory()
	_select_equipment_slot(BlockRegistry.equipment_slot(target_slot_id), item_id)


func _place_item_in_backpack_layout(item_id: String, preferred_index: int,
		base_layout: Array = []) -> void:
	var layout: Array = base_layout.duplicate() if not base_layout.is_empty() \
		else player.inventory.layout_to_array()
	player.inventory.ensure_layout()
	layout = _layout_without_item(layout, item_id)
	var target_index: int = preferred_index
	if not _valid_layout_index(target_index, layout) or str(layout[target_index]) != "":
		target_index = _first_empty_layout_index(layout)
	if target_index >= 0:
		layout[target_index] = item_id
	player.inventory.set_layout(layout)


func _layout_without_item(layout: Array, item_id: String) -> Array:
	var out: Array = layout.duplicate()
	for i in range(out.size()):
		if str(out[i]) == item_id:
			out[i] = ""
	return out


func _first_empty_layout_index(layout: Array) -> int:
	for i in range(layout.size()):
		if str(layout[i]) == "":
			return i
	return layout.size()


func _valid_layout_index(index: int, layout: Array) -> bool:
	return index >= 0 and index < layout.size()


func _is_tool_slot(slot_id: String) -> bool:
	return slot_id == "pickaxe" or slot_id == "axe"


func _sort_inventory_board() -> void:
	if player == null:
		return
	var sorted_ids: Array = player.inventory.counts.keys()
	sorted_ids.sort_custom(Callable(self, "_inventory_sort_less"))
	var layout: Array[String] = []
	for raw_item_id in sorted_ids:
		layout.append(str(raw_item_id))
	player.inventory.set_layout(layout)
	update_inventory()
	_set_selected_detail(["Backpack sorted"])


func _inventory_sort_less(a: Variant, b: Variant) -> bool:
	return _inventory_sort_key(str(a)) < _inventory_sort_key(str(b))


func _inventory_sort_key(item_id: String) -> String:
	var category := "9"
	if BlockRegistry.is_placeable(item_id):
		category = "0"
	elif item_id == "ore" or item_id.ends_with("_ore") or item_id.ends_with("_ingot"):
		category = "1"
	elif item_id == "food" or item_id == "crop_seeds":
		category = "2"
	elif item_id == "slime_gel" or item_id == "meat" or item_id == "hide_scrap" \
			or item_id == "thorn_quill" or item_id == "chitin" or item_id == "silk" \
			or item_id == "eyes":
		category = "3"
	elif not BlockRegistry.equipment_item(item_id).is_empty():
		category = "4"
	return "%s|%s|%s" % [category, BlockRegistry.display_name(item_id).to_lower(), item_id]


func _valid_backpack_index(index: int) -> bool:
	return player != null and index >= 0 and index < player.inventory.layout_to_array().size()


func _valid_dock_index(index: int) -> bool:
	return player != null and index >= 0 and index < player.hotbar.size()


func _set_selected_detail(lines: Array[String]) -> void:
	if _selected_item_detail == null:
		return
	_selected_item_detail.text = "\n".join(lines)


func _refresh_selected_item_detail(item_id: String) -> void:
	if _selected_item_detail == null:
		return
	if item_id == "":
		_selected_item_detail.text = ""
		return
	var desc: String = BlockRegistry.item_description(item_id)
	var lines: Array[String] = [
		"%s x%d" % [BlockRegistry.display_name(item_id), player.inventory.count(item_id)]
	]
	if desc != "":
		lines.append(desc)
	lines.append("Dock %d" % (player.selected_slot + 1))
	_selected_item_detail.text = "\n".join(lines)


func _item_tooltip(item_id: String) -> String:
	var tip: String = BlockRegistry.display_name(item_id)
	var desc: String = BlockRegistry.item_description(item_id)
	if desc != "":
		tip += "\n" + desc
	return tip


func _equipment_icon(item_id: String, accepts: String) -> Texture2D:
	if item_id != "" and BlockRegistry.visual_texture("items", item_id) != null:
		return BlockRegistry.item_icon(item_id)
	var fallback := "armor"
	match accepts:
		"pickaxe":
			fallback = "pick"
		"axe":
			fallback = "axe"
		"weapon":
			fallback = "sword"
		"ring", "amulet":
			fallback = "crystal"
		"accessory":
			fallback = "authority_sigil"
	return BlockRegistry.item_icon(fallback)


func _equipment_short_label(slot_id: String, item_id: String) -> String:
	if item_id != "":
		return BlockRegistry.equipment_item_display_name(item_id)
	return str(BlockRegistry.equipment_slot(slot_id).get("display_name", slot_id))


func _equipment_tooltip(slot: Dictionary, item_id: String) -> String:
	var slot_name: String = str(slot.get("display_name", slot.get("id", "")))
	if item_id == "":
		return "%s\nEmpty" % slot_name
	var item: Dictionary = BlockRegistry.equipment_item(item_id)
	var tip: String = "%s\n%s" % [slot_name, BlockRegistry.equipment_item_display_name(item_id)]
	var desc: String = str(item.get("description", ""))
	if desc != "":
		tip += "\n" + desc
	var effects: Dictionary = item.get("effects", {})
	if not effects.is_empty():
		var parts: Array[String] = []
		for key in effects:
			parts.append("%s %+d" % [str(key).capitalize().replace("_", " "), int(effects[key])])
		tip += "\n" + ", ".join(parts)
	return tip


func _equipment_board_slots() -> Array:
	var by_id := {}
	for slot in BlockRegistry.equipment_slots():
		by_id[str(slot.get("id", ""))] = slot
	var order := [
		"weapon", "offhand_weapon", "pickaxe",
		"axe", "helmet", "torso",
		"feet", "ring_1", "ring_2",
		"ring_3", "ring_4", "amulet",
		"accessory",
	]
	var out: Array = []
	for slot_id in order:
		if by_id.has(slot_id):
			out.append(by_id[slot_id])
	return out


func _build_debug_overlay() -> void:
	_debug_label = Label.new()
	_debug_label.anchor_left = 1.0
	_debug_label.anchor_right = 1.0
	_debug_label.anchor_top = 1.0
	_debug_label.anchor_bottom = 1.0
	_debug_label.offset_left = -300
	_debug_label.offset_top = -220
	_debug_label.offset_right = -12
	_debug_label.visible = false
	_debug_label.add_theme_font_size_override("font_size", 12)
	add_child(_debug_label)


func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	return label


func _bar(parent: Control, title: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(80, 0)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(140, 14)
	bar.max_value = 100.0
	bar.value = 50.0
	bar.show_percentage = true
	bar.modulate = color
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	return bar


func update_settlement(coherence: float, load_value: float, resilience: float,
		inputs: Dictionary, labels: Array) -> void:
	_bars["coherence"].value = coherence
	_bars["load"].value = load_value
	_bars["resilience"].value = resilience
	for key in _bar_values:
		if _bars.has(key):
			(_bar_values[key] as Label).text = str(int(round(_bars[key].value)))
	_status_label.text = "Status: %s" % (", ".join(labels) if not labels.is_empty() else "—")
	var lines := ["C/L/R inputs:"]
	for key in inputs:
		lines.append("  %s = %.1f" % [key, inputs[key]])
	_debug_label.text = "\n".join(lines)
	_refresh_stock()
	if _town_panel.visible:
		refresh_town_panel()


func update_health(health: float, max_health: float) -> void:
	if _health_bar != null:
		_health_bar.max_value = maxf(1.0, max_health)
		_health_bar.value = health
	if _health_vessel_fill != null:
		_health_vessel_fill.max_value = maxf(1.0, max_health)
		_health_vessel_fill.value = health
	if _health_label != null:
		_health_label.text = "%d / %d" % [int(round(health)), int(round(max_health))]
	# FQ-19 vessel effects: damage flashes hot, recovery glows green. The
	# first update after build only seeds the last-seen value.
	var previous := _last_health
	_last_health = health
	if _health_fx != null and previous >= 0.0:
		if health < previous:
			_play_vessel_fx(_health_fx, Color(1.0, 0.45, 0.32, 0.8), 0.25)
		elif health > previous:
			_play_vessel_fx(_health_fx, Color(0.55, 1.0, 0.6, 0.5), 0.6)
	var low: bool = max_health > 0.0 and (health / max_health) < LOW_HEALTH_TINT_FRACTION
	if low != _low_health_active:
		_low_health_active = low
		if not low and _health_fx != null and not _vessel_fx_active(_health_fx):
			_health_fx.self_modulate = Color(1, 1, 1, 0)
	var tint: Color = Color(0.95, 0.25, 0.15) if low else Color(0.82, 0.22, 0.22)
	if _health_bar != null:
		_health_bar.modulate = tint
	if _health_label != null:
		_health_label.add_theme_color_override(
			"font_color", Color(1.0, 0.35, 0.3) if low else Color(0.9, 0.9, 0.9))


## FQ-05: attunement display, mirroring update_health without the low tint.
func update_attunement(attunement: float, max_attunement: float) -> void:
	if _attunement_bar != null:
		_attunement_bar.max_value = maxf(1.0, max_attunement)
		_attunement_bar.value = attunement
	if _attunement_vessel_fill != null:
		_attunement_vessel_fill.max_value = maxf(1.0, max_attunement)
		_attunement_vessel_fill.value = attunement
	if _attunement_label != null:
		_attunement_label.text = "%d / %d" % [int(round(attunement)), int(round(max_attunement))]
	# FQ-19 vessel effects: regeneration shimmers, spending pulses the ring
	# outward; the geometric core burns bright only at full charge.
	var previous := _last_attunement
	_last_attunement = attunement
	if _attunement_fx != null and previous >= 0.0:
		if attunement > previous:
			_play_vessel_fx(_attunement_fx, Color(0.7, 0.95, 1.0, 0.45), 0.5)
		elif attunement < previous:
			_play_vessel_fx(_attunement_fx, Color(0.5, 0.85, 1.0, 0.55), 0.3)
			_pulse_vessel_frame(_attunement_frame)
	if _attunement_core != null:
		var full: bool = max_attunement > 0.0 and attunement >= max_attunement - 0.001
		_attunement_core.self_modulate = Color(1.0, 1.0, 1.0, 1.0) if full \
			else Color(0.4, 0.65, 0.85, 0.5)


## FQ-19: one-shot vessel overlay effect — set the tint synchronously (so
## state is observable immediately) and tween the alpha back to zero.
func _play_vessel_fx(fx: TextureRect, color: Color, duration: float) -> void:
	var running: Tween = _vessel_fx_tweens.get(fx)
	if running != null and running.is_valid():
		running.kill()
	fx.self_modulate = color
	var tween := create_tween()
	tween.tween_property(fx, "self_modulate:a", 0.0, duration)
	_vessel_fx_tweens[fx] = tween


func _vessel_fx_active(fx: TextureRect) -> bool:
	var tween: Tween = _vessel_fx_tweens.get(fx)
	return tween != null and tween.is_valid() and tween.is_running()


## FQ-19: outward use-pulse — the ring frame kicks up and settles back.
func _pulse_vessel_frame(frame: Control) -> void:
	if frame == null:
		return
	if _vessel_pulse_tween != null and _vessel_pulse_tween.is_valid():
		_vessel_pulse_tween.kill()
	# The pivot was fixed to the frame's center at build time, so a
	# pre-layout pulse cannot scale around the top-left corner.
	frame.scale = Vector2(1.14, 1.14)
	_vessel_pulse_tween = create_tween()
	_vessel_pulse_tween.tween_property(frame, "scale", Vector2.ONE, 0.28)


func update_progression(player_level: int, xp_current: int, xp_next: int, base_name: String) -> void:
	if _crest_title != null:
		_crest_title.text = "◆ %s · Lv.%d" % [base_name, player_level]
	_progression_label.text = "Lv.%d %s  XP: %d/%d" % [player_level, base_name, xp_current, xp_next]


## FQ-19: display-only mirrors of game_root's cycle constants (NIGHT_START
## 0.65); the HUD maps the raw fraction onto a readable settlement clock where
## day spans 06:00-20:00 and night wraps 20:00-06:00.
const CLOCK_NIGHT_START := 0.65
const CLOCK_DAWN_END := 0.08
const CLOCK_DUSK_START := 0.55


func _clock_text(fraction: float) -> String:
	var f := clampf(fraction, 0.0, 1.0)
	var hours: float
	if f < CLOCK_NIGHT_START:
		hours = 6.0 + (f / CLOCK_NIGHT_START) * 14.0
	else:
		hours = 20.0 + ((f - CLOCK_NIGHT_START) / (1.0 - CLOCK_NIGHT_START)) * 10.0
		if hours >= 24.0:
			hours -= 24.0
	var h := int(hours)
	var m := int((hours - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]


func update_time(day: int, is_night: bool, threat_count: int = 0,
		time_fraction: float = -1.0) -> void:
	# Blueprint events header: "Day 5 • Dusk 18:42". Callers that do not know
	# the fraction keep the coarse day/night form.
	var text: String
	if time_fraction >= 0.0:
		var phase := "Night"
		if not is_night:
			if time_fraction < CLOCK_DAWN_END:
				phase = "Dawn"
			elif time_fraction >= CLOCK_DUSK_START:
				phase = "Dusk"
			else:
				phase = "Day"
		text = "Day %d • %s %s" % [day, phase, _clock_text(time_fraction)]
	else:
		text = "Day %d — %s" % [day, "Night" if is_night else "Day"]
	if threat_count > 0:
		text += "  ⚠ %d threat%s active" % [threat_count, "" if threat_count == 1 else "s"]
	if _time_label != null:
		_time_label.text = text
	if _event_time_label != null:
		_event_time_label.text = text


## FQ-19: the persistent dock save line moved out of the dock (the controls
## hint already teaches F5/F9); the state is kept for any future consumer and
## the actual save action fires the contextual notify_saved() toast instead.
func set_save_hint(has_save: bool) -> void:
	_has_save_hint = has_save
	if _save_label != null:
		_save_label.text = "Save available — press F9 to load." if has_save \
			else "No save yet — press F5 to save."


func update_inventory() -> void:
	if player == null:
		return
	# FQ-09: slot tiles carry the per-item info; the text line keeps extras
	# and the tool/gear summary.
	_hotbar_selected = player.selected_slot
	# FQ-19: contextual selected-item entry — announced only when the live
	# selection actually changes, then it fades out on its own.
	if player.selected_slot < player.hotbar.size():
		var selected_id: String = str(player.hotbar[player.selected_slot])
		var announce := "%d:%s" % [player.selected_slot, selected_id]
		if announce != _ctx_last_item:
			var first := _ctx_last_item == ""
			_ctx_last_item = announce
			if selected_id != "" and _ctx_item_panel != null and not first:
				_ctx_item_label.text = "%s ×%d" % [
					BlockRegistry.display_name(selected_id),
					player.inventory.count(selected_id)]
				_show_context_entry(_ctx_item_panel, 2.5)
	for i in range(_hotbar_slots.size()):
		if i >= player.hotbar.size():
			continue
		var item_id: String = str(player.hotbar[i])
		if item_id == "":
			_hotbar_icons[i].texture = null
			_hotbar_counts[i].text = ""
			_hotbar_slots[i].tooltip_text = "[%d] Empty dock slot" % (i + 1)
		else:
			_hotbar_icons[i].texture = BlockRegistry.item_icon(item_id)
			_hotbar_counts[i].text = str(player.inventory.count(item_id))
			_hotbar_slots[i].tooltip_text = "[%d] %s" % [
				i + 1, BlockRegistry.display_name(item_id)]
		var selected: bool = i == player.selected_slot
		_hotbar_slots[i].add_theme_stylebox_override("panel",
			_slot_selected_sb if selected else _slot_normal_sb)
		# FQ-19: the selected slot rides its 3px travel upward (blueprint
		# raised-slot treatment); neighbors keep the reserved headroom.
		if i < _hotbar_cells.size():
			_hotbar_cells[i].add_theme_constant_override("margin_top", 0 if selected else 3)
			_hotbar_cells[i].add_theme_constant_override("margin_bottom", 3 if selected else 0)
	var parts: Array[String] = []
	for extra_id in ["ore", "food"]:
		var extra: int = player.inventory.count(extra_id)
		if extra > 0:
			parts.append("%s ×%d" % [BlockRegistry.display_name(extra_id).capitalize(), extra])
	var _axe_hb_str := ("tier %d" % player.axe_tier) if player.axe_tier > 0 else "none"
	# FQ-04: weapon/armor state in the toolbelt line.
	var equipped: Dictionary = player.equipped_dict()
	var _weapon_id: String = str(equipped.get("weapon", ""))
	var _offhand_id: String = str(equipped.get("offhand_weapon", ""))
	var _weapon_str: String = BlockRegistry.equipment_item_display_name(_weapon_id) \
		if _weapon_id != "" else "none"
	var _offhand_str: String = BlockRegistry.equipment_item_display_name(_offhand_id) \
		if _offhand_id != "" else "none"
	parts.append("Pick tier %d · Axe %s · Weapon %s · Stowed %s · Armor %d" % [
		player.tool_tier, _axe_hb_str, _weapon_str, _offhand_str, int(player.armor_total())])
	_hotbar_label.text = "  ".join(parts)
	_refresh_stock()
	if _inv_panel != null and _inv_panel.visible:
		_refresh_inventory_panel()


func log_event(message: String) -> void:
	_log_lines.append(message)
	if _log_lines.size() > 6:
		_log_lines = _log_lines.slice(_log_lines.size() - 6)
	_log_label.text = "\n".join(_log_lines)
	# FQ-19: a growing events panel pushes the contextual stack down with it.
	_position_context_stack.call_deferred()


func toggle_town_panel() -> void:
	var opening := not _town_panel.visible
	if opening:
		_close_open_modal_panels("town")
	_town_panel.visible = opening
	_set_dock_visible(not _any_modal_panel_open())
	if opening:
		refresh_town_panel()


func town_panel_open() -> bool:
	return _town_panel.visible


func refresh_town_panel() -> void:
	if town_hall == null:
		return
	_town_info.text = "Population: %d\nDamage: %d%%" % [
		town_hall.population, int(round(town_hall.damage))]
	# FQ-09: stockpile renders as an icon grid.
	_refresh_station_icons()
	for tile in _stock_grid.get_children():
		tile.queue_free()
	_stock_grid_counts = {}
	_stock_empty_label.visible = town_hall.stockpile.is_empty()
	var stock_ids: Array = town_hall.stockpile.keys()
	stock_ids.sort()
	for item_id in stock_ids:
		var n: int = int(town_hall.stockpile[item_id])
		_stock_grid_counts[item_id] = n
		_make_item_tile(_stock_grid, item_id, n)
	# R-07: crafting/building moved to the Crafting panel (C); refresh_town_panel
	# now only reflects status, stockpile, and Repair.
	_refresh_settler_rows()


## R-08 slice 2: rebuild the per-settler assignment rows from the live crew. Each
## row is a button that cycles that settler's job via game_root; no instructional
## text, just "Settler N: <Job>".
func _refresh_settler_rows() -> void:
	if _settler_box == null:
		return
	for row in _settler_box.get_children():
		row.queue_free()
	var roster: Array = []
	for s in get_tree().get_nodes_in_group("subjects"):
		if not s.is_queued_for_deletion():
			roster.append(s)
	roster.sort_custom(func(a, b): return str(a.subject_id) < str(b.subject_id))
	var idx := 1
	for s in roster:
		var sid: String = str(s.subject_id)
		var b := Button.new()
		b.text = "Settler %d: %s" % [idx, str(s.job).capitalize()]
		b.pressed.connect(func() -> void: subject_job_cycle_requested.emit(sid))
		_settler_box.add_child(b)
		idx += 1


func _refresh_stock() -> void:
	if town_hall == null:
		return
	_stock_label.text = "Town Hall: %d stored, damage %d%%" % [
		town_hall.total_stock(), int(round(town_hall.damage))]
