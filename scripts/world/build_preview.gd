extends Node2D
## R-07 build preview: a translucent ghost of the selected placeable block at the
## aim cell, tinted green when placement is valid and red when it is not (the
## reason is surfaced as event-log feedback on a failed place click). Cosmetic
## only -- it reads player/world state and never mutates the world or any save.
## Validity comes from the same `player.place_reason` the feedback uses, so the
## ghost and the message can never disagree.

const VALID_FILL := Color(0.45, 1.0, 0.5, 0.30)
const INVALID_FILL := Color(1.0, 0.4, 0.4, 0.26)
const VALID_LINE := Color(0.35, 1.0, 0.45, 0.7)
const INVALID_LINE := Color(1.0, 0.32, 0.32, 0.7)

var _player = null
var _world = null


func setup(player: Node, world: Node) -> void:
	_player = player
	_world = world
	z_index = 5   # above blocks/walls, below the HUD CanvasLayer
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	queue_redraw()


## The placeable block currently selected, or "" when nothing placeable is held
## (a tool selected) -- the preview only shows for real placement candidates.
func active_item() -> String:
	if _player == null or _world == null:
		return ""
	var item: String = _player.selected_item()
	return item if BlockRegistry.is_placeable(item) else ""


func _draw() -> void:
	var item := active_item()
	if item == "":
		return
	var t := float(_world.tile_size())
	var cell: Vector2i = _world.cell_of(get_global_mouse_position())
	var valid: bool = _player.place_reason(cell, item) == ""
	var rect := Rect2(_world.cell_center(cell) - Vector2(t, t) * 0.5, Vector2(t, t))
	var tex: Texture2D = BlockRegistry.visual_texture("blocks", item)
	if tex != null:
		draw_texture_rect(tex, rect, false, VALID_FILL if valid else INVALID_FILL)
	else:
		draw_rect(rect, VALID_FILL if valid else INVALID_FILL)
	draw_rect(rect, VALID_LINE if valid else INVALID_LINE, false, 1.0)
