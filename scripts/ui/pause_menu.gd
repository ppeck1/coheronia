extends CanvasLayer
## R-07 slice 1: a real pause menu. Escape opens it and freezes the WHOLE
## simulation via get_tree().paused; this node runs PROCESS_MODE_ALWAYS (as does
## the music director) so the menu and music keep working while everything else
## is frozen. Offers Resume / Settings / Save / Save & Quit. Settings covers
## Music and SFX volume and full keyboard rebinding, persisted to the user
## profile (user://shell.json) -- never to a world or character save.
##
## Save & Quit exits only after a SUCCESSFUL save (game_root guards this); on a
## failed save the menu stays paused and shows a visible error. The Settings
## screen fills the viewport with an expanding key list, so it fits and stays
## operable (Back/Reset always reachable) down to a 640x360 logical viewport.

const AudioSettings := preload("res://scripts/audio/audio_settings.gd")
const InputSettings := preload("res://scripts/shell/input_settings.gd")

const PANEL_BG := Color(0.06, 0.07, 0.09, 0.97)
const DIM := Color(0.0, 0.0, 0.0, 0.55)
const ACCENT := Color(0.56, 0.62, 0.70)
const OK_COL := Color(0.55, 0.80, 0.55)
const ERR_COL := Color(0.90, 0.45, 0.45)

signal save_requested
signal save_and_quit_requested
signal restore_requested

var _confirm: ConfirmationDialog
var _open := false
var _main: Control
var _settings: Control
var _settings_vbox: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _hint: Label
var _rebinding_action := ""
var _rebind_buttons: Dictionary = {}   # action -> Button


func _ready() -> void:
	name = "PauseMenu"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	get_tree().paused = true
	_set_status("", false)
	_show_main()
	visible = true


func resume() -> void:
	if not _open:
		return
	_cancel_rebind()
	_open = false
	get_tree().paused = false
	visible = false


## game_root reports the outcome of a Save / Save & Quit so the menu can show a
## visible status and (on failure) stay open and paused.
func show_save_status(ok: bool) -> void:
	if ok:
		notify("Game saved.", false)
	else:
		notify("Save failed -- staying paused.", true)


## Show a status message on the main panel (used by game_root for save/restore).
func notify(text: String, is_error: bool) -> void:
	_show_main()
	_set_status(text, is_error)


## R-07: ask before restoring -- it discards unsaved progress since the last save.
func _request_restore() -> void:
	_confirm.dialog_text = "Restore your last save? Unsaved progress since then will be lost."
	_confirm.popup_centered()


## Smaller-viewport guard: the minimum height the Settings screen actually needs
## -- all fixed chrome (title, sliders, labels, hint, Back/Reset) plus the key
## list's small scroll floor, NOT the full list (which scrolls). The caller
## asserts this fits inside 640x360, proving Back/Reset stay reachable.
func settings_content_min_height() -> float:
	if _settings_vbox == null:
		return 0.0
	# Sum each fixed child's minimum height; for the scrollable key list use only
	# its 40px floor, NOT its full content (that is exactly what scrolls). Add the
	# separations, the panel content margins (14), and the outer margins (10).
	var total := 0.0
	var count := _settings_vbox.get_child_count()
	for i in count:
		var child := _settings_vbox.get_child(i) as Control
		if child == null:
			continue
		if child == _scroll:
			total += _scroll.custom_minimum_size.y
		else:
			total += child.get_combined_minimum_size().y
	var sep := float(_settings_vbox.get_theme_constant("separation"))
	total += sep * float(maxi(0, count - 1))
	total += 2.0 * 14.0 + 2.0 * 10.0   # panel content margin + outer margin
	return total


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Capturing a new binding takes priority over every other key.
	if _rebinding_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				_cancel_rebind()
			else:
				_apply_rebind(event as InputEventKey)
		return
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if _settings.visible:
			_show_main()
		else:
			resume()


# --- construction --------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_main = _build_main()
	_settings = _build_settings()
	dim.add_child(_main)
	dim.add_child(_settings)
	# R-07: confirm dialog for Restore (discards unsaved progress). ALWAYS so it
	# works while the tree is paused.
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Restore save"
	_confirm.ok_button_text = "Restore"
	_confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm.confirmed.connect(func(): restore_requested.emit())
	add_child(_confirm)


func _build_main() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(240.0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(_title("Paused"))
	vb.add_child(_menu_button("Resume", resume))
	vb.add_child(_menu_button("Settings", _show_settings))
	vb.add_child(_menu_button("Save", func(): save_requested.emit()))
	vb.add_child(_menu_button("Restore Save", _request_restore))
	vb.add_child(_menu_button("Save & Quit", func(): save_and_quit_requested.emit()))
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# No autowrap: an autowrapping label reports a pathological (many-line) min
	# height at min width, which would inflate the panel. Clip instead.
	_status.clip_text = true
	_status.custom_minimum_size = Vector2(0, 18)
	vb.add_child(_status)
	center.add_child(panel)
	return center


func _build_settings() -> Control:
	# Fill the viewport (with a margin) so the panel always fits and the key list
	# -- not the Back/Reset controls -- absorbs any overflow.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var panel := _panel(0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	_settings_vbox = vb

	vb.add_child(_title("Settings"))
	vb.add_child(_slider_row("Music Volume",
		AudioSettings.music_volume(GameState.profile),
		func(v): _on_volume("music", v)))
	vb.add_child(_slider_row("SFX Volume",
		AudioSettings.sfx_volume(GameState.profile),
		func(v): _on_volume("sfx", v)))

	var kb := Label.new()
	kb.text = "Key Bindings"
	kb.add_theme_color_override("font_color", ACCENT)
	vb.add_child(kb)

	# The scrollable list is the ONLY element that grows/shrinks with the
	# viewport; everything else stays fixed and on-screen.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 40)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll = scroll
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for action in InputSettings.REBINDABLE:
		list.add_child(_keybind_row(action))
	scroll.add_child(list)
	vb.add_child(scroll)

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	_hint.custom_minimum_size = Vector2(0, 18)
	_hint.clip_text = true   # single line; keeps the settings min height honest
	vb.add_child(_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_menu_button("Reset Defaults", _reset_keys))
	row.add_child(_menu_button("Back", _show_main))
	vb.add_child(row)
	return margin


func _keybind_row(action: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = InputSettings.label(action)
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 0)
	btn.text = InputSettings.binding_label(action)
	if InputSettings.is_key_rebindable(action):
		btn.pressed.connect(func(): _begin_rebind(action))
		_rebind_buttons[action] = btn
	else:
		# Mouse-bound action: shown for reference (e.g. "Primary Mouse (fixed)")
		# but not editable here -- mouse rebinding is deferred.
		btn.disabled = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = "Mouse binding -- not rebindable in this build."
	row.add_child(btn)
	return row


# --- behavior ------------------------------------------------------------

func _show_main() -> void:
	_cancel_rebind()
	_main.visible = true
	_settings.visible = false


func _show_settings() -> void:
	_set_status("", false)
	_main.visible = false
	_settings.visible = true
	_refresh_keys()
	_set_hint("Click a binding, then press a key. Esc cancels.")


func _on_volume(which: String, value: float) -> void:
	if which == "music":
		AudioSettings.set_music_volume(GameState.profile, value)
	else:
		AudioSettings.set_sfx_volume(GameState.profile, value)
	AudioSettings.apply(GameState.profile)
	GameState.save_shell()


func _begin_rebind(action: String) -> void:
	_cancel_rebind()
	_rebinding_action = action
	var btn: Button = _rebind_buttons.get(action, null)
	if btn != null:
		btn.text = "Press a key..."
	_set_hint("Rebinding %s -- press a key (Esc cancels)." % InputSettings.label(action))


func _apply_rebind(key_event: InputEventKey) -> void:
	var action := _rebinding_action
	_rebinding_action = ""
	# Reject a key already used by another rebindable action.
	var clash := InputSettings.action_using_key(key_event, action)
	if clash != "":
		_refresh_keys()
		_set_hint("That key is already bound to %s. Not changed." % InputSettings.label(clash))
		return
	InputSettings.rebind(GameState.profile, action, key_event)
	GameState.save_shell()
	_refresh_keys()
	_set_hint("%s bound to %s." % [InputSettings.label(action),
		InputSettings.binding_label(action)])


func _cancel_rebind() -> void:
	if _rebinding_action == "":
		return
	var action := _rebinding_action
	_rebinding_action = ""
	var btn: Button = _rebind_buttons.get(action, null)
	if btn != null:
		btn.text = InputSettings.binding_label(action)


func _reset_keys() -> void:
	_cancel_rebind()
	InputSettings.reset(GameState.profile)
	GameState.save_shell()
	_refresh_keys()
	_set_hint("Key bindings reset to defaults.")


func _refresh_keys() -> void:
	for action in _rebind_buttons:
		var btn: Button = _rebind_buttons[action]
		btn.text = InputSettings.binding_label(action)


func _set_status(text: String, is_error: bool) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", ERR_COL if is_error else OK_COL)


func _set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


# --- small widget helpers ------------------------------------------------

func _panel(min_w: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	sb.border_color = ACCENT
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	if min_w > 0.0:
		panel.custom_minimum_size = Vector2(min_w, 0)
	return panel


func _title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	return lbl


func _menu_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(cb)
	return btn


func _slider_row(text: String, value: float, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(150, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(160, 0)
	slider.value_changed.connect(cb)
	row.add_child(slider)
	return row
