extends RefCounted
## EnemyRegistry: parses data/enemies.json once and serves enemy definitions,
## classification, difficulty scaling, and load-time validation. Loaded via
## preload in game_root; construct once in game_root._ready().
##
## S-08.0 (Enemy Expansion Foundation): the registry is the single authority for
## "what is this id, and may it spawn?". It classifies every entry as live /
## planned / mini_boss / boss, validates each entry at load, and FAILS CLOSED:
## `def_for_spawn()` returns an independent copy ONLY for an id that is both live
## AND individually valid, and {} otherwise. A typo, a duplicate id, or a malformed
## live entry all resolve to {}, which the factory turns into an explicit failure —
## never a default Surface Slime. `get_def()` stays a read-only compatibility view.
##
## `_init()` loads the shipped data; `_init(fixture_dict)` ingests injected data so
## validation can be exercised on malformed/duplicate fixtures in tests.

const JsonData := preload("res://scripts/data/json_data.gd")
const EnemyFactory := preload("res://scripts/data/enemy_factory.gd")

const LEGAL_FAMILIES := ["surface", "underground", "raider"]
const LEGAL_ENEMY_STATUS := ["live", "planned"]

var _data: Dictionary = {}
var _live_defs: Array = []
var _defs_by_id: Dictionary = {}       # enemies[] entries: id -> dict (get_def scope)
var _all_by_id: Dictionary = {}        # every entry incl. mini_bosses/bosses: id -> dict
var _category_by_id: Dictionary = {}   # id -> "live" | "planned" | "mini_boss" | "boss"
var _invalid_ids: Dictionary = {}      # id -> true when that specific entry failed validation
var _validation_errors: Array[String] = []


func _init(injected: Dictionary = {}) -> void:
	var data: Dictionary = injected if not injected.is_empty() \
		else JsonData.load_dict("res://data/enemies.json")
	_ingest(data)


func _ingest(data: Dictionary) -> void:
	_data = data
	if _data.is_empty():
		_validation_errors.append("enemies.json missing or empty")
		return
	# The top-level "enemies" array carries both live and planned entries; the
	# get_def scope and _live_defs stay as before for compatibility. Duplicate ids
	# are rejected (first registration wins; the id is marked invalid, never
	# overwriting _defs_by_id / _live_defs).
	for entry: Dictionary in _data.get("enemies", []):
		var eid: String = str(entry.get("id", ""))
		var cat: String = "live" if str(entry.get("status", "")) == "live" else "planned"
		if _register(eid, entry, cat):
			_defs_by_id[eid] = entry
			if cat == "live":
				_live_defs.append(entry)
	for entry: Dictionary in _data.get("mini_bosses", []):
		_register(str(entry.get("id", "")), entry, "mini_boss")
	for entry: Dictionary in _data.get("bosses", []):
		_register(str(entry.get("id", "")), entry, "boss")
	_validate()


## Register an entry. Returns false (and records the problem) for an empty or
## duplicate id, so a later duplicate can never overwrite an earlier registration.
func _register(eid: String, entry: Dictionary, category: String) -> bool:
	if eid == "":
		_validation_errors.append("%s entry with empty id" % category)
		return false
	if _all_by_id.has(eid):
		# Ambiguous id: flag it invalid so neither definition is ever spawnable.
		_flag(eid, "duplicate enemy id '%s'" % eid)
		return false
	_all_by_id[eid] = entry
	_category_by_id[eid] = category
	return true


## Record a validation problem AND mark the id non-spawnable (fail closed).
func _flag(eid: String, msg: String) -> void:
	_validation_errors.append(msg)
	if eid != "":
		_invalid_ids[eid] = true


## --- Compatibility API (unchanged behavior) ---------------------------------

func live_defs() -> Array:
	return _live_defs


## O(1) read-only lookup over the enemies[] array (live + planned). Returns the
## shared authority dict for inspection; unknown -> {}. Spawners must NOT use this —
## they use def_for_spawn() (a validated, fail-closed, independent copy).
func get_def(enemy_id: String) -> Dictionary:
	return _defs_by_id.get(enemy_id, {})


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

func category_of(enemy_id: String) -> String:
	return str(_category_by_id.get(enemy_id, ""))


func is_live(enemy_id: String) -> bool:
	return category_of(enemy_id) == "live"


## Individually valid: known id with no validation problem recorded against it.
func is_valid(enemy_id: String) -> bool:
	return _all_by_id.has(enemy_id) and not _invalid_ids.has(enemy_id)


## Only a live AND individually-valid enemy may spawn. A malformed live entry
## (bad family, missing field, bad range, malformed spawn rule, bad drop ref,
## unknown actor kind, duplicate id) is NOT spawnable.
func is_spawnable(enemy_id: String) -> bool:
	return is_live(enemy_id) and is_valid(enemy_id)


## The ONLY way a spawner should obtain a def: an independent deep copy of a
## spawnable (live + valid) def, or {} otherwise. The factory turns {} into an
## explicit failure, so a typo/duplicate/malformed id never becomes a default enemy.
func def_for_spawn(enemy_id: String) -> Dictionary:
	if not is_spawnable(enemy_id):
		return {}
	return (_defs_by_id.get(enemy_id, {}) as Dictionary).duplicate(true)


func validation_errors() -> Array[String]:
	return _validation_errors


func _validate() -> void:
	for eid: String in _all_by_id:
		var entry: Dictionary = _all_by_id[eid]
		var cat: String = _category_by_id.get(eid, "")
		# Legal status (enemies[] entries only; mini_boss/boss are their own blocks).
		if (cat == "live" or cat == "planned") \
				and not LEGAL_ENEMY_STATUS.has(str(entry.get("status", ""))):
			_flag(eid, "'%s' has illegal status '%s'" % [eid, str(entry.get("status", ""))])
		var fam: String = str(entry.get("family", ""))
		if not LEGAL_FAMILIES.has(fam):
			_flag(eid, "%s '%s' has illegal family '%s'" % [cat, eid, fam])
		# A live enemy must carry the fields the factory reads for real behavior.
		if cat == "live":
			for req: String in ["contact_damage", "speed"]:
				if not entry.has(req):
					_flag(eid, "live '%s' missing required field '%s'" % [eid, req])
			var spd: float = float(entry.get("speed", 0.0))
			if spd <= 0.0:
				_flag(eid, "live '%s' speed must be > 0 (got %s)" % [eid, str(spd)])
			if float(entry.get("contact_damage", 0.0)) < 0.0:
				_flag(eid, "live '%s' contact_damage must be >= 0" % eid)
		# Numeric multipliers, when present, must be positive.
		for mult: String in ["hp_mult", "hall_dps_mult"]:
			if entry.has(mult) and float(entry.get(mult, 1.0)) <= 0.0:
				_flag(eid, "'%s' %s must be > 0" % [eid, mult])
		# Loot references: every drop needs a non-empty item id and a legal chance.
		for key: String in ["drops", "guaranteed_drops", "possible_drops"]:
			for drop in entry.get(key, []):
				if str(drop.get("item_id", "")) == "":
					_flag(eid, "'%s' %s entry with empty item_id" % [eid, key])
				var ch: float = float(drop.get("chance", 0.0))
				if ch < 0.0 or ch > 1.0:
					_flag(eid, "'%s' %s chance out of [0,1]: %s" % [eid, key, str(ch)])
		# Spawn references, when present, must be numeric and non-negative.
		var rule: Dictionary = entry.get("spawn_rule", {})
		for rk: String in ["day_threshold", "stockpile_threshold", "base_chance"]:
			if rule.has(rk) and float(rule.get(rk, 0.0)) < 0.0:
				_flag(eid, "'%s' spawn_rule.%s must be >= 0" % [eid, rk])
		# Incompatible configuration: emitting molten bubbles is a lava-dweller
		# presentation, so it may only appear alongside lava_immune.
		if bool(entry.get("emits_bubbles", false)) and not bool(entry.get("lava_immune", false)):
			_flag(eid, "'%s' emits_bubbles without lava_immune (lava presentation only)" % eid)
		# Actor kind, when present, must be a controller the factory knows how to build.
		if entry.has("actor_kind") \
				and not EnemyFactory.actor_kind_known(str(entry.get("actor_kind", ""))):
			_flag(eid, "'%s' unknown actor_kind '%s'" % [eid, str(entry.get("actor_kind", ""))])
