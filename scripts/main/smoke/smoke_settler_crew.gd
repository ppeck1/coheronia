extends Node
## S-07.3 smoke domain module - visible settler crew (R-08 slices 1-3:
## farmhand/repairer/assignment/work-zone + ground drops/hauler).
## Order-preserving extraction from smoke_test.gd _run(): harness owns _check()
## + _r08_clear_ground_drops() + the ledger. hall_cell is a pure derived read of
## the baseline world, recomputed here (it originates in the mining section).


func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this module declares.
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player
	var hall = ctx.hall
	var settlement = ctx.settlement
	var hud = ctx.hud
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	# --- R-08: visible settler crew (slice 1 farmhand + slice 2 repairer/assignment) ---
	# M3-B: earlier sections drove the population authority and one _on_dawn() synced
	# the roster to it, so reset to a clean starting crew before the crew tests below
	# assert the founding roster.
	for _rs in get_tree().get_nodes_in_group("subjects"):
		_rs.remove_from_group("subjects")
		_rs.queue_free()
	hall.population = BlockRegistry.settlement_starting_crew().size()
	root._spawn_starting_crew()
	# (a) the starting crew is the data-driven roster -- includes a farmhand and a
	# repairer (live count filters queue_free'd subjects not yet reaped this frame).
	var _r08_live: Array = []
	for _r08_s in get_tree().get_nodes_in_group("subjects"):
		if not _r08_s.is_queued_for_deletion():
			_r08_live.append(_r08_s)
	var _sub: Node2D = null      # the farmhand
	var _rep: Node2D = null      # the repairer
	for _r08_pick in _r08_live:
		if str(_r08_pick.job) == "farmhand" and _sub == null:
			_sub = _r08_pick
		elif str(_r08_pick.job) == "repairer" and _rep == null:
			_rep = _r08_pick
	# Settlement Coherence (M1): the starting crew is the data-driven roster (4),
	# no longer a hardcoded pair, and still includes a farmhand + a repairer.
	harness._check("r08_crew_spawns_with_jobs",
		_r08_live.size() == BlockRegistry.settlement_starting_crew().size()
		and _r08_live.size() >= 2 and _sub != null and _rep != null,
		"count=%d crew=%d farmhand=%s repairer=%s" % [_r08_live.size(),
			BlockRegistry.settlement_starting_crew().size(),
			str(_sub != null), str(_rep != null)])

	# (b) the farmhand harvests a ripe crop in range and deposits its yield (+3
	# food) into the Town Hall stockpile. (Reverted by the fq09w reload below.)
	var _r08_cell: Vector2i = world.cell_of(_sub.global_position)
	world.cells[_r08_cell] = "crop_ripe"
	world.deltas[_r08_cell] = "crop_ripe"
	_sub.global_position = world.cell_center(_r08_cell)
	var _r08_food0: int = int(hall.stockpile.get("food", 0))
	var _r08_worked: bool = _sub.run_job(0.1)
	var _r08_harvested: bool = world.block_at(_r08_cell) != "crop_ripe"
	var _r08_gain: bool = int(hall.stockpile.get("food", 0)) == _r08_food0 + 3
	harness._check("r08_farmhand_harvests_to_stockpile",
		_r08_worked and _r08_harvested and _r08_gain,
		"worked=%s harvested=%s food %d->%d" % [str(_r08_worked), str(_r08_harvested),
			_r08_food0, int(hall.stockpile.get("food", 0))])

	# (c) POPULATION / ECONOMY CONTRACT: the abstract town_hall.population food
	# model is the SINGLE food-accounting authority; a visible subject never
	# charges food itself, so the same settler is never charged twice. Seed a
	# known stock and run the subject's per-frame accounting many times -- the
	# stock must be untouched. Then prove the abstract model IS the charger:
	# consume_food() (the once-per-dawn population upkeep) is what deducts.
	var _r08_saved_food: int = int(hall.stockpile.get("food", 0))
	hall.stockpile["food"] = 5
	for _r08_i in 30:
		_sub.refresh_hunger()
	var _r08_no_charge: bool = int(hall.stockpile.get("food", 0)) == 5 and not bool(_sub.hungry)
	var _r08_pop_meal: Dictionary = hall.consume_food(3)
	var _r08_pop_charges: bool = int(_r08_pop_meal.get("eaten", 0)) == 3 \
		and int(hall.stockpile.get("food", 0)) == 2
	harness._check("r08_population_is_sole_food_charger",
		_r08_no_charge and _r08_pop_charges,
		"subj_no_charge=%s pop_charges=%s food=%d" % [str(_r08_no_charge),
			str(_r08_pop_charges), int(hall.stockpile.get("food", 0))])

	# (c2) harvest-then-hunger: with a ripe crop in range but the settlement food
	# exhausted (as the abstract dawn upkeep would leave it), the farmhand reads
	# hunger and idles -- it does NOT harvest -- so the crop is left standing.
	# Restocking clears hunger, still without the subject ever spending food.
	hall.stockpile.erase("food")
	var _r08_idle_cell: Vector2i = world.cell_of(_sub.global_position)
	world.cells[_r08_idle_cell] = "crop_ripe"
	world.deltas[_r08_idle_cell] = "crop_ripe"
	_sub.global_position = world.cell_center(_r08_idle_cell)
	_sub.refresh_hunger()
	var _r08_hungry: bool = bool(_sub.hungry)
	var _r08_worked_hungry := false
	if not _sub.hungry:                       # mirrors _physics_process: hungry => idle
		var _r08_wh: bool = _sub.run_job(0.1)
		_r08_worked_hungry = _r08_wh
	var _r08_crop_standing: bool = world.block_at(_r08_idle_cell) == "crop_ripe"
	hall.stockpile["food"] = 4
	_sub.refresh_hunger()
	var _r08_fed: bool = not bool(_sub.hungry) and int(hall.stockpile.get("food", 0)) == 4
	world.cells.erase(_r08_idle_cell)
	world.deltas.erase(_r08_idle_cell)
	hall.stockpile["food"] = _r08_saved_food
	harness._check("r08_farmhand_hungry_idles_when_food_exhausted",
		_r08_hungry and not _r08_worked_hungry and _r08_crop_standing and _r08_fed,
		"hungry=%s worked_while_hungry=%s crop_standing=%s fed_clears=%s" % [
			str(_r08_hungry), str(_r08_worked_hungry), str(_r08_crop_standing), str(_r08_fed)])

	# Slice 3 (feedback): a farmhand also PLANTS — with no crop to reap but seed in its
	# pouch and tilled soil in its area, it sows a fresh seedling; an empty pouch does
	# not. (Harvesting refills the pouch, so it's a self-sustaining replant loop.)
	hall.stockpile["food"] = 5                    # fed, so it isn't idle-hungry
	_sub.job = "farmhand"
	_sub.refresh_hunger()
	var _fp_soil: Vector2i = world.cell_of(_sub.global_position) + Vector2i(3, 3)
	var _fp_air: Vector2i = Vector2i(_fp_soil.x, _fp_soil.y - 1)
	world.cells[_fp_soil] = "farm_soil"; world.deltas[_fp_soil] = "farm_soil"
	world._set_tile(_fp_soil, "farm_soil")
	world.cells.erase(_fp_air); world.deltas[_fp_air] = "air"; world._set_tile(_fp_air, "air")
	_sub.global_position = world.cell_center(_fp_air)
	_sub.set_home(world.cell_center(_fp_air))     # bed within the work radius
	_sub.seed_pouch = 3
	_sub.run_job(0.1)
	var _fp_planted: bool = world.block_at(_fp_air) == "crop_seedling" and _sub.seed_pouch == 2
	world.break_block(_fp_air)                    # clear it and retry with no seed
	world.cells.erase(_fp_air); world.deltas[_fp_air] = "air"; world._set_tile(_fp_air, "air")
	_sub.seed_pouch = 0
	_sub.run_job(0.1)
	var _fp_no_seed: bool = world.block_at(_fp_air) != "crop_seedling"
	world.cells.erase(_fp_soil); world.deltas.erase(_fp_soil); world._set_tile(_fp_soil, "air")
	hall.stockpile["food"] = _r08_saved_food
	harness._check("farmhand_replants", _fp_planted and _fp_no_seed,
		"planted=%s pouch=%d no_seed=%s" % [str(_fp_planted), _sub.seed_pouch, str(_fp_no_seed)])

	# Slice 4 (feedback): a per-settler work zone steers where it works, scopes its
	# job search, and round-trips through save/load. The zone clamps to settlement
	# bounds; a rect fully inside them is returned verbatim.
	var _wz_rect := Rect2i(hall_cell.x - 3, hall_cell.y - 4, 6, 6)
	_sub.set_home(hall.global_position)
	root.assign_work_zone(str(_sub.subject_id), _wz_rect)
	var _wz_bounds: Rect2i = _sub.work_bounds()
	var _wz_in := Vector2i(hall_cell.x, hall_cell.y - 2)         # inside the zone
	var _wz_out := Vector2i(hall_cell.x + 10, hall_cell.y - 2)   # outside zone, inside radius
	for _wzc in [_wz_in, _wz_out]:
		world.cells[_wzc] = "crop_ripe"; world.deltas[_wzc] = "crop_ripe"
		world._set_tile(_wzc, "crop_ripe")
	var _wz_target: Vector2i = world.nearest_ripe_crop_in(_sub.work_bounds(), hall_cell)
	var _wz_scopes: bool = _wz_target == _wz_in                  # picks in-zone, ignores outside
	var _wz_dict: Dictionary = _sub.to_dict()
	_sub.set_work_rect(Rect2i())
	_sub.from_dict(_wz_dict)
	var _wz_saved: bool = _sub.work_rect == _wz_rect
	for _wzc in [_wz_in, _wz_out]:
		world.cells.erase(_wzc); world.deltas.erase(_wzc); world._set_tile(_wzc, "air")
	_sub.set_work_rect(Rect2i())
	harness._check("subject_work_zone",
		_wz_bounds == _wz_rect and _wz_scopes and _wz_saved,
		"bounds=%s scopes=%s saved=%s" % [str(_wz_bounds), str(_wz_scopes), str(_wz_saved)])

	# (r) R-08 slice 2: a repairer settler repairs a damaged hall from the
	# stockpile (the same town_hall.repair authority as the player's button:
	# -25 damage, 2 stone), and idles -- spending nothing -- when the hall is
	# whole. State is saved/restored around the assertion.
	var _r08_dmg_was: float = hall.damage
	var _r08_stone_was: int = int(hall.stockpile.get("stone", 0))
	hall.damage = 50.0
	hall.stockpile["stone"] = 6
	_rep.global_position = hall.global_position       # in repair range of the hall
	var _r08_rep_worked: bool = _rep.run_job(0.1)
	var _r08_rep_fixed: bool = hall.damage < 50.0 and int(hall.stockpile.get("stone", 0)) == 4
	hall.damage = 0.0
	var _r08_rep_idle_ran: bool = _rep.run_job(0.1)
	var _r08_rep_idle: bool = not _r08_rep_idle_ran and int(hall.stockpile.get("stone", 0)) == 4
	hall.damage = _r08_dmg_was
	if _r08_stone_was > 0:
		hall.stockpile["stone"] = _r08_stone_was
	else:
		hall.stockpile.erase("stone")
	harness._check("r08_repairer_repairs_damaged_hall",
		str(_rep.job) == "repairer" and _r08_rep_worked and _r08_rep_fixed and _r08_rep_idle,
		"worked=%s fixed=%s idle_when_whole=%s" % [str(_r08_rep_worked),
			str(_r08_rep_fixed), str(_r08_rep_idle)])

	# (as) R-08 slice 2: job assignment. The Town Hall panel path
	# (_on_subject_job_cycle) advances a settler through SUBJECT_JOBS;
	# assign_subject_job validates and rejects unknown jobs. Mutates in place --
	# (d) below covers that the assigned job persists across a save.
	var _r08_as_id: String = str(_rep.subject_id)
	var _r08_as_before: String = str(_rep.job)
	root._on_subject_job_cycle(_r08_as_id)
	var _r08_as_cycled: bool = str(_rep.job) != _r08_as_before and str(_rep.job) in root.SUBJECT_JOBS
	var _r08_as_valid: bool = root.assign_subject_job(_r08_as_id, "repairer") \
		and str(_rep.job) == "repairer"
	var _r08_as_reject: bool = not root.assign_subject_job(_r08_as_id, "wizard") \
		and str(_rep.job) == "repairer"
	harness._check("r08_job_assignment_cycles_and_validates",
		_r08_as_cycled and _r08_as_valid and _r08_as_reject,
		"cycled=%s valid=%s rejected_unknown=%s" % [str(_r08_as_cycled),
			str(_r08_as_valid), str(_r08_as_reject)])

	# (d) crew persistence: the farmhand's identity/position/hunger AND the
	# repairer's assigned job survive serialize -> apply. (This is the last check
	# that uses the _sub/_rep node refs -- apply_subjects frees and respawns them.)
	_sub.subject_id = "farmhand_test"
	_sub.hungry = true
	_sub.global_position = Vector2(1234.0, -56.0)
	var _r08_ser: Array = root.serialize_subjects()
	root.apply_subjects(_r08_ser)
	var _r08_re_farm: Node2D = null
	var _r08_re_rep: Node2D = null
	for _r08_s2 in get_tree().get_nodes_in_group("subjects"):
		if _r08_s2.is_queued_for_deletion():
			continue
		if str(_r08_s2.subject_id) == "farmhand_test":
			_r08_re_farm = _r08_s2
		if str(_r08_s2.job) == "repairer":
			_r08_re_rep = _r08_s2
	var _r08_persist: bool = _r08_re_farm != null and bool(_r08_re_farm.hungry) \
		and is_equal_approx(_r08_re_farm.global_position.x, 1234.0) and _r08_re_rep != null
	harness._check("r08_crew_persists_across_save",
		_r08_ser.size() == BlockRegistry.settlement_starting_crew().size() and _r08_persist,
		"n=%d farm=%s rep_job=%s" % [_r08_ser.size(),
			str(_r08_re_farm != null), str(_r08_re_rep != null)])

	# (e) save robustness -- repeated application cannot duplicate: applying the
	# same serialized crew twice leaves exactly the crew (the roster count).
	# remove_from_group() retires outgoing settlers before their deferred
	# queue_free, so the second apply cannot see -- or clone -- them.
	var _r08_ser2: Array = root.serialize_subjects()
	root.apply_subjects(_r08_ser2)
	root.apply_subjects(_r08_ser2)
	var _r08_dup_live := 0
	for _r08_s3 in get_tree().get_nodes_in_group("subjects"):
		if not _r08_s3.is_queued_for_deletion():
			_r08_dup_live += 1
	harness._check("r08_repeated_apply_no_duplicate",
		_r08_ser2.size() == BlockRegistry.settlement_starting_crew().size()
		and _r08_dup_live == _r08_ser2.size(),
		"ser=%d live_after_double_apply=%d" % [_r08_ser2.size(), _r08_dup_live])

	# (e2) save robustness -- legacy world state (pre-R-08, no "subjects" key)
	# applies without error and leaves a clean, non-duplicated subjects group
	# (apply_subjects receives [] via state.get("subjects", [])). The fq09w
	# load_game() below restores the live world for the sections that follow.
	var _r08_legacy: Dictionary = root.save_manager.collect_state()
	_r08_legacy.erase("subjects")
	var _r08_legacy_ok: bool = root.save_manager.apply_state(_r08_legacy)
	var _r08_legacy_live := 0
	for _r08_s4 in get_tree().get_nodes_in_group("subjects"):
		if not _r08_s4.is_queued_for_deletion():
			_r08_legacy_live += 1
	harness._check("r08_legacy_state_without_subjects_loads_safely",
		_r08_legacy_ok and _r08_legacy_live == 0,
		"applied=%s live=%d" % [str(_r08_legacy_ok), _r08_legacy_live])

	# --- R-08 slice 3: ground item drops, radius auto-pickup, and the hauler job ---
	var _r08g_home: Vector2 = hall.global_position
	var _r08g_player_pos: Vector2 = player.global_position
	harness._r08_clear_ground_drops()

	# (g1) mining now routes its yield through a ground drop: a block broken within
	# reach but beyond PICKUP_RADIUS leaves its yield on the ground, NOT in the pack.
	# Mine an injected air-pocket block (returns to air, so terrain is left as found).
	var _r08g_reroute_ok := false
	var _r08g_reroute_detail := "no air cell to mine"
	var _r08g_cell: Vector2i = world.cell_of(_r08g_home) + Vector2i(0, -6)
	if world.block_at(_r08g_cell) == "air":
		world.cells[_r08g_cell] = "dirt"
		world.deltas[_r08g_cell] = "dirt"
		var _r08g_center: Vector2 = world.cell_center(_r08g_cell)
		player.global_position = _r08g_center + Vector2(58.0, 0.0)   # in reach (<80), out of pickup (>40)
		var _r08g_dirt0: int = player.inventory.count("dirt")
		player.process_mining(_r08g_cell, 0.0)
		var _r08g_broke: bool = player.process_mining(_r08g_cell, player.mine_required + 0.05)
		var _r08g_on_ground := false
		for _r08g_d in get_tree().get_nodes_in_group("item_drops"):
			if is_instance_valid(_r08g_d) and not _r08g_d.is_queued_for_deletion() \
					and str(_r08g_d.item_id) == "dirt":
				_r08g_on_ground = true
		_r08g_reroute_ok = _r08g_broke \
			and player.inventory.count("dirt") == _r08g_dirt0 and _r08g_on_ground
		_r08g_reroute_detail = "broke=%s dirt %d->%d on_ground=%s" % [str(_r08g_broke),
			_r08g_dirt0, player.inventory.count("dirt"), str(_r08g_on_ground)]
		world.cells.erase(_r08g_cell)
		world.deltas.erase(_r08g_cell)
	harness._check("r08_mining_routes_through_ground_drops", _r08g_reroute_ok, _r08g_reroute_detail)

	# (g2) radius auto-pickup: a drop beyond PICKUP_RADIUS is left alone; once the
	# player stands on it, the whole stack sweeps into the backpack and it is gone.
	harness._r08_clear_ground_drops()
	var _r08p_far: Vector2 = player.global_position + Vector2(300.0, 0.0)
	var _r08p_drop: Node = world.spawn_item_drop(_r08p_far, "wood", 3)
	var _r08p_wood0: int = player.inventory.count("wood")
	var _r08p_no_pick: bool = not player.collect_ground_drops()
	player.global_position = _r08p_far
	var _r08p_got: bool = player.collect_ground_drops()
	var _r08p_ok: bool = _r08p_no_pick and _r08p_got \
		and player.inventory.count("wood") == _r08p_wood0 + 3 \
		and (not is_instance_valid(_r08p_drop) or _r08p_drop.is_queued_for_deletion())
	harness._check("r08_player_radius_autopickup", _r08p_ok,
		"no_pick=%s got=%s wood %d->%d" % [str(_r08p_no_pick), str(_r08p_got),
			_r08p_wood0, player.inventory.count("wood")])

	# (g3) the hauler job: a settler carries a loose ground drop to the stockpile.
	harness._r08_clear_ground_drops()
	var _r08h_pos: Vector2 = _r08g_home + Vector2(24.0, -8.0)
	var _r08h_drop: Node = world.spawn_item_drop(_r08h_pos, "stone", 2)
	var _r08h_sub: Node = root._spawn_subject_at(_r08h_pos, "hauler_test", "hauler")
	var _r08h_stock0: int = int(hall.stockpile.get("stone", 0))
	var _r08h_worked: bool = _r08h_sub.run_job(0.1)
	var _r08h_gain: bool = int(hall.stockpile.get("stone", 0)) == _r08h_stock0 + 2
	var _r08h_gone: bool = not is_instance_valid(_r08h_drop) or _r08h_drop.is_queued_for_deletion()
	harness._check("r08_hauler_carries_ground_drop_to_stockpile",
		str(_r08h_sub.job) == "hauler" and _r08h_worked and _r08h_gain and _r08h_gone,
		"job=%s worked=%s stone %d->%d gone=%s" % [str(_r08h_sub.job), str(_r08h_worked),
			_r08h_stock0, int(hall.stockpile.get("stone", 0)), str(_r08h_gone)])
	_r08h_sub.remove_from_group("subjects")
	_r08h_sub.queue_free()

	# (g4) enemy loot spills onto the ground (not straight into the pack): killed
	# far from the player, its drop stays loose and the backpack is untouched.
	harness._r08_clear_ground_drops()
	var _r08e_threat: Node = root.spawn_enemy_for_test("thornrat")
	var _r08e_inv0: int = player.inventory.total()
	var _r08e_ground := false
	if _r08e_threat != null and is_instance_valid(_r08e_threat):
		_r08e_threat.global_position = player.global_position + Vector2(400.0, 0.0)
		_r08e_threat.drop_chance_override = 1.0
		_r08e_threat.take_hit(99)
		for _r08e_d in get_tree().get_nodes_in_group("item_drops"):
			if is_instance_valid(_r08e_d) and not _r08e_d.is_queued_for_deletion():
				_r08e_ground = true
	var _r08e_no_autocollect: bool = player.inventory.total() == _r08e_inv0
	harness._check("r08_enemy_loot_drops_to_ground", _r08e_ground and _r08e_no_autocollect,
		"ground=%s inv unchanged=%s (total=%d)" % [str(_r08e_ground),
			str(_r08e_no_autocollect), player.inventory.total()])

	# (g5) ground drops persist through the world save, and a repeated apply cannot
	# duplicate them (mirrors the subject/threat serialize discipline).
	harness._r08_clear_ground_drops()
	world.spawn_item_drop(_r08g_home + Vector2(30.0, -10.0), "stone", 4)
	world.spawn_item_drop(_r08g_home + Vector2(-30.0, -10.0), "wood", 1)
	var _r08sv_ser: Array = root.serialize_item_drops()
	root.apply_item_drops(_r08sv_ser)
	var _r08sv_live := 0
	var _r08sv_stone_ok := false
	for _r08sv_d in get_tree().get_nodes_in_group("item_drops"):
		if _r08sv_d.is_queued_for_deletion():
			continue
		_r08sv_live += 1
		if str(_r08sv_d.item_id) == "stone" and int(_r08sv_d.count) == 4:
			_r08sv_stone_ok = true
	root.apply_item_drops(_r08sv_ser)
	var _r08sv_after := 0
	for _r08sv_d2 in get_tree().get_nodes_in_group("item_drops"):
		if not _r08sv_d2.is_queued_for_deletion():
			_r08sv_after += 1
	harness._check("r08_ground_drops_persist_across_save",
		_r08sv_ser.size() == 2 and _r08sv_live == 2 and _r08sv_stone_ok and _r08sv_after == 2,
		"ser=%d live=%d stone_ok=%s after_double=%d" % [_r08sv_ser.size(), _r08sv_live,
			str(_r08sv_stone_ok), _r08sv_after])

	# (g6) routine ground pickups update the inventory (reflected in the hotbar/inventory
	# UI) but do NOT raise a screen-space toast: no pickup PanelContainer exists and no
	# "+N <Item>" text appears in the contextual stack. Other contextual entries still work,
	# and repeated / multi-item pickups stay toast-free.
	harness._r08_clear_ground_drops()
	var _r08n_stone0: int = player.inventory.count("stone")
	var _r08n_wood0: int = player.inventory.count("wood")
	world.spawn_item_drop(player.global_position, "stone", 5)   # multi-item pickup
	world.spawn_item_drop(player.global_position, "wood", 3)
	var _r08n_collected: bool = player.collect_ground_drops()
	var _r08n_qty: bool = player.inventory.count("stone") == _r08n_stone0 + 5 \
		and player.inventory.count("wood") == _r08n_wood0 + 3
	# UI reflects the new quantities: the inventory grid reads live counts on refresh.
	var _r08n_was_open: bool = hud.inventory_panel_open()
	if not _r08n_was_open:
		hud.toggle_inventory_panel()
	hud.update_inventory()
	var _r08n_ui: bool = int(hud._inv_grid_counts.get("stone", -1)) == player.inventory.count("stone") \
		and int(hud._inv_grid_counts.get("wood", -1)) == player.inventory.count("wood")
	if not _r08n_was_open:
		hud.toggle_inventory_panel()
	# The contextual stack holds exactly the three intended entries (item/save/interact) by
	# identity, and none carries a "+N <Item>" pickup line.
	var _r08n_entries: bool = hud._context_stack.get_child_count() == 3 \
		and hud._context_stack.get_child(0) == hud._ctx_item_panel \
		and hud._context_stack.get_child(1) == hud._ctx_save_panel \
		and hud._context_stack.get_child(2) == hud._ctx_interact_panel
	var _r08n_stone_name := BlockRegistry.display_name("stone")
	var _r08n_no_toast := true
	for _r08n_child in hud._context_stack.get_children():
		var _r08n_lbl := (_r08n_child as PanelContainer).get_child(0) as Label
		if _r08n_lbl != null and "+" in _r08n_lbl.text and _r08n_stone_name in _r08n_lbl.text:
			_r08n_no_toast = false
	# Other contextual entries still function (save confirmation shows on demand).
	hud.notify_saved()
	var _r08n_other: bool = hud._ctx_save_panel.visible
	# Repeated pickup is likewise toast-free.
	world.spawn_item_drop(player.global_position, "stone", 2)
	player.collect_ground_drops()
	var _r08n_repeat := true
	for _r08n_c2 in hud._context_stack.get_children():
		var _r08n_l2 := (_r08n_c2 as PanelContainer).get_child(0) as Label
		if _r08n_l2 != null and "+" in _r08n_l2.text and _r08n_stone_name in _r08n_l2.text:
			_r08n_repeat = false
	harness._check("r08_pickup_updates_inventory_no_toast",
		_r08n_collected and _r08n_qty and _r08n_ui and _r08n_entries and _r08n_no_toast \
		and _r08n_other and _r08n_repeat,
		"collected=%s qty=%s ui=%s entries=%s no_toast=%s other=%s repeat=%s" % [
			str(_r08n_collected), str(_r08n_qty), str(_r08n_ui), str(_r08n_entries),
			str(_r08n_no_toast), str(_r08n_other), str(_r08n_repeat)])

	harness._r08_clear_ground_drops()
	player.global_position = _r08g_player_pos
