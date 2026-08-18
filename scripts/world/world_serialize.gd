extends RefCounted
## Stateless serialization helpers for World's sparse per-cell dictionaries.
##
## Every persisted per-cell map — terrain deltas plus the liquid fill levels and
## the bush / crop / tree growth timers — is a Vector2i-keyed dict at runtime and
## a "x,y"-string-keyed dict on disk. These are the single pure encode/decode
## implementations that every World.serialize_*/parse_* method delegates to, so
## the conversion (and its round-trip save contract) lives in one place instead
## of five near-identical serializers and four byte-identical float parsers.
##
## Loaded via preload (repo convention), not class_name — no editor scan needed;
## all functions are static and touch no node/world state.


## Vector2i-keyed dict -> "x,y"-string-keyed dict. Values pass through unchanged,
## so this serves both the string-valued deltas and the float-valued timer/level
## maps.
static func encode_cells(cells: Dictionary) -> Dictionary:
	var out := {}
	for cell: Vector2i in cells:
		out["%d,%d" % [cell.x, cell.y]] = cells[cell]
	return out


## "x,y"-string-keyed dict -> Vector2i-keyed dict with FLOAT values (liquid fill
## levels + growth timers). Malformed keys are skipped.
static func decode_cell_floats(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = float(raw[key])
	return out


## "x,y"-string-keyed dict -> Vector2i-keyed dict with STRING values (terrain
## deltas = block ids). Malformed keys are skipped.
static func decode_cell_strings(raw: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() == 2:
			out[Vector2i(int(parts[0]), int(parts[1]))] = str(raw[key])
	return out
