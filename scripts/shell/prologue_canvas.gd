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

const Puppets := preload("res://scripts/shell/prologue_puppets.gd")

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
				draw_line(c[1], c[2], c[3], c[4] if c.size() > 4 else 1.0, false)
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


## Camera cut: transforms world-space commands into screen space at an
## integer zoom (1 = wide, 2 = close shot). Pixels become zoom-sized blocks
## and line widths scale, so a close-up keeps the same hard pixel grammar.
func _apply_cam(c: Array, world: Array, center: Vector2, zoom: int) -> void:
	var off := Vector2(W / 2.0, H / 2.0) - center * float(zoom)
	var z := float(zoom)
	for cmd in world:
		match cmd[0]:
			"px":
				c.append(["rect", Rect2(_sn((cmd[1] as Vector2) * z + off), Vector2(z, z)), cmd[2]])
			"rect":
				var r: Rect2 = cmd[1]
				c.append(["rect", Rect2(_sn(r.position * z + off), _sn(r.size * z)), cmd[2]])
			"box":
				var rb: Rect2 = cmd[1]
				c.append(["box", Rect2(_sn(rb.position * z + off), _sn(rb.size * z)), cmd[2]])
			"line":
				c.append(["line", _sn((cmd[1] as Vector2) * z + off),
					_sn((cmd[2] as Vector2) * z + off), cmd[3], z])
			"poly":
				var pts := PackedVector2Array()
				for p in cmd[1]:
					pts.append(_sn((p as Vector2) * z + off))
				c.append(["poly", pts, cmd[2]])


## An entering actor: walks from `from_x` to `to_x` over `walk_ticks` after
## `enter_tick`, then plays its idle/acting track. Nothing shows before entry.
func _actor(c: Array, kind: String, col: Color, t: int, enter_tick: int,
		from_x: float, to_x: float, base_y: float, walk_ticks: int, idle: Array) -> void:
	if t < enter_tick:
		return
	var body := Puppets.spec(kind, col)
	if t < enter_tick + walk_ticks:
		var f := float(t - enter_tick) / float(maxi(1, walk_ticks))
		var x := roundf(lerpf(from_x, to_x, f))
		Puppets.render(c, body, Vector2(x, base_y), Puppets.cycle_at(Puppets.walk_track(), t, 6))
	else:
		Puppets.render(c, body, Vector2(to_x, base_y),
			Puppets.pose_at(idle, t - enter_tick - walk_ticks))


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
	var w: Array = []
	# Night field behind the figures so the silhouettes actually read.
	w.append(["rect", Rect2(0, 0, W, 252), NIGHT])
	# Far ridge: creeps 1px every 8 ticks — barely alive, and behind everything.
	var rx := _step_off(t, 8, 1.0)
	_plot_path(w, [Vector2(-10 + rx, 168), Vector2(120 + rx, 154), Vector2(300 + rx, 172),
		Vector2(470 + rx, 156), Vector2(650 + rx, 170)], LINE_DIM, 1.0)
	# Ground.
	_ln(w, Vector2(0, 252), Vector2(W, 252), SLATE)
	# The shared fire: 3-frame flame cycle, hard palette steps, sparse embers.
	var fire := Vector2(318, 248)
	w.append(["rect", Rect2(fire.x - 8, fire.y, 16, 3), STEEL])   # fire ring stones
	var fl := (t / 3) % 3
	var fcol := _cycle([AMBER, BRASS, AMBER, EMBER], t, 3)
	match fl:
		0:
			w.append(["rect", Rect2(fire.x - 3, fire.y - 9, 6, 9), fcol])
			w.append(["rect", Rect2(fire.x - 1, fire.y - 12, 2, 3), fcol])
		1:
			w.append(["rect", Rect2(fire.x - 2, fire.y - 10, 5, 10), fcol])
			w.append(["rect", Rect2(fire.x + 1, fire.y - 13, 2, 3), fcol])
		2:
			w.append(["rect", Rect2(fire.x - 3, fire.y - 8, 6, 8), fcol])
			w.append(["rect", Rect2(fire.x - 2, fire.y - 11, 2, 3), fcol])
	if t % 5 == 0:
		_px(w, fire + Vector2(3, -15), EMBER)
	if t % 7 == 0:
		_px(w, fire + Vector2(-4, -17), EMBER)
	# The five peoples walk in one at a time and act: the human gestures to
	# the fire, the dwarf sets a pack down, the elf scans the dark, the orc
	# plants itself and breathes, the goblin hurries in to warm its hands.
	var sil := Color8(30, 38, 58)
	_actor(w, "human", sil, t, 4, 180, 264, 252, 10, [
		[0, {}], [8, {"arm_r_ang": 55.0, "lean": 5.0}], [13, {"arm_r_ang": 55.0, "lean": 5.0}],
		[18, {}], [30, {"head_ang": -10.0}], [38, {}]])
	_actor(w, "dwarf", sil, t, 12, 190, 296, 252, 10, [
		[0, {}], [6, {"lean": 22.0, "bob": 2.0}], [11, {"lean": 22.0, "bob": 2.0}],
		[15, {}], [28, {"lean": 6.0}], [34, {}]])
	_actor(w, "elf", sil, t, 20, 470, 354, 252, 10, [
		[0, {}], [8, {"head_ang": -15.0}], [14, {"head_ang": -15.0}],
		[20, {"head_ang": 12.0}], [26, {}]])
	_actor(w, "orc", sil, t, 27, 480, 394, 252, 8, [
		[0, {"arm_l_ang": 24.0, "arm_r_ang": -24.0}],
		[10, {"arm_l_ang": 24.0, "arm_r_ang": -24.0, "bob": -1.0}],
		[20, {"arm_l_ang": 24.0, "arm_r_ang": -24.0}]])
	_actor(w, "goblin", sil, t, 34, 200, 242, 252, 6, [
		[0, {"arm_l_ang": 40.0, "arm_r_ang": 40.0, "lean": 10.0}],
		[5, {"arm_l_ang": 30.0, "arm_r_ang": 32.0, "lean": 10.0}],
		[10, {"arm_l_ang": 40.0, "arm_r_ang": 40.0, "lean": 10.0}],
		[15, {"arm_l_ang": 30.0, "arm_r_ang": 32.0, "lean": 10.0}]])
	# Firelight edge on the ground: two hard amber strips, no gradient.
	if t >= 4:
		_ln(w, Vector2(296, 253), Vector2(346, 253), EMBER)
	if t >= 10:
		_ln(w, Vector2(308, 254), Vector2(334, 254), EMBER)
	# Camera: hold the wide establishing shot, then one hard cut in close on
	# the circle around the fire once everyone has arrived.
	if t < 44:
		_apply_cam(c, w, Vector2(W / 2.0, H / 2.0), 1)
	else:
		_apply_cam(c, w, Vector2(318, 224), 2)


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
	# A lone watch pacing the stake line; each time the eyes open in the cave
	# the walk stops dead and the head snaps toward the dark.
	var frozen := _shown(t, 18, 5) or _shown(t, 34, 5)
	# The patrol clock pauses while frozen so the stop is a real stop.
	var patrol_t := t - clampi(t - 18, 0, 5) - clampi(t - 34, 0, 5)
	var leg_t := posmod(patrol_t, 40)
	var wx: float
	if leg_t < 20:
		wx = roundf(lerpf(300.0, 412.0, float(leg_t) / 20.0))
	else:
		wx = roundf(lerpf(412.0, 300.0, float(leg_t - 20) / 20.0))
	var watch_body := Puppets.spec("human", Color8(30, 38, 58))
	if frozen:
		Puppets.render(c, watch_body, Vector2(wx, 256),
			{"head_ang": -25.0, "lean": -4.0})
	else:
		Puppets.render(c, watch_body, Vector2(wx, 256),
			Puppets.cycle_at(Puppets.walk_track(), t, 6))
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
	var w: Array = []
	var rise := 2.0 * float(clampi((t - 30) / 6, 0, 4))
	var o := Vector2(320, 254 + rise)
	# Dawn: hard horizon bands, one more step of amber every 15 ticks.
	var dawn_step := clampi(t / 15, 0, 3)
	if dawn_step >= 1:
		w.append(["rect", Rect2(0, 250 + rise, W, 2), EMBER])
	if dawn_step >= 2:
		w.append(["rect", Rect2(0, 246 + rise, W, 2), Color8(60, 36, 22)])
	if dawn_step >= 3:
		w.append(["rect", Rect2(0, 238 + rise, W, 1), BRASS])
	_ln(w, Vector2(0, 254 + rise), Vector2(W, 254 + rise), SLATE)
	# Assembly: one segment every 3 ticks, each plotting over its window.
	var seg_f := float(t) / 3.0
	var upto := int(seg_f) + 1
	var partial := seg_f - floorf(seg_f)
	_hall(w, o, t, upto, partial)
	# The crew: two builders on staggered hammer loops (a hard white spark
	# lands on each strike), and the orc walking a roof beam in and raising
	# it overhead while the rafters go up.
	var sil := Color8(34, 42, 62)
	Puppets.render(w, Puppets.spec("human", sil), Vector2(o.x - 40, o.y),
		Puppets.cycle_at(Puppets.hammer_track(12), t, 12))
	Puppets.render(w, Puppets.spec("dwarf", sil), Vector2(o.x + 44, o.y),
		Puppets.mirror(Puppets.cycle_at(Puppets.hammer_track(12), t, 12, 6)))
	if posmod(t, 12) == 10:
		_px(w, Vector2(o.x - 31, o.y - 8), STAR_WHITE)
	if posmod(t + 6, 12) == 10:
		_px(w, Vector2(o.x + 35, o.y - 8), STAR_WHITE)
	_actor(w, "orc", sil, t, 12, 230, 264, o.y, 10, [
		[0, {"tool": "beam", "arm_r_ang": 60.0, "tool_ang": 90.0}],
		[5, {"tool": "beam", "arm_r_ang": 140.0, "tool_ang": 90.0, "lean": -5.0}],
		[10, {"tool": "beam", "arm_r_ang": 165.0, "tool_ang": 90.0, "lean": -5.0}],
		[24, {"tool": "beam", "arm_r_ang": 165.0, "tool_ang": 90.0}]])
	# A shared fire keeps the crew warm at the edge of frame.
	_torch(w, Vector2(o.x - 84, o.y), t, 2)
	# Camera: begin tight on the foundation stones (the storyboard's opening
	# beat), then one hard cut out to the wide as the structure climbs.
	if t < 14:
		_apply_cam(c, w, Vector2(o.x, o.y - 12), 2)
	else:
		_apply_cam(c, w, Vector2(W / 2.0, H / 2.0), 1)


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
	# The founder walks out from the hall, kneels, and lays a hand on the
	# ground; the world answers from exactly that point.
	var touch := Vector2(348, 250)
	_actor(c, "human", Color8(34, 42, 62), t, 0, 390, 340, 254, 8, [
		[0, {}],
		[3, {"lean": 20.0, "bob": 2.0, "leg_l_ang": 25.0, "leg_r_ang": -30.0}],
		[6, {"lean": 30.0, "bob": 4.0, "leg_l_ang": 35.0, "leg_r_ang": -40.0, "arm_r_ang": 55.0}],
		[20, {"lean": 30.0, "bob": 4.0, "leg_l_ang": 35.0, "leg_r_ang": -40.0, "arm_r_ang": 55.0}],
		[26, {"lean": 22.0, "bob": 3.0, "leg_l_ang": 30.0, "leg_r_ang": -35.0,
			"arm_r_ang": 45.0, "head_ang": -25.0}],
		[36, {"lean": 22.0, "bob": 3.0, "leg_l_ang": 30.0, "leg_r_ang": -35.0,
			"arm_r_ang": 45.0, "head_ang": -25.0}]])
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
	var r := 12.0 * float(maxi(0, t - 14))   # wavefront leaves the touch point
	for w in webs:
		for i in range(w.size() - 1):
			var a: Vector2 = w[i]
			var b: Vector2 = w[i + 1]
			var d := ((a + b) * 0.5).distance_to(touch)
			if d < r - 36.0:
				_ln(c, a, b, SLATE)          # settled: the world holds
			elif d < r:
				_ln(c, a, b, STAR_WHITE)     # the front passing through
			else:
				_ln(c, a, b, LINE_DIM)       # not yet reached
	# The pulse itself: two stepped rings leaving the founder's hand.
	_pulse_ring(c, touch, t, 14, 5, 10, STAR_WHITE)
	_pulse_ring(c, touch, t, 20, 5, 10, LINE_DIM)
	# Constellation: five points connect one link per 3 ticks, then hold.
	var stars := [Vector2(268, 90), Vector2(320, 68), Vector2(372, 88),
		Vector2(352, 128), Vector2(292, 126)]
	for sp in stars:
		if t >= 26:
			_px(c, sp, STAR_WHITE)
			_px(c, (sp as Vector2) + Vector2(0, -1), STAR_WHITE)
	var links := clampi((t - 30) / 3, 0, stars.size())
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
	# The settlement works: a digger swings a pick at the tunnel face (stone
	# chips on each strike), a carrier walks crates between the stockpile and
	# the diggings, and the goblin tends the berry line.
	var sil := Color8(30, 38, 58)
	Puppets.render(c, Puppets.spec("dwarf", sil), Vector2(360, g + 46),
		Puppets.cycle_at([
			[0, {"tool": "pick", "arm_r_ang": 140.0, "elbow_r": 35.0, "tool_ang": 150.0, "lean": -5.0}],
			[4, {"tool": "pick", "arm_r_ang": 55.0, "elbow_r": 10.0, "tool_ang": 60.0, "lean": 14.0}],
			[8, {"tool": "pick", "arm_r_ang": 140.0, "elbow_r": 35.0, "tool_ang": 150.0, "lean": -5.0}],
		], t, 8))
	if posmod(t, 8) == 4:
		_px(c, Vector2(374, g + 42), STEEL)
	var ct := posmod(t, 44)
	var cx: float
	if ct < 22:
		cx = roundf(lerpf(262.0, 402.0, float(ct) / 22.0))
	else:
		cx = roundf(lerpf(402.0, 262.0, float(ct - 22) / 22.0))
	var cpose: Dictionary = Puppets.cycle_at(Puppets.walk_track(), t, 6).duplicate()
	cpose["tool"] = "crate"
	cpose["arm_r_ang"] = 30.0
	Puppets.render(c, Puppets.spec("human", sil), Vector2(cx, g), cpose)
	Puppets.render(c, Puppets.spec("goblin", sil), Vector2(424, g),
		Puppets.cycle_at([
			[0, {"lean": 25.0, "bob": 2.0, "arm_r_ang": 50.0}],
			[6, {"lean": 5.0, "arm_r_ang": 20.0}],
			[12, {"lean": 25.0, "bob": 2.0, "arm_r_ang": 50.0}],
		], t, 12))
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
	# The founder stands beside the hall, watching the constellation join.
	Puppets.render(c, Puppets.spec("human", Color8(16, 20, 34)), Vector2(374, 318),
		{"head_ang": -20.0, "arm_l_ang": 3.0, "arm_r_ang": -3.0})
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
