extends RefCounted
## AncestryRegistry: loads data/ancestries.json once and serves ancestry
## definitions and Phase B id list. Mirrors the enemy_registry.gd pattern.
## Construct once in game_root._ready().

const PHASE_B_IDS: Array = ["human", "dwarf", "elf", "goblin", "orc"]

var _data: Dictionary = {}
var _ancestries: Array = []


func _init() -> void:
	var file := FileAccess.open("res://data/ancestries.json", FileAccess.READ)
	if file == null:
		push_error("AncestryRegistry: cannot open res://data/ancestries.json")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("AncestryRegistry: ancestries.json did not parse to a dictionary")
		return
	_data = parsed
	_ancestries = _data.get("ancestries", [])


## Returns the full ancestry dict for the given id, or {} if not found.
func get_ancestry(id: String) -> Dictionary:
	for entry: Dictionary in _ancestries:
		if entry.get("id", "") == id:
			return entry
	return {}


## Returns the list of Phase B ancestry ids that have wired player effects.
func phase_b_ids() -> Array:
	return PHASE_B_IDS


## Total number of ancestries defined in ancestries.json.
func all_count() -> int:
	return _ancestries.size()
