extends RefCounted
## Perception veil model (Phase A of the Perception + Resonance arc).
##
## Pure, scene-free, save-serializable — mirrors the shape of `map_state.gd`.
## Tracks, per world cell, one of three perception states the veil shader reads:
##
##   UNSEEN(0)      never perceived   -> near-black atmospheric veil
##   REMEMBERED(1)  seen before, not currently in sight -> dim desaturated silhouette
##   VISIBLE(2)     in the character's current 360-degree line of sight -> full render
##
## The REMEMBERED set is PERSISTENT (a per-cell "seen" bit): a builder never has to
## rediscover their own construction. VISIBLE is recomputed from the current origin
## by a tile line-of-sight pass. This is deliberately separate from `map_state.gd`
## (the coarse, permanent minimap authority) so Attunement/perception never replaces
## the Wayfarer's scouting identity.
##
## Storage is one byte per cell (fast, simple); serialization bit-packs the seen set
## to a compact base64 blob (~19 KB for a 480x320 world).

const UNSEEN := 0
const REMEMBERED := 1
const VISIBLE := 2

var width := 0
var height := 0

var _seen: PackedByteArray = PackedByteArray()      # 1 byte/cell, 1 == ever seen
var _visible: PackedByteArray = PackedByteArray()   # 1 byte/cell, 1 == currently visible
var _visible_cells: Array[Vector2i] = []            # cells lit this pass (fast clear + finalize)


func _init(w: int = 0, h: int = 0) -> void:
	resize(w, h)


func resize(w: int, h: int) -> void:
	width = maxi(w, 0)
	height = maxi(h, 0)
	var n := width * height
	_seen = PackedByteArray()
	_seen.resize(n)        # PackedByteArray.resize zero-fills
	_visible = PackedByteArray()
	_visible.resize(n)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func _idx(x: int, y: int) -> int:
	return y * width + x


func state_at(cell: Vector2i) -> int:
	if not in_bounds(cell.x, cell.y):
		return UNSEEN
	var i := _idx(cell.x, cell.y)
	if _visible[i] != 0:
		return VISIBLE
	if _seen[i] != 0:
		return REMEMBERED
	return UNSEEN


func is_visible(cell: Vector2i) -> bool:
	return in_bounds(cell.x, cell.y) and _visible[_idx(cell.x, cell.y)] != 0


func is_seen(cell: Vector2i) -> bool:
	return in_bounds(cell.x, cell.y) and _seen[_idx(cell.x, cell.y)] != 0


# Recursive-shadowcasting octant transforms (xx, xy, yx, yy) — the 8 symmetric
# mappings of the first-octant scan onto the whole 360-degree field.
const _OCT_XX := [1, 0, 0, -1, -1, 0, 0, 1]
const _OCT_XY := [0, 1, -1, 0, 0, -1, 1, 0]
const _OCT_YX := [0, 1, 1, 0, 0, -1, -1, 0]
const _OCT_YY := [1, 0, 0, 1, -1, 0, 0, -1]


## Recompute the VISIBLE set as a 360-degree tile line-of-sight field from `origin`
## out to `radius`, using `occluder` (a `Callable(Vector2i) -> bool`, e.g.
## `world.is_solid_at` — a closed door reads solid, an open door does not). Uses
## recursive symmetric shadowcasting: correct corner occlusion (light cannot slip
## between two diagonally-touching blocks) and O(cells), not O(cells * ray length).
## Every newly-lit cell folds into the persistent seen set; a blocking cell is itself
## lit (you see the wall that blocks you) so rooms keep crisp edges.
func recompute(origin: Vector2i, radius: int, occluder: Callable) -> void:
	# Clear only the cells lit last pass (cheap — no full width*height wipe).
	for c in _visible_cells:
		_visible[_idx(c.x, c.y)] = 0
	_visible_cells.clear()
	if width == 0 or height == 0:
		return
	radius = maxi(radius, 0)
	_mark_visible(origin)
	for oct in range(8):
		_cast_light(origin.x, origin.y, 1, 1.0, 0.0, radius,
			_OCT_XX[oct], _OCT_XY[oct], _OCT_YX[oct], _OCT_YY[oct], occluder)
	_finalize_visibility(origin, occluder)


func _mark_visible(cell: Vector2i) -> void:
	if not in_bounds(cell.x, cell.y):
		return
	var i := _idx(cell.x, cell.y)
	if _visible[i] != 0:
		return   # already lit this pass
	_visible[i] = 1
	_visible_cells.append(cell)   # seen is committed in _finalize_visibility


## Close diagonal 1x1 leaks, then commit the surviving cells to the persistent seen
## set. Recursive shadowcasting can slip sight through a corner where two blocks touch
## diagonally; an OPEN cell whose two bridging cells toward the origin are BOTH walls
## is reachable only through that zero-width pinch, so it is not truly visible.
func _finalize_visibility(origin: Vector2i, occluder: Callable) -> void:
	# Process near -> far so a pinch cull PROPAGATES outward: once the cell directly
	# behind a diagonal corner is culled, the next cell out (whose only approach is
	# through it) is culled in turn, sealing the WHOLE ray behind the corner rather than
	# just the first cell.
	_visible_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := a - origin
		var db := b - origin
		return da.x * da.x + da.y * da.y < db.x * db.x + db.y * db.y)
	for c in _visible_cells:
		var i := _idx(c.x, c.y)
		if _visible[i] == 0:
			continue
		if _is_corner_pinched(c, origin, occluder):
			_visible[i] = 0
			continue
		_seen[i] = 1


func _is_corner_pinched(c: Vector2i, origin: Vector2i, occluder: Callable) -> bool:
	var sx := signi(origin.x - c.x)
	var sy := signi(origin.y - c.y)
	if sx == 0 or sy == 0:
		return false            # orthogonal approach — a straight ray, no diagonal pinch
	if occluder.call(c):
		return false            # the cell IS a wall; we're allowed to see it
	# The two cells bridging C toward the origin (both in-bounds, since they step toward
	# an in-bounds origin). A bridge that is a wall OR is itself no-longer-visible
	# (shadowed, or already culled this near->far pass) cannot carry sight to C; if BOTH
	# are blocked, C is reachable only through the zero-width diagonal pinch -> not seen.
	var bx := Vector2i(c.x + sx, c.y)
	var by := Vector2i(c.x, c.y + sy)
	var block_x: bool = bool(occluder.call(bx)) or not is_visible(bx)
	var block_y: bool = bool(occluder.call(by)) or not is_visible(by)
	return block_x and block_y


## One octant of recursive shadowcasting (Björn Bergström's algorithm). Scans rows
## outward from the origin, splitting the visible arc at each blocker into recursive
## child scans of the still-open sub-arcs.
func _cast_light(cx: int, cy: int, row: int, start: float, end: float, radius: int,
		xx: int, xy: int, yx: int, yy: int, occluder: Callable) -> void:
	if start < end:
		return
	var radius2 := radius * radius
	var scan_start := start
	var new_start := 0.0
	for j in range(row, radius + 1):
		var dy := -j
		var dx := -j - 1
		var blocked := false
		while dx <= 0:
			dx += 1
			var mx := cx + dx * xx + dy * xy
			var my := cy + dx * yx + dy * yy
			var l_slope := (float(dx) - 0.5) / (float(dy) + 0.5)
			var r_slope := (float(dx) + 0.5) / (float(dy) - 0.5)
			if scan_start < r_slope:
				continue
			elif end > l_slope:
				break
			if dx * dx + dy * dy <= radius2:
				_mark_visible(Vector2i(mx, my))
			var cell_blocks: bool = occluder.call(Vector2i(mx, my))
			if blocked:
				if cell_blocks:
					new_start = r_slope
					continue
				else:
					blocked = false
					scan_start = new_start
			elif cell_blocks and j < radius:
				blocked = true
				_cast_light(cx, cy, j + 1, scan_start, l_slope, radius,
					xx, xy, yx, yy, occluder)
				new_start = r_slope
		if blocked:
			break


## Write the veil mask for the shader: `buf` sized width*height, one byte per cell,
## 0 = unseen, 128 = remembered, 255 = visible (an R8 texture the cave shader reads).
func fill_mask(buf: PackedByteArray) -> void:
	var n := width * height
	if buf.size() != n:
		buf.resize(n)
	for i in n:
		if _visible[i] != 0:
			buf[i] = 255
		elif _seen[i] != 0:
			buf[i] = 128
		else:
			buf[i] = 0


## Compact save form: dims + a base64 bit-packed seen set (VISIBLE is transient and
## not persisted — it recomputes on load). Missing/empty parses back to all-unseen.
func serialize() -> Dictionary:
	var n := _seen.size()
	var packed := PackedByteArray()
	packed.resize((n + 7) >> 3)   # ceil(n / 8), zero-filled
	for i in n:
		if _seen[i] != 0:
			var bi := i >> 3
			packed[bi] = packed[bi] | (1 << (i & 7))
	return {"w": width, "h": height, "seen": Marshalls.raw_to_base64(packed)}


## Load a serialized seen set. Dimensions must match the current world (they are
## deterministic from the preset); a mismatch is ignored so we never index-crash on
## a foreign blob — the player simply re-reveals as they move.
func load_from(data) -> void:
	if not (data is Dictionary):
		return
	var w := int(data.get("w", width))
	var h := int(data.get("h", height))
	if w != width or h != height:
		return
	var packed := Marshalls.base64_to_raw(str(data.get("seen", "")))
	var n := width * height
	for i in n:
		var byte_i := i >> 3
		if byte_i < packed.size() and (packed[byte_i] & (1 << (i & 7))) != 0:
			_seen[i] = 1
