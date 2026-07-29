extends Node2D
## LQ-2c: presentation-only rising-bubble overlay for lava.
##
## Sporadic bubbles nucleate inside a lava body, drift slowly upward with a
## little wobble, and burst when they reach the exposed lava surface (or when the
## lava under them drains away). This is pure decoration driven by the real frame
## delta: it never reads or writes cells / liquid_level / the save, so it cannot
## affect the deterministic fluid sim or the smoke suite. Only lava tiles inside
## the current view spawn bubbles, so the per-frame work stays bounded no matter
## how large the world is.
##
## No class_name (repo convention): world.gd preloads and owns this node.

var _world: Node2D = null               # the World (owns cells / liquid_level / tile_size)
var _bubbles: Array = []                # active bubble state dictionaries
var _surface_cells: Array = []          # cached visible lava surface cells (Vector2i)
var _rng := RandomNumberGenerator.new()
var _refresh_timer := 0.0

# Rebuild the visible surface-cell cache this often (seconds). Cheap, but no need
# to re-scan every frame as the camera pans.
const REFRESH_INTERVAL := 0.4
# Upward drift, px/sec — deliberately slow so a bubble takes a couple of seconds
# to surface from mid-pool.
const RISE_SPEED := 11.0
# Expected bubbles born per visible surface cell per second (sporadic).
const BUBBLES_PER_CELL_PER_SEC := 0.22
const MAX_BUBBLES := 48
const POP_TIME := 0.30                  # burst animation length (seconds)
const MAX_RISE_CELLS := 12              # deepest a bubble can spawn below the surface

const CORE := Color(1.0, 0.74, 0.30)    # hot bubble centre
const EDGE := Color(0.87, 0.31, 0.11)   # cooler rim / burst ring
const HILITE := Color(1.0, 0.92, 0.64)  # tiny specular fleck


func setup(world: Node2D) -> void:
	_world = world
	_rng.randomize()   # decoration only — no determinism contract to honour
	# Added to the tree after the Blocks TileMapLayer, so it already draws over
	# the lava tiles at the same z; keep the default relative z.


## Dropped when the world is rebuilt (new seed / load) so no stale bubble lingers
## over freshly generated terrain.
func clear() -> void:
	_bubbles.clear()
	_surface_cells.clear()
	queue_redraw()


func tick(delta: float) -> void:
	if _world == null:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_rebuild_surface_cells()
	_maybe_spawn(delta)
	_advance(delta)
	queue_redraw()


## The lava cells on screen whose cell directly above (opposite the flow dir) is
## not the same liquid — i.e. the exposed top of a lava body. Scans only the tile
## range covered by the current view, so cost tracks the viewport, not the world.
func _rebuild_surface_cells() -> void:
	_surface_cells.clear()
	var t: int = _world.tile_size()   # _world is typed Node2D -> explicit type
	if t <= 0:
		return
	var inv := get_canvas_transform().affine_inverse()
	var vp_size := get_viewport_rect().size
	var a := inv * Vector2.ZERO
	var b := inv * vp_size
	var x0 := floori(min(a.x, b.x) / t) - 1
	var x1 := ceili(max(a.x, b.x) / t) + 1
	var y0 := floori(min(a.y, b.y) / t) - 1
	var y1 := ceili(max(a.y, b.y) / t) + 1
	var up := Vector2i(0, BlockRegistry.liquid_flow_dir("lava"))
	for cy in range(y0, y1):
		for cx in range(x0, x1):
			var cell := Vector2i(cx, cy)
			if _world.block_at(cell) != "lava":
				continue
			if _world.block_at(cell - up) != "lava":
				_surface_cells.append(cell)


func _maybe_spawn(delta: float) -> void:
	if _surface_cells.is_empty():
		return
	# Poisson-ish: expected births this frame across every visible surface cell.
	var expected := float(_surface_cells.size()) * BUBBLES_PER_CELL_PER_SEC * delta
	while expected > 0.0 and _bubbles.size() < MAX_BUBBLES:
		if _rng.randf() < expected:
			_spawn_one()
		expected -= 1.0


func _spawn_one() -> void:
	var t: int = _world.tile_size()   # _world is typed Node2D -> explicit type
	var scell: Vector2i = _surface_cells[_rng.randi() % _surface_cells.size()]
	# Contiguous lava depth beneath the surface cell — how far a bubble may rise.
	var depth := 1
	while depth < MAX_RISE_CELLS and _world.block_at(scell + Vector2i(0, depth)) == "lava":
		depth += 1
	# Surface line within the top cell honours a partial fill (a shallow pool's
	# top sits lower in the cell), so a bubble bursts at the real liquid surface.
	var lvl: float = clampf(_world.liquid_level.get(scell, 1.0), 0.0, 1.0)
	var surf_y: float = float(scell.y) * t + t * (1.0 - lvl)
	var start_y: float = float(scell.y) * t + _rng.randf_range(0.6, float(depth)) * t
	var x: float = (float(scell.x) + _rng.randf_range(0.22, 0.78)) * t
	_bubbles.append({
		"x": x, "y": start_y, "surf_y": surf_y,
		"r": _rng.randf_range(1.0, 2.2),
		"speed": RISE_SPEED * _rng.randf_range(0.7, 1.35),
		"wob_phase": _rng.randf() * TAU,
		"wob_amp": _rng.randf_range(2.0, 6.0),   # px of horizontal sway
		"pop": -1.0,                              # >= 0.0 once bursting
	})


func _advance(delta: float) -> void:
	var kept: Array = []
	for b in _bubbles:
		if b["pop"] >= 0.0:
			b["pop"] += delta
			if b["pop"] < POP_TIME:
				kept.append(b)
			continue
		b["wob_phase"] += delta * 3.2
		b["y"] -= b["speed"] * delta
		b["x"] += sin(b["wob_phase"]) * b["wob_amp"] * delta
		# Lava drained out from under it, or it broke the surface -> burst.
		if _world.block_at(_world.cell_of(Vector2(b["x"], b["y"]))) != "lava":
			b["pop"] = 0.0
		elif b["y"] <= b["surf_y"]:
			b["y"] = b["surf_y"]
			b["pop"] = 0.0
		kept.append(b)
	_bubbles = kept


func _draw() -> void:
	for b in _bubbles:
		var pos := Vector2(b["x"], b["y"])
		if b["pop"] >= 0.0:
			# Burst: a quick expanding, fading ring plus a soft flash.
			var f: float = b["pop"] / POP_TIME
			var rr: float = b["r"] * (1.0 + f * 2.4)
			var a: float = 1.0 - f
			draw_circle(pos, rr, Color(EDGE.r, EDGE.g, EDGE.b, a * 0.45))
			draw_arc(pos, rr, 0.0, TAU, 14, Color(CORE.r, CORE.g, CORE.b, a), 0.7, true)
		else:
			var rr: float = b["r"]
			draw_circle(pos, rr + 0.6, Color(EDGE.r, EDGE.g, EDGE.b, 0.85))
			draw_circle(pos, rr, CORE)
			draw_circle(pos - Vector2(rr * 0.3, rr * 0.35), maxf(rr * 0.4, 0.4), HILITE)
