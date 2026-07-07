extends PanelContainer
## FQ-06: visual skill tree navigator (preloaded by hud.gd — no class_name,
## matching the registry pattern, so plain runs never depend on the editor's
## global class cache). Node buttons are laid out from the
## data-driven grid positions in data/progression/perks.json inside a
## ScrollContainer; the inspector shows the selected node; the learn button
## spends real level-derived perk points. Locked / available / purchased
## states come from game_root.perk_state. One live lane (Miner) for now;
## the other lanes are listed as planned.

signal purchase_requested(perk_id: String)

const LIVE_LANE := "miner"
const NODE_SIZE := Vector2(150, 46)
const SPACING := Vector2(180, 76)
const CANVAS_MARGIN := Vector2(20, 16)

const STATE_COLORS := {
	"purchased": Color(0.55, 0.95, 0.55),
	"available": Color(1.0, 1.0, 1.0),
	"locked": Color(0.55, 0.55, 0.62),
}

var game_root: Node
var _selected_id := ""
var _points_label: Label
var _info_label: Label
var _buy_button: Button
var _planned_label: Label
var _canvas: Control
var _node_buttons: Dictionary = {}   # perk_id -> Button


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -270
	offset_top = -210
	custom_minimum_size = Vector2(540, 420)
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "SKILL TREE — MINER LANE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_points_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_canvas = Control.new()
	scroll.add_child(_canvas)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(500, 88)
	_info_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_info_label)
	_buy_button = Button.new()
	_buy_button.text = "Learn perk"
	_buy_button.disabled = true
	_buy_button.pressed.connect(_on_buy_pressed)
	box.add_child(_buy_button)
	_planned_label = Label.new()
	_planned_label.add_theme_font_size_override("font_size", 12)
	_planned_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_planned_label)
	var hint := Label.new()
	hint.text = "Press K to close"
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)


## Called once by game_root._wire_references via hud.setup_skill_panel.
func setup(root: Node) -> void:
	game_root = root
	_build_nodes()
	refresh()


func _build_nodes() -> void:
	for existing in _node_buttons.values():
		existing.queue_free()
	_node_buttons.clear()
	var live_lane: Dictionary = {}
	var planned: Array[String] = []
	for lane: Dictionary in game_root.perk_lanes():
		if str(lane.get("id", "")) == LIVE_LANE:
			live_lane = lane
		else:
			planned.append(str(lane.get("display_name", "?")))
	_planned_label.text = "Planned lanes: %s" % ", ".join(planned)
	var max_grid := Vector2.ZERO
	for perk: Dictionary in live_lane.get("perks", []):
		var perk_id := str(perk.get("id", ""))
		var pos_arr: Array = perk.get("position", [0, 0])
		if pos_arr.size() < 2:
			pos_arr = [0, 0]
		var grid := Vector2(float(pos_arr[0]), float(pos_arr[1]))
		max_grid = max_grid.max(grid)
		var btn := Button.new()
		btn.custom_minimum_size = NODE_SIZE
		btn.position = CANVAS_MARGIN + grid * SPACING
		btn.pressed.connect(_on_node_pressed.bind(perk_id))
		_canvas.add_child(btn)
		_node_buttons[perk_id] = btn
	_canvas.custom_minimum_size = CANVAS_MARGIN * 2.0 + max_grid * SPACING + NODE_SIZE


func refresh() -> void:
	if game_root == null:
		return
	_points_label.text = "Perk points: %d available / %d total (1 per level above 1)" % [
		game_root.perk_points_available(), game_root.perk_points_total()]
	for perk_id in _node_buttons:
		var btn: Button = _node_buttons[perk_id]
		var perk: Dictionary = game_root.get_perk(perk_id)
		var state: String = game_root.perk_state(perk_id)
		btn.modulate = STATE_COLORS.get(state, Color.WHITE)
		var marker := ""
		if state == "purchased":
			marker = "[OWNED] "
		elif state == "locked":
			marker = "[LOCKED] "
		btn.text = "%s%s (%d)" % [marker, str(perk.get("display_name", perk_id)),
			int(perk.get("cost", 1))]
	_refresh_inspector()


func _refresh_inspector() -> void:
	if _selected_id == "":
		_info_label.text = "Select a node to inspect it."
		_buy_button.disabled = true
		return
	var perk: Dictionary = game_root.get_perk(_selected_id)
	var state: String = game_root.perk_state(_selected_id)
	var prereq_names: Array[String] = []
	for prereq in perk.get("prerequisites", []):
		prereq_names.append(str(game_root.get_perk(str(prereq)).get("display_name", prereq)))
	_info_label.text = "%s — %s\nCost: %d point%s · Effect: %s x%.2f · Requires: %s\n%s" % [
		str(perk.get("display_name", _selected_id)), state.to_upper(),
		int(perk.get("cost", 1)), "" if int(perk.get("cost", 1)) == 1 else "s",
		str(perk.get("effect_key", "?")), float(perk.get("effect_value", 0.0)),
		", ".join(prereq_names) if not prereq_names.is_empty() else "nothing",
		str(perk.get("description", ""))]
	_buy_button.disabled = not (state == "available"
		and int(perk.get("cost", 1)) <= game_root.perk_points_available())


## Smoke/test hooks.
func info_text() -> String:
	return _info_label.text


func select_node(perk_id: String) -> void:
	_on_node_pressed(perk_id)


func _on_node_pressed(perk_id: String) -> void:
	_selected_id = perk_id
	refresh()


func _on_buy_pressed() -> void:
	if _selected_id != "":
		purchase_requested.emit(_selected_id)
