extends Control
## Status-effects HUD element: a small top-right stack of active timed effects, each a
## colour tag + name + live countdown + a thin remaining bar. Generic and consumer-
## agnostic — future effects (potions, weather, resonance, ...) register through
## game_root.add_status_effect(); this widget only renders whatever list it's handed.
## Reconciles rows by id (no per-frame rebuild flicker).

const MARGIN := 12.0

var _box: VBoxContainer
var _rows: Dictionary = {}   # id -> row Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)   # fill the viewport; _box pins top-right
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	visible = false


## `effects` = Array of { id, label, color, remaining, duration }.
func set_effects(effects: Array) -> void:
	visible = not effects.is_empty()
	var seen := {}
	for e in effects:
		var id := str(e.get("id", ""))
		seen[id] = true
		var row: Control = _rows.get(id)
		if row == null or not is_instance_valid(row):
			row = _make_row()
			_rows[id] = row
			_box.add_child(row)
		_update_row(row, e)
	for id in _rows.keys():
		if not seen.has(id):
			if is_instance_valid(_rows[id]):
				_rows[id].queue_free()
			_rows.erase(id)
	# Keep pinned to the top-right corner as its own size changes.
	_box.reset_size()
	_box.position = Vector2(size.x - _box.size.x - MARGIN, MARGIN)


func _make_row() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.72)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5.0)
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)
	var time_lbl := Label.new()
	time_lbl.name = "Time"
	time_lbl.add_theme_font_size_override("font_size", 13)
	time_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	row.add_child(time_lbl)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(46, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	panel.set_meta("row", row)
	return panel


func _update_row(panel: Control, e: Dictionary) -> void:
	var row: HBoxContainer = panel.get_meta("row")
	var color: Color = e.get("color", Color.WHITE)
	var remaining := float(e.get("remaining", 0.0))
	var duration := maxf(float(e.get("duration", 1.0)), 0.001)
	(row.get_node("Dot") as ColorRect).color = color
	(row.get_node("Name") as Label).text = str(e.get("label", ""))
	(row.get_node("Time") as Label).text = "%ds" % maxi(0, int(ceil(remaining)))
	var bar := row.get_node("Bar") as ProgressBar
	bar.max_value = duration
	bar.value = clampf(remaining, 0.0, duration)
	bar.modulate = color
