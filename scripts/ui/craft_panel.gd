extends CanvasLayer
## R-07 slice 4: the unified Crafting panel. One navigable place for every recipe,
## grouped by source -- Hand, then each craft station (Town Hall, Workbench,
## Furnace, Anvil) -- plus a Build row for each unbuilt station. Hand recipes draw
## inputs from the player's inventory; every station/town-hall recipe from the
## Town Hall stockpile. Each row shows inputs as have/need (red when short) and a
## Craft/Build button that is disabled with a reason when materials are short or
## the station is not built. Crafting/building now lives here; the Town Hall panel
## keeps only Repair. Control model is unchanged elsewhere: this replaces the old
## hardcoded C = instant-torch with C = open this panel.

const PANEL_BG := Color(0.06, 0.07, 0.09, 0.97)
const DIM := Color(0.0, 0.0, 0.0, 0.5)
const ACCENT := Color(0.56, 0.62, 0.70)
const HAVE_COL := Color(0.72, 0.85, 0.72)
const SHORT_COL := Color(0.92, 0.5, 0.5)
const DIM_TEXT := Color(0.62, 0.66, 0.72)

const STATION_ORDER := ["hand", "town_hall", "workbench", "furnace", "anvil"]
const STATION_TITLE := {
	"hand": "Hand", "town_hall": "Town Hall", "workbench": "Workbench",
	"furnace": "Furnace", "anvil": "Anvil",
}
# stations the player must build first (their recipes are gated until built).
const BUILDABLE := ["workbench", "furnace", "anvil"]

signal craft_requested(recipe_id: String)
signal build_requested(station_id: String)

var _player = null
var _town_hall = null
var _open := false
var _list: VBoxContainer


func _ready() -> void:
	name = "CraftPanel"
	layer = 55
	_build()
	visible = false


func setup(player: Node, town_hall: Node) -> void:
	_player = player
	_town_hall = town_hall


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	GameState.craft_panel_open = true
	refresh()
	visible = true


func close() -> void:
	_open = false
	GameState.craft_panel_open = false
	visible = false


func _input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# --- construction --------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	dim.add_child(margin)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	sb.border_color = ACCENT
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(360, 0)
	margin.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Crafting"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 40)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	vb.add_child(scroll)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)


# --- population ----------------------------------------------------------

func refresh() -> void:
	if _list == null or _player == null or _town_hall == null:
		return
	for child in _list.get_children():
		child.queue_free()
	for station in STATION_ORDER:
		_list.add_child(_section_title(STATION_TITLE.get(station, station)))
		if station in BUILDABLE and not _town_hall.station_built(station):
			_list.add_child(_build_row(station))
			continue   # station's recipes stay hidden until it is built
		for recipe: Dictionary in BlockRegistry.recipes_for_station(station):
			_list.add_child(_recipe_row(recipe))


func _section_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", ACCENT)
	return lbl


## Where a recipe's inputs are checked/spent: the player's inventory for hand
## recipes, the Town Hall stockpile for everything else.
func _stock_of(station: String, item_id: String) -> int:
	if station == "hand":
		return int(_player.inventory.count(item_id))
	return int(_town_hall.stockpile.get(item_id, 0))


func _short_reason(station: String, costs: Dictionary) -> String:
	for item_id in costs:
		if _stock_of(station, item_id) < int(costs[item_id]):
			return "Need more " + BlockRegistry.display_name(item_id)
	return ""


func _costs_line(row: HBoxContainer, station: String, costs: Dictionary) -> void:
	for item_id in costs:
		var need := int(costs[item_id])
		var have := _stock_of(station, item_id)
		var chip := Label.new()
		chip.text = "%s %d/%d" % [BlockRegistry.display_name(item_id), have, need]
		chip.add_theme_color_override("font_color",
			HAVE_COL if have >= need else SHORT_COL)
		row.add_child(chip)


func _recipe_row(recipe: Dictionary) -> Control:
	var station := str(recipe.get("station", "hand"))
	var rid := str(recipe.get("recipe_id", ""))
	var inputs: Dictionary = recipe.get("inputs", {})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var out_id := _first_key(recipe.get("outputs", {}))
	icon.texture = BlockRegistry.item_icon(out_id) if out_id != "" else null
	row.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = str(recipe.get("display_name", rid))
	name_lbl.custom_minimum_size = Vector2(120, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	_costs_line(row, station, inputs)
	var reason := _short_reason(station, inputs)
	var btn := Button.new()
	btn.text = "Craft"
	btn.custom_minimum_size = Vector2(72, 0)
	if reason == "":
		btn.pressed.connect(func(): craft_requested.emit(rid))
	else:
		btn.disabled = true
		btn.tooltip_text = reason
	row.add_child(btn)
	return row


func _build_row(station: String) -> Control:
	var sdef: Dictionary = BlockRegistry.station_def(station)
	var cost: Dictionary = sdef.get("build_cost", {})
	var prereq := str(sdef.get("prereq", ""))
	var prereq_met: bool = prereq == "" or _town_hall.station_built(prereq)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = "Build %s" % str(sdef.get("display_name", station))
	name_lbl.custom_minimum_size = Vector2(120, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not prereq_met:
		name_lbl.add_theme_color_override("font_color", DIM_TEXT)
	row.add_child(name_lbl)
	_costs_line(row, station, cost)
	var reason := ""
	if not prereq_met:
		reason = "Build the %s first" % str(BlockRegistry.station_def(prereq).get("display_name", prereq))
	elif _short_reason(station, cost) != "":
		reason = _short_reason(station, cost)
	var btn := Button.new()
	btn.text = "Build"
	btn.custom_minimum_size = Vector2(72, 0)
	if reason == "":
		btn.pressed.connect(func(): build_requested.emit(station))
	else:
		btn.disabled = true
		btn.tooltip_text = reason
	row.add_child(btn)
	return row


func _first_key(d: Dictionary) -> String:
	for k in d:
		return str(k)
	return ""
