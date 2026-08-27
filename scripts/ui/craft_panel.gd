extends CanvasLayer
## The unified Crafting panel — an icon-led recipe book (redesign of the R-07
## list). One navigable place for every recipe: a persistent station selector
## (Hand, Town Hall, Workbench, Furnace, Anvil), a visual recipe grid on the
## left, and a selected-recipe detail pane on the right with a single Craft/Build
## action. Hand recipes draw from the player's backpack; every station/town-hall
## recipe from the Town Hall stockpile. This is a PRESENTATION redesign only:
## the crafting/building/routing authorities are unchanged — the panel still
## emits craft_requested(recipe_id) / build_requested(station_id), and game_root
## routes them exactly as before. The control model (C toggles, Esc closes,
## GameState.craft_panel_open freezes gameplay) is unchanged.
##
## API preserved for the smoke suite and game_root: setup(), is_open()/toggle()/
## open()/close(), refresh(), _stock_of(station, item_id), _short_reason(station,
## costs), recipe_icon_id(recipe), and the two signals.

const PANEL_BG := Color(0.06, 0.07, 0.09, 0.98)
const DIM := Color(0.0, 0.0, 0.0, 0.55)
const ACCENT := Color(0.56, 0.62, 0.70)
const BRASS := Color(0.85, 0.68, 0.34)          # selected / ready gold
const BRASS_DIM := Color(0.46, 0.39, 0.23)
const HAVE_COL := Color(0.74, 0.86, 0.74)
const SHORT_COL := Color(0.93, 0.52, 0.52)
const DIM_TEXT := Color(0.60, 0.64, 0.70)
const TILE_BG := Color(0.10, 0.12, 0.15, 1.0)
const TILE_BG_SEL := Color(0.16, 0.15, 0.10, 1.0)
const DETAIL_BG := Color(0.08, 0.09, 0.12, 1.0)
const TILE_SIZE := Vector2(84, 98)

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
var _selected_station := "hand"
var _selected_recipe_id := ""

var _margin: MarginContainer
var _panel: PanelContainer
var _source_label: Label
var _station_bar: HFlowContainer
var _grid: HFlowContainer
var _detail_box: VBoxContainer
var _tile_buttons := {}          # recipe_id -> Button (for selection restyle)


func _ready() -> void:
	name = "CraftPanel"
	layer = 55
	_build()
	visible = false
	get_viewport().size_changed.connect(_refit)


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
	_refit()
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


# --- construction ---------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(_margin)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	sb.border_color = ACCENT
	sb.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_margin.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	# Header: CRAFTING + dynamic material-source label.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "CRAFTING"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BRASS)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_source_label = Label.new()
	_source_label.add_theme_color_override("font_color", DIM_TEXT)
	_source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_source_label)
	vb.add_child(header)

	# Persistent station selector (wraps at narrow widths).
	_station_bar = HFlowContainer.new()
	_station_bar.add_theme_constant_override("h_separation", 6)
	_station_bar.add_theme_constant_override("v_separation", 4)
	vb.add_child(_station_bar)

	vb.add_child(HSeparator.new())

	# Two-pane body: recipe grid (left, scrolls) + detail pane (right).
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid_scroll)
	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(_grid)

	var detail_panel := PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = DETAIL_BG
	dsb.set_corner_radius_all(6)
	dsb.set_content_margin_all(10)
	dsb.border_color = ACCENT
	dsb.set_border_width_all(1)
	detail_panel.add_theme_stylebox_override("panel", dsb)
	detail_panel.custom_minimum_size = Vector2(232, 0)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 6)
	detail_panel.add_child(_detail_box)

	vb.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	var fspacer := Control.new()
	fspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fspacer)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(96, 0)
	close_btn.pressed.connect(close)
	footer.add_child(close_btn)
	vb.add_child(footer)


## Size the panel to the current viewport: fills a small (640x360) screen with a
## tight margin, and centres at a comfortable max width on large screens.
func _refit() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var m := clampf(vp.x * 0.04, 8.0, 48.0)
	for side in ["left", "top", "right", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, int(m))
	_panel.custom_minimum_size = Vector2(minf(vp.x - m * 2.0, 1040.0), vp.y - m * 2.0)


# --- population ------------------------------------------------------------

func refresh() -> void:
	if _grid == null or _player == null or _town_hall == null:
		return
	_source_label.text = "Using backpack materials" if _selected_station == "hand" \
		else "Using Town Hall stockpile materials"
	_rebuild_station_bar()
	# Keep the selected recipe if it still belongs to the station; else pick the
	# first, or none for a locked station (which shows the build card instead).
	var recipes: Array = BlockRegistry.recipes_for_station(_selected_station)
	var locked := _is_locked_station(_selected_station)
	if not locked:
		var still_valid := false
		for r: Dictionary in recipes:
			if str(r.get("recipe_id", "")) == _selected_recipe_id:
				still_valid = true
		if not still_valid:
			_selected_recipe_id = str(recipes[0].get("recipe_id", "")) if not recipes.is_empty() else ""
	_rebuild_grid(recipes, locked)
	if locked:
		_build_locked_detail()
	else:
		_build_recipe_detail(_recipe_by_id(_selected_recipe_id))


func _rebuild_station_bar() -> void:
	for child in _station_bar.get_children():
		child.queue_free()
	for station in STATION_ORDER:
		var locked := _is_locked_station(station)
		var btn := Button.new()
		btn.text = STATION_TITLE.get(station, station) + ("  (locked)" if locked else "")
		btn.toggle_mode = true
		btn.button_pressed = station == _selected_station
		btn.focus_mode = Control.FOCUS_NONE
		if locked:
			btn.add_theme_color_override("font_color", DIM_TEXT)
			btn.tooltip_text = "Locked — build the %s first" % STATION_TITLE.get(station, station)
		if station == _selected_station:
			btn.add_theme_color_override("font_color", BRASS)
		btn.pressed.connect(_select_station.bind(station))
		_station_bar.add_child(btn)


func _select_station(station: String) -> void:
	if station == _selected_station:
		return
	_selected_station = station
	_selected_recipe_id = ""
	refresh()


func _select_recipe(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id
	# Restyle tiles + rebuild the detail without a full grid rebuild (keeps scroll).
	for rid in _tile_buttons:
		_style_tile(_tile_buttons[rid], rid == recipe_id)
	_build_recipe_detail(_recipe_by_id(recipe_id))


# --- recipe grid -----------------------------------------------------------

func _rebuild_grid(recipes: Array, locked: bool) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_tile_buttons = {}
	for recipe: Dictionary in recipes:
		var tile := _recipe_tile(recipe, locked)
		_grid.add_child(tile)


func _recipe_tile(recipe: Dictionary, locked: bool) -> Button:
	var rid := str(recipe.get("recipe_id", ""))
	var costs: Dictionary = recipe.get("inputs", {})
	var ready := not locked and _short_reason(_selected_station, costs) == ""
	var btn := Button.new()
	btn.custom_minimum_size = TILE_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = locked           # locked recipes are shown but not selectable
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_tile(btn, rid == _selected_recipe_id)
	if not locked:
		btn.pressed.connect(_select_recipe.bind(rid))
	_tile_buttons[rid] = btn

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(vb)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(0, 40)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_id := recipe_icon_id(recipe)
	icon.texture = BlockRegistry.item_icon(icon_id) if icon_id != "" else null
	if locked:
		icon.modulate = Color(1, 1, 1, 0.45)
	vb.add_child(icon)

	var qty := _output_qty(recipe)
	var name_lbl := Label.new()
	name_lbl.text = str(recipe.get("display_name", rid)) + ("  x%d" % qty if qty > 1 else "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var state := Label.new()
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 10)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		state.text = "Locked"
		state.add_theme_color_override("font_color", DIM_TEXT)
	elif ready:
		state.text = "Ready"
		state.add_theme_color_override("font_color", BRASS)
	else:
		state.text = _readiness(_selected_station, costs)
		state.add_theme_color_override("font_color", SHORT_COL)
	vb.add_child(state)
	return btn


func _style_tile(btn: Button, selected: bool) -> void:
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = TILE_BG_SEL if selected else TILE_BG
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(4)
		sb.border_color = BRASS if selected else Color(0.22, 0.25, 0.30)
		sb.set_border_width_all(2 if selected else 1)
		btn.add_theme_stylebox_override(state_name, sb)


# --- selected-recipe detail pane ------------------------------------------

func _build_recipe_detail(recipe: Dictionary) -> void:
	for child in _detail_box.get_children():
		child.queue_free()
	if recipe.is_empty():
		var empty := Label.new()
		empty.text = "Select a recipe."
		empty.add_theme_color_override("font_color", DIM_TEXT)
		_detail_box.add_child(empty)
		return
	var rid := str(recipe.get("recipe_id", ""))
	var costs: Dictionary = recipe.get("inputs", {})
	var reason := _short_reason(_selected_station, costs)
	var result_id := recipe_icon_id(recipe)

	# Header row: large result icon + name/station.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = BlockRegistry.item_icon(result_id) if result_id != "" else null
	head.add_child(icon)
	var titles := VBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = str(recipe.get("display_name", rid))
	name_lbl.add_theme_font_size_override("font_size", 17)
	titles.add_child(name_lbl)
	var st_lbl := Label.new()
	st_lbl.text = "%s station" % STATION_TITLE.get(_selected_station, _selected_station)
	st_lbl.add_theme_color_override("font_color", DIM_TEXT)
	st_lbl.add_theme_font_size_override("font_size", 11)
	titles.add_child(st_lbl)
	head.add_child(titles)
	_detail_box.add_child(head)

	# Scrolling middle: description, requirements, output, destination.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# Player-facing description ONLY (never the developer `note`).
	var desc := str(BlockRegistry.item_description(result_id)) if result_id != "" else ""
	if desc != "":
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.83, 0.88))
		content.add_child(desc_lbl)

	var req_hdr := Label.new()
	req_hdr.text = "Requires"
	req_hdr.add_theme_color_override("font_color", ACCENT)
	content.add_child(req_hdr)
	for item_id in costs:
		content.add_child(_requirement_tile(item_id, int(costs[item_id])))

	var makes := Label.new()
	var qty := _output_qty(recipe)
	makes.text = "Makes:  %s%s" % [BlockRegistry.display_name(result_id) if result_id != "" \
		else str(recipe.get("display_name", rid)), ("  x%d" % qty) if qty > 1 else ""]
	makes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(makes)
	var dest := Label.new()
	dest.text = "To:  %s" % _output_destination(recipe)
	dest.add_theme_color_override("font_color", DIM_TEXT)
	content.add_child(dest)

	# Pinned readiness + Craft action.
	if reason != "":
		var short_lbl := Label.new()
		short_lbl.text = reason
		short_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		short_lbl.add_theme_color_override("font_color", SHORT_COL)
		_detail_box.add_child(short_lbl)
	var craft_btn := Button.new()
	craft_btn.text = "Craft one"
	craft_btn.custom_minimum_size = Vector2(0, 34)
	if reason == "":
		craft_btn.pressed.connect(func() -> void: craft_requested.emit(rid))
	else:
		craft_btn.disabled = true
		craft_btn.tooltip_text = reason
	_detail_box.add_child(craft_btn)


## The build card shown when a locked (unbuilt) station is selected: prereq,
## construction materials as owned/required tiles, how many recipes it unlocks,
## and a Build action (disabled with a reason when short or the prereq is unmet).
func _build_locked_detail() -> void:
	for child in _detail_box.get_children():
		child.queue_free()
	var sdef: Dictionary = BlockRegistry.station_def(_selected_station)
	var cost: Dictionary = sdef.get("build_cost", {})
	var prereq := str(sdef.get("prereq", ""))
	var prereq_met: bool = prereq == "" or _town_hall.station_built(prereq)

	var name_lbl := Label.new()
	name_lbl.text = "%s  (locked)" % str(sdef.get("display_name", _selected_station))
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", BRASS_DIM)
	_detail_box.add_child(name_lbl)

	if prereq != "":
		var pr := Label.new()
		pr.text = "Requires the %s first" % str(BlockRegistry.station_def(prereq).get("display_name", prereq))
		pr.add_theme_color_override("font_color", DIM_TEXT if prereq_met else SHORT_COL)
		pr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_box.add_child(pr)

	var unlocks := BlockRegistry.recipes_for_station(_selected_station).size()
	var unlocks_lbl := Label.new()
	unlocks_lbl.text = "Unlocks %d recipe%s" % [unlocks, "" if unlocks == 1 else "s"]
	unlocks_lbl.add_theme_color_override("font_color", ACCENT)
	_detail_box.add_child(unlocks_lbl)

	var build_hdr := Label.new()
	build_hdr.text = "Build cost"
	build_hdr.add_theme_color_override("font_color", ACCENT)
	_detail_box.add_child(build_hdr)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	scroll.add_child(content)
	for item_id in cost:
		content.add_child(_requirement_tile(item_id, int(cost[item_id]), _selected_station))

	var reason := ""
	if not prereq_met:
		reason = "Build the %s first" % str(BlockRegistry.station_def(prereq).get("display_name", prereq))
	elif _short_reason(_selected_station, cost) != "":
		reason = _short_reason(_selected_station, cost)
	if reason != "":
		var short_lbl := Label.new()
		short_lbl.text = reason
		short_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		short_lbl.add_theme_color_override("font_color", SHORT_COL)
		_detail_box.add_child(short_lbl)
	var build_btn := Button.new()
	build_btn.text = "Build %s" % str(sdef.get("display_name", _selected_station))
	build_btn.custom_minimum_size = Vector2(0, 34)
	if reason == "":
		build_btn.pressed.connect(func() -> void: build_requested.emit(_selected_station))
	else:
		build_btn.disabled = true
		build_btn.tooltip_text = reason
	_detail_box.add_child(build_btn)


## One material requirement tile: icon, name, "N owned", "xM required", and a
## check when sufficient. Only the owned value is reddened on a shortage — never
## the whole row. `source_station` overrides the current station's source (used
## by the build card, whose cost always comes from the stockpile).
func _requirement_tile(item_id: String, need: int, source_station := "") -> HBoxContainer:
	var station := source_station if source_station != "" else _selected_station
	var have := _stock_of(station, item_id)
	var ok := have >= need
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(18, 18)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = BlockRegistry.item_icon(item_id)
	row.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = BlockRegistry.display_name(item_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(name_lbl)
	var owned := Label.new()
	owned.text = "%d owned" % have
	owned.add_theme_font_size_override("font_size", 12)
	owned.add_theme_color_override("font_color", HAVE_COL if ok else SHORT_COL)
	row.add_child(owned)
	var need_lbl := Label.new()
	need_lbl.text = "x%d needed" % need
	need_lbl.add_theme_font_size_override("font_size", 12)
	need_lbl.add_theme_color_override("font_color", DIM_TEXT)
	row.add_child(need_lbl)
	var check := Label.new()
	check.text = "  ✓" if ok else "   "
	check.add_theme_color_override("font_color", BRASS)
	row.add_child(check)
	return row


# --- helpers (API-stable) --------------------------------------------------

## Where a recipe's inputs are checked/spent: the player's inventory for hand
## recipes, the Town Hall stockpile for everything else. (Preserved for smoke.)
func _stock_of(station: String, item_id: String) -> int:
	if station == "hand":
		return int(_player.inventory.count(item_id))
	return int(_town_hall.stockpile.get(item_id, 0))


## The first-short reason for a cost set, else "". (Preserved for smoke.)
func _short_reason(station: String, costs: Dictionary) -> String:
	for item_id in costs:
		if _stock_of(station, item_id) < int(costs[item_id]):
			return "Need more " + BlockRegistry.display_name(item_id)
	return ""


## Compact readiness for a grid tile: "Ready", "Missing <Name>", or
## "Missing N materials".
func _readiness(station: String, costs: Dictionary) -> String:
	var missing: Array[String] = []
	for item_id in costs:
		if _stock_of(station, item_id) < int(costs[item_id]):
			missing.append(BlockRegistry.display_name(item_id))
	if missing.is_empty():
		return "Ready"
	if missing.size() == 1:
		return "Missing " + missing[0]
	return "Missing %d materials" % missing.size()


func _is_locked_station(station: String) -> bool:
	return station in BUILDABLE and not _town_hall.station_built(station)


func _recipe_by_id(recipe_id: String) -> Dictionary:
	if recipe_id == "":
		return {}
	for r: Dictionary in BlockRegistry.recipes_for_station(_selected_station):
		if str(r.get("recipe_id", "")) == recipe_id:
			return r
	return {}


func _output_qty(recipe: Dictionary) -> int:
	var outputs: Dictionary = recipe.get("outputs", {})
	for k in outputs:
		return int(outputs[k])
	return 1


## Truthful, player-facing destination for a recipe's result (display only — the
## actual routing lives in game_root / town_hall and is unchanged here).
func _output_destination(recipe: Dictionary) -> String:
	var equip_slots: Dictionary = recipe.get("equip_slots", {})
	if not equip_slots.is_empty():
		return _slots_destination(equip_slots.keys())
	match str(recipe.get("recipe_id", "")):
		"basic_pick_upgrade":
			return "Pickaxe"
		"craft_axe":
			return "Axe"
		"craft_sword":
			return "Weapon Slot"
		"craft_armor_set":
			return "Armor Slots"
	if str(recipe.get("output_to", "")) == "stockpile":
		return "Town Hall Stockpile"
	return "Backpack"


func _slots_destination(slot_keys: Array) -> String:
	for k in slot_keys:
		if str(k) == "weapon":
			return "Weapon Slot"
	for k in slot_keys:
		if str(k) == "amulet":
			return "Amulet Slot"
	for k in slot_keys:
		if str(k).begins_with("ring"):
			return "Next Open Ring Slot"
	for k in slot_keys:
		if str(k) in ["helmet", "torso", "feet"]:
			return "Armor Slots"
	return "Equipment"


func _first_key(d: Dictionary) -> String:
	for k in d:
		return str(k)
	return ""


## R-07 icon contract (UNCHANGED — the smoke suite pins this): the item id whose
## icon represents a recipe row. Uses the explicit `icon` recipe metadata (for
## recipes with empty outputs -- the forged gear craft_axe/craft_sword/
## craft_armor_set) else the first output id. A "" here is an intentional,
## documented no-icon state.
func recipe_icon_id(recipe: Dictionary) -> String:
	if recipe.has("icon"):
		return str(recipe.get("icon", ""))   # explicit; "" = intentional no icon
	return _first_key(recipe.get("outputs", {}))
