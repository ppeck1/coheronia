extends Node2D
## R-08 slice 3: a loose item lying on the ground. Mining yield and enemy loot
## now spawn these at the point of production instead of teleporting straight
## into the player's backpack. The drop falls under gravity until it rests on the
## ground, then it is free to be picked up: the player auto-collects any drop
## within Player.PICKUP_RADIUS (so their own mining still lands in the pack
## immediately), and a hauler settler carries whatever is left to the Town Hall
## stockpile. It is drawn with the SAME icon the inventory uses
## (BlockRegistry.item_icon), so a freed item on the map matches its backpack
## slot. Identity (item/count/position) persists in the world save.

const GRAVITY := 900.0
const SETTLE_PROBE_PX := 7.0    # how far below the drop we look for solid ground
const SIZE := 14.0              # on-ground icon size (px); the tile is 16

var world = null
var item_id := ""
var count := 1
var _vy := 0.0                  # accumulated fall speed (real gravity, not a drift)
var _settled := false


func _ready() -> void:
	add_to_group("item_drops")
	z_index = 5           # ride above the tilemap, below HUD
	queue_redraw()


## Place this drop in the world. Count is clamped to at least 1 -- a zero/negative
## stack is never a valid ground item (see world.spawn_item_drop, which refuses it).
func setup(w: Node, id: String, n: int, pos: Vector2) -> void:
	world = w
	item_id = id
	count = maxi(1, n)
	global_position = pos


## Gravity: loot dropped in mid-air (a mined column, an enemy killed over a pit)
## accelerates downward until the cell just below is solid, then rests snapped on
## top of that block. Clamps at the world floor so a drop over the void can never
## fall forever. Once settled it stops processing -- it is now free to pick up.
func _physics_process(delta: float) -> void:
	if world == null or _settled:
		return
	var t: float = float(world.tile_size())
	var below: Vector2i = world.cell_of(global_position + Vector2(0, SETTLE_PROBE_PX))
	if world.is_solid_at(below) or global_position.y >= float(world.height) * t:
		# Rest on the surface of the block below (its top edge less half our size).
		if world.is_solid_at(below):
			global_position.y = float(below.y) * t - SIZE * 0.5
		_settled = true
		return
	_vy += GRAVITY * delta
	global_position.y += _vy * delta


func _draw() -> void:
	# Draw the item with the exact icon the inventory uses, so a freed drop on the
	# map reads as the same picture as its backpack slot. A soft ground shadow sits
	# under it for grounding. item_icon never returns null.
	draw_circle(Vector2(0, SIZE * 0.5), SIZE * 0.42, Color(0, 0, 0, 0.22))   # shadow
	var tex: Texture2D = BlockRegistry.item_icon(item_id)
	if tex != null:
		draw_texture_rect(tex, Rect2(-SIZE / 2.0, -SIZE / 2.0, SIZE, SIZE), false)


func to_dict() -> Dictionary:
	return {"item": item_id, "count": count, "x": global_position.x, "y": global_position.y}


func from_dict(d: Dictionary) -> void:
	item_id = str(d.get("item", item_id))
	count = int(d.get("count", count))
	global_position = Vector2(
		float(d.get("x", global_position.x)), float(d.get("y", global_position.y)))
