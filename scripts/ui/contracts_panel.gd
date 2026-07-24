extends CanvasLayer
## R-09.2: player-facing contracts panel. The panel is presentation/control only;
## contract status, progress, acceptance, and claiming stay in game_root +
## ContractModel.

const PANEL_BG := Color(0.055, 0.065, 0.075, 0.97)
const DIM := Color(0.0, 0.0, 0.0, 0.5)
const ACCENT := Color(0.74, 0.67, 0.46)
const READY_COL := Color(0.72, 0.86, 0.70)
const ACTIVE_COL := Color(0.72, 0.78, 0.92)
const DIM_TEXT := Color(0.62, 0.66, 0.72)

var _game_root = null
var _open := false
var _list: VBoxContainer
var _row_status: Dictionary = {}
var _row_text: Dictionary = {}
var _row_action_enabled: Dictionary = {}


func _ready() -> void:
	name = "ContractsPanel"
	layer = 56
	_build()
	visible = false


func setup(game_root: Node) -> void:
	_game_root = game_root


func is_open() -> bool:
	return _open


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
	panel.custom_minimum_size = Vector2(520, 0)
	margin.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Contracts"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	vb.add_child(scroll)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)


func refresh() -> void:
	if _list == null or _game_root == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_row_status.clear()
	_row_text.clear()
	_row_action_enabled.clear()
	for contract: Dictionary in _game_root.contract_snapshot():
		_list.add_child(_contract_row(contract))


func _contract_row(contract: Dictionary) -> Control:
	var id := str(contract.get("id", ""))
	var status := str(contract.get("status", "available"))
	var progress: Dictionary = contract.get("progress", {})
	var row := VBoxContainer.new()
	row.name = "ContractRow_" + id
	row.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)
	var title := Label.new()
	title.text = "%s  [%s]" % [str(contract.get("title", id)), status.capitalize()]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", _status_color(status))
	top.add_child(title)
	var action := Button.new()
	action.custom_minimum_size = Vector2(86, 0)
	_configure_action(action, id, status)
	top.add_child(action)
	var body := Label.new()
	body.text = "%s\n%s\n%s" % [
		str(contract.get("description", "")),
		_progress_line(progress),
		_reward_line(contract.get("reward", {})),
	]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.86, 0.86, 0.82))
	row.add_child(body)
	_row_status[id] = status
	_row_text[id] = title.text + "\n" + body.text
	_row_action_enabled[id] = not action.disabled
	return row


func _configure_action(button: Button, id: String, status: String) -> void:
	match status:
		"available":
			button.text = "Accept"
			button.pressed.connect(func() -> void:
				_game_root.accept_contract(id)
				refresh())
		"completed":
			button.text = "Claim"
			button.pressed.connect(func() -> void:
				_game_root.claim_contract(id)
				refresh())
		"active":
			button.text = "Active"
			button.disabled = true
		"claimed":
			button.text = "Claimed"
			button.disabled = true
		_:
			button.text = "-"
			button.disabled = true


func _status_color(status: String) -> Color:
	match status:
		"available":
			return ACCENT
		"active":
			return ACTIVE_COL
		"completed":
			return READY_COL
		"claimed":
			return DIM_TEXT
	return Color.WHITE


func _progress_line(progress: Dictionary) -> String:
	return "Progress: %d/%d" % [
		int(progress.get("current", 0)),
		int(progress.get("target", 0)),
	]


func _reward_line(reward: Dictionary) -> String:
	match str(reward.get("type", "")):
		"grant_items":
			var parts: Array[String] = []
			for item_id in reward.get("items", {}):
				parts.append("%s x%d" % [
					BlockRegistry.display_name(str(item_id)),
					int(reward["items"][item_id]),
				])
			return "Reward: " + ", ".join(parts)
		"grant_xp":
			return "Reward: XP"
	return "Reward: -"


# Smoke hooks.
func contract_count() -> int:
	return _row_status.size()


func contract_row_status(id: String) -> String:
	return str(_row_status.get(id, ""))


func contract_row_text(id: String) -> String:
	return str(_row_text.get(id, ""))


func contract_row_action_enabled(id: String) -> bool:
	return bool(_row_action_enabled.get(id, false))
