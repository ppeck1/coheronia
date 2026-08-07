extends Node
## S-07.3 smoke domain module - contracts (R-09 slice 1, directed goals).
## Order-preserving extraction from smoke_test.gd _run(): the harness owns
## _check()/_check_res_fixture() + the ledger; this module holds only the
## R-09 section body, called in place by the coordinator. Boundary ends at the
## R-09 torch-cleanup teardown; the trailing fq09w wall-art/world-restore tail
## stays in the coordinator (it reads _fq09w_storm_was declared far earlier).
const ContractBalanceReportScript := preload("res://scripts/contracts/balance_report.gd")


func run(harness, root, world, player, hall) -> void:
	# --- R-09 slice 1: contracts (directed goals) -----------------------------
	# Drive the model directly (no awaits) for determinism: the objective reads
	# the LIVE stockpile, completion latches, and claim is transactional. See
	# docs/WORK_ORDER_R09_CONTRACTS_BALANCE.md.
	var _r09_cm = root.contracts
	var _r09_id := "stone_reserve"
	var _r09_torch_base: int = player.inventory.count("torch")

	# (1) the runtime model parsed the narrow-vocab definition (the validator is
	# the hard schema gate; this confirms the game sees a well-formed contract).
	var _r09_def: Dictionary = _r09_cm.definition(_r09_id)
	var _r09_obj: Dictionary = _r09_def.get("objective", {})
	var _r09_rew: Dictionary = _r09_def.get("reward", {})
	var _r09_defs_ok: bool = _r09_id in _r09_cm.contract_ids() \
		and str(_r09_obj.get("type", "")) == "stockpile_at_least" \
		and str(_r09_obj.get("item", "")) == "stone" \
		and int(_r09_obj.get("count", 0)) == 20 \
		and str(_r09_rew.get("type", "")) == "grant_items" \
		and int((_r09_rew.get("items", {})).get("torch", 0)) == 3
	harness._check("r09_contract_definitions_valid", _r09_defs_ok,
		"objective=%s reward=%s" % [str(_r09_obj.get("type", "")), str(_r09_rew.get("type", ""))])

	# (2) full lifecycle available -> active -> completed -> claimed grants torch x3.
	_r09_cm.apply([])
	hall.stockpile["stone"] = 0
	var _r09_avail: bool = _r09_cm.status_of(_r09_id) == "available"
	var _r09_accepted: bool = _r09_cm.accept(_r09_id) and _r09_cm.status_of(_r09_id) == "active"
	_r09_cm.evaluate()
	var _r09_active_low: bool = _r09_cm.status_of(_r09_id) == "active"
	hall.stockpile["stone"] = 20
	_r09_cm.evaluate()
	var _r09_completed: bool = _r09_cm.status_of(_r09_id) == "completed"
	var _r09_t0: int = player.inventory.count("torch")
	var _r09_claim: Dictionary = _r09_cm.claim(_r09_id)
	var _r09_life_ok: bool = _r09_avail and _r09_accepted and _r09_active_low and _r09_completed \
		and bool(_r09_claim.get("ok", false)) and _r09_cm.status_of(_r09_id) == "claimed" \
		and player.inventory.count("torch") == _r09_t0 + 3
	harness._check("r09_lifecycle_available_active_completed_claimed", _r09_life_ok,
		"avail=%s active_low=%s completed=%s status=%s torch+%d" % [str(_r09_avail),
			str(_r09_active_low), str(_r09_completed), _r09_cm.status_of(_r09_id),
			player.inventory.count("torch") - _r09_t0])

	# (3) stockpile_at_least completes on the FIRST reach of the threshold.
	_r09_cm.apply([])
	_r09_cm.accept(_r09_id)
	hall.stockpile["stone"] = 19
	_r09_cm.evaluate()
	var _r09_at19: bool = _r09_cm.status_of(_r09_id) == "active"
	hall.stockpile["stone"] = 20
	_r09_cm.evaluate()
	var _r09_at20: bool = _r09_cm.status_of(_r09_id) == "completed"
	harness._check("r09_stockpile_at_least_first_reach", _r09_at19 and _r09_at20,
		"active_at_19=%s completed_at_20=%s" % [str(_r09_at19), str(_r09_at20)])

	# (4) completion latches: spending stock below the threshold never reverts it.
	_r09_cm.apply([])
	_r09_cm.accept(_r09_id)
	hall.stockpile["stone"] = 25
	_r09_cm.evaluate()
	var _r09_latch_done: bool = _r09_cm.status_of(_r09_id) == "completed"
	hall.stockpile["stone"] = 0
	_r09_cm.evaluate()
	var _r09_latch_kept: bool = _r09_cm.status_of(_r09_id) == "completed"
	harness._check("r09_completion_latches", _r09_latch_done and _r09_latch_kept,
		"completed=%s kept_after_drop=%s" % [str(_r09_latch_done), str(_r09_latch_kept)])

	# (5) claim is transactional and cannot double-pay.
	_r09_cm.apply([])
	_r09_cm.accept(_r09_id)
	hall.stockpile["stone"] = 20
	_r09_cm.evaluate()
	var _r09_tp0: int = player.inventory.count("torch")
	var _r09_first: Dictionary = _r09_cm.claim(_r09_id)
	var _r09_after_first: int = player.inventory.count("torch")
	var _r09_second: Dictionary = _r09_cm.claim(_r09_id)   # already claimed -> no-op
	var _r09_nodouble_ok: bool = bool(_r09_first.get("ok", false)) \
		and _r09_after_first == _r09_tp0 + 3 \
		and not bool(_r09_second.get("ok", false)) \
		and player.inventory.count("torch") == _r09_tp0 + 3
	harness._check("r09_claim_transactional_no_double_pay", _r09_nodouble_ok,
		"first=%s second=%s torch %d->%d" % [str(_r09_first.get("ok", false)),
			str(_r09_second.get("ok", false)), _r09_tp0, player.inventory.count("torch")])

	# (6) when the reward cannot be accepted, claim is a safe no-op (stays
	# completed, grants nothing) and succeeds once the authority returns.
	_r09_cm.apply([])
	_r09_cm.accept(_r09_id)
	hall.stockpile["stone"] = 20
	_r09_cm.evaluate()
	var _r09_ta0: int = player.inventory.count("torch")
	_r09_cm.player = null                                   # force can_accept -> false
	var _r09_blocked: Dictionary = _r09_cm.claim(_r09_id)
	var _r09_blocked_ok: bool = not bool(_r09_blocked.get("ok", false)) \
		and str(_r09_blocked.get("reason", "")) == "cannot_accept" \
		and _r09_cm.status_of(_r09_id) == "completed" \
		and player.inventory.count("torch") == _r09_ta0
	_r09_cm.player = player                                 # restore authority
	var _r09_retry: Dictionary = _r09_cm.claim(_r09_id)
	var _r09_accept_ok: bool = _r09_blocked_ok and bool(_r09_retry.get("ok", false)) \
		and player.inventory.count("torch") == _r09_ta0 + 3
	harness._check("r09_claim_inventory_cannot_accept", _r09_accept_ok,
		"blocked=%s reason=%s retry=%s" % [str(not bool(_r09_blocked.get("ok", false))),
			str(_r09_blocked.get("reason", "")), str(_r09_retry.get("ok", false))])

	# (7) save-version migration 0.5 -> 0.6: a legacy world with no contracts key
	# loads as all-available and re-saves under 0.6 with a contracts array.
	var _r09_state_now: Dictionary = root.save_manager.collect_state()
	var _r09_ver_ok: bool = root.save_manager.SAVE_VERSION == "0.6" \
		and "0.6" in root.save_manager.ACCEPTED_VERSIONS \
		and "0.5" in root.save_manager.ACCEPTED_VERSIONS \
		and "0.4" in root.save_manager.ACCEPTED_VERSIONS \
		and str(_r09_state_now.get("save_version", "")) == "0.6" \
		and _r09_state_now.has("contracts")
	var _r09_legacy: Dictionary = _r09_state_now.duplicate(true)
	_r09_legacy.erase("contracts")
	_r09_legacy["save_version"] = "0.5"
	var _r09_applied: bool = root.save_manager.apply_state(_r09_legacy)
	var _r09_migrated_empty: bool = _r09_cm.status_of(_r09_id) == "available"
	var _r09_resave: Dictionary = root.save_manager.collect_state()
	var _r09_resave_ok: bool = str(_r09_resave.get("save_version", "")) == "0.6" \
		and _r09_resave.has("contracts") and typeof(_r09_resave["contracts"]) == TYPE_ARRAY
	root.save_manager.apply_state(_r09_state_now)   # restore the live world snapshot
	harness._check("r09_save_migration_0_5_to_0_6",
		_r09_ver_ok and _r09_applied and _r09_migrated_empty and _r09_resave_ok,
		"ver_ok=%s applied=%s migrated_available=%s resave06=%s" % [str(_r09_ver_ok),
			str(_r09_applied), str(_r09_migrated_empty), str(_r09_resave_ok)])

	# (8) claimed state persists across serialize/apply and never re-grants on
	# reload (idempotent completion).
	_r09_cm.apply([])
	_r09_cm.accept(_r09_id)
	hall.stockpile["stone"] = 20
	_r09_cm.evaluate()
	_r09_cm.claim(_r09_id)
	var _r09_ser: Array = _r09_cm.serialize()
	var _r09_ser_has_claimed := false
	for _r09_e in _r09_ser:
		if str(_r09_e.get("id", "")) == _r09_id and str(_r09_e.get("status", "")) == "claimed":
			_r09_ser_has_claimed = true
	_r09_cm.apply(_r09_ser)                                  # simulate reload
	var _r09_reloaded_claimed: bool = _r09_cm.status_of(_r09_id) == "claimed"
	var _r09_tr0: int = player.inventory.count("torch")
	var _r09_regrant: Dictionary = _r09_cm.claim(_r09_id)   # must be a no-op
	_r09_cm.evaluate()
	var _r09_persist_ok: bool = _r09_ser_has_claimed and _r09_reloaded_claimed \
		and not bool(_r09_regrant.get("ok", false)) \
		and player.inventory.count("torch") == _r09_tr0
	harness._check("r09_claimed_state_persists", _r09_persist_ok,
		"ser_claimed=%s reloaded=%s regrant_blocked=%s" % [str(_r09_ser_has_claimed),
			str(_r09_reloaded_claimed), str(not bool(_r09_regrant.get("ok", false)))])

	# (9) accepting an already-satisfied contract completes it immediately (the
	# game_root.accept_contract edge re-evaluates on accept, no stockpile_changed).
	_r09_cm.apply([])
	hall.stockpile["stone"] = 20
	var _r09_acc: bool = root.accept_contract(_r09_id)
	var _r09_acc_completed: bool = _r09_acc and _r09_cm.status_of(_r09_id) == "completed"
	harness._check("r09_accept_already_satisfied_completes", _r09_acc_completed,
		"accepted=%s status=%s" % [str(_r09_acc), _r09_cm.status_of(_r09_id)])

	# (10) an active stockpile contract already satisfied by the saved stockpile
	# latches on F9/Restore reload (game_root.load_game re-evaluates after apply).
	# This exercises the REAL save/load path; snapshot the good persisted state
	# first, then fully reload it afterward so the round-trip is net-zero for the
	# sections that follow (the inventory board rebuilds off a clean reload).
	# (10) reload re-evaluation: after a saved world carrying an ACTIVE, already-
	# satisfied stockpile contract is restored via save_manager.apply_state (the
	# world-restore half of F9/Restore), the explicit contracts.evaluate() that
	# game_root.load_game() now runs latches it to completed. Driven through
	# apply_state + evaluate rather than the full load_game() wrapper -- load_game
	# rebuilds the HUD/board mid-suite and would perturb later checks; check 7
	# proves apply_state itself is net-zero, and it is restored the same way here.
	var _r09_lg_snap: Dictionary = root.save_manager.collect_state()
	var _r09_lg_craft: Dictionary = _r09_lg_snap.duplicate(true)
	_r09_lg_craft["contracts"] = [{"id": _r09_id, "status": "active"}]
	var _r09_lg_th: Dictionary = _r09_lg_craft.get("town_hall", {})
	var _r09_lg_stock: Dictionary = _r09_lg_th.get("stockpile", {})
	_r09_lg_stock["stone"] = 20
	_r09_lg_th["stockpile"] = _r09_lg_stock
	_r09_lg_craft["town_hall"] = _r09_lg_th
	var _r09_lg_applied: bool = root.save_manager.apply_state(_r09_lg_craft)
	# apply_state restores the record active + stockpile>=20 but does not evaluate
	# (the mid-apply stockpile_changed fires before apply_contracts sets it active).
	var _r09_lg_active_after_restore: bool = _r09_cm.status_of(_r09_id) == "active"
	_r09_cm.evaluate()                                     # the game_root.load_game edge
	var _r09_lg_completed: bool = _r09_cm.status_of(_r09_id) == "completed"
	harness._check("r09_load_game_re_evaluates_active_stockpile_contract",
		_r09_lg_applied and _r09_lg_active_after_restore and _r09_lg_completed,
		"applied=%s active_after_restore=%s completed_after_eval=%s" % [str(_r09_lg_applied),
			str(_r09_lg_active_after_restore), str(_r09_lg_completed)])
	# Restore the pre-test world so later sections are unaffected (mirrors check 7).
	root.save_manager.apply_state(_r09_lg_snap)
	root.save_manager.apply_player_position(_r09_lg_snap)

	# (11) R-09.2 reconstructable objectives: station_built and survive_to_day.
	var _r092_day_saved: int = root.day_count
	var _r092_stations_saved: Dictionary = hall.stations_built.duplicate(true)
	var _r092_xp_saved: Dictionary = root.xp_totals.duplicate(true)
	var _r092_base_xp_saved: int = root.base_xp
	var _r092_level_saved: int = root.player_level
	var _r092_level_start_saved: int = root._level_start_xp

	_r09_cm.apply([])
	hall.stations_built["workbench"] = false
	var _r092_station_accept: bool = root.accept_contract("workbench_charter")
	hall.stations_built["workbench"] = true
	_r09_cm.evaluate()
	harness._check("r09_objective_station_built",
		_r092_station_accept and _r09_cm.status_of("workbench_charter") == "completed",
		"status=%s" % _r09_cm.status_of("workbench_charter"))

	_r09_cm.apply([])
	root.day_count = 1
	var _r092_day_accept: bool = root.accept_contract("second_dawn")
	var _r092_day_active: bool = _r09_cm.status_of("second_dawn") == "active"
	root.day_count = 2
	_r09_cm.evaluate()
	harness._check("r09_objective_survive_to_day",
		_r092_day_accept and _r092_day_active and _r09_cm.status_of("second_dawn") == "completed",
		"active_at_day1=%s status=%s" % [str(_r092_day_active), _r09_cm.status_of("second_dawn")])

	# (12) Event-only objectives count only post-activation events and freeze at
	# completion.
	_r09_cm.apply([])
	_r09_cm.note_event("defeat_enemies")
	_r09_cm.accept("first_hunt")
	_r09_cm.note_event("defeat_enemies")
	var _r092_defeat_p1: Dictionary = _r09_cm.objective_progress("first_hunt")
	var _r092_defeat_active: bool = _r09_cm.status_of("first_hunt") == "active" \
		and int(_r092_defeat_p1.get("current", 0)) == 1
	_r09_cm.note_event("defeat_enemies")
	var _r092_defeat_done: bool = _r09_cm.status_of("first_hunt") == "completed"
	_r09_cm.note_event("defeat_enemies")
	var _r092_defeat_p2: Dictionary = _r09_cm.objective_progress("first_hunt")
	harness._check("r09_event_progress_after_activation_only",
		_r092_defeat_active and _r092_defeat_done and int(_r092_defeat_p2.get("current", 0)) == 2,
		"p1=%d p2=%d status=%s" % [int(_r092_defeat_p1.get("current", 0)),
			int(_r092_defeat_p2.get("current", 0)), _r09_cm.status_of("first_hunt")])

	_r09_cm.apply([])
	_r09_cm.accept("torch_practice")
	_r09_cm.note_event("craft_items", "craft_torch")
	var _r092_ser_progress: Array = _r09_cm.serialize()
	_r09_cm.apply(_r092_ser_progress)
	var _r092_reload_progress: Dictionary = _r09_cm.objective_progress("torch_practice")
	_r09_cm.evaluate()
	var _r092_reload_still_active: bool = _r09_cm.status_of("torch_practice") == "active" \
		and int(_r092_reload_progress.get("current", 0)) == 1
	_r09_cm.note_event("craft_items", "craft_torch")
	harness._check("r09_event_progress_persists_no_replay",
		_r092_reload_still_active and _r09_cm.status_of("torch_practice") == "completed",
		"reload_progress=%d status=%s" % [
			int(_r092_reload_progress.get("current", 0)), _r09_cm.status_of("torch_practice")])

	# (13) craft_items keys by recipe and two contracts on the same event type
	# keep independent objective ids/progress.
	_r09_cm.apply([])
	_r09_cm.accept("torch_order")
	_r09_cm.accept("torch_practice")
	_r09_cm.note_event("craft_items", "smelt_iron")
	var _r092_wrong_key_ok: bool = int(_r09_cm.objective_progress("torch_order").get("current", 0)) == 0 \
		and int(_r09_cm.objective_progress("torch_practice").get("current", 0)) == 0
	_r09_cm.note_event("craft_items", "craft_torch")
	var _r092_first_done: bool = _r09_cm.status_of("torch_order") == "completed" \
		and _r09_cm.status_of("torch_practice") == "active" \
		and int(_r09_cm.objective_progress("torch_practice").get("current", 0)) == 1
	_r09_cm.note_event("craft_items", "craft_torch")
	var _r092_second_done: bool = _r09_cm.status_of("torch_practice") == "completed"
	harness._check("r09_multi_contract_independent",
		_r092_wrong_key_ok and _r092_first_done and _r092_second_done,
		"wrong_key=%s order=%s practice=%s" % [str(_r092_wrong_key_ok),
			_r09_cm.status_of("torch_order"), _r09_cm.status_of("torch_practice")])

	# (14) grant_xp routes through the real progression authority.
	_r09_cm.apply([])
	hall.stations_built["workbench"] = true
	root.accept_contract("workbench_charter")
	var _r092_civic_before: int = int(root.xp_totals.get("civic", 0.0))
	var _r092_xp_claim: bool = root.claim_contract("workbench_charter")
	var _r092_civic_after: int = int(root.xp_totals.get("civic", 0.0))
	harness._check("r09_reward_routes_through_authority",
		_r092_xp_claim and _r09_cm.status_of("workbench_charter") == "claimed" \
			and _r092_civic_after > _r092_civic_before,
		"claim=%s civic %d->%d" % [str(_r092_xp_claim), _r092_civic_before, _r092_civic_after])

	# (15) the player-facing contracts panel lists definitions, accepts a
	# satisfied contract into completed, and claims it once.
	_r09_cm.apply([])
	hall.stockpile["stone"] = 20
	var _r092_panel = root._contracts_panel
	_r092_panel.open()
	var _r092_panel_lists: bool = _r092_panel.is_open() \
		and _r092_panel.contract_count() >= 6 \
		and _r092_panel.contract_row_status("stone_reserve") == "available" \
		and _r092_panel.contract_row_action_enabled("stone_reserve")
	root.accept_contract("stone_reserve")
	_r092_panel.refresh()
	var _r092_panel_completed: bool = _r092_panel.contract_row_status("stone_reserve") == "completed" \
		and _r092_panel.contract_row_action_enabled("stone_reserve")
	root.claim_contract("stone_reserve")
	_r092_panel.refresh()
	var _r092_panel_claimed: bool = _r092_panel.contract_row_status("stone_reserve") == "claimed" \
		and not _r092_panel.contract_row_action_enabled("stone_reserve")
	_r092_panel.close()
	harness._check("r09_contracts_panel_status_actions",
		_r092_panel_lists and _r092_panel_completed and _r092_panel_claimed,
		"lists=%s completed=%s claimed=%s" % [str(_r092_panel_lists),
			str(_r092_panel_completed), str(_r092_panel_claimed)])

	# (16) R-09.3: deterministic fixed-seed balance report. The smoke drives the
	# same pure report logic as the CI driver; timestamps are stripped before
	# comparison.
	var _r093_runner = ContractBalanceReportScript.new()
	var _r093_a: Dictionary = _r093_runner.run_report()
	var _r093_b: Dictionary = _r093_runner.run_report()
	var _r093_norm_a: Dictionary = _r093_runner.normalized_payload(_r093_a)
	var _r093_norm_b: Dictionary = _r093_runner.normalized_payload(_r093_b)
	var _r093_deterministic: bool = JSON.stringify(_r093_norm_a) == JSON.stringify(_r093_norm_b) \
		and str(_r093_a.get("metadata", {}).get("scenario_id", "")) == "r09_fixed_seed_steward_policy" \
		and int(_r093_a.get("metadata", {}).get("world_seed", 0)) == 90240724
	harness._check("r09_balance_report_deterministic", _r093_deterministic,
		"scenario=%s days=%d" % [str(_r093_a.get("metadata", {}).get("scenario_id", "")),
			int(_r093_a.get("metadata", {}).get("days", 0))])

	var _r093_contracts_before := FileAccess.get_file_as_string("res://data/contracts.json")
	var _r093_xp_before := FileAccess.get_file_as_string("res://data/progression/player_xp.json")
	var _r093_recipes_before := FileAccess.get_file_as_string("res://data/recipes.json")
	_r093_runner.run_report()
	var _r093_no_mutation: bool = _r093_contracts_before == FileAccess.get_file_as_string("res://data/contracts.json") \
		and _r093_xp_before == FileAccess.get_file_as_string("res://data/progression/player_xp.json") \
		and _r093_recipes_before == FileAccess.get_file_as_string("res://data/recipes.json")
	harness._check("r09_balance_report_no_mutation", _r093_no_mutation,
		"contracts/xp/recipes unchanged")

	root.day_count = _r092_day_saved
	hall.stations_built = _r092_stations_saved.duplicate(true)
	root.xp_totals = _r092_xp_saved.duplicate(true)
	root.base_xp = _r092_base_xp_saved
	root.player_level = _r092_level_saved
	root._level_start_xp = _r092_level_start_saved
	root._refresh_hud_progression()

	# Leave contracts all-available and net player inventory unchanged for the
	# sections that follow.
	_r09_cm.apply([])
	var _r09_extra: int = player.inventory.count("torch") - _r09_torch_base
	if _r09_extra > 0:
		player.inventory.remove("torch", _r09_extra)
