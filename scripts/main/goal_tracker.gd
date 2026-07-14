extends RefCounted
## FQ-14: the current-goal model. Pure, data-driven, and state-derived — it holds
## no scene references and is fed a plain snapshot dict, so it is trivially
## testable and cannot desync from the real game.
##
## Objectives latch monotonically as a prefix: satisfying objective i marks
## 0..i done (finishing a later step implies the earlier ones — you cannot
## deposit without gathering, or survive a night without a hall). This keeps the
## panel from regressing when a transient input clears (e.g. depositing empties
## the backpack) and makes a loaded game resolve to the right goal on the first
## update, without persisting any tutorial state.

const GOALS := [
	{"id": "gather", "text": "Gather wood and stone",
		"hint": "Mine trees and stone with the pick (LMB)."},
	{"id": "light", "text": "Light the Town Hall",
		"hint": "Craft a torch (C) and place it (RMB) near the hall."},
	{"id": "deposit", "text": "Deposit resources at the hall",
		"hint": "Stand by the Town Hall and press E to store materials."},
	{"id": "craft", "text": "Forge a tool or build a station",
		"hint": "Open the Town Hall (E) to forge gear or build a station."},
	{"id": "survive", "text": "Survive the first night",
		"hint": "Keep the hall lit and hold on until dawn."},
]

var _done: Dictionary = {}   # objective id -> true once latched


## Latch objectives from a snapshot of boolean conditions keyed by objective id.
## Prefix-monotonic: the highest satisfied objective latches every earlier one.
## Returns true if anything newly latched (so the caller can refresh/announce).
func note(snapshot: Dictionary) -> bool:
	var latch_to := -1
	for i in range(GOALS.size()):
		if bool(snapshot.get(str(GOALS[i]["id"]), false)):
			latch_to = i
	var newly := false
	for i in range(latch_to + 1):
		var gid: String = str(GOALS[i]["id"])
		if not bool(_done.get(gid, false)):
			_done[gid] = true
			newly = true
	return newly


## The current objective (first unlatched), or the all-done sentinel.
func current() -> Dictionary:
	for i in range(GOALS.size()):
		var gid: String = str(GOALS[i]["id"])
		if not bool(_done.get(gid, false)):
			return {
				"id": gid,
				"text": str(GOALS[i]["text"]),
				"hint": str(GOALS[i]["hint"]),
				"index": i,
				"total": GOALS.size(),
				"all_done": false,
			}
	return {
		"id": "", "text": "Settlement founded — keep it thriving.",
		"hint": "", "index": GOALS.size(), "total": GOALS.size(), "all_done": true,
	}


func is_done(goal_id: String) -> bool:
	return bool(_done.get(goal_id, false))


func all_done() -> bool:
	return _done.size() >= GOALS.size()


func done_count() -> int:
	return _done.size()
