class_name ContractBalanceReport
extends RefCounted
## R-09.3: deterministic, evidence-only contract balance report.
## It plays one named fixed-seed policy against the real ContractModel
## vocabulary, writes no balance data, and treats its output as scenario-scoped
## evidence rather than global tuning truth.

const ContractModelScript := preload("res://scripts/contracts/contract_model.gd")
const InventoryDataScript := preload("res://scripts/inventory/inventory.gd")

const SCENARIO_ID := "r09_fixed_seed_steward_policy"
const POLICY_NAME := "Steward bootstrap: store stone, build workbench, craft torches, survive and hunt"
const WORLD_SEED := 90240724
const DAYS := 4

const ITEM_VALUE := {
	"torch": 3,
	"food": 2,
	"crop_seeds": 2,
}

class FakeTownHall:
	extends Node2D
	var stockpile: Dictionary = {}
	var stations_built: Dictionary = {"workbench": false, "furnace": false, "anvil": false}

	func station_built(station_id: String) -> bool:
		return bool(stations_built.get(station_id, false))


class FakePlayer:
	extends CharacterBody2D
	var inventory = null


class FakeGameRoot:
	extends Node
	var day_count := 1
	var xp_events: Dictionary = {}
	var xp_totals: Dictionary = {}
	var base_xp := 0
	var xp_awards: Array = []

	func award_xp(event_id: String) -> void:
		var ev: Dictionary = xp_events.get(event_id, {})
		if ev.is_empty():
			return
		var xp_type := str(ev.get("xp_type", ""))
		var amount := int(ev.get("base_amount", 0))
		xp_totals[xp_type] = int(xp_totals.get(xp_type, 0)) + amount
		base_xp += int(ev.get("also_awards", {}).get("base_xp", 0))
		xp_awards.append({"event_id": event_id, "xp_type": xp_type, "amount": amount})


func run_report() -> Dictionary:
	var hall := FakeTownHall.new()
	var player := FakePlayer.new()
	player.inventory = InventoryDataScript.new()
	var game := FakeGameRoot.new()
	game.xp_events = _xp_event_map()

	var model = ContractModelScript.new()
	model.load_definitions()
	model.town_hall = hall
	model.player = player
	model.game_root = game

	var contract_ids: Array[String] = []
	var accepted_day: Dictionary = {}
	var completed_day: Dictionary = {}
	var claimed_day: Dictionary = {}
	for row: Dictionary in model.snapshot():
		var id := str(row.get("id", ""))
		contract_ids.append(id)
		model.accept(id)
		accepted_day[id] = 1
	model.evaluate()

	var days: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for day in range(1, DAYS + 1):
		game.day_count = day
		var inflow := _policy_inflow(day, rng)
		var outflow: Dictionary = {}
		_apply_inflow(hall.stockpile, inflow)
		var actions: Array[String] = []
		_apply_day_actions(day, hall, model, outflow, actions)
		model.evaluate()
		_capture_completed_days(model, contract_ids, completed_day, day)
		var rewards := _claim_completed(model, contract_ids, player, game, claimed_day, day)
		days.append({
			"day": day,
			"inflow": inflow,
			"outflow": outflow,
			"actions": actions,
			"stockpile": _sorted_dict(hall.stockpile),
			"contracts": _contract_statuses(model, contract_ids),
			"pressure": _pressure_snapshot(day, hall, model),
			"rewards_claimed": rewards,
			"reward_value": _reward_value(rewards),
			"bottlenecks": _bottlenecks(model, contract_ids, accepted_day, day),
		})

	var latencies := {}
	for id in contract_ids:
		if completed_day.has(id):
			latencies[id] = int(completed_day[id]) - int(accepted_day.get(id, 1))
		else:
			latencies[id] = null
	var final_status := _contract_statuses(model, contract_ids)
	return {
		"metadata": {
			"scenario_id": SCENARIO_ID,
			"policy": POLICY_NAME,
			"world_seed": WORLD_SEED,
			"days": DAYS,
			"generated_at": Time.get_datetime_string_from_system(false, true),
			"scope": "Deterministic evidence under one scripted policy; not global balance proof.",
		},
		"days": days,
		"contract_completion_latency_days": latencies,
		"final_contract_status": final_status,
		"reward_totals": {
			"items": _sorted_dict(player.inventory.to_dict()),
			"xp": _sorted_dict(game.xp_totals),
			"base_xp": game.base_xp,
		},
		"bottlenecks": _final_bottlenecks(final_status, latencies),
		"proposed_tuning": _proposed_tuning(final_status, latencies),
	}


func normalized_payload(report: Dictionary) -> Dictionary:
	var out: Dictionary = report.duplicate(true)
	if out.has("metadata") and typeof(out["metadata"]) == TYPE_DICTIONARY:
		(out["metadata"] as Dictionary).erase("generated_at")
	return out


func write_outputs(json_path: String, markdown_path: String) -> bool:
	var report := run_report()
	return _write_text(json_path, JSON.stringify(report, "\t")) \
		and _write_text(markdown_path, markdown_for(report))


func markdown_for(report: Dictionary) -> String:
	var meta: Dictionary = report.get("metadata", {})
	var lines: Array[String] = [
		"# R-09.3 Contract Balance Report",
		"",
		"- Scenario: `%s`" % str(meta.get("scenario_id", "")),
		"- Policy: %s" % str(meta.get("policy", "")),
		"- World seed: `%d`" % int(meta.get("world_seed", 0)),
		"- Days simulated: `%d`" % int(meta.get("days", 0)),
		"- Scope: %s" % str(meta.get("scope", "")),
		"",
		"## Daily Summary",
		"",
		"| Day | Inflow | Outflow | Actions | Pressure C/R/L/T | Reward value | Bottlenecks |",
		"|---|---|---|---|---|---|---|",
	]
	for day: Dictionary in report.get("days", []):
		var pressure: Dictionary = day.get("pressure", {})
		lines.append("| %d | %s | %s | %s | %.1f / %.1f / %.1f / %.1f | %d | %s |" % [
			int(day.get("day", 0)),
			_compact_dict(day.get("inflow", {})),
			_compact_dict(day.get("outflow", {})),
			", ".join(day.get("actions", [])),
			float(pressure.get("coherence", 0.0)),
			float(pressure.get("resilience", 0.0)),
			float(pressure.get("load", 0.0)),
			float(pressure.get("threat", 0.0)),
			int(day.get("reward_value", 0)),
			", ".join(day.get("bottlenecks", [])),
		])
	lines.append("")
	lines.append("## Completion Latency")
	lines.append("")
	lines.append("| Contract | Days from activation to completion | Final status |")
	lines.append("|---|---|---|")
	var latencies: Dictionary = report.get("contract_completion_latency_days", {})
	var final_status: Dictionary = report.get("final_contract_status", {})
	var ids: Array = latencies.keys()
	ids.sort()
	for id in ids:
		lines.append("| `%s` | %s | `%s` |" % [
			str(id),
			"N/A" if latencies[id] == null else str(int(latencies[id])),
			str(final_status.get(id, "")),
		])
	lines.append("")
	lines.append("## Proposed Tuning")
	lines.append("")
	for note in report.get("proposed_tuning", []):
		lines.append("- %s" % str(note))
	return "\n".join(lines) + "\n"


func _xp_event_map() -> Dictionary:
	var data := _load_json("res://data/progression/player_xp.json")
	var out := {}
	for ev: Dictionary in data.get("xp_events", []):
		out[str(ev.get("event_id", ""))] = ev
	return out


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _policy_inflow(day: int, rng: RandomNumberGenerator) -> Dictionary:
	var variance := int(rng.randi_range(0, 0))
	match day:
		1:
			return {"wood": 10, "stone": 12 + variance, "coal": 2, "food": 3}
		2:
			return {"wood": 8, "stone": 15, "food": 2}
		3:
			return {"stone": 4, "coal": 1, "food": 4}
		4:
			return {"wood": 4, "stone": 3, "food": 3}
	return {}


func _apply_day_actions(day: int, hall: FakeTownHall, model, outflow: Dictionary,
		actions: Array[String]) -> void:
	match day:
		1:
			_record_craft("craft_torch", {"wood": 1, "coal": 1}, hall, model, outflow, actions)
		2:
			_spend_stockpile(hall.stockpile, {"wood": 12, "stone": 6}, outflow)
			hall.stations_built["workbench"] = true
			actions.append("build_workbench")
			model.evaluate()
			_record_craft("craft_torch", {"wood": 1, "coal": 1}, hall, model, outflow, actions)
			model.note_event("defeat_enemies")
			actions.append("defeat_enemy")
		3:
			model.note_event("defeat_enemies")
			actions.append("defeat_enemy")
		4:
			actions.append("stabilize_stockpile")


func _record_craft(recipe_id: String, cost: Dictionary, hall: FakeTownHall, model,
		outflow: Dictionary, actions: Array[String]) -> void:
	_spend_stockpile(hall.stockpile, cost, outflow)
	model.note_event("craft_items", recipe_id)
	actions.append(recipe_id)


func _apply_inflow(stockpile: Dictionary, inflow: Dictionary) -> void:
	for item_id in inflow:
		stockpile[item_id] = int(stockpile.get(item_id, 0)) + int(inflow[item_id])


func _spend_stockpile(stockpile: Dictionary, cost: Dictionary, outflow: Dictionary) -> void:
	for item_id in cost:
		var n := int(cost[item_id])
		stockpile[item_id] = maxi(0, int(stockpile.get(item_id, 0)) - n)
		if int(stockpile[item_id]) <= 0:
			stockpile.erase(item_id)
		outflow[item_id] = int(outflow.get(item_id, 0)) + n


func _capture_completed_days(model, ids: Array[String], completed_day: Dictionary, day: int) -> void:
	for id in ids:
		if completed_day.has(id):
			continue
		var status: String = model.status_of(id)
		if status == ContractModelScript.COMPLETED or status == ContractModelScript.CLAIMED:
			completed_day[id] = day


func _claim_completed(model, ids: Array[String], player: FakePlayer, game: FakeGameRoot,
		claimed_day: Dictionary, day: int) -> Array:
	var rewards: Array = []
	for id in ids:
		if claimed_day.has(id) or model.status_of(id) != ContractModelScript.COMPLETED:
			continue
		var inv_before: Dictionary = player.inventory.to_dict()
		var xp_before: Dictionary = game.xp_totals.duplicate(true)
		var base_before := game.base_xp
		var res: Dictionary = model.claim(id)
		if not bool(res.get("ok", false)):
			continue
		claimed_day[id] = day
		rewards.append({
			"contract": id,
			"items": _dict_delta(inv_before, player.inventory.to_dict()),
			"xp": _dict_delta(xp_before, game.xp_totals),
			"base_xp": game.base_xp - base_before,
		})
	return rewards


func _dict_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for k in after:
		var delta := int(after[k]) - int(before.get(k, 0))
		if delta != 0:
			out[str(k)] = delta
	return _sorted_dict(out)


func _contract_statuses(model, ids: Array[String]) -> Dictionary:
	var out := {}
	for id in ids:
		out[id] = model.status_of(id)
	return out


func _pressure_snapshot(day: int, hall: FakeTownHall, model) -> Dictionary:
	var total_stock := 0
	for item_id in hall.stockpile:
		total_stock += int(hall.stockpile[item_id])
	var active_count := 0
	for row: Dictionary in model.snapshot():
		if str(row.get("status", "")) == ContractModelScript.ACTIVE:
			active_count += 1
	var threat := 8.0 if day == 2 else (12.0 if day == 3 else 2.0)
	var resilience := clampf(35.0 + float(total_stock) * 1.5 - threat, 0.0, 100.0)
	var load_value := clampf(18.0 + active_count * 8.0 + threat * 0.5, 0.0, 100.0)
	var coherence := clampf(42.0 + float(hall.stockpile.get("food", 0)) * 3.0
		+ (10.0 if hall.station_built("workbench") else 0.0) - active_count * 2.0, 0.0, 100.0)
	return {
		"coherence": snappedf(coherence, 0.1),
		"resilience": snappedf(resilience, 0.1),
		"load": snappedf(load_value, 0.1),
		"threat": threat,
	}


func _bottlenecks(model, ids: Array[String], accepted_day: Dictionary, day: int) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		if model.status_of(id) == ContractModelScript.ACTIVE \
				and day - int(accepted_day.get(id, day)) >= 2:
			out.append(id)
	return out


func _final_bottlenecks(final_status: Dictionary, latencies: Dictionary) -> Array:
	var out: Array[String] = []
	for id in final_status:
		if str(final_status[id]) != ContractModelScript.CLAIMED:
			out.append("%s did not reach claimed" % str(id))
		elif latencies.get(id, null) != null and int(latencies[id]) > 2:
			out.append("%s completed slowly (%d days)" % [str(id), int(latencies[id])])
	return out


func _proposed_tuning(final_status: Dictionary, latencies: Dictionary) -> Array:
	var notes: Array[String] = []
	if _final_bottlenecks(final_status, latencies).is_empty():
		notes.append("No automatic balance mutation. Under this policy every R-09.2 contract reaches claimed by day %d." % DAYS)
		notes.append("Keep `first_hunt` at 2 defeats for now; it completes later than the setup contracts and supplies the intended combat pacing contrast.")
	else:
		notes.append("Review contracts listed as bottlenecks before changing reward values; this report is evidence only.")
	return notes


func _reward_value(rewards: Array) -> int:
	var total := 0
	for reward: Dictionary in rewards:
		for item_id in reward.get("items", {}):
			total += int(reward["items"][item_id]) * int(ITEM_VALUE.get(str(item_id), 1))
		for xp_type in reward.get("xp", {}):
			total += int(reward["xp"][xp_type])
		total += int(reward.get("base_xp", 0))
	return total


func _sorted_dict(data: Dictionary) -> Dictionary:
	var out := {}
	var keys: Array = data.keys()
	keys.sort()
	for k in keys:
		out[str(k)] = data[k]
	return out


func _compact_dict(data: Dictionary) -> String:
	if data.is_empty():
		return "-"
	var parts: Array[String] = []
	var keys: Array = data.keys()
	keys.sort()
	for k in keys:
		parts.append("%s:%s" % [str(k), str(data[k])])
	return ", ".join(parts)


func _write_text(path: String, text: String) -> bool:
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write balance report: " + path)
		return false
	f.store_string(text)
	return true
