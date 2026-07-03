extends RefCounted
## ProgressionRegistry: loads player_xp.json and base_levels.json once and
## serves XP event definitions, level-curve values, and ordered base levels.
## Mirrors the enemy_registry.gd pattern. Construct once in game_root._ready().

const JsonData := preload("res://scripts/data/json_data.gd")

var _xp_data: Dictionary = {}
var _base_data: Dictionary = {}
var _events: Dictionary = {}     # event_id -> event dict
var _base_levels: Array = []     # sorted by level ascending
## Fix 14: cache curve scalars in _init so xp_to_next is a single pow call.
var _curve_base: float = 100.0
var _curve_growth: float = 1.35


func _init() -> void:
	_xp_data = JsonData.load_dict("res://data/progression/player_xp.json")
	if not _xp_data.is_empty():
		for ev: Dictionary in _xp_data.get("xp_events", []):
			_events[str(ev.get("event_id", ""))] = ev
		var curve: Dictionary = _xp_data.get("level_curve", {})
		_curve_base = float(curve.get("base", 100))
		_curve_growth = float(curve.get("growth", 1.35))

	_base_data = JsonData.load_dict("res://data/progression/base_levels.json")
	if not _base_data.is_empty():
		_base_levels = _base_data.get("base_levels", []).duplicate()
		_base_levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("level", 0)) < int(b.get("level", 0)))


## Returns the full event dict for event_id, or {} if not found.
func xp_event(event_id: String) -> Dictionary:
	return _events.get(event_id, {})


## XP required to advance FROM level to the next level.
## Fix 14: uses cached _curve_base/_curve_growth for a single pow call.
func xp_to_next(level: int) -> int:
	return int(round(_curve_base * pow(_curve_growth, level - 1)))


## All base level defs sorted ascending by level (1..6).
func base_levels_ordered() -> Array:
	return _base_levels


## All xp_type defs (Array of Dicts with id, display_name, …).
func xp_types() -> Array:
	return _xp_data.get("xp_types", [])
