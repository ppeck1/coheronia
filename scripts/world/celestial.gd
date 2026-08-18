extends Node2D
## M5-A: sun & moon celestial renderer — presentation-only polish over the existing
## day/night cycle. It moves a sun along an arc across the sky during the day and a
## moon during the night, both driven purely by game_root.time_of_day (the same
## saved 0..1 value that already drives the tint and HUD clock). Like the backdrop
## it lives in the world canvas so the day/night CanvasModulate tint applies, has
## no collision, and NEVER enters a save.
##
## The moon is drawn as a per-pixel texture so only its LIT crescent/gibbous is
## opaque and its dark side is fully transparent — it blends into the night sky
## instead of showing a grey disc. Both bodies also carry a soft PointLight2D so
## they radiate light.
##
## No class_name (repo convention + the runtime global-class gotcha): game_root
## preloads and owns this node.

const LightingScript := preload("res://scripts/world/lighting.gd")  # shared soft glow

## Mirror of game_root.NIGHT_START so the sun sets exactly when night falls.
const NIGHT_START := 0.65
const SUN_CORE := Color(1.0, 0.9, 0.5)
const SUN_GLOW := Color(1.0, 0.85, 0.45, 0.25)
const MOON_CORE := Color(0.92, 0.94, 1.0)
# Bodies at 4x the first size (operator request: +100% twice). Sun = glow + core;
# moon = a lit-crescent texture of side 2*MOON_R.
const SUN_GLOW_R := 88.0
const SUN_CORE_R := 44.0
const MOON_R := 36.0
const MOON_TEX_PX := 128     # moon texture resolution (square) — hi-res for a soft edge
# The arc is anchored to a FIXED sky altitude in world space (not the camera view), so
# the bodies sit high above the surface and slide off-screen as you descend — never
# floating over rock. X follows the camera; Y rides this fixed baseline.
const ARC_HEIGHT_PX := 150.0   # how far above the sky baseline the body peaks at noon
# Moonlight reads cool + subtle; the sun warm + strong.
const MOON_LIGHT_COL := Color(0.55, 0.68, 1.0)
const SUN_LIGHT_COL := Color(1.0, 0.86, 0.55)
# A true continuous synodic cycle: illumination advances smoothly one day at a time
# over SYNODIC_DAYS, `_phase_f` in [0,1) where 0 = new moon and 0.5 = full moon. The
# eight named milestones are read off `_phase_f`; full moons are rare (once per cycle),
# which is what makes the deferred full-moon hook special.
const SYNODIC_DAYS := 29
const FULL_MOON_DAY := 15    # posmod(day, SYNODIC_DAYS) whose phase is nearest full
const MOON_PHASE_NAMES := ["New Moon", "Waxing Crescent", "First Quarter",
	"Waxing Gibbous", "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"]
# Baked mare/craters: [nx, ny, radius, depth] in normalized disc space (-1..1). Only
# darken already-lit pixels, so the transparent dark side stays untouched.
const MOON_CRATERS := [
	[-0.30, -0.26, 0.24, 0.34], [0.30, 0.12, 0.17, 0.30], [0.06, 0.44, 0.14, 0.26],
	[0.42, -0.40, 0.11, 0.24], [-0.16, 0.30, 0.10, 0.22], [-0.44, 0.18, 0.09, 0.20],
]

var _time := 0.25
var _phase_f := 0.0                  # continuous lunar phase, 0 = new .. 0.5 = full
var _phase_day := 0                  # posmod(day, SYNODIC_DAYS) — rebuild key
var _moon_tex: ImageTexture = null   # cached per-phase lit-crescent texture
var _light: PointLight2D = null      # the soft glow the body casts onto the world
var _sky_layer: CanvasLayer = null   # camera-following layer, immune to the tint
var _sky: Node2D = null              # draws the bodies at full brightness on _sky_layer
var _sky_visible := true             # false underground so the sky never shows on rock
var _glow_tex: GradientTexture2D = null   # smooth radial glow sprite (no stacked rings)
var _sky_baseline_y := NAN           # fixed world-Y the arc rides (fed by game_root)


func _ready() -> void:
	name = "Celestial"
	light_mask = 0                    # a torch must not light the sky bodies
	# The radiated moon/sunlight that falls on the world stays in the world canvas.
	_glow_tex = _make_glow_texture()
	_light = PointLight2D.new()
	_light.texture = _glow_tex
	_light.energy = 0.0               # positioned/energised per-frame while drawing
	_light.z_index = -9
	# Cast shadows against the terrain occluders (like torch light) so sun/moonlight
	# is blocked by solid ground instead of bleeding through it to light underground
	# rock — only a mined shaft admits daylight below the surface.
	_light.shadow_enabled = true
	_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	add_child(_light)
	# The bodies themselves draw on a follow-the-camera CanvasLayer so the day/night
	# CanvasModulate does NOT dim them — a full moon reads as a bright disc against
	# the dark sky, and the sun stays luminous (mirrors the R-07 build-preview layer).
	_sky_layer = CanvasLayer.new()
	_sky_layer.name = "CelestialSkyLayer"
	_sky_layer.follow_viewport_enabled = true
	_sky_layer.layer = 0
	add_child(_sky_layer)
	_sky = Node2D.new()
	_sky.name = "CelestialBodies"
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sky.light_mask = 0
	_sky.z_index = -9
	_sky.draw.connect(_draw_bodies)
	_sky_layer.add_child(_sky)
	_rebuild_moon_texture()


## The soft radiated glow — shared with torches/lava via the lighting module so all
## light sources fall off the same gentle way (bright core, feathered rim).
func _make_glow_texture() -> GradientTexture2D:
	return LightingScript.glow_texture()


## Underground the sky must not draw over rock: game_root feeds this from the
## player's depth vs the surface line. Hiding the sky node stops its `draw` signal,
## so we also zero the cast light (which is re-energised on the next visible draw).
func set_sky_visible(v: bool) -> void:
	if v == _sky_visible:
		return
	_sky_visible = v
	if _sky != null:
		_sky.visible = v
	if not v and _light != null:
		_light.energy = 0.0


## The fixed world-Y the arc rides — game_root feeds this from the average surface so
## the bodies sit at a constant sky altitude (never drawn relative to the camera view).
func set_sky_baseline(world_y: float) -> void:
	_sky_baseline_y = world_y
	_redraw_sky()


func set_time(t: float) -> void:
	_time = fposmod(t, 1.0)
	_redraw_sky()


## Advance the continuous lunar cycle from the day count (one step per in-game day
## over the ~29-day synodic period). Rebuild the texture only when the day changes.
func set_phase_from_day(day: int) -> void:
	var d := posmod(day, SYNODIC_DAYS)
	if d != _phase_day:
		_phase_day = d
		_phase_f = float(d) / float(SYNODIC_DAYS)
		_rebuild_moon_texture()
	_redraw_sky()


func _redraw_sky() -> void:
	if _sky != null:
		_sky.queue_redraw()


## The 0..1 lit fraction of the moon for a continuous phase (0 = new, 0.5 = full).
## Pure so the smoke can assert the cycle without rendering.
static func illumination_f(phase_f: float) -> float:
	return 0.5 - 0.5 * cos(fposmod(phase_f, 1.0) * TAU)


## A later gameplay hook: true only on the single full-moon day of the cycle.
func is_full_moon() -> bool:
	return _phase_day == FULL_MOON_DAY


## Nearest named milestone (New / Waxing Crescent / First Quarter / Waxing Gibbous /
## Full / Waning Gibbous / Last Quarter / Waning Crescent).
func phase_name() -> String:
	return MOON_PHASE_NAMES[int(round(_phase_f * 8.0)) % 8]


## Nearest 0..7 milestone bucket (0 = new, 4 = full) — kept for external readers.
func moon_phase() -> int:
	return int(round(_phase_f * 8.0)) % 8


## Pure geometry so the smoke can assert the arc without rendering: where the sun and
## moon sit for a given time-of-day and which is up. X sweeps across the visible width
## (rise left → set right) so the body is always above the surface you're on; Y rides a
## FIXED sky altitude (`baseline_y`, world-space) and peaks `ARC_HEIGHT_PX` above it at
## noon — so underground (camera far below the baseline) the body is off-screen. When
## `baseline_y` is NAN (pure-geometry callers) it falls back to a view-relative altitude.
static func positions(t: float, view: Rect2, baseline_y := NAN) -> Dictionary:
	var margin := view.size.x * 0.08
	var span := view.size.x - margin * 2.0
	var is_night := t >= NIGHT_START
	var frac := t / NIGHT_START if not is_night \
		else (t - NIGHT_START) / (1.0 - NIGHT_START)
	frac = clampf(frac, 0.0, 1.0)
	var base_y := baseline_y if not is_nan(baseline_y) else view.position.y + view.size.y * 0.40
	var body := Vector2(view.position.x + margin + span * frac,
		base_y - sin(frac * PI) * ARC_HEIGHT_PX)
	return {
		"is_night": is_night,
		"sun": body, "moon": body,
		"sun_visible": not is_night, "moon_visible": is_night,
	}


## The world-space direction (normalized, +y down) from terrain UP toward the
## currently-visible body, for the cave-depth shader's sky-admission march. The arc
## sweeps rise-left → set-right, so at dawn the sun sits low to the east (ray slants
## up-and-right), at noon nearly straight up, at dusk up-and-left — a mined window
## facing that direction admits the light. Pure geometry off `time_of_day`; the fixed
## `ARC_HEIGHT_PX`/half-width span set the slope the same way `positions()` does.
func sky_direction() -> Vector2:
	var is_night := _time >= NIGHT_START
	var frac := _time / NIGHT_START if not is_night \
		else (_time - NIGHT_START) / (1.0 - NIGHT_START)
	frac = clampf(frac, 0.0, 1.0)
	# Horizontal progress across the arc maps to a slant: -1 (east/low) .. +1 (west/low),
	# 0 at the zenith. The vertical reach is the arc peak; combine for the up-toward-body
	# ray. Keep it always pointing UP (negative y) so it never marches down into rock.
	var slant := 2.0 * frac - 1.0
	return Vector2(slant, -1.0).normalized()


## How strongly a clear slant path re-admits ambient sky light (0 disables the march):
## full by day, and by night scaled by the moon's lit fraction so a new moon admits
## nothing while a full moon lets soft moonlight down an open shaft/window.
func sky_admit_strength() -> float:
	var is_night := _time >= NIGHT_START
	if not is_night:
		return 1.0
	return clampf(illumination_f(_phase_f), 0.0, 1.0)


## Rebuild the moon texture for the current phase: opaque only where the disc is LIT
## (dark side transparent → blends into the night sky). Waxing lights the right
## limb, waning the left; full is a whole disc, new is empty.
func _rebuild_moon_texture() -> void:
	var n := MOON_TEX_PX
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var f := illumination_f(_phase_f)
	var waxing := _phase_f < 0.5
	var r := float(n) * 0.5 - 1.0
	var cx := float(n) * 0.5
	var cy := float(n) * 0.5
	for py in range(n):
		var ny := (float(py) + 0.5 - cy) / r        # -1..1
		if absf(ny) > 1.0:
			continue
		var limb := sqrt(maxf(0.0, 1.0 - ny * ny))   # normalized half-width of the disc row
		var term_x := (1.0 - 2.0 * f) * limb          # terminator x (normalized)
		for px in range(n):
			var nx := (float(px) + 0.5 - cx) / r      # -1..1
			if nx * nx + ny * ny > 1.0:
				continue                              # outside the disc
			var lit := nx >= term_x if waxing else nx <= -term_x
			if not lit:
				continue
			# wide soft rim so the whole edge (and the crescent terminator) feathers
			# out instead of reading as a hard-cut disc.
			var dist := sqrt((nx * r) * (nx * r) + (ny * r) * (ny * r))
			var edge := 1.0 - smoothstep(r - 4.0, r, dist)
			# soften the terminator too, so the lit/dark boundary is not a hard line.
			var term_soft := smoothstep(0.0, 0.06, absf(nx - (term_x if waxing else -term_x)))
			var c := MOON_CORE
			# baked mare: darken (not erase) near crater centres → grey seas, silhouette intact.
			var dim := 1.0
			for cr in MOON_CRATERS:
				var cd := sqrt((nx - cr[0]) * (nx - cr[0]) + (ny - cr[1]) * (ny - cr[1]))
				if cd < cr[2]:
					dim -= float(cr[3]) * (1.0 - smoothstep(cr[2] * 0.35, cr[2], cd))
			dim = clampf(dim, 0.45, 1.0)
			c = Color(c.r * dim, c.g * dim, c.b * dim, c.a)
			c.a *= clampf(edge, 0.0, 1.0) * clampf(0.4 + 0.6 * term_soft, 0.0, 1.0)
			img.set_pixel(px, py, c)
	_moon_tex = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	_redraw_sky()                # follow the camera as it pans


func _current_view() -> Rect2:
	var inv := _sky.get_canvas_transform().affine_inverse()
	var vp := get_viewport_rect().size
	var a := inv * Vector2.ZERO
	var b := inv * vp
	return Rect2(a, b - a)


## Draw the sun/moon on the tint-immune sky layer and cast the matching light onto
## the world. Called via the _sky node's `draw` signal (the drawing calls target it).
func _draw_bodies() -> void:
	var view := _current_view()
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		return
	var p: Dictionary = positions(_time, view, _sky_baseline_y)
	if bool(p["sun_visible"]):
		var s: Vector2 = p["sun"]
		# Smooth, layered soft-glow sprites (a broad warm corona → tighter bright glow),
		# then a solid core. Using the shared radial gradient means a continuous falloff
		# with no stacked-circle banding or hard flare polygons.
		_draw_glow(s, SUN_GLOW_R * 2.6, Color(1.0, 0.82, 0.45, 0.22))
		_draw_glow(s, SUN_GLOW_R * 1.5, Color(1.0, 0.86, 0.5, 0.45))
		_draw_glow(s, SUN_CORE_R * 1.6, Color(1.0, 0.9, 0.55, 0.7))
		_sky.draw_circle(s, SUN_CORE_R, SUN_CORE)
		# A large, soft warm pool cast onto the world so light visibly radiates from the
		# sun (most apparent at dawn/dusk when the ambient is dim; midday daylight is
		# already full-bright ambient). Fades smoothly from the body outward.
		_radiate(s, SUN_LIGHT_COL, 760.0, 0.85)
	else:
		var m: Vector2 = p["moon"]
		var lit := illumination_f(_phase_f)
		# A cool, subtle halo (blue, far fainter than the sun) that grows with how full
		# the moon is; smooth gradient sprite, no banding.
		if lit > 0.05:
			_draw_glow(m, MOON_R * 2.4, Color(0.6, 0.72, 1.0, 0.10 * lit))
		if _moon_tex != null:
			var side := MOON_R * 2.0
			_sky.draw_texture_rect(_moon_tex, Rect2(m - Vector2(MOON_R, MOON_R),
				Vector2(side, side)), false)
		# A large but subtle, cool moonlight pool — clearly weaker than the sun, so the
		# night reads as softly moonlit rather than daylit.
		_radiate(m, MOON_LIGHT_COL, 600.0, 0.10 + 0.22 * lit)


## Draw one smooth radial glow sprite (the shared gradient, tinted) centred at `at`.
func _draw_glow(at: Vector2, radius: float, color: Color) -> void:
	if _glow_tex == null:
		return
	var d := radius * 2.0
	_sky.draw_texture_rect(_glow_tex, Rect2(at - Vector2(radius, radius),
		Vector2(d, d)), false, color)


## Position and energise the radiated glow at the body.
func _radiate(at: Vector2, color: Color, radius: float, energy: float) -> void:
	if _light == null:
		return
	_light.position = at
	_light.color = color
	_light.energy = energy
	# GradientTexture2D is 256px; texture_scale maps it to the desired radius.
	_light.texture_scale = (radius * 2.0) / 256.0
