extends RefCounted
## AncestryRegistry: loads data/ancestries.json once and serves ancestry
## definitions and Phase B id list. Mirrors the enemy_registry.gd pattern.
## Construct once in game_root._ready().

const JsonData := preload("res://scripts/data/json_data.gd")

var _data: Dictionary = {}
var _ancestries: Array = []


func _init() -> void:
	_data = JsonData.load_dict("res://data/ancestries.json")
	if not _data.is_empty():
		_ancestries = _data.get("ancestries", [])


## Returns the full ancestry dict for the given id, or {} if not found.
func get_ancestry(id: String) -> Dictionary:
	for entry: Dictionary in _ancestries:
		if entry.get("id", "") == id:
			return entry
	return {}


## Fix 13: derive phase B ids from data instead of a hardcoded constant.
func phase_b_ids() -> Array:
	var ids: Array = []
	for entry: Dictionary in _ancestries:
		if entry.get("implementation_phase", "") == "B":
			ids.append(str(entry.get("id", "")))
	return ids


## Total number of ancestries defined in ancestries.json.
func all_count() -> int:
	return _ancestries.size()
