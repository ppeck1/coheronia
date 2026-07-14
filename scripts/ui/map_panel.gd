extends Control
## FQ-15: a compact schematic map. Draws from a plain snapshot dict (world size,
## hall/player cells, revealed bands, ore/threat markers) supplied by game_root —
## it holds no game references and only shows scouted bands, so it is testable and
## never X-rays the world.

const PAD := 10.0
const TITLE_H := 20.0

const COL_BG := Color(0.06, 0.07, 0.10, 0.95)
const COL_FRAME := Color(0.85, 0.72, 0.35, 0.85)
const COL_UNSEEN := Color(0.10, 0.11, 0.15, 1.0)
const COL_SEEN := Color(0.20, 0.24, 0.31, 1.0)
const COL_HALL := Color(0.92, 0.76, 0.35)
const COL_PLAYER := Color(0.35, 0.82, 0.96)
const COL_ORE := Color(0.86, 0.66, 0.28)
const COL_THREAT := Color(0.88, 0.28, 0.28)

var snapshot: Dictionary = {}


func set_snapshot(s: Dictionary) -> void:
	snapshot = s
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Panel background + frame.
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	draw_rect(Rect2(Vector2.ZERO, size), COL_FRAME, false, 1.0)
	draw_string(font, Vector2(PAD, PAD + 12.0), "Map — Town Hall ◆  You ●  ore ·  threat ·",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.88, 0.95))

	var w := int(snapshot.get("width", 0))
	var h := int(snapshot.get("height", 0))
	if w <= 0 or h <= 0:
		return
	var origin := Vector2(PAD, PAD + TITLE_H)
	var draw_w := size.x - PAD * 2.0
	var draw_h := size.y - PAD * 2.0 - TITLE_H
	var sx := draw_w / float(w)
	var sy := draw_h / float(h)

	# Unseen field, then revealed bands on top.
	draw_rect(Rect2(origin, Vector2(draw_w, draw_h)), COL_UNSEEN)
	var region := int(snapshot.get("region", 16))
	for reg in snapshot.get("revealed", []):
		var rp: Vector2 = origin + Vector2(reg.x * region * sx, reg.y * region * sy)
		draw_rect(Rect2(rp, Vector2(region * sx, region * sy)), COL_SEEN)

	for cell in snapshot.get("ore", []):
		draw_rect(Rect2(origin + Vector2(cell.x * sx, cell.y * sy) - Vector2(1, 1),
			Vector2(3, 3)), COL_ORE)
	for cell in snapshot.get("threats", []):
		draw_rect(Rect2(origin + Vector2(cell.x * sx, cell.y * sy) - Vector2(1.5, 1.5),
			Vector2(3, 3)), COL_THREAT)

	var hall: Vector2i = snapshot.get("hall", Vector2i.ZERO)
	_marker(origin + Vector2(hall.x * sx, hall.y * sy), 4.0, COL_HALL)
	var pl: Vector2i = snapshot.get("player", Vector2i.ZERO)
	_marker(origin + Vector2(pl.x * sx, pl.y * sy), 3.0, COL_PLAYER)

	draw_rect(Rect2(origin, Vector2(draw_w, draw_h)), COL_FRAME, false, 1.0)


func _marker(at: Vector2, r: float, color: Color) -> void:
	draw_rect(Rect2(at - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), color)
	draw_rect(Rect2(at - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), Color(0, 0, 0, 0.6), false, 1.0)
