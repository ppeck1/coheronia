extends Node
## S-07.3 smoke domain module - settlement citizens (Settlement Coherence
## M1-M5: bounded persistent citizens, ancestry identity, roster<->population,
## defender, raider_sapper, lava_slime, sun/moon, stockpile withdraw, doors,
## housing). Order-preserving extraction from smoke_test.gd _run(): harness owns
## _check() + the ledger. _m1_live and the other _m*/_mN_* locals are internal
## to this cluster; hall_cell is recomputed (pure derived read of the baseline).
const CelestialScript := preload("res://scripts/world/celestial.gd")
const HousingScript := preload("res://scripts/settlement/housing.gd")


## _fq01_msg_conn is the player_event signal handle connected back in the FQ-01
## section; this cluster's state-restore tail disconnects it, so it is threaded
## in (a Callable can't be recomputed).
func run(harness, root, world, player, hall, settlement, hud, _fq01_msg_conn) -> void:
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	# --- Settlement Coherence (M1): bounded, persistent citizens; roster ==
	# starting population. -----------------------------------------------------
	for _m1_s in get_tree().get_nodes_in_group("subjects"):
		_m1_s.remove_from_group("subjects")
		_m1_s.queue_free()
	root._spawn_starting_crew()
	var _m1_live: Array = []
	for _m1_s2 in get_tree().get_nodes_in_group("subjects"):
		if not _m1_s2.is_queued_for_deletion():
			_m1_live.append(_m1_s2)
	var _m1_crew: int = BlockRegistry.settlement_starting_crew().size()
	# (m1a) the visible roster matches the starting population authority.
	harness._check("m1_roster_matches_population",
		_m1_live.size() == _m1_crew and hall.population == _m1_crew and _m1_crew == 4,
		"live=%d pop=%d crew=%d" % [_m1_live.size(), hall.population, _m1_crew])

	# (m1b) hard settlement bounds: a position outside the rectangle clamps to the
	# edge; a position inside is untouched (pure clamp, no physics needed).
	var _m1_c: Node = _m1_live[0]
	var _m1_b: Dictionary = _m1_c.settlement_bounds_px()
	var _m1_clamped: Vector2 = _m1_c.clamp_to_settlement(
		Vector2(float(_m1_b["min_x"]) - 1000.0, float(_m1_b["min_y"]) + 8.0))
	var _m1_inside_pos := Vector2(
		(float(_m1_b["min_x"]) + float(_m1_b["max_x"])) * 0.5,
		(float(_m1_b["min_y"]) + float(_m1_b["max_y"])) * 0.5)
	var _m1_inside: Vector2 = _m1_c.clamp_to_settlement(_m1_inside_pos)
	harness._check("m1_hard_movement_bounds",
		absf(_m1_clamped.x - float(_m1_b["min_x"])) < 0.001 and _m1_inside == _m1_inside_pos,
		"clamped_x=%.1f min_x=%.1f inside_kept=%s" % [
			_m1_clamped.x, float(_m1_b["min_x"]), str(_m1_inside == _m1_inside_pos)])

	# (m1c) the citizen's home/guard post persists through a to_dict -> from_dict
	# round-trip (save/load).
	_m1_c.set_home(Vector2(1234.0, 567.0))
	var _m1_dict: Dictionary = _m1_c.to_dict()
	var _m1_c2: Node = _m1_live[1]
	_m1_c2.from_dict(_m1_dict)
	harness._check("m1_home_persists",
		absf(float(_m1_dict.get("home_x", 0.0)) - 1234.0) < 0.001
		and absf(float(_m1_c2.to_dict().get("home_x", 0.0)) - 1234.0) < 0.001,
		"saved=%s restored=%s" % [
			str(_m1_dict.get("home_x")), str(_m1_c2.to_dict().get("home_x"))])

	# (m1d) stuck recovery: a citizen that intends to move but makes no horizontal
	# progress accumulates stuck time and recovers past the threshold.
	_m1_c.velocity.x = 40.0
	_m1_c._last_x = _m1_c.global_position.x
	var _m1_fired := false
	for _m1_i in 3:
		if _m1_c.update_stuck(1.0):
			_m1_fired = true
	harness._check("m1_stuck_recovery", _m1_fired, "fired=%s" % str(_m1_fired))

	# --- Settlement Coherence (M3-A): per-citizen ancestry identity ---
	# deterministic: the same key always yields the same identity (stable faces).
	var _id_a: Dictionary = root._generate_citizen_identity(12345)
	var _id_b: Dictionary = root._generate_citizen_identity(12345)
	harness._check("m3_identity_deterministic",
		str(_id_a["species"]) == str(_id_b["species"])
		and str(_id_a["body_variant"]) == str(_id_b["body_variant"]),
		"a=%s b=%s" % [str(_id_a), str(_id_b)])
	# every generated species is a LIVE (art-backed) player species.
	var _id_live: Array = BlockRegistry.player_visuals.get("live_species", [])
	var _id_live_ok := true
	for _id_i in 20:
		if str(root._generate_citizen_identity(_id_i)["species"]) not in _id_live:
			_id_live_ok = false
	harness._check("m3_identity_species_live", _id_live_ok and not _id_live.is_empty())
	# identity persists through to_dict -> from_dict (never regenerated on load).
	var _idc: Node = _m1_live[0]
	_idc.set_identity("dwarf", "feminine", 0)
	var _idd: Dictionary = _idc.to_dict()
	var _idc2: Node = _m1_live[1]
	_idc2.from_dict(_idd)
	harness._check("m3_identity_persists",
		str(_idd.get("species")) == "dwarf" and str(_idd.get("body_variant")) == "feminine"
		and str(_idc2.to_dict().get("species")) == "dwarf",
		"saved=%s restored=%s" % [str(_idd.get("species")), str(_idc2.to_dict().get("species"))])
	# the ancestry sprite resolves from the live imagery (player-pipeline reuse).
	harness._check("m3_identity_sprite_resolves",
		BlockRegistry.visual_texture("players",
			BlockRegistry.player_body_id("dwarf", "feminine")) != null)

	# --- Citizen profile: ancestry-aligned name, days alive, stats, info panel ---
	# deterministic name/stats for a given seed+ancestry.
	var _cp_a: Dictionary = root._generate_citizen_profile(7777, "dwarf", "masculine")
	var _cp_b: Dictionary = root._generate_citizen_profile(7777, "dwarf", "masculine")
	harness._check("cp_profile_deterministic", str(_cp_a["name"]) == str(_cp_b["name"]))
	# the name is aligned with the ancestry: the given (first) name is in that
	# species' pool for the body variant.
	var _cp_pool: Dictionary = BlockRegistry.citizen_name_pool("dwarf")
	var _cp_given: String = str(_cp_a["name"]).split(" ")[0]
	harness._check("cp_name_ancestry_aligned", _cp_given in _cp_pool.get("masculine", []),
		"given=%s name=%s" % [_cp_given, str(_cp_a["name"])])
	# stats: every declared stat present and within 1..10.
	var _cp_stats: Dictionary = _cp_a["stats"]
	var _cp_stat_ids: Array = BlockRegistry.citizen_stat_ids()
	var _cp_range_ok := _cp_stats.size() == _cp_stat_ids.size()
	for _cp_sid in _cp_stat_ids:
		var _cp_v: int = int(_cp_stats.get(str(_cp_sid), 0))
		if _cp_v < 1 or _cp_v > 10:
			_cp_range_ok = false
	harness._check("cp_stats_in_range", _cp_range_ok, "stats=%s" % str(_cp_stats))
	# days-alive and profile persistence through save/load.
	var _cp_c: Node = _m1_live[0]
	_cp_c.set_profile("Test Dwarf", 2, {"vigor": 5})
	harness._check("cp_days_alive", _cp_c.days_alive(6) == 4, "days=%d" % _cp_c.days_alive(6))
	var _cp_dict: Dictionary = _cp_c.to_dict()
	var _cp_c2: Node = _m1_live[1]
	_cp_c2.from_dict(_cp_dict)
	harness._check("cp_profile_persists",
		str(_cp_c2.citizen_name) == "Test Dwarf" and int(_cp_c2.birth_day) == 2
		and int(_cp_c2.stats.get("vigor", 0)) == 5,
		"name=%s born=%d vigor=%d" % [str(_cp_c2.citizen_name), int(_cp_c2.birth_day),
			int(_cp_c2.stats.get("vigor", 0))])
	# the info panel opens for a settler and closes cleanly.
	hud.open_npc_panel(_cp_c)
	var _cp_open: bool = hud.npc_panel_open()
	hud.close_npc_panel()
	harness._check("cp_info_panel_opens", _cp_open and not hud.npc_panel_open())

	# stats drive effectiveness: higher Guard hits harder, higher Vigor moves faster.
	_cp_c.set_profile("Strong", 2, {"guard": 10, "vigor": 10}, "")
	var _cp_hi_dmg: int = _cp_c.defend_damage()
	var _cp_hi_spd: float = _cp_c.effective_move_speed()
	_cp_c.set_profile("Weak", 2, {"guard": 1, "vigor": 1}, "")
	harness._check("cp_stats_affect_behavior",
		_cp_hi_dmg > _cp_c.defend_damage() and _cp_hi_spd > _cp_c.effective_move_speed(),
		"dmg %d>%d spd %.1f>%.1f" % [_cp_hi_dmg, _cp_c.defend_damage(),
			_cp_hi_spd, _cp_c.effective_move_speed()])

	# citizen report: needs (food met/unmet), a work-inhibiting issue when hungry,
	# contentment that drops when a need fails, and a want tied to a need.
	root.assign_subject_job(str(_cp_c.subject_id), "farmhand")   # non-defender: hunger stops work
	_cp_c.set_profile("Hopeful", 2, {"spirit": 5}, "larder")     # wants a full larder (food)
	hall.stockpile["food"] = 8
	var _cp_rep_fed: Dictionary = root.citizen_report(_cp_c)
	hall.stockpile.erase("food")
	var _cp_rep_hungry: Dictionary = root.citizen_report(_cp_c)
	harness._check("cp_report_needs_issue_want",
		bool(_cp_rep_fed["needs"]["food"]) and not bool(_cp_rep_hungry["needs"]["food"])
		and str(_cp_rep_fed["issue"]) == "" and str(_cp_rep_hungry["issue"]) != ""
		and int(_cp_rep_fed["coherence"]) > int(_cp_rep_hungry["coherence"])
		and bool(_cp_rep_fed["want"]["met"]) and not bool(_cp_rep_hungry["want"]["met"]),
		"fed_coh=%d hungry_coh=%d hungry_issue=%s" % [int(_cp_rep_fed["coherence"]),
			int(_cp_rep_hungry["coherence"]), str(_cp_rep_hungry["issue"] != "")])

	# Slice 2 (feedback): each need carries a label + a plain-language reason (the
	# hover qualifier), the reason changes with met/unmet, and a vague want ("strong
	# walls") is defined via its need so the panel is self-explanatory.
	_cp_c.set_profile("Curious", 2, {"spirit": 5}, "walls")     # wants strong walls (safety)
	var _cp_walls: Dictionary = root.citizen_report(_cp_c)
	var _cp_food_d: Dictionary = _cp_walls.get("need_details", {}).get("food", {})
	hall.stockpile["food"] = 8
	var _cp_food_ok_d: Dictionary = root.citizen_report(_cp_c).get("need_details", {}).get("food", {})
	hall.stockpile.erase("food")
	var _cp_want: Dictionary = _cp_walls.get("want", {})
	harness._check("cp_report_needs_reasons",
		str(_cp_food_d.get("label", "")) == "Food"
		and str(_cp_food_d.get("reason", "")) != ""
		and str(_cp_food_d.get("reason", "")) != str(_cp_food_ok_d.get("reason", ""))
		and str(_cp_want.get("text", "")) == "strong walls"
		and str(_cp_want.get("need", "")) == "safety"
		and str(_cp_want.get("definition", "")) != "",
		"unmet_reason=%s want=%s def=%s" % [str(_cp_food_d.get("reason", "")),
			str(_cp_want.get("text", "")), str(_cp_want.get("definition", ""))])

	# --- Settlement Coherence (M3-B): dynamic roster <-> population authority ---
	# grow the population authority; the sync spawns newcomers to match, each born
	# with a live-species identity.
	hall.population = 6
	root.sync_roster_to_population()
	var _rc_grow := 0
	var _rc_species := {}
	for _rc_s in get_tree().get_nodes_in_group("subjects"):
		if not _rc_s.is_queued_for_deletion():
			_rc_grow += 1
			_rc_species[str(_rc_s.subject_id)] = str(_rc_s.species)
	harness._check("m3b_roster_grows_to_population",
		_rc_grow == 6 and _rc_grow == hall.population,
		"roster=%d pop=%d" % [_rc_grow, hall.population])
	var _rc_live: Array = BlockRegistry.player_visuals.get("live_species", [])
	var _rc_born_ok := not _rc_species.is_empty()
	for _rc_k in _rc_species:
		if str(_rc_species[_rc_k]) not in _rc_live:
			_rc_born_ok = false
	harness._check("m3b_newcomers_born_with_identity", _rc_born_ok)
	# starve the authority; the sync removes settlers (newest first) down to target.
	hall.population = 3
	root.sync_roster_to_population()
	var _rc_shrink := 0
	for _rc_s2 in get_tree().get_nodes_in_group("subjects"):
		if not _rc_s2.is_queued_for_deletion():
			_rc_shrink += 1
	harness._check("m3b_roster_shrinks_to_population",
		_rc_shrink == 3 and _rc_shrink == hall.population,
		"roster=%d pop=%d" % [_rc_shrink, hall.population])

	# --- Settlement Coherence (M3-C): defender role ---
	for _dt in get_tree().get_nodes_in_group("threats"):   # clean slate for the guard-zone checks
		_dt.remove_from_group("threats")
		_dt.queue_free()
	var _df_home: Vector2 = world.cell_center(Vector2i(hall_cell.x + 2, hall_cell.y))
	var _df: Node = root._spawn_subject_at(_df_home, "defender_test", "defender")
	_df.set_home(_df_home)
	var _df_threat = root.spawn_enemy_for_test("surface_slime")
	_df_threat.global_position = _df_home + Vector2(10.0, 0.0)   # in attack range + guard zone
	var _df_hp0: int = int(_df_threat.hp)
	# a defender engages a threat in its guard zone and damages/kills it (delta 1.0
	# clears the attack cooldown each tick).
	var _df_engaged := false
	for _df_i in 12:
		_df.run_job(1.0)
		if not is_instance_valid(_df_threat) or _df_threat.is_queued_for_deletion() \
				or int(_df_threat.hp) < _df_hp0:
			_df_engaged = true
			break
	harness._check("m3c_defender_attacks_threat_in_guard_zone", _df_engaged,
		"engaged=%s hp0=%d" % [str(_df_engaged), _df_hp0])
	if is_instance_valid(_df_threat):
		_df_threat.remove_from_group("threats")
		_df_threat.queue_free()
	# a defender ignores a threat OUTSIDE its guard radius (it returns to its post).
	var _df_far = root.spawn_enemy_for_test("surface_slime")
	_df_far.global_position = _df_home + Vector2(400.0, 0.0)
	harness._check("m3c_defender_ignores_out_of_zone_threat", not _df.run_job(1.0))
	_df.remove_from_group("subjects")
	_df.queue_free()
	if is_instance_valid(_df_far):
		_df_far.remove_from_group("threats")
		_df_far.queue_free()

	# --- Settlement Coherence (M4-A): raider_sapper breaches walls ---
	var _sp = root.spawn_enemy_for_test("raider_sapper")
	harness._check("m4_sapper_is_live",
		_sp != null and str(_sp.enemy_id) == "raider_sapper" and bool(_sp.breaks_walls),
		"id=%s breaks=%s" % [str(_sp.enemy_id) if _sp != null else "null",
			str(_sp.breaks_walls) if _sp != null else "n/a"])
	if _sp != null:
		# a structural wall between the sapper and the hall gets broken; a protected
		# block (hall core / bedrock) never does.
		var _sp_center: Vector2i = world.hall_info["center_cell"]
		var _sp_cell := Vector2i(_sp_center.x + 6, _sp_center.y)
		var _sp_wall := _sp_cell + Vector2i(-1, 0)   # one cell toward the hall
		world.break_block(_sp_wall)
		world.place_block(_sp_wall, "stone")
		_sp.global_position = world.cell_center(_sp_cell)
		var _sp_broke := false
		for _sp_i in 3:
			_sp._try_sap_wall(1.0)
			if world.block_at(_sp_wall) == "air":
				_sp_broke = true
				break
		harness._check("m4_sapper_breaks_structural_wall", _sp_broke,
			"wall_now=%s" % world.block_at(_sp_wall))
		harness._check("m4_sapper_spares_protected",
			not _sp._is_sappable("town_hall_core") and not _sp._is_sappable("bedrock")
			and _sp._is_sappable("stone") and _sp._is_sappable("door"))
		_sp.remove_from_group("threats")
		_sp.queue_free()

	# --- Settlement Coherence (M4-B): lava_slime (capped bubbles + lava immunity) ---
	var _ls = root.spawn_enemy_for_test("lava_slime")
	harness._check("m4_lava_slime_is_live",
		_ls != null and str(_ls.enemy_id) == "lava_slime"
		and bool(_ls.emits_bubbles) and bool(_ls.lava_immune),
		"id=%s bubbles=%s immune=%s" % [str(_ls.enemy_id) if _ls != null else "null",
			str(_ls.emits_bubbles) if _ls != null else "n/a",
			str(_ls.lava_immune) if _ls != null else "n/a"])
	if _ls != null:
		# the molten-bubble field is HARD-CAPPED — a long run never exceeds the cap
		# (a per-entity budget of array dicts, never runaway scene nodes).
		for _ls_i in 300:
			_ls._tick_bubbles(0.1)
		harness._check("m4_lava_slime_bubbles_capped",
			_ls._bubbles.size() <= _ls.MAX_SLIME_BUBBLES,
			"bubbles=%d cap=%d" % [_ls._bubbles.size(), _ls.MAX_SLIME_BUBBLES])
		# lava immunity: standing in a lava cell deals no environmental hazard damage.
		var _ls_cell := Vector2i(hall_cell.x + 25, hall_cell.y + 6)
		world.break_block(_ls_cell)
		world.cells[_ls_cell] = "lava"
		world._set_tile(_ls_cell, "lava")
		_ls.global_position = world.cell_center(_ls_cell)
		var _ls_hp0: int = int(_ls.hp)
		for _ls_j in 20:
			_ls.apply_environmental_hazard(1.0)
		harness._check("m4_lava_slime_immune_to_lava", int(_ls.hp) == _ls_hp0,
			"hp %d->%d" % [_ls_hp0, int(_ls.hp)])
		world.cells.erase(_ls_cell)
		world.deltas[_ls_cell] = "air"
		world._set_tile(_ls_cell, "air")
		_ls.remove_from_group("threats")
		_ls.queue_free()

	# --- Settlement Coherence (M5-A): sun/moon celestial renderer (presentation) ---
	harness._check("m5_celestial_node_present", root._celestial != null)
	var _cv := Rect2(0.0, 0.0, 1280.0, 720.0)
	var _sky_dawn: Dictionary = CelestialScript.positions(0.02, _cv)
	var _sky_noon: Dictionary = CelestialScript.positions(0.325, _cv)   # mid-day (0.65/2)
	var _sky_dusk: Dictionary = CelestialScript.positions(0.63, _cv)
	var _sky_night: Dictionary = CelestialScript.positions(0.82, _cv)
	# the sun rises left, peaks (highest = smallest y) at mid-day, and sets right.
	harness._check("m5_sun_arcs_across_day",
		bool(_sky_dawn["sun_visible"]) and not bool(_sky_dawn["moon_visible"])
		and float(_sky_noon["sun"].y) < float(_sky_dawn["sun"].y)
		and float(_sky_noon["sun"].y) < float(_sky_dusk["sun"].y)
		and float(_sky_dawn["sun"].x) < float(_sky_noon["sun"].x)
		and float(_sky_noon["sun"].x) < float(_sky_dusk["sun"].x),
		"dawn_y=%.0f noon_y=%.0f dusk_y=%.0f" % [
			float(_sky_dawn["sun"].y), float(_sky_noon["sun"].y), float(_sky_dusk["sun"].y)])
	# night belongs to the moon; the sun is down.
	harness._check("m5_moon_rules_the_night",
		bool(_sky_night["moon_visible"]) and not bool(_sky_night["sun_visible"]),
		"is_night=%s" % str(_sky_night["is_night"]))
	# continuous lunar cycle: new (dark) at phase 0.0, full at 0.5, half at 0.25.
	harness._check("m5_moon_phase_cycle",
		CelestialScript.illumination_f(0.5) > 0.98
		and CelestialScript.illumination_f(0.0) < 0.02
		and absf(CelestialScript.illumination_f(0.25) - 0.5) < 0.02,
		"full=%.2f new=%.2f quarter=%.2f" % [CelestialScript.illumination_f(0.5),
			CelestialScript.illumination_f(0.0), CelestialScript.illumination_f(0.25)])
	# a true ~29-day synodic cycle: exactly one full-moon day, illumination peaks near 1.
	var _cyc_full_days: int = 0
	var _cyc_peak: float = 0.0
	var _cyc_names := {}
	for _cyc_d in range(root._celestial.SYNODIC_DAYS):
		root._celestial.set_phase_from_day(_cyc_d)
		if root._celestial.is_full_moon():
			_cyc_full_days += 1
		_cyc_peak = maxf(_cyc_peak,
			CelestialScript.illumination_f(float(_cyc_d) / float(root._celestial.SYNODIC_DAYS)))
		_cyc_names[root._celestial.phase_name()] = true
	root._celestial.set_phase_from_day(root.day_count)   # restore
	harness._check("m5_lunar_cycle_true",
		_cyc_full_days == 1 and _cyc_peak > 0.98 and _cyc_names.size() >= 6,
		"full_days=%d peak=%.2f distinct_names=%d" % [_cyc_full_days, _cyc_peak, _cyc_names.size()])
	# the full-moon gameplay hook tracks the day-driven phase.
	root._celestial.set_phase_from_day(root._celestial.FULL_MOON_DAY)
	var _fm_full: bool = root._celestial.is_full_moon()
	root._celestial.set_phase_from_day(0)   # new moon
	var _fm_new: bool = not root._celestial.is_full_moon()
	root._celestial.set_phase_from_day(root.day_count)   # restore
	harness._check("m5_full_moon_hook", _fm_full and _fm_new)

	# --- Settlement Coherence (M2-A): stockpile withdrawal (Town Hall authority) ---
	hall.stockpile = {"wood": 5, "stone": 4}
	player.inventory.from_dict({})
	# withdraw a chosen amount: exactly that many move, stockpile is decremented.
	var _w_take: int = hall.withdraw("wood", 2, player)
	harness._check("m2_withdraw_amount",
		_w_take == 2 and int(hall.stockpile.get("wood", 0)) == 3
		and player.inventory.count("wood") == 2,
		"took=%d stock=%d inv=%d" % [_w_take, int(hall.stockpile.get("wood", 0)),
			player.inventory.count("wood")])
	# a request larger than the stock takes only the remainder (atomic, clamped).
	var _w_over: int = hall.withdraw("wood", 99, player)
	harness._check("m2_withdraw_clamps_to_stock",
		_w_over == 3 and not hall.stockpile.has("wood") and player.inventory.count("wood") == 5,
		"took=%d has_wood=%s inv=%d" % [_w_over, str(hall.stockpile.has("wood")),
			player.inventory.count("wood")])
	# withdrawing an absent item is a safe no-op.
	harness._check("m2_withdraw_empty_is_noop", hall.withdraw("gold", 1, player) == 0)
	# withdraw-all empties the whole stockpile into the backpack.
	var _w_all: Dictionary = hall.withdraw_all(player)
	harness._check("m2_withdraw_all_empties_stockpile",
		int(_w_all.get("stone", 0)) == 4 and hall.stockpile.is_empty()
		and player.inventory.count("stone") == 4,
		"moved=%s empty=%s inv=%d" % [str(_w_all), str(hall.stockpile.is_empty()),
			player.inventory.count("stone")])

	# Slice 5: the stockpile is a two-way drag-and-drop grid — dropping a backpack
	# item onto it deposits, dragging a tile into the pack withdraws, and only
	# stockpile-eligible items deposit. town_hall stays the sole authority.
	var _s5_inv0: Dictionary = player.inventory.to_dict()
	var _s5_stock0: Dictionary = hall.stockpile.duplicate()
	hall.stockpile = {"wood": 5}
	player.inventory.from_dict({"stone": 4})
	player.inventory_changed.emit()
	# deposit: drag backpack "stone" onto the stockpile.
	hud.drop_inventory_slot("stockpile", -1, {"source": "inventory_board",
		"kind": "backpack", "item_id": "stone", "index": 0, "slot_id": ""}, "")
	var _s5_deposit_ok: bool = int(hall.stockpile.get("stone", 0)) == 4 \
		and player.inventory.count("stone") == 0
	# withdraw: drag stockpile "wood" into the backpack.
	hud.drop_inventory_slot("backpack", 0, {"source": "inventory_board",
		"kind": "stockpile", "item_id": "wood", "index": -1, "slot_id": "wood"}, "")
	var _s5_withdraw_ok: bool = not hall.stockpile.has("wood") \
		and player.inventory.count("wood") == 5
	# a UI-only surrogate (not stockpile-eligible) cannot be deposited.
	var _s5_reject: bool = not hud.can_drop_inventory_slot("stockpile", -1,
		{"source": "inventory_board", "kind": "backpack", "item_id": "armor",
		"index": 0, "slot_id": ""}, "")
	# a deposited stack can be dragged back (round-trips through the authority).
	var _s5_roundtrip: bool = hud.can_drop_inventory_slot("backpack", 0,
		{"source": "inventory_board", "kind": "stockpile", "item_id": "stone",
		"index": -1, "slot_id": "stone"}, "")
	hall.stockpile = _s5_stock0
	player.inventory.from_dict(_s5_inv0)
	player.inventory_changed.emit()
	harness._check("stockpile_drag_grid",
		_s5_deposit_ok and _s5_withdraw_ok and _s5_reject and _s5_roundtrip,
		"deposit=%s withdraw=%s reject=%s roundtrip=%s" % [str(_s5_deposit_ok),
			str(_s5_withdraw_ok), str(_s5_reject), str(_s5_roundtrip)])

	# --- Settlement Coherence (M2-B): doors — obtainable, placeable-solid, toggle ---
	player.inventory.from_dict({"wood": 4})
	var _dr_crafted: bool = player.craft("craft_door")
	harness._check("m2b_craft_door", _dr_crafted and player.inventory.count("door") >= 1,
		"crafted=%s door=%d" % [str(_dr_crafted), player.inventory.count("door")])
	var _dr_cell := Vector2i(hall_cell.x + 18,
		int(world.surface.get(hall_cell.x + 18, hall_cell.y)) - 3)
	world.break_block(_dr_cell)
	var _dr_placed: bool = world.place_block(_dr_cell, "door")
	harness._check("m2b_door_places_solid",
		_dr_placed and world.block_at(_dr_cell) == "door" and world.is_solid_at(_dr_cell)
		and BlockRegistry.blocks_light("door"),
		"placed=%s block=%s solid=%s" % [str(_dr_placed), world.block_at(_dr_cell),
			str(world.is_solid_at(_dr_cell))])
	# opening it makes it passable, lets light through, and saves as a delta.
	var _dr_open: bool = world.toggle_door(_dr_cell)
	harness._check("m2b_door_opens_passable",
		_dr_open and world.block_at(_dr_cell) == "door_open"
		and not world.is_solid_at(_dr_cell) and not BlockRegistry.blocks_light("door_open")
		and str(world.deltas.get(_dr_cell, "")) == "door_open",
		"open=%s block=%s solid=%s delta=%s" % [str(_dr_open), world.block_at(_dr_cell),
			str(world.is_solid_at(_dr_cell)), str(world.deltas.get(_dr_cell, ""))])
	# closing it restores a solid door; toggling a non-door is a safe no-op.
	world.toggle_door(_dr_cell)
	harness._check("m2b_door_closes_and_noop",
		world.block_at(_dr_cell) == "door" and world.is_solid_at(_dr_cell)
		and not world.toggle_door(Vector2i(hall_cell.x, hall_cell.y - 20)),
		"block=%s" % world.block_at(_dr_cell))
	world.break_block(_dr_cell)

	# Slice 6: a door is a DOOR_HEIGHT-tall, 1-wide unit so a full-height character
	# fits through the opening. Place via the player, open the whole run, then mine
	# it as one unit.
	var _td_x: int = hall_cell.x + 20
	var _td_by: int = int(world.surface.get(_td_x, hall_cell.y)) - 1   # base cell (on grade)
	for _td_i in range(world.DOOR_HEIGHT + 1):
		world.break_block(Vector2i(_td_x, _td_by - _td_i))            # clear the column
	player.global_position = world.cell_center(Vector2i(_td_x - 2, _td_by - 1))
	player.inventory.from_dict({"door": 1})
	player.inventory_changed.emit()
	var _td_placed: bool = player.try_place(Vector2i(_td_x, _td_by), "door")
	var _td_solid := true
	for _td_i in range(world.DOOR_HEIGHT):
		var _tc := Vector2i(_td_x, _td_by - _td_i)
		if world.block_at(_tc) != "door" or not world.is_solid_at(_tc):
			_td_solid = false
	var _td_consumed: bool = player.inventory.count("door") == 0
	# open: the whole run becomes passable (a DOOR_HEIGHT-tall walk-through opening).
	world.toggle_door(Vector2i(_td_x, _td_by))
	var _td_open := true
	for _td_i in range(world.DOOR_HEIGHT):
		var _to := Vector2i(_td_x, _td_by - _td_i)
		if world.block_at(_to) != "door_open" or world.is_solid_at(_to):
			_td_open = false
	# mine one cell → the whole door is removed and exactly one door returns.
	var _td_drops: Dictionary = world.break_block(Vector2i(_td_x, _td_by - 1))
	var _td_gone := true
	for _td_i in range(world.DOOR_HEIGHT):
		if world.block_at(Vector2i(_td_x, _td_by - _td_i)) != "air":
			_td_gone = false
	harness._check("m6_tall_door_place_toggle_mine",
		_td_placed and _td_solid and _td_consumed and _td_open and _td_gone
		and int(_td_drops.get("door", 0)) == 1 and world.DOOR_HEIGHT >= 2,
		"placed=%s solid=%s consumed=%s open=%s gone=%s drop=%s H=%d" % [str(_td_placed),
			str(_td_solid), str(_td_consumed), str(_td_open), str(_td_gone),
			str(_td_drops), world.DOOR_HEIGHT])

	# Slice C: block gravity — a free-standing tree collapses (its blocks fall as ground
	# drops) when its footing is cut; the grounded part stays; cohesive stone never falls.
	var _gv_x: int = hall_cell.x - 24
	var _gv_gy: int = int(world.surface.get(_gv_x, hall_cell.y))   # ground row for this column
	for _gv_i in range(7):
		world.break_block(Vector2i(_gv_x, _gv_gy - 1 - _gv_i))     # clear a column above ground
	# an explicit solid floor so the base's footing is deterministic (not terrain-dependent).
	world.cells[Vector2i(_gv_x, _gv_gy)] = "stone"
	world.deltas[Vector2i(_gv_x, _gv_gy)] = "stone"
	world._set_tile(Vector2i(_gv_x, _gv_gy), "stone")
	for _gv_i in range(4):                                          # 4-tall trunk on the floor
		var _tc := Vector2i(_gv_x, _gv_gy - 1 - _gv_i)
		world.cells[_tc] = "tree_trunk"; world.deltas[_tc] = "tree_trunk"
		world._set_tile(_tc, "tree_trunk")
	var _gv_leaf := Vector2i(_gv_x + 1, _gv_gy - 4)                 # a leaf on the top trunk
	world.cells[_gv_leaf] = "tree_leaves"; world.deltas[_gv_leaf] = "tree_leaves"
	world._set_tile(_gv_leaf, "tree_leaves")
	var _gv_drops0: int = get_tree().get_nodes_in_group("item_drops").size()
	world.break_block(Vector2i(_gv_x, _gv_gy - 2))                 # cut the trunk mid-way
	var _gv_base_stays: bool = world.block_at(Vector2i(_gv_x, _gv_gy - 1)) == "tree_trunk"
	var _gv_top_fell: bool = world.block_at(Vector2i(_gv_x, _gv_gy - 3)) == "air" \
		and world.block_at(Vector2i(_gv_x, _gv_gy - 4)) == "air" \
		and world.block_at(_gv_leaf) == "air"
	var _gv_dropped: bool = get_tree().get_nodes_in_group("item_drops").size() > _gv_drops0
	# stone is cohesive: mining beside it never makes it fall.
	var _gv_sx := Vector2i(_gv_x + 6, _gv_gy + 2)
	world.cells[_gv_sx] = "stone"; world.deltas[_gv_sx] = "stone"; world._set_tile(_gv_sx, "stone")
	world.break_block(Vector2i(_gv_sx.x, _gv_sx.y + 1))            # mine directly under it
	var _gv_stone_stays: bool = world.block_at(_gv_sx) == "stone"
	harness._check("gravity_tree_collapse",
		_gv_base_stays and _gv_top_fell and _gv_dropped and _gv_stone_stays,
		"base=%s top_fell=%s dropped=%s stone_stays=%s" % [str(_gv_base_stays),
			str(_gv_top_fell), str(_gv_dropped), str(_gv_stone_stays)])

	# Slice 1 (feedback): ore now has gravity — undermining a lone ore drops it, while
	# cohesive stone beside it never falls.
	var _go_x: int = hall_cell.x - 28
	var _go_gy: int = int(world.surface.get(_go_x, hall_cell.y))
	for _go_i in range(4):
		world.break_block(Vector2i(_go_x, _go_gy - 1 - _go_i))
	world.cells[Vector2i(_go_x, _go_gy)] = "stone"                 # a floor under the ore
	world.deltas[Vector2i(_go_x, _go_gy)] = "stone"
	world._set_tile(Vector2i(_go_x, _go_gy), "stone")
	var _go_ore := Vector2i(_go_x, _go_gy - 1)
	world.cells[_go_ore] = "iron_ore"; world.deltas[_go_ore] = "iron_ore"
	world._set_tile(_go_ore, "iron_ore")
	var _go_drops0: int = get_tree().get_nodes_in_group("item_drops").size()
	world.break_block(Vector2i(_go_x, _go_gy))                     # mine the floor under it
	var _go_ore_fell: bool = world.block_at(_go_ore) == "air" \
		and get_tree().get_nodes_in_group("item_drops").size() > _go_drops0
	# a stone with its footing mined is cohesive and stays put.
	var _go_stone := Vector2i(_go_x + 4, _go_gy - 1)
	world.cells[_go_stone] = "stone"; world.deltas[_go_stone] = "stone"
	world._set_tile(_go_stone, "stone")
	world.break_block(Vector2i(_go_stone.x, _go_stone.y + 1))
	var _go_stone_stays: bool = world.block_at(_go_stone) == "stone"
	harness._check("gravity_ore_falls",
		_go_ore_fell and _go_stone_stays and BlockRegistry.has_gravity("iron_ore")
		and not BlockRegistry.has_gravity("stone"),
		"ore_fell=%s stone_stays=%s" % [str(_go_ore_fell), str(_go_stone_stays)])

	# --- Settlement Coherence (M2-B): housing validation + housing-capped growth ---
	var _hs_cfg: Dictionary = BlockRegistry.settlement_def().get("housing", {})
	var _hs_hw: int = BlockRegistry.settlement_bound_cells("half_width_cells", 28)
	var _hs_up: int = BlockRegistry.settlement_bound_cells("up_cells", 12)
	var _hs_dn: int = BlockRegistry.settlement_bound_cells("down_cells", 10)
	var _hs_x0: int = hall_cell.x + 14
	var _hs_y0: int = hall_cell.y - 7        # inside the up-bound, above hall grade
	var _hs_w := 5
	var _hs_h := 4
	# clear the footprint, then stamp a solid stone shell with an air interior.
	for _yy in range(_hs_y0, _hs_y0 + _hs_h):
		for _xx in range(_hs_x0, _hs_x0 + _hs_w):
			world.break_block(Vector2i(_xx, _yy))
	var _hs_base_count: int = HousingScript.count_valid_houses(
		world, hall_cell, _hs_hw, _hs_up, _hs_dn, _hs_cfg)
	var _hs_cap_before: int = root.housing_capacity()
	for _yy in range(_hs_y0, _hs_y0 + _hs_h):
		for _xx in range(_hs_x0, _hs_x0 + _hs_w):
			if _xx == _hs_x0 or _xx == _hs_x0 + _hs_w - 1 \
					or _yy == _hs_y0 or _yy == _hs_y0 + _hs_h - 1:
				world.place_block(Vector2i(_xx, _yy), "stone")
	var _hs_door := Vector2i(_hs_x0 + 2, _hs_y0 + _hs_h - 1)   # a door in the bottom wall
	world.break_block(_hs_door)
	world.place_block(_hs_door, "door")
	# (a) the enclosed, doored room is recognised, adding per_house_capacity.
	harness._check("m2b_housing_recognizes_valid_house",
		HousingScript.count_valid_houses(world, hall_cell, _hs_hw, _hs_up, _hs_dn, _hs_cfg)
			== _hs_base_count + 1,
		"base=%d with_house=%d" % [_hs_base_count,
			HousingScript.count_valid_houses(world, hall_cell, _hs_hw, _hs_up, _hs_dn, _hs_cfg)])
	harness._check("m2b_housing_capacity_increases",
		root.housing_capacity() == _hs_cap_before + int(_hs_cfg.get("per_house_capacity", 2)),
		"before=%d after=%d" % [_hs_cap_before, root.housing_capacity()])
	# (b) sealing the only door makes it NOT a house (>=1 door is required).
	world.break_block(_hs_door)
	world.place_block(_hs_door, "stone")
	harness._check("m2b_house_needs_a_door",
		HousingScript.count_valid_houses(world, hall_cell, _hs_hw, _hs_up, _hs_dn, _hs_cfg)
			== _hs_base_count,
		"sealed_count=%d base=%d" % [
			HousingScript.count_valid_houses(world, hall_cell, _hs_hw, _hs_up, _hs_dn, _hs_cfg),
			_hs_base_count])
	# (c) growth is gated by housing: with the base-level cap high (village, 8) and
	# housing capacity == population, a thriving dawn adds nobody; raising housing
	# capacity above population lets exactly one settler arrive. housing_override
	# controls capacity deterministically so this isolates the housing gate from the
	# base-level cap (and from any incidental enclosed pockets in the test world).
	root.base_level = 3                       # base cap 8, so housing is the binding gate
	hall.population = 4
	hall.stockpile["food"] = 100
	settlement.coherence = 80.0
	root.housing_override = 4                  # capacity == population -> blocked
	root.consume_daily_food()
	var _g_blocked: bool = hall.population == 4
	root.housing_override = 6                  # capacity above population -> +1
	hall.stockpile["food"] = 100
	settlement.coherence = 80.0
	root.consume_daily_food()
	harness._check("m2b_growth_gated_by_housing",
		_g_blocked and hall.population == 5,
		"blocked=%s grew_to=%d" % [str(_g_blocked), hall.population])
	root.housing_override = -1
	# clean up the test house so later sections see clean terrain.
	for _yy in range(_hs_y0, _hs_y0 + _hs_h):
		for _xx in range(_hs_x0, _hs_x0 + _hs_w):
			world.break_block(Vector2i(_xx, _yy))

	# Restore global state so later sections (screenshot) see a sane player.
	player.player_event.disconnect(_fq01_msg_conn)
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	player._eat_cooldown = 0.0
	player.modulate = Color(1, 1, 1)
	player.inventory.from_dict({})
	player.inventory_changed.emit()
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species(str(GameState.current_character.get("species", "")))
	player.tool_tier = 2
	player.axe_tier = 1
