extends RefCounted
## Settlement Coherence (M2-B): the house-recognition authority.
## Loaded via preload (not class_name) so it works at runtime without an editor
## global-class scan — matching how game_root loads its other internal scripts. A valid house is
## an ENCLOSED air pocket inside the settlement rectangle: a connected region of
## interior cells (air or non-solid decor — NOT doors) whose entire boundary is
## solid walls/roof or door blocks, with at least one door, an interior area in
## [min_interior, max_interior], and a bounding box of [min_dim, max_dim] cells per
## side. Open sky / oversized rooms flood past max_interior and are rejected, so no
## general architecture engine is needed — just a bounded flood fill.
##
## Pure over the world grid (reads world.block_at + BlockRegistry), so the smoke
## can assert it deterministically. The scan is confined to the settlement
## rectangle, so cost is bounded by that small window, not the whole world.

## A cell the interior flood may pass through: non-solid AND not a door. Air,
## torches, lanterns, crops etc. count as interior; solids and doors bound it.
static func _is_interior(world: Node2D, cell: Vector2i) -> bool:
	var id: String = world.block_at(cell)
	if BlockRegistry.has_tag(id, "door"):
		return false
	return not BlockRegistry.is_solid(id)


## Count the valid houses whose bounding box lies fully inside the settlement
## rectangle [hall - hw .. hall + hw] x [hall - up .. hall + down] (cells). `cfg`
## is the settlement.housing dict; missing keys fall back to sane defaults.
static func count_valid_houses(world: Node2D, hall_cell: Vector2i,
		hw: int, up: int, down: int, cfg: Dictionary) -> int:
	var min_interior := int(cfg.get("min_interior", 1))
	var max_interior := int(cfg.get("max_interior", 40))
	var min_dim := int(cfg.get("min_dim", 3))
	var max_dim := int(cfg.get("max_dim", 9))
	var x0 := hall_cell.x - hw
	var x1 := hall_cell.x + hw
	var y0 := hall_cell.y - up
	var y1 := hall_cell.y + down
	var visited := {}
	var houses := 0
	var neighbours := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var start := Vector2i(cx, cy)
			if visited.has(start) or not _is_interior(world, start):
				continue
			# Flood the interior region, capped one past max so an open/oversized
			# pocket bails cheaply. Collect the solid/door boundary cells adjacent.
			var flood: Array[Vector2i] = []
			var boundary := {}
			var queue: Array[Vector2i] = [start]
			visited[start] = true
			var overflow := false
			while not queue.is_empty():
				var c: Vector2i = queue.pop_back()
				flood.append(c)
				if flood.size() > max_interior:
					overflow = true
					break
				for d in neighbours:
					var n: Vector2i = c + d
					if _is_interior(world, n):
						if not visited.has(n):
							visited[n] = true
							queue.append(n)
					else:
						boundary[n] = world.block_at(n)
			if overflow or flood.size() < min_interior:
				continue
			# Every boundary cell must be a solid wall/roof or a door, with >=1 door.
			# The bounding box spans the interior plus its enclosing walls.
			var bx0 := x1 + 1
			var bx1 := x0 - 1
			var by0 := y1 + 1
			var by1 := y0 - 1
			for c in flood:
				bx0 = mini(bx0, c.x); bx1 = maxi(bx1, c.x)
				by0 = mini(by0, c.y); by1 = maxi(by1, c.y)
			var all_walls := true
			var door_count := 0
			for bc in boundary:
				var id: String = str(boundary[bc])
				if BlockRegistry.has_tag(id, "door"):
					door_count += 1
				elif not BlockRegistry.is_solid(id):
					all_walls = false
					break
				bx0 = mini(bx0, bc.x); bx1 = maxi(bx1, bc.x)
				by0 = mini(by0, bc.y); by1 = maxi(by1, bc.y)
			if not all_walls or door_count < 1:
				continue
			var w := bx1 - bx0 + 1
			var h := by1 - by0 + 1
			if w < min_dim or h < min_dim or w > max_dim or h > max_dim:
				continue
			if bx0 < x0 or bx1 > x1 or by0 < y0 or by1 > y1:
				continue
			houses += 1
	return houses
