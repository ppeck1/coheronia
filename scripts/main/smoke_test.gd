extends Node
## Automated acceptance smoke test. Runs when COHERONIA_SMOKE=1, exercises
## the real gameplay code paths, prints SMOKE lines, saves a screenshot
## (windowed runs only), and quits with a nonzero exit code on failure.

var _results: Array = []
var _details: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _check(name: String, ok: bool, detail: String = "") -> void:
	_results.append([name, ok])
	_details[name] = detail
	print("SMOKE %s: %s%s" % ["PASS" if ok else "FAIL", name, (" — " + detail) if detail != "" else ""])


func _run() -> void:
	var root: Node2D = get_parent()
	var world: Node2D = root.world
	var player: CharacterBody2D = root.player
	var hall: Node2D = root.town_hall
	var settlement: Node = root.settlement
	var hud: CanvasLayer = root.hud

	# Deterministic terrain for the test run.
	world.setup(12345)
	root._position_actors()
	settlement.compute()
	for i in range(40):
		await get_tree().physics_frame

	_check("main_scene_launches", true)
	_check("terrain_generated", world.cells.size() > 1000, "%d cells" % world.cells.size())
	_check("town_hall_exists", not world.hall_info.is_empty()
		and world.block_at(world.hall_info["core_cells"][0]) == "town_hall_core")
	_check("town_hall_core_protected", not world.can_mine(world.hall_info["core_cells"][0], 99))

	# --- Real input bindings (programmatic action_press below bypasses the
	# InputMap, so verify keys/mouse are actually bound to the actions) ---
	var unbound := ""
	for action in ["move_left", "move_right", "jump", "mine", "place", "interact",
			"toggle_town", "craft", "save_game", "load_game", "toggle_inventory",
			"debug_overlay", "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5",
			"eat_food"]:
		var has_device_event := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton:
				has_device_event = true
		if not has_device_event:
			unbound += action + " "
	_check("input_actions_bound", unbound == "",
		("unbound: " + unbound) if unbound != "" else "all actions have device events")
	_check("role_items_granted", player.inventory.count("dirt") >= 10,
		"dirt=%d (homesteader start)" % player.inventory.count("dirt"))

	# --- Shell persistence: characters + worlds as simulation containers ---
	var test_char: Dictionary = GameState.create_character({
		"name": "Smoke Tester", "role": "prospector", "traits": ["hardy"], "appearance": "ash"})
	var df_config: Dictionary = WorldConfig.from_preset("dark_frontier")
	df_config["name"] = "Smoke Frontier"
	df_config["seed"] = 777
	df_config["size"] = "small"
	var test_world_id: String = GameState.create_world(df_config)
	GameState.load_shell()   # force a fresh read from disk
	var reloaded_char: Dictionary = GameState.get_character(str(test_char["id"]))
	var reloaded_cfg := WorldConfig.new(GameState.load_world_file(test_world_id).get("config", {}))
	_check("shell_persists_characters", not reloaded_char.is_empty()
		and str(reloaded_char.get("role", "")) == "prospector"
		and "hardy" in reloaded_char.get("traits", []))
	_check("shell_persists_worlds", reloaded_cfg.difficulty("enemy") == 1.75
		and reloaded_cfg.seed_value() == 777 and reloaded_cfg.size_id() == "small")
	_check("presets_apply", not WorldConfig.new(
		WorldConfig.from_preset("peaceful_builder")).rule("darkness_increases_enemies"))
	GameState.delete_world(test_world_id)
	GameState.delete_character(str(test_char["id"]))

	# --- Movement ---
	var start_x := player.global_position.x
	Input.action_press("move_right")
	for i in range(30):
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check("player_moves", player.global_position.x > start_x + 8.0,
		"dx=%.1f" % (player.global_position.x - start_x))

	for i in range(30):
		await get_tree().physics_frame
	var min_vy := 0.0
	Input.action_press("jump")
	for i in range(12):
		await get_tree().physics_frame
		min_vy = minf(min_vy, player.velocity.y)
	Input.action_release("jump")
	_check("player_jumps", min_vy < -100.0, "min velocity.y=%.0f" % min_vy)

	# --- Mining with hardness timing ---
	player.set_physics_process(false)
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	var dirt_cell: Variant = _find_block(world, hall_cell, "dirt")
	var stone_cell: Variant = _find_block(world, hall_cell, "stone")
	var wood_cell: Variant = _find_block(world, hall_cell, "wood")
	_check("mineable_blocks_found", dirt_cell != null and stone_cell != null and wood_cell != null)

	var dirt_frames := await _mine_cell(world, player, dirt_cell)
	var wood_frames := await _mine_cell(world, player, wood_cell)
	var stone_frames := await _mine_cell(world, player, stone_cell)
	_check("mining_yields_drops",
		player.inventory.count("dirt") >= 1 and player.inventory.count("stone") >= 1
		and player.inventory.count("wood") >= 1,
		"inv=%s" % str(player.inventory.counts))
	_check("hardness_orders_mining_time", dirt_frames < wood_frames and wood_frames < stone_frames,
		"frames dirt=%d wood=%d stone=%d" % [dirt_frames, wood_frames, stone_frames])

	# --- Tool tier progression (forge at Town Hall) ---
	var ore_cell: Variant = _find_block(world, hall_cell, "ore", 2)
	_check("ore_exists_in_world", ore_cell != null)
	if ore_cell != null:
		_check("ore_gated_by_tool_tier", not world.can_mine(ore_cell, player.tool_tier))
	player.inventory.add("wood", 3)
	player.inventory.add("stone", 5)
	hall.deposit_all(player.inventory)
	var forged: bool = hall.forge_pick(player)
	_check("forge_pick_upgrade", forged and player.tool_tier == 2,
		"stock after forge=%s" % str(hall.stockpile))
	var dirt_cell2: Variant = _find_block(world, hall_cell, "dirt")
	var dirt_frames_t2 := await _mine_cell(world, player, dirt_cell2)
	_check("tier2_mines_faster", dirt_frames_t2 < dirt_frames,
		"frames tier1=%d tier2=%d" % [dirt_frames, dirt_frames_t2])
	if ore_cell != null:
		var ore_frames := await _mine_cell(world, player, ore_cell)
		_check("ore_mineable_after_forge", player.inventory.count("ore") >= 1,
			"%d frames" % ore_frames)

	# --- Food source ---
	var bush_cell: Variant = _find_block(world, hall_cell, "berry_bush")
	_check("berry_bush_exists", bush_cell != null)
	if bush_cell != null:
		await _mine_cell(world, player, bush_cell)
	_check("food_from_bush", player.inventory.count("food") >= 2,
		"food=%d" % player.inventory.count("food"))
	if bush_cell != null:
		_check("bush_regrow_timer_started", world.bush_regrow.has(bush_cell))
		world.bush_regrow[bush_cell] = 0.05
		for i in range(10):
			await get_tree().process_frame
		_check("bush_regrows", world.block_at(bush_cell) == "berry_bush")

	# --- Placement ---
	player.global_position = world.cell_center(dirt_cell) + Vector2(0, -40.0)
	var place_cell: Vector2i = dirt_cell
	var dirt_before: int = player.inventory.count("dirt")
	var placed: bool = player.try_place(place_cell, "dirt")
	_check("block_placement", placed and world.block_at(place_cell) == "dirt"
		and player.inventory.count("dirt") == dirt_before - 1)

	# --- Torch + light ---
	player.inventory.add("torch", 3)
	var torch_cell := Vector2i(place_cell.x, place_cell.y - 2)
	while world.block_at(torch_cell) != "air":
		torch_cell.y -= 1
	var torch_placed: bool = player.try_place(torch_cell, "torch")
	_check("torch_placement", torch_placed and world.block_at(torch_cell) == "torch")
	_check("torch_emits_light", world.has_light_at(torch_cell)
		and world._lights[torch_cell].energy > 0.0)
	_check("light_occlusion_configured",
		world._tilemap.tile_set.get_occlusion_layers_count() > 0
		and world._lights[torch_cell].shadow_enabled)

	# --- Town Hall deposit ---
	var stock_before: int = hall.total_stock()
	var moved: Dictionary = hall.deposit_all(player.inventory)
	_check("town_hall_deposit", hall.total_stock() > stock_before and not moved.is_empty(),
		"stock=%d" % hall.total_stock())

	# --- Population food consumption at dawn ---
	var food_before: int = int(hall.stockpile.get("food", 0))
	root.consume_daily_food()
	var food_after: int = int(hall.stockpile.get("food", 0))
	_check("population_consumes_food", food_before > 0 and food_after < food_before,
		"food %d→%d" % [food_before, food_after])

	# --- Population reacts to C/L/R and food ---
	var pop_start: int = hall.population
	root.consume_daily_food()          # stockpile food is now 0 -> starvation
	_check("population_shrinks_when_starved", hall.population == pop_start - 1,
		"pop %d→%d" % [pop_start, hall.population])
	hall.stockpile["food"] = 20
	settlement.coherence = 80.0        # force a thriving dawn snapshot
	root.consume_daily_food()
	_check("population_grows_when_thriving", hall.population == pop_start,
		"pop back to %d, food=%d" % [hall.population, int(hall.stockpile.get("food", 0))])
	# Bounds: repeated starvation floors at 1; repeated thriving caps at max.
	for i in range(6):
		hall.stockpile.erase("food")
		root.consume_daily_food()
	_check("population_floors_at_one", hall.population == 1, "pop=%d" % hall.population)
	hall.stockpile["food"] = 100
	root.base_level = 3  # village cap reaches POPULATION_MAX; growth is gated by base level
	for i in range(10):
		settlement.coherence = 80.0
		root.consume_daily_food()
	_check("population_caps_at_max", hall.population == root.POPULATION_MAX,
		"pop=%d" % hall.population)

	# --- Simulation rule toggles read from the world config ---
	var rules: Dictionary = GameState.current_config.data["rules"]
	var pop_no_rule: int = hall.population
	var food_no_rule: int = int(hall.stockpile.get("food", 0))
	rules["subjects_require_food"] = false
	settlement.coherence = 10.0
	root.consume_daily_food()
	_check("food_rule_toggle", hall.population == pop_no_rule
		and int(hall.stockpile.get("food", 0)) == food_no_rule,
		"no eating or starvation when feeding disabled")
	rules["subjects_require_food"] = true
	rules["weather_affects_survival"] = false
	var storm_started: bool = root.force_storm()
	_check("weather_rule_toggle", not storm_started and not root.storm_active)
	rules["weather_affects_survival"] = true
	rules["darkness_increases_enemies"] = false
	_check("darkness_rule_toggle", root.night_spawn_count() == 0)
	rules["darkness_increases_enemies"] = true
	var diff: Dictionary = GameState.current_config.data["difficulty"]
	diff["enemy"] = 2.0
	var hard_count: int = root.night_spawn_count()
	var hard_hp: int = root.threat_hp()
	diff["enemy"] = 1.0
	_check("enemy_difficulty_scales", hard_count > root.night_spawn_count()
		and hard_hp == 6 and root.threat_hp() == 3,
		"count %d vs %d, hp %d vs 3" % [hard_count, root.night_spawn_count(), hard_hp])
	diff["impressionability"] = 2.0
	var easy_threshold: float = root.growth_threshold()
	diff["impressionability"] = 1.0
	_check("impressionability_scales", easy_threshold < root.growth_threshold(),
		"threshold %.0f vs %.0f" % [easy_threshold, root.growth_threshold()])

	# --- Lantern (ore sink) crafted at the Town Hall ---
	player.inventory.add("ore", 2)
	player.inventory.add("wood", 1)
	hall.deposit_all(player.inventory)
	var lantern_crafted: bool = hall.craft_from_stockpile("craft_lantern", player)
	_check("lantern_crafted_from_stockpile",
		lantern_crafted and player.inventory.count("lantern") >= 1)
	var lantern_cell := Vector2i(place_cell.x + 1, place_cell.y - 2)
	while world.block_at(lantern_cell) != "air":
		lantern_cell.y -= 1
	player.global_position = world.cell_center(lantern_cell) + Vector2(0, 24.0)
	var lantern_placed: bool = player.try_place(lantern_cell, "lantern")
	_check("lantern_emits_light", lantern_placed and world.has_light_at(lantern_cell))

	# --- C/L/R responds to state ---
	settlement.compute()
	var c_before: float = settlement.coherence
	var light_before: float = settlement.inputs.get("light_score", 0.0)
	for offset in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(0, -4)]:
		var cell: Vector2i = hall_cell + offset
		if world.block_at(cell) == "air":
			world.place_block(cell, "torch")
	settlement.compute()
	_check("clr_reacts_to_light",
		settlement.inputs.get("light_score", 0.0) > light_before
		and settlement.coherence > c_before,
		"C %.1f→%.1f light %.1f→%.1f" % [c_before, settlement.coherence, light_before,
			settlement.inputs.get("light_score", 0.0)])

	# --- Storm event (daytime pressure mitigated by shelter) ---
	var storm_sev_before: float = root.current_threat_severity()
	var storm_damage_before: float = hall.damage
	root.force_storm()
	_check("storm_raises_pressure",
		root.storm_active and root.current_threat_severity() > storm_sev_before,
		"severity %.1f→%.1f" % [storm_sev_before, root.current_threat_severity()])
	for i in range(30):
		await get_tree().physics_frame
	_check("storm_damages_exposed_hall", hall.damage > storm_damage_before,
		"damage %.2f→%.2f" % [storm_damage_before, hall.damage])
	# Mitigation: a full roof over the hall stops storm damage.
	var ground_y: int = world.hall_info["ground_y"]
	for dx in range(-3, 4):
		var roof_cell := Vector2i(hall_cell.x + dx, ground_y - 3)
		if world.block_at(roof_cell) == "air":
			world.place_block(roof_cell, "wood")
	var roofed_damage: float = hall.damage
	for i in range(30):
		await get_tree().physics_frame
	_check("roof_blocks_storm_damage",
		settlement.roof_coverage() >= 0.99 and hall.damage - roofed_damage < 0.01,
		"coverage=%.2f damage %.2f→%.2f" % [settlement.roof_coverage(), roofed_damage, hall.damage])

	# --- Threat/pressure event ---
	var load_before: float = settlement.load_value
	root.force_night()
	await get_tree().physics_frame
	settlement.compute()
	_check("threat_event_raises_load",
		settlement.inputs.get("threat_score", 0.0) > 0.0
		and settlement.load_value > load_before,
		"load %.1f→%.1f threat=%.1f" % [load_before, settlement.load_value,
			settlement.inputs.get("threat_score", 0.0)])
	_check("threat_entity_spawned", get_tree().get_nodes_in_group("threats").size() > 0)

	# --- Save / load round trip ---
	var save_pos := player.global_position
	var save_dirt: int = player.inventory.count("dirt")
	var save_stock: int = hall.total_stock()
	var mined_before_save: Vector2i = wood_cell            # mined pre-save, must stay air
	if bush_cell != null:
		world.break_block(bush_cell)                       # pending regrow timer to persist
	var storm_at_save: bool = root.storm_active
	var saved: bool = root.save_manager.save_game()
	_check("save_game", saved)

	var mined_after_save: Variant = _find_block(world, hall_cell, "stone")
	world.break_block(mined_after_save)                     # must be restored on load
	player.global_position += Vector2(200, -60)
	player.inventory.add("dirt", 50)

	var loaded: bool = root.load_game()
	_check("load_game", loaded)
	_check("load_restores_player", player.global_position.distance_to(save_pos) < 1.0
		and player.inventory.count("dirt") == save_dirt)
	_check("load_restores_terrain", world.block_at(mined_before_save) == "air"
		and world.block_at(mined_after_save) == "stone"
		and world.block_at(place_cell) == "dirt"
		and world.block_at(torch_cell) == "torch")
	_check("load_restores_stockpile", hall.total_stock() == save_stock)
	_check("load_keeps_torch_light", world.has_light_at(torch_cell))
	var live_threats := 0
	for threat in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(threat) and not threat.is_queued_for_deletion():
			live_threats += 1
	_check("load_restores_threats", live_threats > 0, "%d live threats" % live_threats)
	_check("load_restores_tool_tier", player.tool_tier == 2)
	_check("load_restores_bush_regrow_timer",
		bush_cell != null and world.bush_regrow.has(bush_cell))
	_check("load_restores_storm_state", root.storm_active == storm_at_save,
		"storm at save=%s after load=%s" % [storm_at_save, root.storm_active])

	player.set_physics_process(true)

	# --- World size + per-block seed variation (regenerates terrain; the
	# live state was already saved above and is restored afterwards) ---
	var original_config: WorldConfig = GameState.current_config
	GameState.current_config = WorldConfig.new({"size": "small"})
	world.setup(777)
	_check("world_size_setting", world.width == 160 and world.height == 64,
		"%dx%d" % [world.width, world.height])
	GameState.current_config = WorldConfig.new({"generation": {"ore_abundance": 2.0}})
	world.setup(777)
	var ore_rich: int = _count_blocks(world, "ore")
	GameState.current_config = WorldConfig.new({"generation": {"ore_abundance": 0.0}})
	world.setup(777)
	var ore_none: int = _count_blocks(world, "ore")
	_check("ore_abundance_setting", ore_rich > 0 and ore_none == 0,
		"rich=%d none=%d" % [ore_rich, ore_none])
	GameState.current_config = WorldConfig.new({"generation": {"ore_seed_offset": 9999}})
	world.setup(777)
	var ore_cells_alt: Array = _block_cells(world, "ore")
	GameState.current_config = WorldConfig.new({})
	world.setup(777)
	var ore_cells_default: Array = _block_cells(world, "ore")
	_check("per_block_seed_variation", ore_cells_alt.size() > 0
		and ore_cells_default.size() > 0 and ore_cells_alt != ore_cells_default,
		"offset-9999 veins=%d default veins=%d (layouts differ)" % [
			ore_cells_alt.size(), ore_cells_default.size()])
	GameState.current_config = WorldConfig.new(
		{"generation": {"tree_density": 0.0, "bush_density": 0.0}})
	world.setup(777)
	_check("density_settings", _count_blocks(world, "wood") == 0
		and _count_blocks(world, "berry_bush") == 0)
	GameState.current_config = original_config
	_check("world_restored_after_config_tests", root.load_game())

	# --- Character traits/roles affect the player ---
	var default_speed: float = player.effective_mine_speed()
	player.apply_character({"appearance": "umber", "traits": ["hardy", "miner"], "role": "warden"})
	_check("character_traits_apply", absf(player.max_health - 140.0) < 0.01
		and player.effective_mine_speed() > default_speed * 1.19,
		"max_health=%.0f speed %.2f→%.2f" % [player.max_health, default_speed, player.effective_mine_speed()])
	player.apply_character(GameState.current_character)

	# --- Enemy registry and data-driven spawning (v0.5) ---
	# Clear any threats left from earlier phases before spawning test enemies.
	for t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(t):
			t.queue_free()
	await get_tree().process_frame

	# Fix 16: use root's shared registry instances instead of creating duplicates.
	var enemy_reg = root._enemy_registry
	_check("enemies_json_loads", enemy_reg.live_defs().size() == 3,
		"%d live defs" % enemy_reg.live_defs().size())

	var slime_node: Node = root.spawn_enemy_for_test("surface_slime")
	_check("surface_slime_spawns", slime_node != null
		and str(slime_node.enemy_id) == "surface_slime",
		"id=%s" % (str(slime_node.enemy_id) if slime_node != null else "null"))

	var crawler_node: Node = root.spawn_enemy_for_test("cave_crawler")
	_check("cave_crawler_spawns", crawler_node != null
		and str(crawler_node.enemy_id) == "cave_crawler",
		"family=%s" % (str(crawler_node.family) if crawler_node != null else "null"))

	var raider_node: Node = root.spawn_enemy_for_test("raider_basic")
	_check("raider_basic_spawns", raider_node != null
		and str(raider_node.enemy_id) == "raider_basic",
		"family=%s" % (str(raider_node.family) if raider_node != null else "null"))

	# Kill slime with forced 1.0 drop chance; all drops should land.
	var inv_before: int = player.inventory.total()
	if slime_node != null and is_instance_valid(slime_node):
		slime_node.drop_chance_override = 1.0
		slime_node.take_hit(99)
	await get_tree().process_frame
	_check("enemy_drop_on_death", player.inventory.total() > inv_before,
		"inventory total %d→%d" % [inv_before, player.inventory.total()])

	# Serialize/apply round-trip: raider_basic enemy_id must survive.
	if crawler_node != null and is_instance_valid(crawler_node):
		crawler_node.queue_free()
	await get_tree().process_frame
	var serialized_threats: Array = root.serialize_threats()
	root.apply_threats(serialized_threats)
	var raider_restored := false
	for t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(t) and not t.is_queued_for_deletion() \
				and str(t.enemy_id) == "raider_basic":
			raider_restored = true
	_check("save_load_enemy_id", raider_restored,
		"raider_basic found after serialize/apply")

	# Fix 17a: save/load round-trip of a raider_basic preserves hall_dps > 0 and max_hp.
	var raider_hall_dps_ok := false
	var raider_max_hp_ok := false
	for t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(t) and not t.is_queued_for_deletion() \
				and str(t.enemy_id) == "raider_basic":
			raider_hall_dps_ok = t.hall_dps > 0.0
			raider_max_hp_ok = t.max_hp > 0
			break
	_check("raider_save_load_hall_dps_and_max_hp", raider_hall_dps_ok and raider_max_hp_ok,
		"hall_dps_ok=%s max_hp_ok=%s" % [raider_hall_dps_ok, raider_max_hp_ok])

	# --- Progression MVP: XP, player level, base levels, population cap ---

	# Fix 16: use root's shared registry instance.
	var prog_reg = root._progression_registry
	_check("progression_jsons_load",
		prog_reg.base_levels_ordered().size() == 6
		and prog_reg.xp_event("block_mined").get("xp_type") == "labor",
		"base_levels=%d block_mined_type=%s" % [
			prog_reg.base_levels_ordered().size(),
			str(prog_reg.xp_event("block_mined").get("xp_type", "?"))])

	# Level-curve: xp_to_next(1) must equal the base value of 100.
	_check("xp_to_next_level_1", prog_reg.xp_to_next(1) == 100,
		"xp_to_next(1)=%d" % prog_reg.xp_to_next(1))

	# award_xp("block_mined") increases labor XP.
	var labor_before: int = int(root.xp_totals.get("labor", 0))
	root.award_xp("block_mined")
	_check("award_xp_increases_labor_xp",
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
	_check("base_level_advances_to_hamlet", root.base_level == 2,
		"base_level=%d" % root.base_level)

	# population_cap reflects base_level from registry data.
	root.base_level = 1   # camp -> cap 4
	_check("population_cap_at_camp", root.effective_population_cap() == 4,
		"cap=%d" % root.effective_population_cap())
	root.base_level = 2   # hamlet -> cap 6
	_check("population_cap_at_hamlet", root.effective_population_cap() == 6,
		"cap=%d" % root.effective_population_cap())
	root.base_level = 3   # village -> data cap 16 clamps to POPULATION_MAX
	_check("population_cap_at_village", root.effective_population_cap() == root.POPULATION_MAX,
		"cap=%d" % root.effective_population_cap())

	# Growth is gated by the effective cap: at camp (cap 4) a thriving dawn
	# does not grow population past the cap. _update_population is called
	# directly so the settlement tick cannot auto-advance the level mid-check.
	root.base_level = 1
	hall.population = 4
	hall.stockpile["food"] = 100
	root._update_population({"eaten": 4, "needed": 4}, 80.0)
	_check("population_growth_gated_by_cap", hall.population == 4,
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
	_check("save_load_round_trips_progression",
		prog_saved and prog_loaded
		and root.base_level == prog_base_save
		and int(root.xp_totals.get("labor", 0)) == 77,
		"base_level=%d labor_xp=%d" % [root.base_level, int(root.xp_totals.get("labor", 0))])

	# --- Ancestry Phase B: registry loads + player_effects wired ---

	# Registry loads all 12 ancestries; phase_b_ids returns exactly 5.
	# Fix 16: use root's shared registry instance.
	var ancestry_reg = root._ancestry_registry
	_check("ancestries_json_loads_via_registry", ancestry_reg.all_count() == 12,
		"%d ancestries loaded" % ancestry_reg.all_count())
	_check("ancestry_phase_b_ids_count", ancestry_reg.phase_b_ids().size() == 5,
		"phase_b_ids=%s" % str(ancestry_reg.phase_b_ids()))

	# Dwarf: 0.9x move speed and 1.2x stone/ore mining vs baseline defaults.
	player.apply_character(GameState.current_character)
	var baseline_move_mult: float = player.ancestry_move_mult  # 1.0 after reset
	var baseline_mine_mult: float = player.stone_ore_mine_mult  # 1.0 after reset
	root.apply_ancestry_for_species("dwarf")
	_check("dwarf_move_speed_09x", absf(player.ancestry_move_mult - 0.9 * baseline_move_mult) < 0.001,
		"ancestry_move_mult=%.3f (expected %.3f)" % [player.ancestry_move_mult, 0.9 * baseline_move_mult])
	_check("dwarf_stone_ore_mining_12x", absf(player.stone_ore_mine_mult - 1.2 * baseline_mine_mult) < 0.001,
		"stone_ore_mine_mult=%.3f (expected %.3f)" % [player.stone_ore_mine_mult, 1.2 * baseline_mine_mult])

	# Orc: max health rises by exactly 25 above the trait/role baseline.
	player.apply_character(GameState.current_character)
	var baseline_max_health: float = player.max_health
	root.apply_ancestry_for_species("orc")
	_check("orc_health_bonus_25", absf(player.max_health - (baseline_max_health + 25.0)) < 0.01,
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
	_check("human_learning_mult_xp", human_gain >= baseline_gain,
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
	_check("human_20x_block_mined_labor_xp", _baseline20 == 20 and _human20 >= 21,
		"baseline=%d human=%d" % [_baseline20, _human20])

	# Unknown/legacy species: all ancestry multipliers stay at their safe defaults.
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species("unknown_legacy_species")
	_check("unknown_species_at_baseline",
		absf(player.ancestry_move_mult - 1.0) < 0.001
		and absf(player.ancestry_jump_mult - 1.0) < 0.001
		and absf(player.stone_ore_mine_mult - 1.0) < 0.001
		and absf(player.learning_speed_mult - 1.0) < 0.001,
		"move=%.3f jump=%.3f mine=%.3f learn=%.3f" % [player.ancestry_move_mult,
			player.ancestry_jump_mult, player.stone_ore_mine_mult, player.learning_speed_mult])

	# Fix 17b: elf ancestry yields ancestry_jump_mult > 1.0 (via jump_bonus 0.15).
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species("elf")
	_check("elf_ancestry_jump_mult_gt_1", player.ancestry_jump_mult > 1.0,
		"ancestry_jump_mult=%.3f" % player.ancestry_jump_mult)

	# Fix 17c: goblin ancestry yields max_health < the no-ancestry baseline.
	player.apply_character(GameState.current_character)
	var _goblin_baseline_health: float = player.max_health
	root.apply_ancestry_for_species("goblin")
	_check("goblin_ancestry_max_health_lt_baseline", player.max_health < _goblin_baseline_health,
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
	_check("underground_survives_dawn", _ug_alive and _surf_freed,
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
	_check("cave_spawns_respect_peaceful_rule", _cave_count == 0,
		"cave_count=%d" % _cave_count)
	_rules_f["darkness_increases_enemies"] = true

	# --- Wave A: ancestry detail panel text (v0.6) ---
	var _ancestry_detail_scr := preload("res://scripts/data/ancestry_detail.gd")

	# (a) Dwarf detail text contains its mining bonus and its constraint.
	var _detail_reg = root._ancestry_registry
	var _dwarf_anc: Dictionary = _detail_reg.get_ancestry("dwarf")
	var _dwarf_text: String = _ancestry_detail_scr.build_panel_text(_dwarf_anc, true)
	_check("ancestry_detail_dwarf_mining_and_constraint",
		"Mining" in _dwarf_text and "Slower movement" in _dwarf_text,
		"panel(100)=%s" % _dwarf_text.left(100))

	# (b) A non-live ancestry id produces a planned/reserved label.
	var _dd_anc: Dictionary = _detail_reg.get_ancestry("deep_dwarf")
	var _dd_text: String = _ancestry_detail_scr.build_panel_text(_dd_anc, false)
	_check("ancestry_detail_nonlive_planned_label",
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
	_check("world_settings_axis_help_covers_all_axes", _all_axes,
		"axis_help keys=%s" % str(_axis_help_d.keys()))

	# (d) dark_frontier preset summary is non-empty and mentions at least one deviation.
	var _df_descs: Dictionary = _ui_help_d.get("preset_descriptions", {})
	var _df_entry: Dictionary = _df_descs.get("dark_frontier", {})
	var _df_devs: String = str(_df_entry.get("deviations", ""))
	_check("world_preset_summary_dark_frontier_nonempty",
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
	_check("wave_b_char_a_distinct_inventory",
		int(_ba_reload.get("carried_inventory", {}).get("dirt", 0)) == 5
		and not _ba_reload.get("carried_inventory", {}).has("stone"),
		"char_a inv=%s" % str(_ba_reload.get("carried_inventory", {})))
	_check("wave_b_char_b_distinct_inventory",
		int(_bb_reload.get("carried_inventory", {}).get("stone", 0)) == 7
		and not _bb_reload.get("carried_inventory", {}).has("dirt"),
		"char_b inv=%s" % str(_bb_reload.get("carried_inventory", {})))

	# (b) Char A's inventory survives entering a second world (state is on the character).
	var _b_world2_id: String = GameState.create_world(WorldConfig.from_preset("folk_kingdom"))
	var _ba2: Dictionary = GameState.get_character(str(_b_char_a["id"]))
	_check("wave_b_inventory_survives_second_world",
		int(_ba2.get("carried_inventory", {}).get("dirt", 0)) == 5,
		"char_a after second world=%s" % str(_ba2.get("carried_inventory", {})))
	GameState.delete_world(_b_world2_id)

	# (c) Role starter items granted once — items_granted flag prevents duplication.
	# The current character already went through _grant_role_items() in _ready().
	var _curr_cid: String = str(GameState.current_character.get("id", ""))
	var _curr_ch: Dictionary = GameState.get_character(_curr_cid)
	_check("wave_b_items_granted_after_ready",
		bool(_curr_ch.get("items_granted", false)),
		"items_granted=%s" % str(_curr_ch.get("items_granted", false)))
	var _dirt_pre_regrant: int = player.inventory.count("dirt")
	root._grant_role_items()   # second call — should be a no-op due to flag
	_check("wave_b_no_duplicate_role_items",
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
	_check("wave_b_legacy_char_no_carried_field",
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
	_check("wave_b_legacy_migration_extracts_inventory",
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
	_check("fq00_legacy_migration_marks_items_granted",
		bool(_fq00_after_migration.get("items_granted", false))
		and int(player.inventory.count("dirt")) == 4,
		"items_granted=%s dirt=%d" % [
			str(_fq00_after_migration.get("items_granted", false)),
			player.inventory.count("dirt")])
	var _fq00_dirt_after_migration: int = player.inventory.count("dirt")
	root._grant_role_items()   # homesteader would add dirt+10/wood+5 if this were not a no-op
	_check("fq00_no_duplicate_role_items_after_legacy_migration",
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
	_check("wave_c_toggle_inventory_bound", _inv_has_device,
		"toggle_inventory has a device event")

	# (f) Panel opens/closes and content reflects a known inventory count.
	_check("wave_c_inv_panel_starts_closed", not hud.inventory_panel_open())
	hud.toggle_inventory_panel()
	_check("wave_c_inv_panel_opens", hud.inventory_panel_open())
	hud.toggle_inventory_panel()
	_check("wave_c_inv_panel_closes", not hud.inventory_panel_open())
	# Inject a known inventory count, open panel, verify label text.
	player.inventory.from_dict({"dirt": 13})
	player.inventory_changed.emit()
	hud.toggle_inventory_panel()
	var _inv_text: String = hud.get_inventory_panel_text()
	_check("wave_c_inv_panel_reflects_count",
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
	var _e_bush: Variant = _find_block(world, world.hall_info["center_cell"], "berry_bush")
	_check("wave_e_bush_found", _e_bush != null)
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
	_check("wave_e_support_mine_removes_bush",
		_e_bush == null or world.block_at(_e_bush as Vector2i) == "air",
		"block_at_bush=%s" % (world.block_at(_e_bush as Vector2i) if _e_bush != null else "n/a"))
	_check("wave_e_support_mine_yields_food",
		_e_bush == null or player.inventory.count("food") > _e_food_before,
		"food %d→%d" % [_e_food_before, player.inventory.count("food")])
	_check("wave_e_bush_regrow_scheduled",
		_e_bush == null or world.bush_regrow.has(_e_bush as Vector2i),
		"bush_regrow_has=%s" % str(world.bush_regrow.has(_e_bush as Vector2i) if _e_bush != null else "n/a"))

	# (b) Regrowth into unsupported air re-schedules the timer instead of placing a bush.
	# The support is now air; force-expire the regrow timer and check nothing is placed.
	if _e_bush != null:
		world.bush_regrow[_e_bush] = 0.01
		for _ei in range(5):
			await get_tree().process_frame
		_check("wave_e_no_regrow_without_support",
			world.block_at(_e_bush as Vector2i) == "air" and world.bush_regrow.has(_e_bush as Vector2i),
			"block=%s regrow_present=%s" % [world.block_at(_e_bush as Vector2i),
				str(world.bush_regrow.has(_e_bush as Vector2i))])

	# (c) After support is restored, regrowth places the bush normally.
	if _e_bush != null:
		world.place_block(_e_supp, "dirt")  # restore solid support
		world.bush_regrow[_e_bush] = 0.01
		for _ei2 in range(5):
			await get_tree().process_frame
		_check("wave_e_regrows_when_supported", world.block_at(_e_bush as Vector2i) == "berry_bush",
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
		_check("wave_e_load_no_floating_bush",
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

	# Baseline wood frame count without axe (tier 1, no axe) — ordering must hold.
	var _f_wood: Variant = _find_block(world, _f_hall, "wood")
	_check("wave_f_wood_found", _f_wood != null)
	var _f_wood_frames_no_axe := 0
	if _f_wood != null:
		_f_wood_frames_no_axe = await _mine_cell(world, player, _f_wood as Vector2i)
	# (d) Existing hardness ordering still holds without axe: dirt < wood < stone.
	# (Covered by the earlier hardness_orders_mining_time check; this confirms the
	#  baseline wood frames are still > dirt and < stone frame bands.)
	_check("wave_f_wood_baseline_positive", _f_wood_frames_no_axe > 0,
		"wood_frames_no_axe=%d" % _f_wood_frames_no_axe)

	# (e) Crafting the axe via forge_axe consumes stockpile and sets axe_tier = 1.
	hall.stockpile["wood"] = 10
	hall.stockpile["stone"] = 10
	var _f_wood_stock_before: int = int(hall.stockpile.get("wood", 0))
	var _f_stone_stock_before: int = int(hall.stockpile.get("stone", 0))
	var _f_axe_forged: bool = hall.forge_axe(player)
	_check("wave_f_axe_crafted", _f_axe_forged and player.axe_tier == 1,
		"forged=%s axe_tier=%d" % [str(_f_axe_forged), player.axe_tier])
	_check("wave_f_axe_consumes_stockpile",
		int(hall.stockpile.get("wood", 0)) == _f_wood_stock_before - 4
		and int(hall.stockpile.get("stone", 0)) == _f_stone_stock_before - 2,
		"wood %d→%d stone %d→%d" % [_f_wood_stock_before, int(hall.stockpile.get("wood", 0)),
			_f_stone_stock_before, int(hall.stockpile.get("stone", 0))])
	_check("wave_f_axe_no_duplicate_craft", not hall.forge_axe(player),
		"second forge_axe must return false")

	# (f) With axe, wood mines measurably faster than without.
	var _f_wood2: Variant = _find_block(world, _f_hall, "wood")
	var _f_wood_frames_axe := 600
	if _f_wood2 != null:
		_f_wood_frames_axe = await _mine_cell(world, player, _f_wood2 as Vector2i)
	_check("wave_f_axe_speeds_wood",
		_f_wood2 == null or _f_wood_frames_axe < _f_wood_frames_no_axe,
		"frames: no_axe=%d axe=%d" % [_f_wood_frames_no_axe, _f_wood_frames_axe])

	# (g) Stone speed is unaffected by axe (preferred_tool = pick).
	var _f_stone: Variant = _find_block(world, _f_hall, "stone")
	var _f_stone_frames_no_axe := 0
	player.axe_tier = 0
	if _f_stone != null:
		_f_stone_frames_no_axe = await _mine_cell(world, player, _f_stone as Vector2i)
	var _f_stone2: Variant = _find_block(world, _f_hall, "stone")
	var _f_stone_frames_axe := 0
	player.axe_tier = 1
	if _f_stone2 != null:
		_f_stone_frames_axe = await _mine_cell(world, player, _f_stone2 as Vector2i)
	_check("wave_f_axe_no_effect_on_stone",
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
	_check("wave_f_tool_state_round_trips",
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
	_check("wave_f_legacy_tool_tier_migrates_to_dict",
		player.tool_tier == 3 and player.axe_tier == 0,
		"pick=%d axe=%d" % [player.tool_tier, player.axe_tier])
	GameState.current_character = _f_prev_char
	GameState.delete_character(_f_lcid)
	# Restore player state for screenshot.
	player.tool_tier = 2
	player.axe_tier = 1
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species(str(GameState.current_character.get("species", "")))

	# --- FQ-01: player health, damage, healing, and death loop ---

	player.set_physics_process(false)
	# Array box: GDScript lambdas capture locals by value, so a mutable
	# single-element Array is used to observe player_event messages by reference.
	var _fq01_last_msg_box: Array = [""]
	var _fq01_msg_conn := func(msg: String) -> void: _fq01_last_msg_box[0] = msg
	player.player_event.connect(_fq01_msg_conn)

	# (a) i-frames: two take_damage calls back-to-back only apply the first.
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	player.take_damage(10.0)
	var _fq01_health_after_first: float = player.health
	player.take_damage(10.0)
	_check("fq01_iframes_block_same_window_damage",
		absf(player.health - _fq01_health_after_first) < 0.001,
		"health after first=%.1f after second=%.1f" % [_fq01_health_after_first, player.health])

	# (b) forcing the cooldown to 0 lets the next hit land.
	player._hurt_cooldown = 0.0
	var _fq01_health_before_second: float = player.health
	player.take_damage(10.0)
	_check("fq01_second_hit_after_cooldown",
		player.health < _fq01_health_before_second - 0.001,
		"health %.1f -> %.1f" % [_fq01_health_before_second, player.health])

	# (c) eating food heals (clamped) and consumes exactly one food.
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	player.inventory.from_dict({"food": 3})
	player.inventory_changed.emit()
	player.take_damage(30.0)
	var _fq01_health_before_eat: float = player.health
	player._eat_cooldown = 0.0
	player._try_eat_food()
	_check("fq01_eat_food_heals_and_consumes",
		player.health > _fq01_health_before_eat
		and absf(player.health - minf(player.max_health, _fq01_health_before_eat + 25.0)) < 1.0
		and player.inventory.count("food") == 2,
		"health %.1f -> %.1f, food=%d" % [_fq01_health_before_eat, player.health, player.inventory.count("food")])

	# (d) eating at full health is a no-op — no food consumed, health unchanged.
	player.health = player.max_health
	player._eat_cooldown = 0.0
	var _fq01_food_before_noop: int = player.inventory.count("food")
	player._try_eat_food()
	_check("fq01_eat_at_full_health_noop",
		absf(player.health - player.max_health) < 0.001
		and player.inventory.count("food") == _fq01_food_before_noop,
		"health=%.1f food=%d (before=%d)" % [player.health, player.inventory.count("food"), _fq01_food_before_noop])
	player.inventory.from_dict({})
	player.inventory_changed.emit()

	# (e) passive regen only triggers near the hall and clear of threats.
	for _fq01_t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_fq01_t):
			_fq01_t.queue_free()
	await get_tree().process_frame
	var _fq01_hall_center: Vector2 = world.cell_center(world.hall_info["center_cell"])
	player.health = player.max_health - 20.0
	player.global_position = _fq01_hall_center + Vector2(10, -10)
	var _fq01_health_near_before: float = player.health
	for _fq01_i in range(65):
		player._update_passive_regen(1.0 / 60.0)
	_check("fq01_passive_regen_near_hall", player.health > _fq01_health_near_before,
		"health %.2f -> %.2f near hall" % [_fq01_health_near_before, player.health])

	player.health = player.max_health - 20.0
	player.global_position = _fq01_hall_center + Vector2(player._safe_radius_px + 400.0, -10)
	var _fq01_health_far_before: float = player.health
	for _fq01_i2 in range(65):
		player._update_passive_regen(1.0 / 60.0)
	_check("fq01_no_regen_far_from_hall",
		absf(player.health - _fq01_health_far_before) < 0.001,
		"health %.2f -> %.2f far from hall" % [_fq01_health_far_before, player.health])

	# (f) collapse: taking lethal damage loses a floor(fraction) of each stack,
	# then respawns at the hall at full health.
	player.global_position = _fq01_hall_center + Vector2(500, -300)
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	player.inventory.from_dict({"dirt": 8, "stone": 5})
	player.inventory_changed.emit()
	_fq01_last_msg_box[0] = ""
	player.take_damage(9999.0)
	_check("fq01_collapse_respawns_at_hall_with_loss",
		player.global_position.distance_to(_fq01_hall_center + Vector2(-48, -24)) < 1.0
		and absf(player.health - player.max_health) < 0.001
		and player.inventory.count("dirt") == 6
		and player.inventory.count("stone") == 4
		and "collapsed" in str(_fq01_last_msg_box[0]),
		"pos=%s health=%.1f dirt=%d stone=%d msg=%s" % [
			str(player.global_position), player.health,
			player.inventory.count("dirt"), player.inventory.count("stone"), str(_fq01_last_msg_box[0])])
	player.inventory.from_dict({})
	player.inventory_changed.emit()

	# (f2) lootless collapse: with nothing carried, the respawn message must not
	# claim supplies were lost (FQ-01 review fix).
	player.global_position = _fq01_hall_center + Vector2(500, -300)
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	_fq01_last_msg_box[0] = ""
	player.take_damage(9999.0)
	_check("fq01_lootless_collapse_message_honest",
		"collapsed" in str(_fq01_last_msg_box[0])
		and not ("supplies" in str(_fq01_last_msg_box[0])),
		"msg=%s" % str(_fq01_last_msg_box[0]))

	# (g) health save/load round-trip: max_health still reflects ancestry/traits.
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species(str(GameState.current_character.get("species", "")))
	var _fq01_max_health_before: float = player.max_health
	player.health = maxf(1.0, player.max_health - 33.0)
	player._hurt_cooldown = 0.0
	var _fq01_saved_health: float = player.health
	root.save_manager.save_game()
	player.health = player.max_health
	root.load_game()
	_check("fq01_health_save_load_roundtrip",
		absf(player.health - _fq01_saved_health) < 0.001
		and absf(player.max_health - _fq01_max_health_before) < 0.001,
		"health restored=%.1f (expected %.1f), max_health=%.1f (expected %.1f)" % [
			player.health, _fq01_saved_health, player.max_health, _fq01_max_health_before])

	# (h) enemy contact damage is data-driven: runtime contact_damage equals
	# the JSON value scaled by GameState.current_config.difficulty("enemy").
	for _fq01_t2 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_fq01_t2):
			_fq01_t2.queue_free()
	await get_tree().process_frame
	var _fq01_slime_def: Dictionary = root._enemy_registry.get_def("surface_slime")
	var _fq01_slime: Node = root.spawn_enemy_for_test("surface_slime")
	var _fq01_expected_dmg: float = float(_fq01_slime_def.get("contact_damage", 8)) \
		* GameState.current_config.difficulty("enemy")
	_check("fq01_enemy_contact_damage_from_data",
		_fq01_slime != null and absf(_fq01_slime.contact_damage - _fq01_expected_dmg) < 0.001,
		"contact_damage=%.2f expected=%.2f" % [
			_fq01_slime.contact_damage if _fq01_slime != null else -1.0, _fq01_expected_dmg])
	if _fq01_slime != null and is_instance_valid(_fq01_slime):
		_fq01_slime.queue_free()
	await get_tree().process_frame

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

	# --- Screenshot evidence (windowed runs only) ---
	if DisplayServer.get_name() != "headless":
		# Frame the Town Hall and its torches so lighting/shadows are visible.
		player.global_position = world.cell_center(hall_cell) + Vector2(-48, -24)
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		for i in range(20):
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://smoke_screenshot.png")
		print("SMOKE screenshot saved to user://smoke_screenshot.png")

	var failed := 0
	var failed_names: Array = []
	for r in _results:
		if not r[1]:
			failed += 1
			failed_names.append(r[0])
	_write_result_file(failed, failed_names)
	print("SMOKE RESULT: %s (%d/%d passed)" % [
		"PASS" if failed == 0 else "FAIL", _results.size() - failed, _results.size()])
	get_tree().quit(0 if failed == 0 else 1)


func _write_result_file(failed: int, failed_names: Array) -> void:
	var file := FileAccess.open("user://smoke_results.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"result": "PASS" if failed == 0 else "FAIL",
		"passed": _results.size() - failed,
		"total": _results.size(),
		"failed": failed_names,
		"details": _details,
		"timestamp": Time.get_datetime_string_from_system(),
	}, "  "))


func _mine_cell(world: Node2D, player: CharacterBody2D, cell: Vector2i) -> int:
	player.global_position = world.cell_center(cell) + Vector2(0, -32.0)
	var frames := 0
	var delta := 1.0 / 60.0
	while frames < 600:
		frames += 1
		if player.process_mining(cell, delta):
			return frames
		await get_tree().process_frame
	return frames


func _count_blocks(world: Node2D, block_id: String) -> int:
	var count := 0
	for cell in world.cells:
		if world.cells[cell] == block_id:
			count += 1
	return count


func _block_cells(world: Node2D, block_id: String) -> Array:
	var out: Array = []
	for cell in world.cells:
		if world.cells[cell] == block_id:
			out.append(cell)
	out.sort()
	return out


## Finds a mineable cell of the given type, preferring cells away from the hall.
func _find_block(world: Node2D, near: Vector2i, block_id: String, tool_tier: int = 1) -> Variant:
	for radius in range(8, 60):
		for dx in range(-radius, radius + 1):
			for dy in range(-12, 30):
				var cell := near + Vector2i(dx, dy)
				if world.block_at(cell) == block_id and world.can_mine(cell, tool_tier):
					return cell
	return null
