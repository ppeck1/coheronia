extends RefCounted
## EnemyRegistry: parses data/enemies.json once and serves live enemy
## definitions and difficulty scaling. Loaded via preload in game_root.
## Construct once in game_root._ready().

const JsonData := preload("res://scripts/data/json_data.gd")

var _data: Dictionary = {}
var _live_defs: Array = []
var _defs_by_id: Dictionary = {}  # Fix 14: enemy_id -> dict for O(1) lookup


func _init() -> void:
	_data = JsonData.load_dict("res://data/enemies.json")
	if _data.is_empty():
		return
	for entry: Dictionary in _data.get("enemies", []):
		var eid: String = str(entry.get("id", ""))
		_defs_by_id[eid] = entry
		if entry.get("status", "") == "live":
			_live_defs.append(entry)


func live_defs() -> Array:
	return _live_defs


## Fix 14: O(1) lookup via pre-built dict instead of linear scan.
func get_def(enemy_id: String) -> Dictionary:
	return _defs_by_id.get(enemy_id, {})


## Maps the world-config enemy difficulty float to a named profile then
## returns its density_mult / loot_mult dict from enemies.json.
func scaling_for_difficulty(enemy_diff: float) -> Dictionary:
	var profile := "normal"
	if enemy_diff <= 0.3:
		profile = "peaceful"
	elif enemy_diff <= 0.7:
		profile = "easy"
	elif enemy_diff <= 1.2:
		profile = "normal"
	elif enemy_diff <= 1.6:
		profile = "hard"
	else:
		profile = "brutal"
	var fallback := {"density_mult": 1.0, "loot_mult": 1.0}
	return _data.get("difficulty_scaling", {}).get(profile, fallback)
