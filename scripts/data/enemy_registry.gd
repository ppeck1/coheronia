extends RefCounted
## EnemyRegistry: parses data/enemies.json once and serves enemy definitions,
## classification, difficulty scaling, and load-time validation. Loaded via
## preload in game_root; construct once in game_root._ready().
##
## S-08.0 (Enemy Expansion Foundation): the registry is the single authority for
## "what is this id, and may it spawn?". It classifies every entry as live /
## planned / mini_boss / boss, validates the data at load, and FAILS CLOSED: only
## a `live` def is spawnable, and `def_for_spawn()` hands out an independent copy
## (never the shared authority dict) so a caller can never mutate the registry or
## silently coerce an unknown/planned id into a live enemy. A typo resolves to an
## empty def, which the factory rejects — it must never become a default enemy.

const JsonData := preload("res://scripts/data/json_data.gd")

## Categories, in the JSON blocks they come from. `live`/`planned` both live in
## the top-level "enemies" array (distinguished by each entry's `status`).
const LEGAL_FAMILIES := ["surface", "underground", "raider"]

var _data: Dictionary = {}
var _live_defs: Array = []
var _defs_by_id: Dictionary = {}       # enemies[] entries: id -> dict (get_def scope, unchanged)
var _all_by_id: Dictionary = {}        # every entry incl. mini_bosses/bosses: id -> dict
var _category_by_id: Dictionary = {}   # id -> "live" | "planned" | "mini_boss" | "boss"
var _validation_errors: Array[String] = []


func _init() -> void:
	_data = JsonData.load_dict("res://data/enemies.json")
	if _data.is_empty():
		_validation_errors.append("enemies.json missing or empty")
		return
	# The top-level "enemies" array carries both live and planned entries; the
	# get_def scope and _live_defs stay exactly as before for compatibility.
	for entry: Dictionary in _data.get("enemies", []):
		var eid: String = str(entry.get("id", ""))
		_register(eid, entry, "planned" if str(entry.get("status", "")) != "live" else "live")
		_defs_by_id[eid] = entry
		if entry.get("status", "") == "live":
			_live_defs.append(entry)
	for entry: Dictionary in _data.get("mini_bosses", []):
		_register(str(entry.get("id", "")), entry, "mini_boss")
	for entry: Dictionary in _data.get("bosses", []):
		_register(str(entry.get("id", "")), entry, "boss")
	_validate()


func _register(eid: String, entry: Dictionary, category: String) -> void:
	if eid == "":
		_validation_errors.append("%s entry with empty id" % category)
		return
	if _all_by_id.has(eid):
		_validation_errors.append("duplicate enemy id '%s'" % eid)
		return
	_all_by_id[eid] = entry
	_category_by_id[eid] = category


## --- Compatibility API (unchanged behavior) ---------------------------------

func live_defs() -> Array:
	return _live_defs


## O(1) lookup over the enemies[] array (live + planned). Returns the shared
## authority dict for read-only inspection; unknown -> {}. Preserved verbatim for
## existing callers/tests. Spawners must use def_for_spawn() (fail-closed copy).
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


## --- S-08.0 classification + fail-closed spawn API --------------------------

## "live" | "planned" | "mini_boss" | "boss" for a known id, else "" (unknown).
func category_of(enemy_id: String) -> String:
	return str(_category_by_id.get(enemy_id, ""))


func is_live(enemy_id: String) -> bool:
	return category_of(enemy_id) == "live"


## Only a live enemy may spawn through normal runtime or save restoration.
## Planned enemies, mini-bosses, bosses, and unknown ids all fail closed here.
func is_spawnable(enemy_id: String) -> bool:
	return is_live(enemy_id)


## The ONLY way a spawner should obtain a def. Returns an independent deep copy of
## a live def (so the caller can never mutate the registry authority), or {} for a
## non-live/unknown id — the factory turns {} into an explicit failure, never a
## default Surface Slime.
func def_for_spawn(enemy_id: String) -> Dictionary:
	if not is_live(enemy_id):
		return {}
	return (_defs_by_id.get(enemy_id, {}) as Dictionary).duplicate(true)


## Load-time validation problems (empty = healthy). Consumed by the smoke gate so
## malformed data fails closed with an actionable list instead of at spawn time.
func validation_errors() -> Array[String]:
	return _validation_errors


func _validate() -> void:
	for eid: String in _all_by_id:
		var entry: Dictionary = _all_by_id[eid]
		var cat: String = _category_by_id.get(eid, "")
		var fam: String = str(entry.get("family", ""))
		if not LEGAL_FAMILIES.has(fam):
			_validation_errors.append("%s '%s' has illegal family '%s'" % [cat, eid, fam])
		# A live enemy must carry the fields the factory reads for real behavior.
		if cat == "live":
			for req: String in ["contact_damage", "speed"]:
				if not entry.has(req):
					_validation_errors.append("live '%s' missing required field '%s'" % [eid, req])
			var spd: float = float(entry.get("speed", 0.0))
			if spd <= 0.0:
				_validation_errors.append("live '%s' speed must be > 0 (got %s)" % [eid, str(spd)])
			if float(entry.get("contact_damage", 0.0)) < 0.0:
				_validation_errors.append("live '%s' contact_damage must be >= 0" % eid)
		# Numeric multipliers, when present, must be positive.
		for mult: String in ["hp_mult", "hall_dps_mult"]:
			if entry.has(mult) and float(entry.get(mult, 1.0)) <= 0.0:
				_validation_errors.append("'%s' %s must be > 0" % [eid, mult])
		# Loot references: every drop needs a non-empty item id and a legal chance.
		for key: String in ["drops", "guaranteed_drops", "possible_drops"]:
			for drop in entry.get(key, []):
				if str(drop.get("item_id", "")) == "":
					_validation_errors.append("'%s' %s entry with empty item_id" % [eid, key])
				var ch: float = float(drop.get("chance", 0.0))
				if ch < 0.0 or ch > 1.0:
					_validation_errors.append("'%s' %s chance out of [0,1]: %s" % [eid, key, str(ch)])
		# Spawn references, when present, must be numeric and non-negative.
		var rule: Dictionary = entry.get("spawn_rule", {})
		for rk: String in ["day_threshold", "stockpile_threshold", "base_chance"]:
			if rule.has(rk) and float(rule.get(rk, 0.0)) < 0.0:
				_validation_errors.append("'%s' spawn_rule.%s must be >= 0" % [eid, rk])
		# Mutually incompatible configuration: emitting molten bubbles is a
		# lava-dweller presentation, so it may only appear alongside lava_immune.
		if bool(entry.get("emits_bubbles", false)) and not bool(entry.get("lava_immune", false)):
			_validation_errors.append("'%s' emits_bubbles without lava_immune (lava presentation only)" % eid)
