extends RefCounted
## EnemyRegistry: parses data/enemies.json once and serves live enemy
## definitions and difficulty scaling. Loaded via preload in game_root.
## Parses data/enemies.json once and serves live enemy definitions
## and difficulty scaling. Construct once in game_root._ready().

var _data: Dictionary = {}
var _live_defs: Array = []


func _init() -> void:
	var file := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if file == null:
		push_error("EnemyRegistry: cannot open res://data/enemies.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("EnemyRegistry: enemies.json did not parse to a dictionary")
		return
	_data = parsed
	for entry: Dictionary in _data.get("enemies", []):
		if entry.get("status", "") == "live":
			_live_defs.append(entry)


func live_defs() -> Array:
	return _live_defs


func get_def(enemy_id: String) -> Dictionary:
	for entry: Dictionary in _data.get("enemies", []):
		if entry.get("id", "") == enemy_id:
			return entry
	return {}


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
