extends Node2D
## M5-A: sun & moon celestial renderer — presentation-only polish over the existing
## day/night cycle. It moves a sun along an arc across the sky during the day and a
## moon during the night, both driven purely by game_root.time_of_day (the same
## saved 0..1 value that already drives the tint and HUD clock). Like the backdrop
## it lives in the world canvas so the day/night CanvasModulate tint applies, has
## no collision, ignores 2D lights (light_mask = 0), and NEVER enters a save.
##
## No class_name (repo convention + the runtime global-class gotcha): game_root
## preloads and owns this node.

## Mirror of game_root.NIGHT_START so the sun sets exactly when night falls.
const NIGHT_START := 0.65
const SUN_CORE := Color(1.0, 0.9, 0.5)
const SUN_GLOW := Color(1.0, 0.85, 0.45, 0.25)
const MOON_CORE := Color(0.9, 0.92, 0.98)
const MOON_SHADOW := Color(0.20, 0.22, 0.34)
# Bodies at 2x their first size (operator request). Sun = glow + core; moon disc.
const SUN_GLOW_R := 44.0
const SUN_CORE_R := 22.0
const MOON_R := 18.0
# An 8-step lunar cycle (advances one step per in-game day). Phase 0 = full moon,
# phase 4 = new moon; a later gameplay hook can read is_full_moon().
const MOON_PHASES := 8

var _time := 0.25
var _phase := 0   # 0..MOON_PHASES-1, set from the day count


func _ready() -> void:
	name = "Celestial"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light_mask = 0                # a torch must not light the sky
	z_index = -9                  # in front of the backdrop (-10), behind terrain


## Set the current time-of-day fraction (0..1) and redraw. Called by game_root as
## time advances and on load.
func set_time(t: float) -> void:
	_time = fposmod(t, 1.0)
	queue_redraw()


## Advance the lunar cycle from the day count (one phase per day).
func set_phase_from_day(day: int) -> void:
	_phase = posmod(day, MOON_PHASES)
	queue_redraw()


## The 0..1 lit fraction of the moon for a phase (1 = full at phase 0, 0 = new at
## phase 4). Pure so the smoke can assert the cycle without rendering.
static func illumination(phase: int) -> float:
	return cos(float(posmod(phase, MOON_PHASES)) / float(MOON_PHASES) * TAU) * 0.5 + 0.5


## A later gameplay hook: true on the full-moon night (brightest phase).
func is_full_moon() -> bool:
	return posmod(_phase, MOON_PHASES) == 0


func moon_phase() -> int:
	return posmod(_phase, MOON_PHASES)


func _process(_delta: float) -> void:
	queue_redraw()               # follow the camera as it pans


## Pure geometry so the smoke can assert the arc without rendering: where the sun
## and moon sit for a given time-of-day within a visible world rect, and which is
## up. The active body rises at the left edge, peaks at mid-phase, and sets at the
## right — sun across the day, moon across the night.
static func positions(t: float, view: Rect2) -> Dictionary:
	var horizon_y := view.position.y + view.size.y * 0.42
	var arc_h := view.size.y * 0.34
	var margin := view.size.x * 0.08
	var span := view.size.x - margin * 2.0
	var is_night := t >= NIGHT_START
	var frac := t / NIGHT_START if not is_night \
		else (t - NIGHT_START) / (1.0 - NIGHT_START)
	frac = clampf(frac, 0.0, 1.0)
	var body := Vector2(view.position.x + margin + span * frac,
		horizon_y - sin(frac * PI) * arc_h)
	return {
		"is_night": is_night,
		"sun": body, "moon": body,
		"sun_visible": not is_night, "moon_visible": is_night,
	}


func _current_view() -> Rect2:
	var inv := get_canvas_transform().affine_inverse()
	var vp := get_viewport_rect().size
	var a := inv * Vector2.ZERO
	var b := inv * vp
	return Rect2(a, b - a)


func _draw() -> void:
	var view := _current_view()
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		return
	var p: Dictionary = positions(_time, view)
	if bool(p["sun_visible"]):
		var s: Vector2 = p["sun"]
		draw_circle(s, SUN_GLOW_R, SUN_GLOW)
		draw_circle(s, SUN_CORE_R * 1.55, Color(SUN_GLOW.r, SUN_GLOW.g, SUN_GLOW.b, 0.35))
		draw_circle(s, SUN_CORE_R, SUN_CORE)
	else:
		_draw_moon(p["moon"])


## Draw the moon at its current phase: the bright disc, then a shadow disc offset
## horizontally to leave a lit crescent/gibbous (waxing = shadow on the left, waning
## = on the right). At full moon (phase 0) no shadow is drawn.
func _draw_moon(m: Vector2) -> void:
	draw_circle(m, MOON_R, MOON_CORE)
	var illum := illumination(_phase)
	if illum >= 0.98:
		return
	var side := -1.0 if _phase < 4 else 1.0        # waxing shadow left, waning right
	var shadow_dx := side * (1.0 - illum) * 2.0 * MOON_R
	draw_circle(m + Vector2(shadow_dx, 0.0), MOON_R, MOON_SHADOW)
