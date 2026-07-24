class_name ContractModel
extends RefCounted
## R-09 Slice 1: directed goals ("contracts"). Observes LIVE authoritative game
## state and never copies it -- the save persists only lifecycle status (event-
## only accumulators arrive in Slice 2). Rewards route through existing player-
## facing authorities (player inventory). Lifecycle:
##   available -> active -> completed -> claimed
## `available` is implicit (a defined contract with no persisted record).
## Authority: docs/WORK_ORDER_R09_CONTRACTS_BALANCE.md.

const CONTRACTS_PATH := "res://data/contracts.json"

const AVAILABLE := "available"
const ACTIVE := "active"
const COMPLETED := "completed"
const CLAIMED := "claimed"

# Slice 1 vocabulary (deliberately narrow -- not a generic quest engine).
const OBJECTIVE_TYPES := ["stockpile_at_least"]
const REWARD_TYPES := ["grant_items"]

# Live authority references, injected by the owner before evaluate()/claim().
var town_hall: Node2D = null
var player: CharacterBody2D = null

# id -> definition dict (from data/contracts.json), in stable file order.
var _defs: Dictionary = {}
var _order: Array[String] = []
# id -> { "status": String }  -- only for contracts advanced beyond `available`.
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


## Live status: `available` when no record exists, else the stored status.
## Returns "" for an unknown contract id.
func status_of(id: String) -> String:
	if not _defs.has(id):
		return ""
	if _records.has(id):
		return str(_records[id].get("status", AVAILABLE))
	return AVAILABLE


## available -> active. False for unknown ids or non-available contracts.
func accept(id: String) -> bool:
	if not _defs.has(id) or status_of(id) != AVAILABLE:
		return false
	_records[id] = {"status": ACTIVE}
	return true


## Re-evaluate every ACTIVE contract against live authoritative state. A
## reconstructable objective completes the FIRST time its threshold is reached
## while active, then LATCHES -- a later state drop never reverts it. Completed
## and claimed contracts are never re-evaluated.
func evaluate() -> void:
	for id in _order:
		if status_of(id) != ACTIVE:
			continue
		if _objective_met(_defs[id].get("objective", {})):
			_records[id]["status"] = COMPLETED


## completed -> claimed, transactional: grant the FULL reward AND set claimed, or
## neither. Returns { "ok": bool, "reason": String }. Any no-op (already claimed,
## not completed, or inventory cannot accept) leaves status unchanged and is
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


# --- Objective observation (LIVE reads only, never a persisted copy) ---

func _objective_met(objective: Dictionary) -> bool:
	match str(objective.get("type", "")):
		"stockpile_at_least":
			if town_hall == null:
				return false
			var item := str(objective.get("item", ""))
			var have := int(town_hall.stockpile.get(item, 0))
			return have >= int(objective.get("count", 0))
	return false


# --- Reward granting (existing player-facing authority only) ---

func _can_accept_reward(reward: Dictionary) -> bool:
	match str(reward.get("type", "")):
		"grant_items":
			# Player inventory is currently uncapped; the predicate exists so a
			# future capacity model makes claim a safe, retryable no-op.
			return player != null and player.inventory != null
	return false


func _grant_reward(reward: Dictionary) -> bool:
	match str(reward.get("type", "")):
		"grant_items":
			player.inventory.add_many(reward.get("items", {}))
			return true
	return false


# --- Persistence (world-owned): only records advanced beyond `available` ---

func serialize() -> Array:
	var out: Array = []
	for id in _order:
		if _records.has(id):
			out.append({"id": id, "status": str(_records[id].get("status", AVAILABLE))})
	return out


## Restore lifecycle records. A missing/empty array (legacy pre-R-09 world state)
## clears to all-available. Records for unknown ids, or with an `available`/
## invalid status, are dropped safely.
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
		_records[id] = {"status": status}
