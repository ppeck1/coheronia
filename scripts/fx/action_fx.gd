extends Node2D
## FQ-09M: tiny self-freeing action effects. Presentation only — stepped
## 10 Hz visual updates, deterministic geometry (no randomness), small and
## brief so actions get easier to read, not noisier. Effects free themselves
## when their last step ends, live in the "action_fx" group for tests, and
## never touch gameplay numbers or saves.
##
## Kinds: "place_pulse" (expanding box at a placed cell), "hit_spark"
## (radial sparks on a landed hit), "cast_ring" (attunement cast ring),
## "dust_puff" (collapse/respawn/death dust), "forge_spark" (craft/forge
## confirmation burst).

const TICK_HZ := 10.0
const STEPS := {
	"place_pulse": 3,
	"hit_spark": 2,
	"cast_ring": 4,
	"dust_puff": 4,
	"forge_spark": 3,
}
const DEFAULT_COLORS := {
	"place_pulse": Color(0.95, 0.9, 0.75, 0.9),
	"hit_spark": Color(1.0, 0.9, 0.6),
	"cast_ring": Color(0.72, 0.83, 1.0),
	"dust_puff": Color(0.62, 0.58, 0.52),
	"forge_spark": Color(1.0, 0.75, 0.3),
}

var kind := ""
var color := Color.WHITE
var _time := 0.0
var _step := 0


## Spawns a self-freeing effect at a world position. Returns the node (null
## for unknown kinds or a null parent, so callers never need to guard).
static func spawn(parent: Node, fx_kind: String, at: Vector2,
		tint: Color = Color.TRANSPARENT) -> Node2D:
	if parent == null or not STEPS.has(fx_kind):
		return null
	var fx: Node2D = (load("res://scripts/fx/action_fx.gd") as GDScript).new()
	fx.kind = fx_kind
	fx.color = DEFAULT_COLORS[fx_kind] if tint == Color.TRANSPARENT else tint
	fx.global_position = at
	fx.z_index = 20
	parent.add_child(fx)
	return fx


func _ready() -> void:
	add_to_group("action_fx")
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var new_step := int(_time * TICK_HZ)
	if new_step >= int(STEPS.get(kind, 0)):
		queue_free()
	elif new_step != _step:
		_step = new_step
		queue_redraw()


func _draw() -> void:
	var fade := 1.0 - float(_step) / float(maxi(1, int(STEPS.get(kind, 1))))
	var col := Color(color, color.a * (0.4 + 0.6 * fade))
	match kind:
		"place_pulse":
			var half := 8.0 + 3.0 * float(_step)
			draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), col, false, 1.0)
		"hit_spark":
			var r := 3.0 + 3.0 * float(_step)
			for k in range(6):
				var ang := TAU * float(k) / 6.0 + 0.26
				var p := Vector2(cos(ang), sin(ang)) * r
				draw_rect(Rect2(floorf(p.x), floorf(p.y), 1, 1), col)
		"cast_ring":
			var radius := 6.0 + 6.0 * float(_step)
			for k in range(16):
				var ang2 := TAU * float(k) / 16.0
				var p2 := Vector2(cos(ang2), sin(ang2)) * radius
				draw_rect(Rect2(floorf(p2.x), floorf(p2.y), 1, 1), col)
		"dust_puff":
			for k in range(5):
				var ang3 := PI + PI * float(k) / 4.0   # upward fan
				var p3 := Vector2(cos(ang3), sin(ang3) * 0.6) * (2.0 + 2.0 * float(_step)) \
					+ Vector2(0, -float(_step))
				draw_rect(Rect2(floorf(p3.x), floorf(p3.y), 2, 1), col)
		"forge_spark":
			for k in range(4):
				var ang4 := -PI * 0.8 + PI * 0.6 * float(k) / 3.0   # up and out
				var p4 := Vector2(cos(ang4), sin(ang4)) * (3.0 + 3.0 * float(_step))
				draw_rect(Rect2(floorf(p4.x), floorf(p4.y), 1, 2), col)
			if _step == 0:
				draw_rect(Rect2(-2, -2, 4, 4), col, false, 1.0)
