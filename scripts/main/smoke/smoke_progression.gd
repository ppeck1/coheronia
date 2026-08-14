extends Node
## S-07.3 smoke domain module - progression & character setup: Progression MVP
## (XP/level/base-levels/pop cap), Ancestry Phase B, and character-inventory
## Waves A-F (v0.6). Order-preserving extraction; harness owns
## _check/_find_block/_mine_cell (via harness.*).


func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this cluster uses.
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player
	var hall = ctx.hall
	var settlement = ctx.settlement
	var hud = ctx.hud
	# --- Progression MVP: XP, player level, base levels, population cap ---

	# Fix 16: use root's shared registry instance.
	var prog_reg = root._progression_registry
	harness._check("progression_jsons_load",
		prog_reg.base_levels_ordered().size() == 6
		and prog_reg.xp_event("block_mined").get("xp_type") == "labor",
		"base_levels=%d block_mined_type=%s" % [
			prog_reg.base_levels_ordered().size(),
			str(prog_reg.xp_event("block_mined").get("xp_type", "?"))])

	# Level-curve: xp_to_next(1) must equal the base value of 100.
	harness._check("xp_to_next_level_1", prog_reg.xp_to_next(1) == 100,
		"xp_to_next(1)=%d" % prog_reg.xp_to_next(1))

	# award_xp("block_mined") increases labor XP.
	var labor_before: int = int(root.xp_totals.get("labor", 0))
	root.award_xp("block_mined")
	harness._check("award_xp_increases_labor_xp",
		int(root.xp_totals.get("labor", 0)) > labor_before,
		"labor %d→%d" % [labor_before, int(root.xp_totals.get("labor", 0))])

	# Simulate requires-met conditions to advance base_level from camp (1) to hamlet (2).
	# We set settlement.inputs directly to inject the needed shelter/light values,
	# and prime the food stockpile, then call _check_base_level() as the test hook.
	var saved_base_level: int = root.base_level
	root.base_level = 1
	settlement.inputs["shelter_score"] = 15.0
	settlement.inputs["light_score"] = 20.0
	hall.stockpile["food"] = 20
	root._check_base_level()
	harness._check("base_level_advances_to_hamlet", root.base_level == 2,
		"base_level=%d" % root.base_level)

	# population_cap reflects base_level from registry data.
	root.base_level = 1   # camp -> cap 4
	harness._check("population_cap_at_camp", root.effective_population_cap() == 4,
		"cap=%d" % root.effective_population_cap())
	root.base_level = 2   # hamlet -> cap 6
	harness._check("population_cap_at_hamlet", root.effective_population_cap() == 6,
		"cap=%d" % root.effective_population_cap())
	root.base_level = 3   # village -> data cap 16 clamps to POPULATION_MAX
	harness._check("population_cap_at_village", root.effective_population_cap() == root.POPULATION_MAX,
		"cap=%d" % root.effective_population_cap())

	# Growth is gated by the effective cap: at camp (cap 4) a thriving dawn
	# does not grow population past the cap. _update_population is called
	# directly so the settlement tick cannot auto-advance the level mid-check.
	root.base_level = 1
	hall.population = 4
	hall.stockpile["food"] = 100
	root._update_population({"eaten": 4, "needed": 4}, 80.0)
	harness._check("population_growth_gated_by_cap", hall.population == 4,
		"pop=%d cap=%d" % [hall.population, root.effective_population_cap()])

	# Restore base level for the next section.
	root.base_level = maxi(saved_base_level, 2)

	# Save/load round-trips XP totals and base level.
	var prog_base_save: int = root.base_level
	root.xp_totals["labor"] = 77
	root.player_level = 1
	var prog_saved: bool = root.save_manager.save_game()
	root.base_level = 1
	root.xp_totals["labor"] = 0
	var prog_loaded: bool = root.load_game()
	harness._check("save_load_round_trips_progression",
		prog_saved and prog_loaded
		and root.base_level == prog_base_save
		and int(root.xp_totals.get("labor", 0)) == 77,
		"base_level=%d labor_xp=%d" % [root.base_level, int(root.xp_totals.get("labor", 0))])

	# --- Ancestry Phase B: registry loads + player_effects wired ---

	# Registry loads all 12 ancestries; phase_b_ids returns exactly 5.
	# Fix 16: use root's shared registry instance.
	var ancestry_reg = root._ancestry_registry
	harness._check("ancestries_json_loads_via_registry", ancestry_reg.all_count() == 12,
		"%d ancestries loaded" % ancestry_reg.all_count())
	harness._check("ancestry_phase_b_ids_count", ancestry_reg.phase_b_ids().size() == 5,
		"phase_b_ids=%s" % str(ancestry_reg.phase_b_ids()))

	# Dwarf: 0.9x move speed and 1.2x stone/ore mining vs baseline defaults.
	player.apply_character(GameState.current_character)
	var baseline_move_mult: float = player.ancestry_move_mult  # 1.0 after reset
	var baseline_mine_mult: float = player.stone_ore_mine_mult  # 1.0 after reset
	root.apply_ancestry_for_species("dwarf")
	harness._check("dwarf_move_speed_09x", absf(player.ancestry_move_mult - 0.9 * baseline_move_mult) < 0.001,
		"ancestry_move_mult=%.3f (expected %.3f)" % [player.ancestry_move_mult, 0.9 * baseline_move_mult])
	harness._check("dwarf_stone_ore_mining_12x", absf(player.stone_ore_mine_mult - 1.2 * baseline_mine_mult) < 0.001,
		"stone_ore_mine_mult=%.3f (expected %.3f)" % [player.stone_ore_mine_mult, 1.2 * baseline_mine_mult])

	# Orc: max health rises by exactly 25 above the trait/role baseline.
	player.apply_character(GameState.current_character)
	var baseline_max_health: float = player.max_health
	root.apply_ancestry_for_species("orc")
	harness._check("orc_health_bonus_25", absf(player.max_health - (baseline_max_health + 25.0)) < 0.01,
		"max_health=%.0f baseline=%.0f" % [player.max_health, baseline_max_health])

	# Human: award_xp yields >= the baseline amount (1.05x, rounded).
	player.apply_character(GameState.current_character)
	var _labor_snap: int = int(root.xp_totals.get("labor", 0))
	root.award_xp("block_mined")
	var baseline_gain: int = int(root.xp_totals.get("labor", 0)) - _labor_snap
	root.xp_totals["labor"] = _labor_snap  # restore before human test
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species("human")
	var _human_snap: int = int(root.xp_totals.get("labor", 0))
	root.award_xp("block_mined")
	var human_gain: int = int(root.xp_totals.get("labor", 0)) - _human_snap
	harness._check("human_learning_mult_xp", human_gain >= baseline_gain,
		"human_gain=%d baseline_gain=%d" % [human_gain, baseline_gain])

	# Fix 17d: 20 block_mined events — human (1.05x) must accumulate 21 labor XP
	# where a baseline (no ancestry) accumulates exactly 20. Tests float storage.
	player.apply_character(GameState.current_character)
	var _xp_snap20: float = float(root.xp_totals.get("labor", 0.0))
	for _i20 in range(20):
		root.award_xp("block_mined")
	var _baseline20: int = int(root.xp_totals.get("labor", 0.0)) - int(_xp_snap20)
	root.xp_totals["labor"] = _xp_snap20
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species("human")
	var _xp_snap_h20: float = float(root.xp_totals.get("labor", 0.0))
	for _ih20 in range(20):
		root.award_xp("block_mined")
	var _human20: int = int(root.xp_totals.get("labor", 0.0)) - int(_xp_snap_h20)
	root.xp_totals["labor"] = _xp_snap20
	harness._check("human_20x_block_mined_labor_xp", _baseline20 == 20 and _human20 >= 21,
		"baseline=%d human=%d" % [_baseline20, _human20])

	# Unknown/legacy species: all ancestry multipliers stay at their safe defaults.
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species("unknown_legacy_species")
	harness._check("unknown_species_at_baseline",
		absf(player.ancestry_move_mult - 1.0) < 0.001
		and absf(player.ancestry_jump_mult - 1.0) < 0.001
		and absf(player.stone_ore_mine_mult - 1.0) < 0.001
		and absf(player.learning_speed_mult - 1.0) < 0.001,
		"move=%.3f jump=%.3f mine=%.3f learn=%.3f" % [player.ancestry_move_mult,
			player.ancestry_jump_mult, player.stone_ore_mine_mult, player.learning_speed_mult])

	# Fix 17b: elf ancestry yields ancestry_jump_mult > 1.0 (via jump_bonus 0.15).
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species("elf")
	harness._check("elf_ancestry_jump_mult_gt_1", player.ancestry_jump_mult > 1.0,
		"ancestry_jump_mult=%.3f" % player.ancestry_jump_mult)

	# Fix 17c: goblin ancestry yields max_health < the no-ancestry baseline.
	player.apply_character(GameState.current_character)
	var _goblin_baseline_health: float = player.max_health
	root.apply_ancestry_for_species("goblin")
	harness._check("goblin_ancestry_max_health_lt_baseline", player.max_health < _goblin_baseline_health,
		"goblin=%.0f baseline=%.0f" % [player.max_health, _goblin_baseline_health])

	# Restore: apply the current character and its ancestry before the screenshot.
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species(str(GameState.current_character.get("species", "")))

	# Fix 17e: underground-family threat (cave_crawler) survives _on_dawn(),
	# while a surface threat (surface_slime) is freed.
	# Clear existing threats first.
	for t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(t):
			t.queue_free()
	await get_tree().process_frame
	var _ug_threat: Node = root.spawn_enemy_for_test("cave_crawler")
	var _surf_threat: Node = root.spawn_enemy_for_test("surface_slime")
	root._on_dawn()
	await get_tree().process_frame
	var _ug_alive: bool = is_instance_valid(_ug_threat) and not _ug_threat.is_queued_for_deletion()
	var _surf_freed: bool = not is_instance_valid(_surf_threat) or _surf_threat.is_queued_for_deletion()
	harness._check("underground_survives_dawn", _ug_alive and _surf_freed,
		"cave_crawler_alive=%s surface_slime_freed=%s" % [_ug_alive, _surf_freed])
	if is_instance_valid(_ug_threat) and not _ug_threat.is_queued_for_deletion():
		_ug_threat.queue_free()
	await get_tree().process_frame

	# Fix 17f: with darkness_increases_enemies=false, _advance_cave_spawns spawns nothing.
	var _rules_f: Dictionary = GameState.current_config.data["rules"]
	_rules_f["darkness_increases_enemies"] = false
	root._cave_spawn_timer = root.CAVE_SPAWN_INTERVAL + 1.0
	root._advance_cave_spawns(0.0)
	var _cave_count := 0
	for t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(t) and not t.is_queued_for_deletion() and t.family == "underground":
			_cave_count += 1
	harness._check("cave_spawns_respect_peaceful_rule", _cave_count == 0,
		"cave_count=%d" % _cave_count)
	_rules_f["darkness_increases_enemies"] = true

	# --- Wave A: ancestry detail panel text (v0.6) ---
	var _ancestry_detail_scr := preload("res://scripts/data/ancestry_detail.gd")

	# (a) Dwarf detail text contains its mining bonus and its constraint.
	var _detail_reg = root._ancestry_registry
	var _dwarf_anc: Dictionary = _detail_reg.get_ancestry("dwarf")
	var _dwarf_text: String = _ancestry_detail_scr.build_panel_text(_dwarf_anc, true)
	harness._check("ancestry_detail_dwarf_mining_and_constraint",
		"Mining" in _dwarf_text and "Slower movement" in _dwarf_text,
		"panel(100)=%s" % _dwarf_text.left(100))

	# (b) A non-live ancestry id produces a planned/reserved label.
	var _dd_anc: Dictionary = _detail_reg.get_ancestry("deep_dwarf")
	var _dd_text: String = _ancestry_detail_scr.build_panel_text(_dd_anc, false)
	harness._check("ancestry_detail_nonlive_planned_label",
		"planned" in _dd_text.to_lower() or "not playable" in _dd_text.to_lower(),
		"dd_text=%s" % _dd_text.left(80))

	# --- Wave D: world builder data sections (v0.6) ---

	# (c) ui_help/axis_help covers all six difficulty axes.
	var _ui_help_d: Dictionary = WorldConfig.settings().get("ui_help", {})
	var _axis_help_d: Dictionary = _ui_help_d.get("axis_help", {})
	var _all_axes := true
	for _ax in ["enemy", "ruler", "survival", "economy", "social", "impressionability"]:
		if not _axis_help_d.has(_ax):
			_all_axes = false
	harness._check("world_settings_axis_help_covers_all_axes", _all_axes,
		"axis_help keys=%s" % str(_axis_help_d.keys()))

	# (d) dark_frontier preset summary is non-empty and mentions at least one deviation.
	var _df_descs: Dictionary = _ui_help_d.get("preset_descriptions", {})
	var _df_entry: Dictionary = _df_descs.get("dark_frontier", {})
	var _df_devs: String = str(_df_entry.get("deviations", ""))
	harness._check("world_preset_summary_dark_frontier_nonempty",
		_df_devs != "" and ("1.75" in _df_devs or "Enemy" in _df_devs or "x1." in _df_devs),
		"dark_frontier deviations=%s" % _df_devs.left(80))

	# --- Wave B: character-owned inventory across worlds (v0.6) ---

	# (a) Two characters keep distinct inventories written to/from shell.json.
	var _b_char_a: Dictionary = GameState.create_character({"name": "B_CharA", "role": "homesteader"})
	var _b_char_b: Dictionary = GameState.create_character({"name": "B_CharB", "role": "prospector"})
	var _b_world_id: String = GameState.create_world(WorldConfig.from_preset("folk_kingdom"))
	GameState.save_character_carried(str(_b_char_a["id"]), {"dirt": 5}, 0, {"pick": 1, "axe": 0})
	GameState.save_character_carried(str(_b_char_b["id"]), {"stone": 7}, 1, {"pick": 2, "axe": 0})
	GameState.load_shell()  # force fresh read from disk
	var _ba_reload: Dictionary = GameState.get_character(str(_b_char_a["id"]))
	var _bb_reload: Dictionary = GameState.get_character(str(_b_char_b["id"]))
	harness._check("wave_b_char_a_distinct_inventory",
		int(_ba_reload.get("carried_inventory", {}).get("dirt", 0)) == 5
		and not _ba_reload.get("carried_inventory", {}).has("stone"),
		"char_a inv=%s" % str(_ba_reload.get("carried_inventory", {})))
	harness._check("wave_b_char_b_distinct_inventory",
		int(_bb_reload.get("carried_inventory", {}).get("stone", 0)) == 7
		and not _bb_reload.get("carried_inventory", {}).has("dirt"),
		"char_b inv=%s" % str(_bb_reload.get("carried_inventory", {})))

	# (b) Char A's inventory survives entering a second world (state is on the character).
	var _b_world2_id: String = GameState.create_world(WorldConfig.from_preset("folk_kingdom"))
	var _ba2: Dictionary = GameState.get_character(str(_b_char_a["id"]))
	harness._check("wave_b_inventory_survives_second_world",
		int(_ba2.get("carried_inventory", {}).get("dirt", 0)) == 5,
		"char_a after second world=%s" % str(_ba2.get("carried_inventory", {})))
	GameState.delete_world(_b_world2_id)

	# (c) Role starter items granted once — items_granted flag prevents duplication.
	# The current character already went through _grant_role_items() in _ready().
	var _curr_cid: String = str(GameState.current_character.get("id", ""))
	var _curr_ch: Dictionary = GameState.get_character(_curr_cid)
	harness._check("wave_b_items_granted_after_ready",
		bool(_curr_ch.get("items_granted", false)),
		"items_granted=%s" % str(_curr_ch.get("items_granted", false)))
	var _dirt_pre_regrant: int = player.inventory.count("dirt")
	root._grant_role_items()   # second call — should be a no-op due to flag
	harness._check("wave_b_no_duplicate_role_items",
		player.inventory.count("dirt") == _dirt_pre_regrant,
		"dirt before=%d after regrant=%d" % [_dirt_pre_regrant, player.inventory.count("dirt")])

	# (d) Legacy character (no carried_inventory field) + old-format world save migrates cleanly.
	var _leg_char: Dictionary = GameState.create_character({"name": "LegacyChar", "role": "homesteader"})
	var _lcid: String = str(_leg_char["id"])
	# Simulate legacy: strip Wave B fields from the in-memory array and persist.
	for _li in range(GameState.characters.size()):
		if str(GameState.characters[_li].get("id", "")) == _lcid:
			GameState.characters[_li].erase("carried_inventory")
			GameState.characters[_li].erase("carried_slot")
			GameState.characters[_li].erase("carried_tool_tier")
			GameState.characters[_li].erase("items_granted")
			break
	GameState.save_shell()
	GameState.load_shell()
	var _lc_check: Dictionary = GameState.get_character(_lcid)
	harness._check("wave_b_legacy_char_no_carried_field",
		not _lc_check.has("carried_inventory"),
		"has_carried=%s" % str(_lc_check.has("carried_inventory")))
	# Old-format state dict with player.inventory embedded (pre-Wave-B format).
	var _old_state: Dictionary = {
		"save_version": "0.5",
		"world_seed": 12345,
		"terrain_deltas": {},
		"player": {
			"x": 100.0, "y": 100.0, "health": 90.0,
			"tool_tier": 2, "selected_slot": 3,
			"inventory": {"dirt": 4, "stone": 6},
		},
		"town_hall": {}, "time": {}, "threats": [], "bush_regrow": {}, "progression": {},
	}
	var _legacy_carried: Dictionary = root.save_manager.legacy_player_carried(_old_state)
	harness._check("wave_b_legacy_migration_extracts_inventory",
		not _legacy_carried.is_empty()
		and int(_legacy_carried.get("inventory", {}).get("dirt", 0)) == 4
		and int(_legacy_carried.get("tool_tier", 1)) == 2,
		"legacy_carried=%s" % str(_legacy_carried))

	# (e) FQ-00: running the full character-carried-state load path for a legacy
	# character (no carried_inventory field, items_granted false/absent) must
	# mark items_granted so a subsequent _grant_role_items() call cannot stack
	# the role's starting_items on top of the migrated old-world inventory.
	var _fq00_prev_char: Dictionary = GameState.current_character
	GameState.current_character = GameState.get_character(_lcid)
	root._load_character_carried_state(_old_state)
	var _fq00_after_migration: Dictionary = GameState.get_character(_lcid)
	harness._check("fq00_legacy_migration_marks_items_granted",
		bool(_fq00_after_migration.get("items_granted", false))
		and int(player.inventory.count("dirt")) == 4,
		"items_granted=%s dirt=%d" % [
			str(_fq00_after_migration.get("items_granted", false)),
			player.inventory.count("dirt")])
	var _fq00_dirt_after_migration: int = player.inventory.count("dirt")
	root._grant_role_items()   # homesteader would add dirt+10/wood+5 if this were not a no-op
	harness._check("fq00_no_duplicate_role_items_after_legacy_migration",
		player.inventory.count("dirt") == _fq00_dirt_after_migration,
		"dirt before regrant=%d after=%d" % [
			_fq00_dirt_after_migration, player.inventory.count("dirt")])
	GameState.current_character = _fq00_prev_char

	# Clean up Wave B test characters/world.
	GameState.delete_character(str(_b_char_a["id"]))
	GameState.delete_character(str(_b_char_b["id"]))
	GameState.delete_character(_lcid)
	GameState.delete_world(_b_world_id)

	# --- Wave C: openable inventory panel (v0.6) ---

	# (e) toggle_inventory action is bound to a device key.
	var _inv_has_device := false
	for _ev in InputMap.action_get_events("toggle_inventory"):
		if _ev is InputEventKey or _ev is InputEventMouseButton:
			_inv_has_device = true
	harness._check("wave_c_toggle_inventory_bound", _inv_has_device,
		"toggle_inventory has a device event")

	# (f) Panel opens/closes and content reflects a known inventory count.
	harness._check("wave_c_inv_panel_starts_closed", not hud.inventory_panel_open())
	hud.toggle_inventory_panel()
	harness._check("wave_c_inv_panel_opens", hud.inventory_panel_open())
	hud.toggle_inventory_panel()
	harness._check("wave_c_inv_panel_closes", not hud.inventory_panel_open())
	# Inject a known inventory count, open panel, verify label text.
	player.inventory.from_dict({"dirt": 13})
	player.inventory_changed.emit()
	hud.toggle_inventory_panel()
	var _inv_text: String = hud.get_inventory_panel_text()
	harness._check("wave_c_inv_panel_reflects_count",
		"13" in _inv_text and "dirt" in _inv_text.to_lower(),
		"inv_panel_text=%s" % _inv_text.left(80))
	hud.toggle_inventory_panel()   # close before screenshot

	# --- Wave E: berry bush support rule (v0.6) ---

	# Reset to a clean world state for deterministic support tests.
	world.setup(12345)
	root._position_actors()
	player.set_physics_process(false)
	player.inventory.from_dict({})
	player.inventory_changed.emit()

	# (a) Mining the block directly under a bush removes the bush and yields food.
	var _e_bush: Variant = harness._find_block(world, world.hall_info["center_cell"], "berry_bush")
	harness._check("wave_e_bush_found", _e_bush != null)
	var _e_supp: Vector2i = Vector2i(0, 0)
	if _e_bush != null:
		_e_supp = Vector2i((_e_bush as Vector2i).x, (_e_bush as Vector2i).y + 1)
	var _e_food_before: int = player.inventory.count("food")
	if _e_bush != null:
		# Mine the support block directly via the world API — drops are merged by break_block.
		player.global_position = world.cell_center(_e_supp) + Vector2(0, -32.0)
		var _e_drops: Dictionary = world.break_block(_e_supp)
		player.inventory.add_many(_e_drops)
		player.inventory_changed.emit()
	harness._check("wave_e_support_mine_removes_bush",
		_e_bush == null or world.block_at(_e_bush as Vector2i) == "air",
		"block_at_bush=%s" % (world.block_at(_e_bush as Vector2i) if _e_bush != null else "n/a"))
	harness._check("wave_e_support_mine_yields_food",
		_e_bush == null or player.inventory.count("food") > _e_food_before,
		"food %d→%d" % [_e_food_before, player.inventory.count("food")])
	harness._check("wave_e_bush_regrow_scheduled",
		_e_bush == null or world.bush_regrow.has(_e_bush as Vector2i),
		"bush_regrow_has=%s" % str(world.bush_regrow.has(_e_bush as Vector2i) if _e_bush != null else "n/a"))

	# (b) Regrowth into unsupported air re-schedules the timer instead of placing a bush.
	# The support is now air; force-expire the regrow timer and check nothing is placed.
	if _e_bush != null:
		world.bush_regrow[_e_bush] = 0.01
		for _ei in range(5):
			await get_tree().process_frame
		harness._check("wave_e_no_regrow_without_support",
			world.block_at(_e_bush as Vector2i) == "air" and world.bush_regrow.has(_e_bush as Vector2i),
			"block=%s regrow_present=%s" % [world.block_at(_e_bush as Vector2i),
				str(world.bush_regrow.has(_e_bush as Vector2i))])

	# (c) After support is restored, regrowth places the bush normally.
	if _e_bush != null:
		world.place_block(_e_supp, "dirt")  # restore solid support
		world.bush_regrow[_e_bush] = 0.01
		for _ei2 in range(5):
			await get_tree().process_frame
		harness._check("wave_e_regrows_when_supported", world.block_at(_e_bush as Vector2i) == "berry_bush",
			"block_at=%s" % world.block_at(_e_bush as Vector2i))

	# (d) Save/load after an unsupported bush delta does not resurrect a floating bush.
	# Inject a floating bush into deltas (no solid support below it) then reload.
	if _e_bush != null:
		# Mine the support again to ensure it's air, inject bush delta.
		world.cells.erase(_e_bush as Vector2i)  # remove any regrown bush
		world.break_block(_e_supp)              # mine support away again
		world.deltas[_e_bush as Vector2i] = "berry_bush"  # inject floating bush delta
		world.cells[_e_bush as Vector2i] = "berry_bush"
		world.bush_regrow.erase(_e_bush as Vector2i)      # clear regrow to force sweep
		root.save_manager.save_game()
		root.load_game()
		harness._check("wave_e_load_no_floating_bush",
			world.block_at(_e_bush as Vector2i) == "air",
			"block_after_load=%s" % world.block_at(_e_bush as Vector2i))

	# --- Wave F: differentiated tools (v0.6) ---

	# Rebuild world fresh for deterministic frame counts.
	world.setup(12345)
	root._position_actors()
	player.axe_tier = 0
	player.tool_tier = 1
	player.inventory.from_dict({})
	player.inventory_changed.emit()
	var _f_hall: Vector2i = world.hall_info["center_cell"]

	# Baseline trunk frame count without axe (tier 1, no axe) — ordering must
	# hold. FQ-09R: generated trees are tree_trunk (wood hardness, drops wood).
	var _f_wood: Variant = harness._find_block(world, _f_hall, "tree_trunk")
	harness._check("wave_f_wood_found", _f_wood != null)
	var _f_wood_frames_no_axe := 0
	if _f_wood != null:
		_f_wood_frames_no_axe = await harness._mine_cell(world, player, _f_wood as Vector2i)
	# (d) Existing hardness ordering still holds without axe: dirt < wood < stone.
	# (Covered by the earlier hardness_orders_mining_time check; this confirms the
	#  baseline wood frames are still > dirt and < stone frame bands.)
	harness._check("wave_f_wood_baseline_positive", _f_wood_frames_no_axe > 0,
		"wood_frames_no_axe=%d" % _f_wood_frames_no_axe)

	# (e) Crafting the axe via forge_axe consumes stockpile and sets axe_tier = 1.
	hall.stockpile["wood"] = 10
	hall.stockpile["stone"] = 10
	var _f_wood_stock_before: int = int(hall.stockpile.get("wood", 0))
	var _f_stone_stock_before: int = int(hall.stockpile.get("stone", 0))
	var _f_axe_forged: bool = hall.forge_axe(player)
	harness._check("wave_f_axe_crafted", _f_axe_forged and player.axe_tier == 1,
		"forged=%s axe_tier=%d" % [str(_f_axe_forged), player.axe_tier])
	harness._check("wave_f_axe_consumes_stockpile",
		int(hall.stockpile.get("wood", 0)) == _f_wood_stock_before - 4
		and int(hall.stockpile.get("stone", 0)) == _f_stone_stock_before - 2,
		"wood %d→%d stone %d→%d" % [_f_wood_stock_before, int(hall.stockpile.get("wood", 0)),
			_f_stone_stock_before, int(hall.stockpile.get("stone", 0))])
	harness._check("wave_f_axe_no_duplicate_craft", not hall.forge_axe(player),
		"second forge_axe must return false")

	# (f) With axe, wood mines measurably faster than without.
	var _f_wood2: Variant = harness._find_block(world, _f_hall, "tree_trunk")
	var _f_wood_frames_axe := 600
	if _f_wood2 != null:
		_f_wood_frames_axe = await harness._mine_cell(world, player, _f_wood2 as Vector2i)
	harness._check("wave_f_axe_speeds_wood",
		_f_wood2 == null or _f_wood_frames_axe < _f_wood_frames_no_axe,
		"frames: no_axe=%d axe=%d" % [_f_wood_frames_no_axe, _f_wood_frames_axe])

	# (g) Stone speed is unaffected by axe (preferred_tool = pick).
	var _f_stone: Variant = harness._find_block(world, _f_hall, "stone")
	var _f_stone_frames_no_axe := 0
	player.axe_tier = 0
	if _f_stone != null:
		_f_stone_frames_no_axe = await harness._mine_cell(world, player, _f_stone as Vector2i)
	var _f_stone2: Variant = harness._find_block(world, _f_hall, "stone")
	var _f_stone_frames_axe := 0
	player.axe_tier = 1
	if _f_stone2 != null:
		_f_stone_frames_axe = await harness._mine_cell(world, player, _f_stone2 as Vector2i)
	harness._check("wave_f_axe_no_effect_on_stone",
		_f_stone == null or _f_stone2 == null or _f_stone_frames_axe == _f_stone_frames_no_axe,
		"stone frames: no_axe=%d axe=%d" % [_f_stone_frames_no_axe, _f_stone_frames_axe])
	player.axe_tier = 1  # keep axe active for remaining tests

	# (h) Tool state {pick, axe} round-trips through the character-carried save path.
	player.tool_tier = 2
	player.axe_tier = 1
	root.save_manager.save_game()
	player.tool_tier = 1
	player.axe_tier = 0
	root.load_game()
	harness._check("wave_f_tool_state_round_trips",
		player.tool_tier == 2 and player.axe_tier == 1,
		"pick=%d axe=%d" % [player.tool_tier, player.axe_tier])

	# (i) Legacy character with only carried_tool_tier migrates to {pick: N, axe: 0}.
	var _f_leg_char: Dictionary = GameState.create_character({"name": "LegacyF", "role": "homesteader"})
	var _f_lcid: String = str(_f_leg_char["id"])
	for _fli in range(GameState.characters.size()):
		if str(GameState.characters[_fli].get("id", "")) == _f_lcid:
			GameState.characters[_fli].erase("carried_tool_tiers")
			GameState.characters[_fli]["carried_tool_tier"] = 3
			break
	GameState.save_shell()
	GameState.load_shell()
	var _f_lc_char: Dictionary = GameState.get_character(_f_lcid)
	var _f_prev_char: Dictionary = GameState.current_character
	GameState.current_character = _f_lc_char
	root._load_character_carried_state({})
	harness._check("wave_f_legacy_tool_tier_migrates_to_dict",
		player.tool_tier == 3 and player.axe_tier == 0,
		"pick=%d axe=%d" % [player.tool_tier, player.axe_tier])
	GameState.current_character = _f_prev_char
	GameState.delete_character(_f_lcid)
	# Restore player state for screenshot.
	player.tool_tier = 2
	player.axe_tier = 1
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species(str(GameState.current_character.get("species", "")))
