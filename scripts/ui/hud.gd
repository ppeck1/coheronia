extends CanvasLayer
## HUD: health, C/L/R bars, status labels, day/night, hotbar/inventory,
## event log, Town Hall panel, and an F3 debug overlay. Built in code to
## keep scene files minimal.

signal deposit_requested
signal repair_requested
signal forge_requested
signal lantern_requested

var player: CharacterBody2D
var town_hall: Node2D

var _health_label: Label
var _bars: Dictionary = {}       # "coherence"/"load"/"resilience" -> ProgressBar
var _status_label: Label
var _time_label: Label
var _stock_label: Label
var _progression_label: Label
var _hotbar_label: Label
var _mine_bar: ProgressBar
var _log_label: Label
var _log_lines: Array[String] = []
var _town_panel: PanelContainer
var _town_info: Label
var _forge_button: Button
var _save_label: Label
var _debug_label: Label


func _ready() -> void:
	_build_top_left()
	_build_bottom_left()
	_build_log()
	_build_town_panel()
	_build_debug_overlay()


func _process(_delta: float) -> void:
	if player != null:
		_mine_bar.visible = player.mine_progress_ratio() > 0.0
		_mine_bar.value = player.mine_progress_ratio() * 100.0
	if Input.is_action_just_pressed("debug_overlay"):
		_debug_label.visible = not _debug_label.visible


func _build_top_left() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(12, 10)
	box.custom_minimum_size = Vector2(240, 0)
	add_child(box)
	_health_label = _label(box, "Health: 100")
	_bars["coherence"] = _bar(box, "Coherence", Color(0.35, 0.75, 0.40))
	_bars["load"] = _bar(box, "Load", Color(0.85, 0.45, 0.30))
	_bars["resilience"] = _bar(box, "Resilience", Color(0.35, 0.55, 0.85))
	_status_label = _label(box, "Status: —")
	_time_label = _label(box, "Day 1 — Day")
	_stock_label = _label(box, "Town Hall: empty")
	_progression_label = _label(box, "Lv.1 Camp  XP: 0/100")


func _build_bottom_left() -> void:
	var box := VBoxContainer.new()
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 12
	box.offset_top = -96
	add_child(box)
	_mine_bar = ProgressBar.new()
	_mine_bar.custom_minimum_size = Vector2(180, 10)
	_mine_bar.show_percentage = false
	_mine_bar.visible = false
	box.add_child(_mine_bar)
	_hotbar_label = _label(box, "")
	_label(box, "LMB mine · RMB place · E town hall · C craft torch · F5 save · F9 load")
	_save_label = _label(box, "No save yet — press F5 to save.")


func _build_log() -> void:
	_log_label = Label.new()
	_log_label.anchor_left = 1.0
	_log_label.anchor_right = 1.0
	_log_label.offset_left = -360
	_log_label.offset_right = -12
	_log_label.offset_top = 10
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_log_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	_log_label.add_theme_font_size_override("font_size", 13)
	add_child(_log_label)


func _build_town_panel() -> void:
	_town_panel = PanelContainer.new()
	_town_panel.anchor_left = 0.5
	_town_panel.anchor_right = 0.5
	_town_panel.anchor_top = 0.5
	_town_panel.anchor_bottom = 0.5
	_town_panel.offset_left = -150
	_town_panel.offset_top = -110
	_town_panel.custom_minimum_size = Vector2(300, 200)
	_town_panel.visible = false
	add_child(_town_panel)
	var box := VBoxContainer.new()
	_town_panel.add_child(box)
	var title := _label(box, "TOWN HALL")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_town_info = _label(box, "")
	var deposit := Button.new()
	deposit.text = "Deposit all resources"
	deposit.pressed.connect(func() -> void: deposit_requested.emit())
	box.add_child(deposit)
	var repair := Button.new()
	repair.text = "Repair (2 stone → -25 damage)"
	repair.pressed.connect(func() -> void: repair_requested.emit())
	box.add_child(repair)
	_forge_button = Button.new()
	_forge_button.text = "Forge pick upgrade (3 wood + 5 stone)"
	_forge_button.pressed.connect(func() -> void: forge_requested.emit())
	box.add_child(_forge_button)
	var lantern := Button.new()
	lantern.text = "Craft lantern (2 ore + 1 wood)"
	lantern.pressed.connect(func() -> void: lantern_requested.emit())
	box.add_child(lantern)
	_label(box, "Press E to close")


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
	_status_label.text = "Status: %s" % (", ".join(labels) if not labels.is_empty() else "—")
	var lines := ["C/L/R inputs:"]
	for key in inputs:
		lines.append("  %s = %.1f" % [key, inputs[key]])
	_debug_label.text = "\n".join(lines)
	_refresh_stock()
	if _town_panel.visible:
		refresh_town_panel()


func update_health(health: float) -> void:
	_health_label.text = "Health: %d" % int(round(health))


func update_progression(player_level: int, xp_current: int, xp_next: int, base_name: String) -> void:
	_progression_label.text = "Lv.%d %s  XP: %d/%d" % [player_level, base_name, xp_current, xp_next]


func update_time(day: int, is_night: bool, threat_count: int = 0) -> void:
	var text := "Day %d — %s" % [day, "Night" if is_night else "Day"]
	if threat_count > 0:
		text += "  ⚠ %d threat%s active" % [threat_count, "" if threat_count == 1 else "s"]
	_time_label.text = text


func set_save_hint(has_save: bool) -> void:
	_save_label.text = "Save available — press F9 to load." if has_save \
		else "No save yet — press F5 to save."


func update_inventory() -> void:
	if player == null:
		return
	var parts: Array[String] = []
	for i in range(player.hotbar.size()):
		var item_id: String = player.hotbar[i]
		var marker := "▶" if i == player.selected_slot else " "
		parts.append("%s[%d] %s ×%d" % [marker, i + 1, BlockRegistry.display_name(item_id), player.inventory.count(item_id)])
	for extra_id in ["ore", "food"]:
		var extra: int = player.inventory.count(extra_id)
		if extra > 0:
			parts.append("  %s ×%d" % [BlockRegistry.display_name(extra_id).capitalize(), extra])
	parts.append("  Pick tier %d" % player.tool_tier)
	_hotbar_label.text = "  ".join(parts)
	_refresh_stock()


func log_event(message: String) -> void:
	_log_lines.append(message)
	if _log_lines.size() > 6:
		_log_lines = _log_lines.slice(_log_lines.size() - 6)
	_log_label.text = "\n".join(_log_lines)


func toggle_town_panel() -> void:
	_town_panel.visible = not _town_panel.visible
	if _town_panel.visible:
		refresh_town_panel()


func town_panel_open() -> bool:
	return _town_panel.visible


func refresh_town_panel() -> void:
	if town_hall == null:
		return
	var lines: Array[String] = ["Population: %d" % town_hall.population,
		"Damage: %d%%" % int(round(town_hall.damage))]
	lines.append("Stockpile:")
	if town_hall.stockpile.is_empty():
		lines.append("  (empty)")
	for item_id in town_hall.stockpile:
		lines.append("  %s ×%d" % [BlockRegistry.display_name(item_id), town_hall.stockpile[item_id]])
	_town_info.text = "\n".join(lines)
	if player != null:
		var forged: bool = player.tool_tier >= 2
		_forge_button.disabled = forged
		_forge_button.text = "Pick forged (tier 2)" if forged else "Forge pick upgrade (3 wood + 5 stone)"


func _refresh_stock() -> void:
	if town_hall == null:
		return
	_stock_label.text = "Town Hall: %d stored, damage %d%%" % [
		town_hall.total_stock(), int(round(town_hall.damage))]
