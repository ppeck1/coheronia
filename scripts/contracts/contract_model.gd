class_name ContractModel
extends RefCounted
## R-09 directed goals ("contracts"). Observes LIVE authoritative game state and
## never copies it -- the save persists only lifecycle status plus, for the two
## event-only objective types, a small per-objective accumulator. Rewards route
## through existing player-facing authorities (player inventory, player XP).
## Lifecycle:  available -> active -> completed -> claimed
## `available` is implicit (a defined contract with no persisted record).
## Authority: docs/WORK_ORDER_R09_CONTRACTS_BALANCE.md.

const CONTRACTS_PATH := "res://data/contracts.json"

const AVAILABLE := "available"
const ACTIVE := "active"
const COMPLETED := "completed"
const CLAIMED := "claimed"

# Slice 2 vocabulary (deliberately narrow -- not a generic quest engine).
const OBJECTIVE_TYPES := ["stockpile_at_least", "station_built", "survive_to_day",
	"defeat_enemies", "craft_items"]
const REWARD_TYPES := ["grant_items", "grant_xp"]
# The two types whose progress cannot be reconstructed from current state -- they
# accumulate a persisted integer keyed by the objective's stable `oid`.
const EVENT_OBJECTIVE_TYPES := ["defeat_enemies", "craft_items"]

# Live authority references, injected by the owner before evaluate()/claim().
var town_hall: Node2D = null
var player: CharacterBody2D = null
var game_root: Node = null

# id -> definition dict (from data/contracts.json), in stable file order.
var _defs: Dictionary = {}
var _order: Array[String] = []
# id -> { "status": String, "progress": { oid: int } }  -- only for contracts
# advanced beyond `available`; `progress` present only for event-only objectives.
var _records: Dictionary = {}


## Load contract definitions. `.json` has no import remap, so a direct
## FileAccess read is export-safe (see the R-00 export finding).
func load_definitions(path: String = CONTRACTS_PATH) -> void:
	_defs.clear()
	_order.clear()
	if not FileAccess.file_exists(path):
		push_error("ContractModel: missing %s" % path)
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ContractModel: %s is not an object" % path)
		return
	for entry in (parsed as Dictionary).get("contracts", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str((entry as Dictionary).get("id", ""))
		if id == "" or _defs.has(id):
			continue
		_defs[id] = entry
		_order.append(id)


## All defined contract ids, in file order.
func contract_ids() -> Array:
	return _order.duplicate()


func definition(id: String) -> Dictionary:
	return _defs.get(id, {})


func has_contract(id: String) -> bool:
	return _defs.has(id)


func is_event_only(objective_type: String) -> bool:
	return objective_type in EVENT_OBJECTIVE_TYPES


## Live status: `available` when no record exists, else the stored status.
## Returns "" for an unknown contract id.
func status_of(id: String) -> String:
	if not _defs.has(id):
		return ""
	if _records.has(id):
		return str(_records[id].get("status", AVAILABLE))
	return AVAILABLE


## available -> active. False for unknown ids or non-available contracts. An
## event-only objective starts its accumulator at 0 so only events AFTER
## activation ever count.
func accept(id: String) -> bool:
	if not _defs.has(id) or status_of(id) != AVAILABLE:
		return false
	var rec: Dictionary = {"status": ACTIVE}
	var objective: Dictionary = _defs[id].get("objective", {})
	if is_event_only(str(objective.get("type", ""))):
		rec["progress"] = {str(objective.get("oid", "")): 0}
	_records[id] = rec
	return true


## Record a gameplay event. For each ACTIVE contract whose event-only objective
## matches, increment its accumulator and latch to completed at the target.
## Events before activation or after completion never count (status != ACTIVE),
## and nothing is replayed on load -- only live events reach here.
func note_event(event_type: String, key: String = "") -> void:
	for id in _order:
		if status_of(id) != ACTIVE:
			continue
		var objective: Dictionary = _defs[id].get("objective", {})
		if str(objective.get("type", "")) != event_type:
			continue
		# craft_items is keyed to a specific recipe; defeat_enemies counts any kill.
		if event_type == "craft_items" and str(objective.get("recipe", "")) != key:
			continue
		var oid := str(objective.get("oid", ""))
		if oid == "":
			continue
		var rec: Dictionary = _records[id]
		var prog: Dictionary = rec.get("progress", {})
		prog[oid] = int(prog.get(oid, 0)) + 1
		rec["progress"] = prog
		if int(prog[oid]) >= int(objective.get("count", 0)):
			rec["status"] = COMPLETED


## Re-evaluate every ACTIVE contract against live authoritative state. A
## reconstructable objective completes the FIRST time its threshold is reached
## while active, then LATCHES. Event-only objectives complete here too when their
## restored accumulator already meets the target (e.g. after load) -- never by
## replaying history. Completed/claimed contracts are never re-evaluated.
func evaluate() -> void:
	for id in _order:
		if status_of(id) != ACTIVE:
			continue
		if _objective_met(id):
			_records[id]["status"] = COMPLETED


## completed -> claimed, transactional: grant the FULL reward AND set claimed, or
## neither. Returns { "ok": bool, "reason": String }. Any no-op (already claimed,
## not completed, or the reward cannot be accepted) leaves status unchanged and is
## safely retryable -- the reward can never be granted twice.
func claim(id: String) -> Dictionary:
	if not _defs.has(id):
		return {"ok": false, "reason": "unknown"}
	if status_of(id) != COMPLETED:
		return {"ok": false, "reason": "not_completed"}
	var reward: Dictionary = _defs[id].get("reward", {})
	if not _can_accept_reward(reward):
		return {"ok": false, "reason": "cannot_accept"}
	if not _grant_reward(reward):
		return {"ok": false, "reason": "grant_failed"}
	_records[id]["status"] = CLAIMED
	return {"ok": true, "reason": ""}


## {current, target} for an active/tracked contract's objective (UI + status).
## Reconstructable types read live; event-only types read the accumulator.
func objective_progress(id: String) -> Dictionary:
	if not _defs.has(id):
		return {"current": 0, "target": 0}
	var objective: Dictionary = _defs.get(id, {}).get("objective", {})
	var rec: Dictionary = _records.get(id, {})
	var otype := str(objective.get("type", ""))
	match otype:
		"stockpile_at_least":
			var have := 0
			if town_hall != null:
				have = int(town_hall.stockpile.get(str(objective.get("item", "")), 0))
			return {"current": have, "target": int(objective.get("count", 0))}
		"station_built":
			var built := 0
			if town_hall != null and bool(town_hall.station_built(str(objective.get("station", "")))):
				built = 1
			return {"current": built, "target": 1}
		"survive_to_day":
			var day := 0
			if game_root != null:
				day = int(game_root.day_count)
			return {"current": day, "target": int(objective.get("day", 0))}
		"defeat_enemies", "craft_items":
			var prog: Dictionary = rec.get("progress", {})
			return {"current": int(prog.get(str(objective.get("oid", "")), 0)),
				"target": int(objective.get("count", 0))}
	return {"current": 0, "target": 0}


## UI-facing snapshot in definition order. The model remains the authority for
## status/progress; callers decide how to present or act on each row.
func snapshot() -> Array:
	var out: Array = []
	for id in _order:
		var def: Dictionary = _defs[id]
		var objective: Dictionary = def.get("objective", {})
		out.append({
			"id": id,
			"title": str(def.get("title", id)),
			"description": str(def.get("description", "")),
			"status": status_of(id),
			"objective": objective.duplicate(),
			"progress": objective_progress(id),
			"reward": (def.get("reward", {}) as Dictionary).duplicate(),
		})
	return out


# --- Objective observation (LIVE reads / stored accumulator only) ---

func _objective_met(id: String) -> bool:
	var objective: Dictionary = _defs[id].get("objective", {})
	var rec: Dictionary = _records.get(id, {})
	match str(objective.get("type", "")):
		"stockpile_at_least":
			if town_hall == null:
				return false
			return int(town_hall.stockpile.get(str(objective.get("item", "")), 0)) \
				>= int(objective.get("count", 0))
		"station_built":
			if town_hall == null:
				return false
			return bool(town_hall.station_built(str(objective.get("station", ""))))
		"survive_to_day":
			if game_root == null:
				return false
			return int(game_root.day_count) >= int(objective.get("day", 0))
		"defeat_enemies", "craft_items":
			var prog: Dictionary = rec.get("progress", {})
			return int(prog.get(str(objective.get("oid", "")), 0)) \
				>= int(objective.get("count", 0))
	return false


# --- Reward granting (existing player-facing authorities only) ---

func _can_accept_reward(reward: Dictionary) -> bool:
	match str(reward.get("type", "")):
		"grant_items":
			# Player inventory is currently uncapped; the predicate exists so a
			# future capacity model makes claim a safe, retryable no-op.
			return player != null and player.inventory != null
		"grant_xp":
			return game_root != null
	return false


func _grant_reward(reward: Dictionary) -> bool:
	match str(reward.get("type", "")):
		"grant_items":
			player.inventory.add_many(reward.get("items", {}))
			return true
		"grant_xp":
			game_root.award_xp(str(reward.get("event_id", "")))
			return true
	return false


# --- Persistence (world-owned): only records advanced beyond `available` ---

func serialize() -> Array:
	var out: Array = []
	for id in _order:
		if not _records.has(id):
			continue
		var rec: Dictionary = _records[id]
		var entry: Dictionary = {"id": id, "status": str(rec.get("status", AVAILABLE))}
		if rec.has("progress"):
			entry["progress"] = (rec["progress"] as Dictionary).duplicate()
		out.append(entry)
	return out


## Restore lifecycle records (status + event accumulators). A missing/empty array
## (legacy pre-R-09 world state) clears to all-available. Records for unknown ids,
## or with an `available`/invalid status, are dropped safely. Progress is restored
## verbatim, never replayed.
func apply(data: Array) -> void:
	_records.clear()
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str((entry as Dictionary).get("id", ""))
		if not _defs.has(id):
			continue
		var status := str((entry as Dictionary).get("status", AVAILABLE))
		if status not in [ACTIVE, COMPLETED, CLAIMED]:
			continue
		var rec: Dictionary = {"status": status}
		var raw_prog: Variant = (entry as Dictionary).get("progress", null)
		if typeof(raw_prog) == TYPE_DICTIONARY:
			var prog: Dictionary = {}
			for k in (raw_prog as Dictionary):
				prog[str(k)] = int((raw_prog as Dictionary)[k])
			rec["progress"] = prog
		_records[id] = rec
