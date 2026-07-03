extends RefCounted
## Fix 14: shared JSON loading helper used by the three data registries to
## eliminate repeated FileAccess/parse/type-check boilerplate.

static func load_dict(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("JsonData: cannot open " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("JsonData: " + path + " did not parse to a dictionary")
		return {}
	return parsed
