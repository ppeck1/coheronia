extends RefCounted
## FQ-15: discovered-region tracker for the map/minimap. The world is bucketed
## into coarse REGION×REGION-tile bands; a band is "revealed" once the player has
## been near it. Pure and scene-free (fed cells, holds no node refs) so it is
## trivially testable, and compact enough to persist in the world save without
## bloat (a 240×80 world has at most ~75 regions).

const REGION := 16

var _revealed: Dictionary = {}   # Vector2i region -> true


func region_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(REGION)), floori(cell.y / float(REGION)))


## Reveal the band around a cell (plus `radius` neighbours). Returns true if any
## new band was revealed, so the caller can refresh an open map.
func reveal_around(cell: Vector2i, radius: int = 1) -> bool:
	var base := region_of(cell)
	var newly := false
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var reg := base + Vector2i(dx, dy)
			if not _revealed.has(reg):
				_revealed[reg] = true
				newly = true
	return newly


func is_revealed(region: Vector2i) -> bool:
	return _revealed.has(region)


func cell_revealed(cell: Vector2i) -> bool:
	return _revealed.has(region_of(cell))


func revealed_regions() -> Array:
	return _revealed.keys()


func revealed_count() -> int:
	return _revealed.size()


func clear() -> void:
	_revealed.clear()


## Compact save form: ["rx,ry", ...].
func serialize() -> Array:
	var out: Array = []
	for reg in _revealed:
		out.append("%d,%d" % [reg.x, reg.y])
	return out


## Parse the save form back into a region dict.
static func parse(raw) -> Dictionary:
	var out: Dictionary = {}
	if raw is Array:
		for key in raw:
			var parts: PackedStringArray = str(key).split(",")
			if parts.size() == 2:
				out[Vector2i(int(parts[0]), int(parts[1]))] = true
	return out
