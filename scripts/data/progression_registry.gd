extends RefCounted
## ProgressionRegistry: loads player_xp.json and base_levels.json once and
## serves XP event definitions, level-curve values, and ordered base levels.
## Mirrors the enemy_registry.gd pattern. Construct once in game_root._ready().

var _xp_data: Dictionary = {}
var _base_data: Dictionary = {}
var _events: Dictionary = {}     # event_id -> event dict
var _base_levels: Array = []     # sorted by level ascending


func _init() -> void:
	var f1 := FileAccess.open("res://data/progression/player_xp.json", FileAccess.READ)
	if f1 == null:
		push_error("ProgressionRegistry: cannot open player_xp.json")
		return
	var p1 = JSON.parse_string(f1.get_as_text())
	if not p1 is Dictionary:
		push_error("ProgressionRegistry: player_xp.json did not parse to a dictionary")
		return
	_xp_data = p1
	for ev: Dictionary in _xp_data.get("xp_events", []):
		_events[str(ev.get("event_id", ""))] = ev

	var f2 := FileAccess.open("res://data/progression/base_levels.json", FileAccess.READ)
	if f2 == null:
		push_error("ProgressionRegistry: cannot open base_levels.json")
		return
	var p2 = JSON.parse_string(f2.get_as_text())
	if not p2 is Dictionary:
		push_error("ProgressionRegistry: base_levels.json did not parse to a dictionary")
		return
	_base_data = p2
	_base_levels = _base_data.get("base_levels", []).duplicate()
	_base_levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("level", 0)) < int(b.get("level", 0)))


## Returns the full event dict for event_id, or {} if not found.
func xp_event(event_id: String) -> Dictionary:
	return _events.get(event_id, {})


## XP required to advance FROM level to the next level.
## Formula: base * growth^(level-1), rounded.
func xp_to_next(level: int) -> int:
	var curve: Dictionary = _xp_data.get("level_curve", {})
	var base: float = float(curve.get("base", 100))
	var growth: float = float(curve.get("growth", 1.35))
	return int(round(base * pow(growth, level - 1)))


## All base level defs sorted ascending by level (1..6).
func base_levels_ordered() -> Array:
	return _base_levels


## All xp_type defs (Array of Dicts with id, display_name, …).
func xp_types() -> Array:
	return _xp_data.get("xp_types", [])
