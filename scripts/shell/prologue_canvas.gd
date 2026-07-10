extends Control
## FQ-09C cinematic canvas: the 640x360 pixel surface of the opening.
## Style: "Coheronia DOS Vector Cinematic" — rasterized monoline contours,
## stepped plotting, hard palette, no gradients, no smooth tweens.
##
## Everything is deterministic: `build_commands(scene_index, tick)` is a pure
## function from (scene, tick) to a flat draw-command list, and `_draw` only
## executes that list. One tick = one visual update (the controller steps
## ticks at TICK_HZ). Tests fingerprint the command list at chosen ticks, so
## animation never depends on wall-clock timing.
##
## Command forms (all coordinates pre-snapped to the 640x360 integer grid):
##   ["px",   Vector2, Color]          one pixel
##   ["rect", Rect2, Color]            filled rectangle
##   ["box",  Rect2, Color]            rectangle outline
##   ["line", Vector2, Vector2, Color] hard 1px segment
##   ["poly", PackedVector2Array, Color] filled silhouette polygon

const W := 640
const H := 360
const TICK_HZ := 10

# --- EGA-inspired palette: ~60% void, ~30% cool linework, ~10% accents ---
const INK := Color8(3, 5, 10)            # void / negative space
const NIGHT := Color8(10, 14, 26)        # deep blue-black field
const LINE_DIM := Color8(52, 66, 96)     # unlit structure
const SLATE := Color8(96, 116, 148)      # dominant cool linework
const CYAN_MUTED := Color8(88, 148, 158) # water / distance
const STEEL := Color8(130, 138, 154)     # stone / iron
const AMBER := Color8(226, 156, 60)      # fire / shelter / labor
const BRASS := Color8(178, 134, 66)      # dimmer civilization tone
const EMBER := Color8(140, 84, 40)       # lowest fire step
const RED_WARN := Color8(168, 52, 40)    # danger, sparingly
const STAR_WHITE := Color8(236, 240, 250)# coherence / attunement

var scene_index := 0
var tick := 0


func set_state(scene: int, new_tick: int) -> void:
	scene_index = scene
	tick = new_tick
	queue_redraw()


func _draw() -> void:
	for c in build_commands(scene_index, tick):
		match c[0]:
			"px":
				draw_rect(Rect2(c[1], Vector2.ONE), c[2], true)
			"rect":
				draw_rect(c[1], c[2], true)
			"box":
				draw_rect(c[1], c[2], false, 1.0)
			"line":
				draw_line(c[1], c[2], c[3], 1.0, false)
			"poly":
				draw_colored_polygon(c[1], c[2])


## Pure (scene, tick) -> draw command list. The whole cinematic lives here.
func build_commands(s: int, t: int) -> Array:
	var c: Array = []
	c.append(["rect", Rect2(0, 0, W, H), INK])
	match s:
		0: _scene_first_star(c, t)
		1: _scene_unraveling_roads(c, t)
		2: _scene_scattered_peoples(c, t)
		3: _scene_darkness_measures(c, t)
		4: _scene_first_hall(c, t)
		5: _scene_attunement_pulse(c, t)
		6: _scene_civilization(c, t)
		7: _scene_title_card(c, t)
	return c


## Deterministic state fingerprint for tests: same (scene, tick) must always
## hash identically, and an animated scene must hash differently across ticks.
func fingerprint(s: int, t: int) -> int:
	return hash(var_to_str(build_commands(s, t)))


# =========================================================================
# Animation primitives (all quantized; no randf, no easing)
# =========================================================================

## Deterministic pseudo-random int from an index (plotter jitter, shuffles).
static func _h(n: int) -> int:
	var x := n * 2654435761
	x = (x ^ (x >> 13)) * 1274126177
	return absi(x ^ (x >> 16))


static func _sn(v: Vector2) -> Vector2:
	return Vector2(floorf(v.x), floorf(v.y))


func _px(c: Array, v: Vector2, col: Color) -> void:
	c.append(["px", _sn(v), col])


func _ln(c: Array, a: Vector2, b: Vector2, col: Color) -> void:
	c.append(["line", _sn(a), _sn(b), col])


## plotLine: reveals the first `progress` (0..1) of a segment, as though a
## plotter is drawing it. Endpoint snapped to the pixel grid.
func _plot_line(c: Array, a: Vector2, b: Vector2, col: Color, progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	if p <= 0.0:
		return
	_ln(c, a, a.lerp(b, p), col)


## revealContour: progressive polyline plot across the path's total length.
func _plot_path(c: Array, pts: Array, col: Color, progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	if p <= 0.0 or pts.size() < 2:
		return
	var total := 0.0
	for i in range(pts.size() - 1):
		total += (pts[i + 1] as Vector2).distance_to(pts[i])
	var budget := total * p
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := a.distance_to(b)
		if budget <= 0.0:
			return
		if budget >= seg:
			_ln(c, a, b, col)
			budget -= seg
		else:
			_ln(c, a, a.lerp(b, budget / seg), col)
			return


## segmentedDissolve: draws a polyline with `removed` segments already gone,
## vanishing in a fixed hash-shuffled order — discrete, never a fade.
func _dissolve_path(c: Array, pts: Array, col: Color, removed: int, seed_val: int) -> void:
	var n := pts.size() - 1
	if n < 1:
		return
	var order: Array = []
	for i in range(n):
		order.append(i)
	order.sort_custom(func(x, y): return _h(seed_val + x) < _h(seed_val + y))
	var gone := {}
	for k in range(clampi(removed, 0, n)):
		gone[order[k]] = true
	for i in range(n):
		if not gone.has(i):
			_ln(c, pts[i], pts[i + 1], col)


## stepPulse: one hard-edged expanding ring, drawn as plotted pixels on a
## circle (16 stepped angles), alive for `life` ticks after `start`.
func _pulse_ring(c: Array, center: Vector2, t: int, start: int, life: int,
		step_px: int, col: Color) -> void:
	var age := t - start
	if age < 0 or age >= life:
		return
	var r := float((age + 1) * step_px)
	for k in range(16):
		var ang := TAU * float(k) / 16.0
		_px(c, center + Vector2(cos(ang), sin(ang)) * r, col)


## paletteCycle: hard color table lookup by tick.
static func _cycle(cols: Array, t: int, period: int) -> Color:
	return cols[(t / maxi(1, period)) % cols.size()]


## Torch: a stake pixel-pair plus a 2px flame stepping through the fire table.
func _torch(c: Array, base: Vector2, t: int, phase: int) -> void:
	_ln(c, base, base + Vector2(0, -4), BRASS)
	var flame := _cycle([AMBER, EMBER, AMBER, BRASS], t + phase, 2)
	_px(c, base + Vector2(0, -5), flame)
	_px(c, base + Vector2(0, -6), flame)
	if (t + phase) % 4 == 0:
		_px(c, base + Vector2(-1, -5), EMBER)


## showForFrames helper: true only inside [start, start+frames).
static func _shown(t: int, start: int, frames: int) -> bool:
	return t >= start and t < start + frames


## steppedPan / discrete parallax: quantized offset, one jump per `per` ticks.
static func _step_off(t: int, per: int, px_per_step: float) -> float:
	return float(t / maxi(1, per)) * px_per_step


# =========================================================================
# Shared structures
# =========================================================================

## The founding hall as an ordered assembly of plotted segments. Scene 05
## builds it piece by piece (`upto` = how many segments exist, `partial` =
## progress of the segment currently being plotted); later scenes pass a
## large `upto` for the finished frame. This is the deliberate inversion of
## scene 02: there lines vanish, here lines join and lock.
func _hall(c: Array, o: Vector2, t: int, upto: int, partial: float) -> void:
	var segs := [
		# foundation stones (rects appear whole, one per step)
		["rect", Rect2(o.x - 30, o.y - 4, 12, 4)],
		["rect", Rect2(o.x - 14, o.y - 4, 12, 4)],
		["rect", Rect2(o.x + 2, o.y - 4, 12, 4)],
		["rect", Rect2(o.x + 18, o.y - 4, 12, 4)],
		# posts
		["line", Vector2(o.x - 26, o.y - 4), Vector2(o.x - 26, o.y - 34)],
		["line", Vector2(o.x + 26, o.y - 4), Vector2(o.x + 26, o.y - 34)],
		# wall plate + door frame
		["line", Vector2(o.x - 26, o.y - 34), Vector2(o.x + 26, o.y - 34)],
		["box", Rect2(o.x - 5, o.y - 16, 10, 12)],
		# diagonal braces
		["line", Vector2(o.x - 26, o.y - 20), Vector2(o.x - 12, o.y - 34)],
		["line", Vector2(o.x + 26, o.y - 20), Vector2(o.x + 12, o.y - 34)],
		# rafters to the ridge
		["line", Vector2(o.x - 26, o.y - 34), Vector2(o.x, o.y - 52)],
		["line", Vector2(o.x + 26, o.y - 34), Vector2(o.x, o.y - 52)],
		# ridge beam (the lock)
		["line", Vector2(o.x - 8, o.y - 47), Vector2(o.x + 8, o.y - 47)],
	]
	for i in range(mini(upto, segs.size())):
		var sg: Array = segs[i]
		var col := STEEL if i < 4 else BRASS
		var prog := 1.0
		if i == upto - 1 and upto <= segs.size():
			prog = partial
		match sg[0]:
			"rect":
				if prog >= 1.0:
					c.append(["rect", sg[1], col])
			"box":
				if prog >= 1.0:
					c.append(["box", sg[1], col])
			"line":
				_plot_line(c, sg[1], sg[2], col, prog)
	# The ridge locking in gets a single white confirmation flash.
	if upto >= segs.size() and _shown(t, 39, 2):
		_ln(c, Vector2(o.x - 8, o.y - 47), Vector2(o.x + 8, o.y - 47), STAR_WHITE)


func _hall_segment_count() -> int:
	return 13


## Finished hall as a filled silhouette (title card / settlement schematic).
func _hall_silhouette(c: Array, o: Vector2, col: Color) -> void:
	c.append(["poly", PackedVector2Array([
		Vector2(o.x - 28, o.y), Vector2(o.x - 28, o.y - 34),
		Vector2(o.x, o.y - 52), Vector2(o.x + 28, o.y - 34),
		Vector2(o.x + 28, o.y),
	]), col])


## Blocky ancestry silhouettes built from filled rects (period raster look).
## Pose B nudges head/lean by 1px on a stepped cadence — small, alive, cheap.
func _figure(c: Array, kind: String, base: Vector2, pose_b: bool, col: Color) -> void:
	var lean := 1 if pose_b else 0
	match kind:
		"human":   # balanced, upright, civic
			c.append(["rect", Rect2(base.x - 3 + lean, base.y - 22, 6, 12), col])
			c.append(["rect", Rect2(base.x - 2 + lean, base.y - 26, 4, 4), col])
			c.append(["rect", Rect2(base.x - 3, base.y - 10, 2, 10), col])
			c.append(["rect", Rect2(base.x + 1, base.y - 10, 2, 10), col])
		"dwarf":   # low, compact, heavy
			c.append(["rect", Rect2(base.x - 5, base.y - 12, 10, 8), col])
			c.append(["rect", Rect2(base.x - 3 + lean, base.y - 16, 6, 4), col])
			c.append(["rect", Rect2(base.x - 4, base.y - 4, 3, 4), col])
			c.append(["rect", Rect2(base.x + 1, base.y - 4, 3, 4), col])
		"elf":     # narrow, vertical, agile
			c.append(["rect", Rect2(base.x - 2 + lean, base.y - 24, 4, 14), col])
			c.append(["rect", Rect2(base.x - 1 + lean, base.y - 28, 3, 4), col])
			c.append(["rect", Rect2(base.x - 2, base.y - 10, 1, 10), col])
			c.append(["rect", Rect2(base.x + 1, base.y - 10, 1, 10), col])
		"orc":     # broad, durable, grounded
			c.append(["rect", Rect2(base.x - 5, base.y - 20, 11, 12), col])
			c.append(["rect", Rect2(base.x - 3 + lean, base.y - 25, 6, 5), col])
			c.append(["rect", Rect2(base.x - 4, base.y - 8, 3, 8), col])
			c.append(["rect", Rect2(base.x + 2, base.y - 8, 3, 8), col])
		"goblin":  # small, quick, irregular
			c.append(["rect", Rect2(base.x - 3, base.y - 9, 6, 6), col])
			c.append(["rect", Rect2(base.x - 1 + lean * 2, base.y - 13, 4, 4), col])
			c.append(["rect", Rect2(base.x - 2, base.y - 3, 2, 3), col])
			c.append(["rect", Rect2(base.x + 1, base.y - 3, 2, 3), col])


# =========================================================================
# Scene 01 — Orientation: the first star (40 ticks)
# =========================================================================
## Black-blue void, one faint broken land contour plotting itself, one star,
## one pulse. Nothing else.
func _scene_first_star(c: Array, t: int) -> void:
	c.append(["rect", Rect2(0, 0, W, H), NIGHT])
	# Broken land contour: two separated fragments plot left-to-right.
	var frag_a := [Vector2(0, 246), Vector2(70, 238), Vector2(140, 248),
		Vector2(210, 236), Vector2(260, 244)]
	var frag_b := [Vector2(330, 248), Vector2(420, 234), Vector2(500, 246),
		Vector2(580, 237), Vector2(640, 244)]
	_plot_path(c, frag_a, LINE_DIM, float(t - 4) / 16.0)
	_plot_path(c, frag_b, LINE_DIM, float(t - 10) / 16.0)
	# The one star: appears, then pulses exactly once.
	var star := Vector2(320, 96)
	if t >= 14:
		c.append(["rect", Rect2(star - Vector2(1, 1), Vector2(2, 2)), STAR_WHITE])
		_px(c, star + Vector2(-3, 0), SLATE)
		_px(c, star + Vector2(2, 0), SLATE)
	_pulse_ring(c, star, t, 18, 6, 3, STAR_WHITE)


# =========================================================================
# Scene 02 — Deviation: unraveling roads (50 ticks)
# =========================================================================
## A map assembles from plotted contours, then comes apart in discrete
## pieces: roads lose segments, the river detaches, borders break, towers
## fall. Slow stepped pan left-to-right.
func _scene_unraveling_roads(c: Array, t: int) -> void:
	var ox := -_step_off(maxi(0, t - 14), 6, 4.0)   # stepped pan starts after assembly
	var o := Vector2(ox, 0)
	var undo := maxi(0, t - 16)   # unraveling clock
	# Coastline contour (stays: the land itself endures).
	var coast := [Vector2(40, 70) + o, Vector2(150, 62) + o, Vector2(260, 84) + o,
		Vector2(390, 66) + o, Vector2(520, 88) + o, Vector2(620, 72) + o]
	_plot_path(c, coast, SLATE, float(t) / 8.0)
	# Roads: three routes with node squares; segments vanish one per 3 ticks.
	var roads := [
		[Vector2(80, 240) + o, Vector2(150, 210) + o, Vector2(230, 220) + o,
			Vector2(320, 190) + o, Vector2(410, 200) + o],
		[Vector2(320, 190) + o, Vector2(360, 150) + o, Vector2(430, 130) + o,
			Vector2(520, 140) + o],
		[Vector2(230, 220) + o, Vector2(240, 250) + o, Vector2(320, 266) + o,
			Vector2(430, 258) + o],
	]
	for ri in range(roads.size()):
		var pts: Array = roads[ri]
		if t < 16:
			_plot_path(c, pts, SLATE, float(t - 4 - ri * 2) / 8.0)
		else:
			_dissolve_path(c, pts, SLATE, undo / 3, 31 + ri)
		# Road nodes: endpoints marked with 2x2 waypoints while any road remains.
		if t >= 8 and undo / 3 < pts.size() - 1:
			c.append(["rect", Rect2((pts[0] as Vector2) - Vector2(1, 1), Vector2(2, 2)), STEEL])
			c.append(["rect", Rect2((pts[pts.size() - 1] as Vector2) - Vector2(1, 1), Vector2(2, 2)), STEEL])
	# River: plotted in cyan; after tick 20 its middle drifts from the course
	# in stepped 3px drops (the old channel stays as a dim ghost).
	var drift := 3.0 * float(clampi((t - 20) / 6, 0, 3))
	var river: Array = []
	var river_src := [Vector2(500, 70), Vector2(470, 125), Vector2(440, 180),
		Vector2(450, 225), Vector2(430, 266)]
	for i in range(river_src.size()):
		var v: Vector2 = river_src[i] + o
		if i >= 1 and i <= 3:
			v.y += drift
		river.append(v)
	if drift > 0.0:
		_dissolve_path(c, [river_src[1] + o, river_src[2] + o, river_src[3] + o],
			LINE_DIM, int(drift / 3.0), 77)
	_plot_path(c, river, CYAN_MUTED, float(t - 6) / 8.0)
	# Border: a dashed claim that stops meaning anything, two dashes per step.
	var border := [Vector2(120, 120) + o, Vector2(210, 100) + o, Vector2(330, 120) + o,
		Vector2(430, 100) + o, Vector2(540, 120) + o, Vector2(560, 200) + o,
		Vector2(470, 250) + o, Vector2(350, 240) + o]
	var dashes: Array = []
	for i in range(border.size() - 1):
		var a: Vector2 = border[i]
		var b: Vector2 = border[i + 1]
		for d in range(3):
			dashes.append([a.lerp(b, float(d) / 3.0), a.lerp(b, (float(d) + 0.55) / 3.0)])
	var dash_gone := maxi(0, (t - 18) / 2)
	for di in range(dashes.size()):
		if t < 12 and di > t * 2:
			continue
		if _h(400 + di) % dashes.size() < dash_gone:
			continue
		_ln(c, dashes[di][0], dashes[di][1], LINE_DIM)
	# Two watch towers become broken geometric forms at fixed steps.
	for tw in [[Vector2(150, 210), 26], [Vector2(520, 140), 36]]:
		var base: Vector2 = (tw[0] as Vector2) + o
		if t < tw[1]:
			_ln(c, base, base + Vector2(0, -14), STEEL)
			_ln(c, base + Vector2(-4, -14), base + Vector2(4, -14), STEEL)
			_ln(c, base + Vector2(-4, -14), base + Vector2(0, -18), STEEL)
			_ln(c, base + Vector2(4, -14), base + Vector2(0, -18), STEEL)
		else:
			_ln(c, base, base + Vector2(1, -7), STEEL)
			_ln(c, base + Vector2(1, -7), base + Vector2(6, -4), LINE_DIM)
			_ln(c, base + Vector2(-5, -2), base + Vector2(-9, 0), LINE_DIM)


# =========================================================================
# Scene 03 — Propagation: scattered peoples (60 ticks)
# =========================================================================
## Five readable ancestry silhouettes assemble around a weak fire with a
## low-frame-rate flame cycle, staggered pose shifts, and one ridge of
## restrained parallax behind them.
func _scene_scattered_peoples(c: Array, t: int) -> void:
	# Night field behind the figures so the silhouettes actually read.
	c.append(["rect", Rect2(0, 0, W, 252), NIGHT])
	# Far ridge: creeps 1px every 8 ticks — barely alive, and behind everything.
	var rx := _step_off(t, 8, 1.0)
	_plot_path(c, [Vector2(-10 + rx, 168), Vector2(120 + rx, 154), Vector2(300 + rx, 172),
		Vector2(470 + rx, 156), Vector2(650 + rx, 170)], LINE_DIM, 1.0)
	# Ground.
	_ln(c, Vector2(0, 252), Vector2(W, 252), SLATE)
	# The shared fire: 3-frame flame cycle, hard palette steps, sparse embers.
	var fire := Vector2(320, 248)
	c.append(["rect", Rect2(fire.x - 8, fire.y, 16, 3), STEEL])   # fire ring stones
	var fl := (t / 3) % 3
	var fcol := _cycle([AMBER, BRASS, AMBER, EMBER], t, 3)
	match fl:
		0:
			c.append(["rect", Rect2(fire.x - 3, fire.y - 9, 6, 9), fcol])
			c.append(["rect", Rect2(fire.x - 1, fire.y - 12, 2, 3), fcol])
		1:
			c.append(["rect", Rect2(fire.x - 2, fire.y - 10, 5, 10), fcol])
			c.append(["rect", Rect2(fire.x + 1, fire.y - 13, 2, 3), fcol])
		2:
			c.append(["rect", Rect2(fire.x - 3, fire.y - 8, 6, 8), fcol])
			c.append(["rect", Rect2(fire.x - 2, fire.y - 11, 2, 3), fcol])
	if t % 5 == 0:
		_px(c, fire + Vector2(3, -15), EMBER)
	if t % 7 == 0:
		_px(c, fire + Vector2(-4, -17), EMBER)
	# The five peoples arrive one at a time, then hold with tiny pose shifts.
	var order := [["human", Vector2(268, 252), 6], ["dwarf", Vector2(296, 252), 14],
		["elf", Vector2(352, 252), 22], ["orc", Vector2(392, 252), 30],
		["goblin", Vector2(238, 252), 38]]
	for i in range(order.size()):
		var f: Array = order[i]
		if t < f[2]:
			continue
		var pose_b := ((t + i * 7) / 16) % 2 == 1
		_figure(c, f[0], f[1], pose_b, Color8(30, 38, 58))
	# Firelight edge on the ground: two hard amber strips, no gradient.
	if t >= 4:
		_ln(c, Vector2(296, 253), Vector2(346, 253), EMBER)
	if t >= 10:
		_ln(c, Vector2(308, 254), Vector2(334, 254), EMBER)


# =========================================================================
# Scene 04 — Instability: the dark measures every light (50 ticks)
# =========================================================================
## Mostly absence: a sparse frontier line, an empty cave mouth, torch points
## flickering by palette cycle, eyes for two stepped frames, storm contours
## crossing in discrete jumps, one plotted lightning fork.
func _scene_darkness_measures(c: Array, t: int) -> void:
	# Frontier ground and an unfinished stake line (gaps are the point).
	_plot_path(c, [Vector2(0, 256), Vector2(200, 250), Vector2(420, 258), Vector2(640, 252)],
		SLATE, float(t) / 6.0)
	for i in range(7):
		if i == 2 or i == 5:
			continue   # missing stakes: the palisade is incomplete
		var sx := 250.0 + float(i) * 26.0
		if t >= 6 + i:
			_ln(c, Vector2(sx, 256), Vector2(sx, 244), BRASS)
	# Cave mouth: an arch of darkness in the hillside, left.
	if t >= 4:
		_plot_path(c, [Vector2(60, 256), Vector2(70, 218), Vector2(110, 202),
			Vector2(150, 216), Vector2(160, 256)], STEEL, float(t - 4) / 8.0)
		c.append(["poly", PackedVector2Array([Vector2(78, 256), Vector2(86, 228),
			Vector2(112, 218), Vector2(140, 230), Vector2(146, 256)]), Color8(0, 0, 0)])
	# Eyes: two stepped frames each, then gone. The dark is looking.
	for eye in [[Vector2(104, 240), 18], [Vector2(126, 246), 34], [Vector2(96, 248), 35]]:
		if _shown(t, eye[1], 2):
			_px(c, eye[0], RED_WARN)
			_px(c, (eye[0] as Vector2) + Vector2(4, 0), RED_WARN)
	# Three torch points along the line: vulnerable, cycling, one gutters.
	_torch(c, Vector2(276, 256), t, 0)
	_torch(c, Vector2(354, 256), t, 3)
	if t % 11 < 8:   # this one keeps almost going out
		_torch(c, Vector2(432, 256), t, 6)
	else:
		_px(c, Vector2(432, 251), EMBER)
	# Storm contours cross the upper frame in 6px steps.
	var sx2 := _step_off(t, 2, 6.0)
	for row in [[40.0, 0.0], [64.0, 120.0], [88.0, 260.0]]:
		var y: float = row[0]
		var start_x := fmod(row[1] - sx2, 760.0)
		var zig: Array = []
		for k in range(5):
			zig.append(Vector2(start_x + float(k) * 30.0,
				y + float(6 * (k % 2))))
		_plot_path(c, zig, LINE_DIM, 1.0)
	# One lightning fork: two ticks of light, one tick of afterimage.
	var fork := [Vector2(560, 30), Vector2(548, 80), Vector2(560, 110), Vector2(544, 170)]
	if _shown(t, 25, 2):
		_plot_path(c, fork, STAR_WHITE, 1.0)
		_plot_path(c, [Vector2(560, 110), Vector2(576, 140)], STAR_WHITE, 1.0)
	elif _shown(t, 27, 1):
		_plot_path(c, fork, LINE_DIM, 1.0)


# =========================================================================
# Scene 05 — Collapse Edge: the first hall raised (60 ticks)
# =========================================================================
## The emotional turn and the inversion of scene 02: lines join and lock.
## Foundation stones step in, posts and beams plot upward, figures raise the
## lines, the ridge locks with a white flash, dawn steps up in hard bands.
func _scene_first_hall(c: Array, t: int) -> void:
	# The camera rises slightly as the roof completes: world shifts down in
	# 2px steps after tick 30.
	var rise := 2.0 * float(clampi((t - 30) / 6, 0, 4))
	var o := Vector2(320, 254 + rise)
	# Dawn: hard horizon bands, one more step of amber every 15 ticks.
	var dawn_step := clampi(t / 15, 0, 3)
	if dawn_step >= 1:
		c.append(["rect", Rect2(0, 250 + rise, W, 2), EMBER])
	if dawn_step >= 2:
		c.append(["rect", Rect2(0, 246 + rise, W, 2), Color8(60, 36, 22)])
	if dawn_step >= 3:
		c.append(["rect", Rect2(0, 238 + rise, W, 1), BRASS])
	_ln(c, Vector2(0, 254 + rise), Vector2(W, 254 + rise), SLATE)
	# Assembly: one segment every 3 ticks, each plotting over its window.
	var seg_f := float(t) / 3.0
	var upto := int(seg_f) + 1
	var partial := seg_f - floorf(seg_f)
	_hall(c, o, t, upto, partial)
	# Builders raise structural lines: two-pose work loop, staggered.
	_figure(c, "human", Vector2(o.x - 40, o.y), (t / 4) % 2 == 0, NIGHT.lightened(0.08))
	_figure(c, "dwarf", Vector2(o.x + 42, o.y), (t / 4) % 2 == 1, NIGHT.lightened(0.08))
	if t >= 12:
		_figure(c, "orc", Vector2(o.x - 58, o.y), (t / 6) % 2 == 0, NIGHT.lightened(0.08))
	# Raising lines: from the working figures to the segment under assembly.
	if t >= 12 and t < 39 and (t / 2) % 2 == 0:
		_ln(c, Vector2(o.x - 38, o.y - 18), Vector2(o.x - 26, o.y - 30), LINE_DIM)
		_ln(c, Vector2(o.x + 40, o.y - 18), Vector2(o.x + 26, o.y - 30), LINE_DIM)
	# A shared fire keeps the crew warm at the edge of frame.
	_torch(c, Vector2(o.x - 80, o.y), t, 2)


# =========================================================================
# Scene 06 — Insight: the attunement pulse (50 ticks)
# =========================================================================
## Structural, not magical: a star-white front expands from the hall in
## quantized radius steps, re-illuminating contours segment by segment —
## soil, roots, stone, trees, cave — which then settle to slate. A small
## constellation connects and holds.
func _scene_attunement_pulse(c: Array, t: int) -> void:
	var hall := Vector2(320, 254)
	_ln(c, Vector2(0, 254), Vector2(W, 254), LINE_DIM)
	_hall(c, hall, t, 99, 1.0)
	# Contour web: each entry is a polyline the pulse can reach.
	var webs := [
		[Vector2(292, 254), Vector2(240, 260), Vector2(180, 258), Vector2(110, 264)],
		[Vector2(348, 254), Vector2(410, 262), Vector2(480, 258), Vector2(560, 264)],
		[Vector2(300, 258), Vector2(286, 266), Vector2(262, 272)],   # roots
		[Vector2(340, 258), Vector2(352, 266), Vector2(376, 272)],
		[Vector2(150, 258), Vector2(146, 240), Vector2(154, 224)],   # tree left
		[Vector2(146, 240), Vector2(136, 230)],
		[Vector2(500, 258), Vector2(506, 238), Vector2(498, 222)],   # tree right
		[Vector2(506, 238), Vector2(516, 228)],
		[Vector2(560, 264), Vector2(590, 254), Vector2(612, 236), Vector2(622, 254)],  # cave edge
	]
	var r := 12.0 * float(maxi(0, t - 4))   # quantized wavefront radius
	for w in webs:
		for i in range(w.size() - 1):
			var a: Vector2 = w[i]
			var b: Vector2 = w[i + 1]
			var d := ((a + b) * 0.5).distance_to(hall + Vector2(0, -20))
			if d < r - 36.0:
				_ln(c, a, b, SLATE)          # settled: the world holds
			elif d < r:
				_ln(c, a, b, STAR_WHITE)     # the front passing through
			else:
				_ln(c, a, b, LINE_DIM)       # not yet reached
	# The pulse itself: two stepped rings leaving the hall.
	_pulse_ring(c, hall + Vector2(0, -30), t, 4, 5, 10, STAR_WHITE)
	_pulse_ring(c, hall + Vector2(0, -30), t, 10, 5, 10, LINE_DIM)
	# Constellation: five points connect one link per 3 ticks, then hold.
	var stars := [Vector2(268, 90), Vector2(320, 68), Vector2(372, 88),
		Vector2(352, 128), Vector2(292, 126)]
	for sp in stars:
		if t >= 20:
			_px(c, sp, STAR_WHITE)
			_px(c, (sp as Vector2) + Vector2(0, -1), STAR_WHITE)
	var links := clampi((t - 24) / 3, 0, stars.size())
	for i in range(links):
		_ln(c, stars[i], stars[(i + 1) % stars.size()], LINE_DIM)


# =========================================================================
# Scene 07 — Reintegration: civilization pushes back (60 ticks)
# =========================================================================
## A working settlement schematic in layers: sky, far ridge, hall + torches,
## food, stockpile, worked earth, a mined tunnel below — and the dark still
## waiting past the light's stepped boundary.
func _scene_civilization(c: Array, t: int) -> void:
	# Sky: fixed sparse stars.
	for i in range(14):
		_px(c, Vector2(float(_h(900 + i) % W), float(20 + _h(950 + i) % 80)),
			LINE_DIM if i % 3 else SLATE)
	# Far ridge: 1px per 12 ticks, opposite the foreground creep.
	var rx := -_step_off(t, 12, 1.0)
	_plot_path(c, [Vector2(-8 + rx, 180), Vector2(140 + rx, 168), Vector2(330 + rx, 186),
		Vector2(520 + rx, 170), Vector2(648 + rx, 184)], LINE_DIM, 1.0)
	# Settlement plane.
	var g := 216.0
	_ln(c, Vector2(0, g), Vector2(W, g), SLATE)
	_hall(c, Vector2(300, g), t, 99, 1.0)
	_torch(c, Vector2(238, g), t, 0)
	_torch(c, Vector2(366, g), t, 4)
	# Berry bushes: paired pixel clusters with amber berries.
	for bx in [402.0, 418.0, 434.0]:
		c.append(["rect", Rect2(bx - 3, g - 6, 6, 5), Color8(30, 52, 34)])
		_px(c, Vector2(bx - 1, g - 5), RED_WARN.lerp(AMBER, 0.5))
	# Stockpile: three hard crates.
	c.append(["box", Rect2(252, g - 8, 8, 8), BRASS])
	c.append(["box", Rect2(261, g - 8, 8, 8), BRASS])
	c.append(["box", Rect2(256, g - 15, 8, 7), BRASS])
	# Worked earth: hatch marks stepping in as the crew digs (left field).
	for i in range(mini(8, t / 6)):
		var hx := 160.0 + float(i) * 7.0
		_ln(c, Vector2(hx, g + 2), Vector2(hx + 3, g + 6), STEEL)
	# The mined tunnel: shaft, ladder rungs, one working torch underground.
	_ln(c, Vector2(316, g), Vector2(316, g + 54), STEEL)
	_ln(c, Vector2(332, g), Vector2(332, g + 40), STEEL)
	_ln(c, Vector2(332, g + 40), Vector2(384, g + 46), STEEL)
	for i in range(mini(6, (t - 6) / 4)):
		_ln(c, Vector2(317, g + 10 + i * 8), Vector2(331, g + 10 + i * 8), BRASS)
	if t >= 30:
		_torch(c, Vector2(372, g + 46), t, 2)
	# The light's boundary: a dotted amber arc that pushes outward in three
	# discrete increments — and holds.
	var reach: float = [70.0, 96.0, 122.0][clampi(t / 20, 0, 2)]
	for k in range(20):
		var ang := PI + PI * float(k) / 19.0
		var p: Vector2 = Vector2(302, g) + Vector2(cos(ang), sin(ang)) * reach
		if p.y < g + 1.0 and (k + t / 5) % 2 == 0:
			_px(c, p, EMBER)
	# Beyond it: the dark keeps its eyes. Pressure, not hopelessness.
	if (t % 25) < 3:
		_px(c, Vector2(520, g - 6), RED_WARN)
		_px(c, Vector2(524, g - 6), RED_WARN)
	if (t % 31) < 3:
		_px(c, Vector2(96, g - 4), RED_WARN)
		_px(c, Vector2(100, g - 4), RED_WARN)
	c.append(["poly", PackedVector2Array([Vector2(600, g), Vector2(608, g - 14),
		Vector2(622, g - 4), Vector2(628, g)]), Color8(6, 8, 14)])


# =========================================================================
# Scene 08 — Reintegration: title card (50 ticks)
# =========================================================================
## Stars shift in sparse steps and settle into a constellation above the
## hall silhouette. The engine renders every word of the title separately.
func _scene_title_card(c: Array, t: int) -> void:
	c.append(["rect", Rect2(0, 0, W, H), NIGHT])
	_ln(c, Vector2(0, 318), Vector2(W, 318), LINE_DIM)
	_hall_silhouette(c, Vector2(320, 318), Color8(6, 8, 14))
	_px(c, Vector2(320, 296), AMBER if (t / 4) % 2 == 0 else BRASS)   # hearth kept lit
	# Six stars: three drift 1px at fixed steps, then all settle.
	var stars := [Vector2(258, 62), Vector2(304, 40), Vector2(352, 52),
		Vector2(384, 82), Vector2(330, 102), Vector2(276, 94)]
	for i in range(stars.size()):
		var p: Vector2 = stars[i]
		if i % 2 == 0:
			if t < 5:
				p.x -= 2
			elif t < 15:
				p.x -= 1
		c.append(["rect", Rect2(p - Vector2(1, 1), Vector2(2, 2)), STAR_WHITE])
	# After settling, the constellation joins: one link per 2 ticks.
	var links := clampi((t - 18) / 2, 0, stars.size())
	for i in range(links):
		_ln(c, stars[i], stars[(i + 1) % stars.size()], LINE_DIM)
	# One final restrained pulse when the figure completes.
	_pulse_ring(c, Vector2(320, 72), t, 18 + stars.size() * 2, 4, 4, LINE_DIM)
