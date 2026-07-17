extends PanelContainer
## Drag/drop wrapper for inventory board slots. The HUD owns all mutation; this
## cell only packages source/target metadata and draws the moving preview.

var hud: CanvasLayer
var slot_kind := ""
var slot_index := -1
var slot_id := ""
var item_id := ""
var count := 0


func setup(owner: CanvasLayer, kind: String, index: int, item: String, amount: int,
		id: String = "") -> void:
	hud = owner
	slot_kind = kind
	slot_index = index
	slot_id = id
	item_id = item
	count = amount


func _get_drag_data(_at_position: Vector2) -> Variant:
	if hud == null or item_id == "":
		return null
	set_drag_preview(_build_drag_preview())
	return {
		"source": "inventory_board",
		"kind": slot_kind,
		"index": slot_index,
		"slot_id": slot_id,
		"item_id": item_id,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if hud == null:
		return false
	return hud.can_drop_inventory_slot(slot_kind, slot_index, data, slot_id)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if hud == null:
		return
	hud.drop_inventory_slot(slot_kind, slot_index, data, slot_id)


func _build_drag_preview() -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = custom_minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.1, 0.92)
	style.border_color = Color(0.95, 0.74, 0.25, 0.95)
	style.set_border_width_all(2)
	preview.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = BlockRegistry.item_icon(item_id)
	box.add_child(icon)
	var label := Label.new()
	label.text = "x%d" % count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	box.add_child(label)
	return preview
