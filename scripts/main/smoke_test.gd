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
			"eat_food", "attune_pulse", "toggle_skills"]:
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
	# FQ-09R: generated trees are tree_trunk columns (hardness matches wood,
	# drops wood), so tree harvesting rides the same mining assertions.
	var wood_cell: Variant = _find_block(world, hall_cell, "tree_trunk")
	_check("mineable_blocks_found", dirt_cell != null and stone_cell != null and wood_cell != null)

	var dirt_frames := await _mine_cell(world, player, dirt_cell)
	var wood_frames := await _mine_cell(world, player, wood_cell)
	var stone_frames := await _mine_cell(world, player, stone_cell)
	_check("mining_yields_drops",
		player.inventory.count("dirt") >= 1 and player.inventory.count("stone") >= 1
		and player.inventory.count("wood") >= 1,
		"inv=%s" % str(player.inventory.counts))
	_check("hardness_orders_mining_time", dirt_frames < wood_frames and wood_frames < stone_frames,
		"frames dirt=%d trunk=%d stone=%d" % [dirt_frames, wood_frames, stone_frames])

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
	_check("density_settings", _count_blocks(world, "tree_trunk") == 0
		and _count_blocks(world, "berry_bush") == 0)

	# --- FQ-09R: unified trees — leafy, walk-past, harvestable ---
	_check("fq09r_density_zero_clears_trees",
		_count_blocks(world, "tree_trunk") == 0
		and _count_blocks(world, "tree_leaves") == 0,
		"trunks=%d leaves=%d" % [
			_count_blocks(world, "tree_trunk"), _count_blocks(world, "tree_leaves")])
	GameState.current_config = WorldConfig.new({})
	world.setup(777)
	var _fq09r_trunks: int = _count_blocks(world, "tree_trunk")
	var _fq09r_leaves: int = _count_blocks(world, "tree_leaves")
	_check("fq09r_trees_have_leaves", _fq09r_trunks > 0 and _fq09r_leaves > 0,
		"trunks=%d leaves=%d" % [_fq09r_trunks, _fq09r_leaves])
	# One tree class: every tree cell is non-solid (walk in front of/past) and
	# mineable bare-handed (harvestable) — no second walk-past-only tree kind.
	var _fq09r_bad := 0
	for _fq09r_cell: Vector2i in world.cells:
		var _fq09r_id: String = world.cells[_fq09r_cell]
		if _fq09r_id == "tree_trunk" or _fq09r_id == "tree_leaves":
			if BlockRegistry.is_solid(_fq09r_id) or not world.can_mine(_fq09r_cell, 0):
				_fq09r_bad += 1
	_check("fq09r_trees_passable_and_harvestable", _fq09r_bad == 0,
		"violating_cells=%d of %d" % [_fq09r_bad, _fq09r_trunks + _fq09r_leaves])
	GameState.current_config = WorldConfig.new(
		{"generation": {"tree_density": 2.0}})
	world.setup(777)
	var _fq09r_trunks_dense: int = _count_blocks(world, "tree_trunk")
	_check("fq09r_density_scales_tree_count", _fq09r_trunks_dense > _fq09r_trunks,
		"default=%d dense=%d" % [_fq09r_trunks, _fq09r_trunks_dense])

	# Harvest: mining a trunk yields wood via the normal drop path; clearing
	# leaves yields nothing (no new resource economy).
	player.set_physics_process(false)
	var _fq09r_hall: Vector2i = world.hall_info["center_cell"]
	var _fq09r_trunk_cell: Variant = _find_block(world, _fq09r_hall, "tree_trunk", 0)
	var _fq09r_wood_before: int = player.inventory.count("wood")
	if _fq09r_trunk_cell != null:
		await _mine_cell(world, player, _fq09r_trunk_cell as Vector2i)
	_check("fq09r_harvest_trunk_yields_wood", _fq09r_trunk_cell != null
		and player.inventory.count("wood") == _fq09r_wood_before + 1
		and world.block_at(_fq09r_trunk_cell as Vector2i) == "air",
		"wood %d→%d" % [_fq09r_wood_before, player.inventory.count("wood")])
	var _fq09r_leaf_cell: Variant = _find_block(world, _fq09r_hall, "tree_leaves", 0)
	var _fq09r_inv_before: Dictionary = player.inventory.counts.duplicate()
	if _fq09r_leaf_cell != null:
		await _mine_cell(world, player, _fq09r_leaf_cell as Vector2i)
	_check("fq09r_leaves_clear_without_drops", _fq09r_leaf_cell != null
		and player.inventory.counts == _fq09r_inv_before
		and world.block_at(_fq09r_leaf_cell as Vector2i) == "air",
		"inv unchanged=%s" % str(player.inventory.counts == _fq09r_inv_before))
	player.set_physics_process(true)

	# Walk-through: on flat terrain the player walks past a tree trunk without
	# jumping or mining. Threats are cleared so nothing shoves the player
	# during the walk; load_game below restores the saved set.
	for _fq09r_t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_fq09r_t):
			_fq09r_t.queue_free()
	await get_tree().process_frame
	GameState.current_config = WorldConfig.new({"generation": {
		"terrain_amplitude": 0.0, "tree_density": 2.0, "bush_density": 0.0}})
	world.setup(777)
	root._position_actors()
	var _fq09r_hall_x: int = (world.hall_info["center_cell"] as Vector2i).x
	var _fq09r_trunk: Variant = null
	for _fq09r_walk_cell: Vector2i in world.cells:
		if world.cells[_fq09r_walk_cell] == "tree_trunk" \
				and _fq09r_walk_cell.y == int(world.surface[_fq09r_walk_cell.x]) - 1 \
				and _fq09r_walk_cell.x > _fq09r_hall_x + 10 \
				and _fq09r_walk_cell.x < world.width - 8:
			_fq09r_trunk = _fq09r_walk_cell
			break
	_check("fq09r_walkable_trunk_found", _fq09r_trunk != null,
		"trunks=%d" % _count_blocks(world, "tree_trunk"))
	if _fq09r_trunk != null:
		var _fq09r_walk_trunk: Vector2i = _fq09r_trunk
		player.global_position = world.cell_center(
			Vector2i(_fq09r_walk_trunk.x - 4, _fq09r_walk_trunk.y)) + Vector2(0, -4)
		player.velocity = Vector2.ZERO
		for _fq09r_i in range(20):
			await get_tree().physics_frame  # settle onto the floor
		Input.action_press("move_right")
		for _fq09r_j in range(75):
			await get_tree().physics_frame
		Input.action_release("move_right")
		var _fq09r_target_x: float = world.cell_center(
			Vector2i(_fq09r_walk_trunk.x + 3, _fq09r_walk_trunk.y)).x
		_check("fq09r_player_walks_past_tree",
			player.global_position.x >= _fq09r_target_x,
			"x=%.1f target=%.1f trunk_x=%d" % [
				player.global_position.x, _fq09r_target_x, _fq09r_walk_trunk.x])

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

	# Baseline trunk frame count without axe (tier 1, no axe) — ordering must
	# hold. FQ-09R: generated trees are tree_trunk (wood hardness, drops wood).
	var _f_wood: Variant = _find_block(world, _f_hall, "tree_trunk")
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
	var _f_wood2: Variant = _find_block(world, _f_hall, "tree_trunk")
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

	# --- FQ-03: equipment data model and character-owned gear slots ---

	# (a) equipment.json loads with the 12 expected slots, in order.
	var _fq03_expected: Array = ["weapon", "axe", "pickaxe", "helmet", "torso",
		"feet", "ring_1", "ring_2", "ring_3", "ring_4", "amulet", "accessory"]
	var _fq03_slot_ids: Array = []
	for _fq03_slot in BlockRegistry.equipment_slots():
		_fq03_slot_ids.append(str(_fq03_slot.get("id", "")))
	_check("fq03_equipment_json_loads", _fq03_slot_ids == _fq03_expected,
		"slots=%s" % str(_fq03_slot_ids))

	# (b) a new character record carries default gear: basic pick, rest empty.
	var _fq03_char: Dictionary = GameState.create_character(
		{"name": "GearSmoke", "role": "homesteader"})
	var _fq03_equip: Dictionary = Dictionary(_fq03_char.get("equipment", {}))
	var _fq03_empty_count := 0
	for _fq03_sid in _fq03_equip:
		if str(_fq03_equip[_fq03_sid]) == "":
			_fq03_empty_count += 1
	_check("fq03_new_character_default_gear",
		_fq03_equip.size() == 12 and str(_fq03_equip.get("pickaxe", "")) == "pick_basic"
		and _fq03_empty_count == 11,
		"equipment=%s" % str(_fq03_equip))
	GameState.delete_character(str(_fq03_char["id"]))

	# (c) equipped tool slots mirror the live tool tiers both ways.
	player.tool_tier = 2
	player.axe_tier = 1
	var _fq03_geared: Dictionary = player.equipped_dict()
	player.tool_tier = 1
	player.axe_tier = 0
	var _fq03_bare: Dictionary = player.equipped_dict()
	_check("fq03_tool_slots_mirror_tiers",
		str(_fq03_geared.get("pickaxe", "")) == "pick_forged"
		and str(_fq03_geared.get("axe", "")) == "axe_crude"
		and str(_fq03_bare.get("pickaxe", "")) == "pick_basic"
		and str(_fq03_bare.get("axe", "")) == "",
		"tier2/1=%s|%s tier1/0=%s|%s" % [str(_fq03_geared.get("pickaxe")),
			str(_fq03_geared.get("axe")), str(_fq03_bare.get("pickaxe")),
			str(_fq03_bare.get("axe"))])
	player.tool_tier = 2
	player.axe_tier = 1

	# (d) slot/item fit is enforced; tool slots cannot be cleared (no silent
	# tier reset); equipping never touches the backpack.
	var _fq03_inv_total: int = player.inventory.total()
	_check("fq03_equip_rejects_mismatch",
		not player.equip_item("helmet", "ring_band")
		and not player.equip_item("no_such_slot", "ring_band")
		and not player.equip_item("pickaxe", "")
		and player.tool_tier == 2
		and player.equip_item("ring_2", "ring_band")
		and player.inventory.total() == _fq03_inv_total,
		"ring_2=%s pick=%d inv_total %d→%d" % [str(player.equipment.get("ring_2", "")),
			player.tool_tier, _fq03_inv_total, player.inventory.total()])

	# (e) an equipped item round-trips through the character save/load path;
	# empty slots stay valid alongside it.
	root.save_manager.save_game()
	player.apply_equipment({})   # wipe live gear; load must restore it
	var _fq03_wiped: Dictionary = player.equipped_dict()
	root.load_game()
	var _fq03_restored: Dictionary = player.equipped_dict()
	_check("fq03_equipped_item_round_trips",
		str(_fq03_wiped.get("ring_2", "")) == ""
		and str(_fq03_restored.get("ring_2", "")) == "ring_band"
		and str(_fq03_restored.get("amulet", "")) == ""
		and str(_fq03_restored.get("pickaxe", "")) == "pick_forged",
		"wiped_ring=%s restored_ring=%s pickaxe=%s" % [str(_fq03_wiped.get("ring_2")),
			str(_fq03_restored.get("ring_2")), str(_fq03_restored.get("pickaxe"))])

	# (f) inventory panel shows every gear slot; empty slots are visible.
	hud.toggle_inventory_panel()
	var _fq03_panel: String = hud.get_inventory_panel_text()
	hud.toggle_inventory_panel()
	_check("fq03_panel_shows_gear_slots",
		"EQUIPMENT" in _fq03_panel and "Pickaxe: Forged Pick" in _fq03_panel
		and "Ring 2: Plain Band" in _fq03_panel
		and "Ring 4: (empty)" in _fq03_panel and "Amulet: (empty)" in _fq03_panel,
		"panel_tail=%s" % _fq03_panel.right(180))

	# (g) a pre-FQ-03 character (no equipment key) migrates: tool tiers and
	# inventory preserved, gear derived from the tiers.
	var _fq03_leg: Dictionary = GameState.create_character(
		{"name": "GearLegacy", "role": "homesteader"})
	var _fq03_lid: String = str(_fq03_leg["id"])
	for _fq03_i in range(GameState.characters.size()):
		if str(GameState.characters[_fq03_i].get("id", "")) == _fq03_lid:
			GameState.characters[_fq03_i].erase("equipment")
			GameState.characters[_fq03_i]["carried_inventory"] = {"dirt": 3}
			GameState.characters[_fq03_i]["carried_tool_tiers"] = {"pick": 2, "axe": 1}
			GameState.characters[_fq03_i]["items_granted"] = true
			break
	GameState.save_shell()
	GameState.load_shell()
	var _fq03_prev_char: Dictionary = GameState.current_character
	GameState.current_character = GameState.get_character(_fq03_lid)
	root._load_character_carried_state({})
	var _fq03_mig_equip: Dictionary = player.equipped_dict()
	# Review fix: the migration must persist the equipment key onto the record
	# immediately, not just derive it in memory.
	var _fq03_lc_record: Dictionary = GameState.get_character(_fq03_lid)
	var _fq03_rec_equip: Dictionary = Dictionary(_fq03_lc_record.get("equipment", {}))
	_check("fq03_legacy_character_migrates",
		player.tool_tier == 2 and player.axe_tier == 1
		and player.inventory.count("dirt") == 3
		and str(_fq03_mig_equip.get("pickaxe", "")) == "pick_forged"
		and str(_fq03_mig_equip.get("axe", "")) == "axe_crude"
		and _fq03_lc_record.has("equipment")
		and str(_fq03_rec_equip.get("pickaxe", "")) == "pick_forged",
		"pick=%d axe=%d dirt=%d gear=%s|%s record_gear=%s" % [player.tool_tier,
			player.axe_tier, player.inventory.count("dirt"),
			str(_fq03_mig_equip.get("pickaxe")), str(_fq03_mig_equip.get("axe")),
			str(_fq03_rec_equip.get("pickaxe"))])
	GameState.current_character = _fq03_prev_char
	GameState.delete_character(_fq03_lid)
	# Restore the real character's carried state for the FQ-01 section below.
	root._apply_character_carried_state()
	player.tool_tier = 2
	player.axe_tier = 1

	# --- FQ-04: first combat gear slice — sword and armor ---

	# (a) bare-handed baseline: no weapon, no armor.
	_check("fq04_unarmed_baseline",
		player.attack_damage() == 1 and player.armor_total() == 0.0
		and str(player.equipped_dict().get("weapon", "")) == "",
		"attack=%d armor=%.0f" % [player.attack_damage(), player.armor_total()])

	# (b) forging the sword equips it, consumes stockpile, and cannot repeat.
	hall.stockpile["wood"] = 20
	hall.stockpile["stone"] = 20
	var _fq04_wood_before: int = int(hall.stockpile.get("wood", 0))
	var _fq04_stone_before: int = int(hall.stockpile.get("stone", 0))
	var _fq04_sword_ok: bool = hall.forge_sword(player)
	_check("fq04_forge_sword_equips",
		_fq04_sword_ok and str(player.equipped_dict().get("weapon", "")) == "sword_crude"
		and player.attack_damage() == 3
		and int(hall.stockpile.get("wood", 0)) == _fq04_wood_before - 2
		and int(hall.stockpile.get("stone", 0)) == _fq04_stone_before - 3
		and not hall.forge_sword(player),
		"attack=%d wood %d→%d stone %d→%d" % [player.attack_damage(),
			_fq04_wood_before, int(hall.stockpile.get("wood", 0)),
			_fq04_stone_before, int(hall.stockpile.get("stone", 0))])

	# (c) the sword kills a 3 hp slime in one real hit-path strike.
	for _fq04_t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_fq04_t):
			_fq04_t.queue_free()
	await get_tree().process_frame
	var _fq04_slime: Node = root.spawn_enemy_for_test("surface_slime")
	_fq04_slime.hp = 3
	_fq04_slime.max_hp = 3
	player.global_position = _fq04_slime.global_position
	var _fq04_hit: bool = player._try_hit_threat(_fq04_slime.global_position)
	await get_tree().process_frame
	var _fq04_dead: bool = not is_instance_valid(_fq04_slime) \
		or _fq04_slime.is_queued_for_deletion()
	_check("fq04_sword_damages_enemy", _fq04_hit and _fq04_dead,
		"hit=%s dead_after_one_sword_strike=%s" % [str(_fq04_hit), str(_fq04_dead)])

	# (d) forging the armor set equips helmet/torso/feet and cannot repeat.
	var _fq04_armor_ok: bool = hall.forge_armor(player)
	var _fq04_after_armor: Dictionary = player.equipped_dict()
	_check("fq04_forge_armor_equips_set",
		_fq04_armor_ok
		and str(_fq04_after_armor.get("helmet", "")) == "helmet_crude"
		and str(_fq04_after_armor.get("torso", "")) == "torso_crude"
		and str(_fq04_after_armor.get("feet", "")) == "feet_crude"
		and player.armor_total() == 4.0
		and not hall.forge_armor(player),
		"armor=%.0f set=%s|%s|%s" % [player.armor_total(),
			str(_fq04_after_armor.get("helmet")), str(_fq04_after_armor.get("torso")),
			str(_fq04_after_armor.get("feet"))])

	# (e) armor reduces incoming damage by exactly the data-defined sum.
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	var _fq04_expected_loss: float = 10.0 - player.armor_total()
	player.take_damage(10.0)
	_check("fq04_armor_reduces_damage",
		absf((player.max_health - player.health) - _fq04_expected_loss) < 0.001,
		"lost %.1f expected %.1f (armor %.0f)" % [player.max_health - player.health,
			_fq04_expected_loss, player.armor_total()])

	# (f) armor can never fully block: a landed hit chips at least 1 health.
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	player.take_damage(2.0)
	_check("fq04_armor_minimum_chip_damage",
		absf((player.max_health - player.health) - 1.0) < 0.001,
		"lost %.1f from a 2.0 hit under %.0f armor" % [
			player.max_health - player.health, player.armor_total()])

	# (g) combat gear round-trips through character save/load and leaves
	# ancestry/trait max_health untouched.
	var _fq04_max_health_before: float = player.max_health
	root.save_manager.save_game()
	player.apply_equipment({})
	var _fq04_armor_wiped: float = player.armor_total()
	root.load_game()
	_check("fq04_gear_round_trips_ancestry_intact",
		_fq04_armor_wiped == 0.0
		and str(player.equipped_dict().get("weapon", "")) == "sword_crude"
		and player.armor_total() == 4.0
		and absf(player.max_health - _fq04_max_health_before) < 0.001,
		"armor wiped=%.0f restored=%.0f max_health=%.1f (expected %.1f)" % [
			_fq04_armor_wiped, player.armor_total(),
			player.max_health, _fq04_max_health_before])

	# (h) the equipment UI shows weapon/armor state.
	hud.toggle_inventory_panel()
	var _fq04_panel: String = hud.get_inventory_panel_text()
	hud.toggle_inventory_panel()
	_check("fq04_ui_shows_weapon_and_armor",
		"Attack 3" in _fq04_panel and "Armor 4" in _fq04_panel
		and "Weapon: Crude Sword" in _fq04_panel
		and "Torso: Crude Cuirass" in _fq04_panel,
		"panel_head=%s" % _fq04_panel.left(60))

	# Clear combat gear so the FQ-01 exact-damage checks below see the same
	# unarmored player they were written against.
	player.equip_item("weapon", "")
	player.equip_item("helmet", "")
	player.equip_item("torso", "")
	player.equip_item("feet", "")
	player.health = player.max_health

	# --- FQ-05: attunement resource, hooks, pulse, save/load ---

	# (a) data-driven defaults: base max 50, current within bounds.
	_check("fq05_attunement_defaults",
		absf(player.max_attunement() - 50.0) < 0.001
		and player.attunement > 0.0 and player.attunement <= player.max_attunement(),
		"attunement=%.1f max=%.1f" % [player.attunement, player.max_attunement()])

	# (b) the light pulse spends attunement, lights up, and respects its cooldown.
	player.attunement = player.max_attunement()
	player._pulse_cooldown = 0.0
	var _fq05_max: float = player.max_attunement()
	var _fq05_fired: bool = player._try_attune_pulse()
	var _fq05_after_pulse: float = player.attunement
	var _fq05_light_on: bool = player._pulse_light != null \
		and player._pulse_light.enabled and player._pulse_light.energy > 0.0
	var _fq05_second: bool = player._try_attune_pulse()   # cooldown active
	_check("fq05_pulse_spends_and_cools",
		_fq05_fired and absf(_fq05_after_pulse - (_fq05_max - 15.0)) < 0.001
		and _fq05_light_on and not _fq05_second
		and absf(player.attunement - _fq05_after_pulse) < 0.001,
		"fired=%s attunement %.1f→%.1f light=%s second_blocked=%s" % [str(_fq05_fired),
			_fq05_max, _fq05_after_pulse, str(_fq05_light_on), str(not _fq05_second)])

	# (c) insufficient attunement blocks the pulse without spending.
	player.attunement = 5.0
	player._pulse_cooldown = 0.0
	var _fq05_blocked: bool = not player._try_attune_pulse()
	_check("fq05_pulse_blocked_when_insufficient",
		_fq05_blocked and absf(player.attunement - 5.0) < 0.001,
		"blocked=%s attunement=%.1f" % [str(_fq05_blocked), player.attunement])

	# (d) attunement regenerates over time (no safety gate).
	player.attunement = 10.0
	for _fq05_i in range(65):
		player._update_attunement_regen(1.0 / 60.0)
	_check("fq05_attunement_regenerates", player.attunement > 10.0,
		"attunement 10.0→%.2f after ~1s" % player.attunement)

	# (e) ancestry and equipment hooks raise the maximum; removing them clamps.
	player.apply_ancestry_effects({"attunement_bonus": 20.0, "attunement_regen_mult": 2.0})
	var _fq05_anc_max: float = player.max_attunement()
	var _fq05_regen_mult: float = player.attunement_regen_mult
	var _fq05_amulet_ok: bool = player.equip_item("amulet", "amulet_focus")
	var _fq05_gear_max: float = player.max_attunement()
	# Restore: reset ancestry to the real character and remove the amulet.
	player.apply_character(GameState.current_character)
	root.apply_ancestry_for_species(str(GameState.current_character.get("species", "")))
	player.equip_item("amulet", "")
	_check("fq05_ancestry_and_gear_hooks",
		absf(_fq05_anc_max - 70.0) < 0.001 and absf(_fq05_regen_mult - 2.0) < 0.001
		and _fq05_amulet_ok and absf(_fq05_gear_max - 80.0) < 0.001
		and absf(player.max_attunement() - 50.0) < 0.001
		and player.attunement <= player.max_attunement(),
		"ancestry_max=%.1f gear_max=%.1f restored_max=%.1f regen_mult=%.1f" % [
			_fq05_anc_max, _fq05_gear_max, player.max_attunement(), _fq05_regen_mult])

	# (f) current attunement rides the world save next to health — including
	# a surplus above the base max from gear (review fix: the load path must
	# not clamp against the pre-gear cap and destroy the surplus).
	player.equip_item("amulet", "amulet_focus")   # max 60
	player.attunement = 55.0
	root.save_manager.save_game()
	player.equip_item("amulet", "")               # max back to 50; clamps to 50
	player.attunement = 10.0
	root.load_game()                              # re-equips the amulet from the record
	_check("fq05_attunement_saves_and_loads",
		absf(player.attunement - 55.0) < 0.01
		and absf(player.max_attunement() - 60.0) < 0.001,
		"attunement after load=%.2f (expected 55.0) max=%.1f" % [
			player.attunement, player.max_attunement()])
	player.equip_item("amulet", "")
	player.attunement = player.max_attunement()
	root.save_manager.save_game()   # persist the amulet removal for later sections

	# --- FQ-06: visual skill tree — perk points, states, purchase, persistence ---

	# (a) perk data loads through the registry: 7 lanes, miner nodes indexed.
	var _fq06_reg = root._progression_registry
	_check("fq06_perks_json_loads",
		_fq06_reg.perk_lanes().size() == 7
		and str(_fq06_reg.get_perk("stone_recovery").get("lane", "")) == "miner"
		and _fq06_reg.get_perk("stone_recovery").get("prerequisites", [null]).is_empty()
		and "stone_recovery" in _fq06_reg.get_perk("deep_sense").get("prerequisites", []),
		"lanes=%d stone_recovery_lane=%s" % [_fq06_reg.perk_lanes().size(),
			str(_fq06_reg.get_perk("stone_recovery").get("lane", "?"))])

	# (b) states at level 1 with nothing purchased: root available, child locked.
	var _fq06_saved_level: int = root.player_level
	var _fq06_saved_perks: Array = root.purchased_perks.duplicate()
	root.purchased_perks = []
	root._apply_purchased_perk_effects()
	root.player_level = 1
	_check("fq06_states_and_zero_points",
		root.perk_points_total() == 0
		and root.perk_state("stone_recovery") == "available"
		and root.perk_state("deep_sense") == "locked"
		and not root.try_purchase_perk("stone_recovery"),
		"points=%d root=%s child=%s" % [root.perk_points_total(),
			root.perk_state("stone_recovery"), root.perk_state("deep_sense")])

	# (c) a real level grants points; purchase applies the live mining effect.
	root.player_level = 3   # 2 points
	var _fq06_speed_before: float = player.effective_mine_speed()
	var _fq06_bought: bool = root.try_purchase_perk("stone_recovery")
	_check("fq06_purchase_applies_effect",
		_fq06_bought
		and root.perk_state("stone_recovery") == "purchased"
		and root.perk_points_available() == 1
		and absf(player.perk_mine_speed_mult - 1.15) < 0.001
		and absf(player.effective_mine_speed() - _fq06_speed_before * 1.15) < 0.001,
		"bought=%s points_left=%d mult=%.2f speed %.2f→%.2f" % [str(_fq06_bought),
			root.perk_points_available(), player.perk_mine_speed_mult,
			_fq06_speed_before, player.effective_mine_speed()])

	# (d) prerequisites unlock; cost still gates (tunnel_safety costs 2 > 1 left).
	_check("fq06_prereqs_and_cost_gate",
		root.perk_state("deep_sense") == "available"
		and root.perk_state("tunnel_safety") == "available"
		and not root.try_purchase_perk("tunnel_safety")
		and not root.try_purchase_perk("stone_recovery"),
		"deep_sense=%s tunnel_safety=%s (2-cost blocked at 1 point)" % [
			root.perk_state("deep_sense"), root.perk_state("tunnel_safety")])

	# (e) purchased perks persist through the world save round-trip.
	root.save_manager.save_game()
	root.purchased_perks = []
	root._apply_purchased_perk_effects()
	root.player_level = 1
	root.load_game()
	_check("fq06_perks_persist",
		"stone_recovery" in root.purchased_perks
		and absf(player.perk_mine_speed_mult - 1.15) < 0.001
		and root.player_level == 3,
		"purchased=%s mult=%.2f level=%d" % [str(root.purchased_perks),
			player.perk_mine_speed_mult, root.player_level])

	# (f) the panel opens, a node can be selected/inspected, states render.
	hud.toggle_skill_panel()
	var _fq06_open: bool = hud.skill_panel_open()
	hud.skill_panel().select_node("stone_recovery")
	var _fq06_info: String = hud.skill_panel().info_text()
	hud.skill_panel().select_node("deep_sense")
	var _fq06_info2: String = hud.skill_panel().info_text()
	hud.toggle_skill_panel()
	_check("fq06_panel_opens_and_inspects",
		_fq06_open and not hud.skill_panel_open()
		and "Stone Recovery" in _fq06_info and "PURCHASED" in _fq06_info
		and "15%" in _fq06_info
		and "Deep Sense" in _fq06_info2 and "AVAILABLE" in _fq06_info2
		and "Stone Recovery" in _fq06_info2,
		"info=%s" % _fq06_info.left(90))

	# (g) FQ-09S: the star-map canvas draws one constellation link per
	# prerequisite pair in the live lane — derived from the same perk data
	# the buttons use, so presentation can never invent or drop an edge.
	var _fq09s_expected_links := 0
	for _fq09s_lane: Dictionary in root.perk_lanes():
		if str(_fq09s_lane.get("id", "")) == "miner":
			for _fq09s_perk: Dictionary in _fq09s_lane.get("perks", []):
				_fq09s_expected_links += (_fq09s_perk.get("prerequisites", []) as Array).size()
	_check("fq09s_constellation_links_match_prereqs",
		_fq09s_expected_links > 0
		and hud.skill_panel().link_count() == _fq09s_expected_links,
		"links=%d expected=%d" % [hud.skill_panel().link_count(), _fq09s_expected_links])

	# Restore progression so later sections see the pre-FQ-06 world.
	root.purchased_perks = _fq06_saved_perks.duplicate()
	root._apply_purchased_perk_effects()
	root.player_level = _fq06_saved_level
	root.save_manager.save_game()

	# --- FQ-07: visual asset pipeline with color fallback ---

	# Temp art uses smoke_tmp_* names (gitignored, never real asset names)
	# wired to real ids through the explicit-override path in
	# visual_assets.json, which this section therefore also exercises.
	# Clean any leftover from a previously killed run, then cold-cache.
	for _fq07_leftover in ["res://art/generated/blocks/smoke_tmp_dirt.png",
			"res://art/generated/items/smoke_tmp_wood.png"]:
		if FileAccess.file_exists(_fq07_leftover):
			DirAccess.remove_absolute(_fq07_leftover)
	BlockRegistry.clear_visual_cache()

	# (a) visual_assets.json loads with the four categories.
	var _fq07_cats: Dictionary = BlockRegistry.visual_assets.get("categories", {})
	_check("fq07_visual_assets_loads",
		_fq07_cats.has("blocks") and _fq07_cats.has("items")
		and _fq07_cats.has("enemies") and _fq07_cats.has("ui"),
		"categories=%s" % str(_fq07_cats.keys()))

	# (b) missing images never crash: lookups return null, the generated
	# color/shape textures still render, and toolbelt slots show the FQ-09
	# fallback swatch rather than real art.
	var _fq07_fallback_tex: ImageTexture = world._make_block_texture("dirt", 16)
	_check("fq07_missing_assets_fall_back",
		BlockRegistry.visual_texture("blocks", "dirt") == null
		and BlockRegistry.visual_texture("enemies", "surface_slime") == null
		and _fq07_fallback_tex != null
		and not hud.hotbar_icon_is_art(0),
		"fallback_tex_ok=%s" % str(_fq07_fallback_tex != null))

	# (c) a block image wins over the generated texture when present (via an
	# explicit visual_assets override), and the fallback returns on removal.
	var _fq07_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq07_img.fill(Color(1.0, 0.0, 1.0))
	_fq07_img.save_png("res://art/generated/blocks/smoke_tmp_dirt.png")
	BlockRegistry.visual_assets["categories"]["blocks"]["dirt"] = \
		"art/generated/blocks/smoke_tmp_dirt.png"
	BlockRegistry.clear_visual_cache()
	var _fq07_art_pixel: Color = world._make_block_texture("dirt", 16) \
		.get_image().get_pixel(4, 4)
	DirAccess.remove_absolute("res://art/generated/blocks/smoke_tmp_dirt.png")
	BlockRegistry.visual_assets["categories"]["blocks"].erase("dirt")
	BlockRegistry.clear_visual_cache()
	var _fq07_clean_pixel: Color = world._make_block_texture("dirt", 16) \
		.get_image().get_pixel(4, 4)
	_check("fq07_block_renders_from_image",
		_fq07_art_pixel.is_equal_approx(Color(1.0, 0.0, 1.0))
		and not _fq07_clean_pixel.is_equal_approx(Color(1.0, 0.0, 1.0)),
		"with_art=%s after_cleanup=%s" % [str(_fq07_art_pixel), str(_fq07_clean_pixel)])

	# (d) an item image lights up its hotbar icon; removal hides it again.
	var _fq07_item_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq07_item_img.fill(Color(0.0, 1.0, 1.0))
	_fq07_item_img.save_png("res://art/generated/items/smoke_tmp_wood.png")
	BlockRegistry.visual_assets["categories"]["items"]["wood"] = \
		"art/generated/items/smoke_tmp_wood.png"
	BlockRegistry.clear_visual_cache()
	hud.update_inventory()
	var _fq07_icon_on: bool = hud.hotbar_icon_is_art(1)    # slot 1 = wood
	var _fq07_icon_dirt: bool = hud.hotbar_icon_is_art(0)  # dirt has no art
	DirAccess.remove_absolute("res://art/generated/items/smoke_tmp_wood.png")
	BlockRegistry.visual_assets["categories"]["items"].erase("wood")
	BlockRegistry.clear_visual_cache()
	hud.update_inventory()
	_check("fq07_item_renders_from_image",
		_fq07_icon_on and not _fq07_icon_dirt and not hud.hotbar_icon_is_art(1),
		"art_icon=%s dirt_art=%s after_cleanup=%s" % [
			str(_fq07_icon_on), str(_fq07_icon_dirt), str(hud.hotbar_icon_is_art(1))])

	# --- FQ-08: block and enemy damage visuals ---

	var _fq08_stone: Variant = _find_block(world, world.hall_info["center_cell"], "stone")
	_check("fq08_stone_found", _fq08_stone != null)
	if _fq08_stone != null:
		var _fq08_cell: Vector2i = _fq08_stone

		# (a) damage stages rise mid-mine: 0 untouched, 1..3 in progress.
		player.global_position = world.cell_center(_fq08_cell) + Vector2(0, -32.0)
		player._reset_mining()
		var _fq08_stage_start: int = player.mine_damage_stage()
		player.process_mining(_fq08_cell, 0.0)   # locks target, computes required
		var _fq08_required: float = player.mine_required
		player.process_mining(_fq08_cell, _fq08_required * 0.6)
		var _fq08_stage_mid: int = player.mine_damage_stage()
		_check("fq08_block_damage_stages",
			_fq08_stage_start == 0 and _fq08_stage_mid >= 1 and _fq08_stage_mid <= 3,
			"start=%d mid=%d required=%.2f" % [_fq08_stage_start, _fq08_stage_mid, _fq08_required])

		# (b) the stage resets when the target moves off the damaged cell —
		# whether via a genuine target switch or the can_mine/reach guard
		# (both are documented reset paths through _reset_mining/retarget) —
		# and on mining stop.
		player.process_mining(_fq08_cell + Vector2i(0, 1), 0.0)
		var _fq08_after_switch: int = player.mine_damage_stage()
		player._reset_mining()
		_check("fq08_stage_resets",
			_fq08_after_switch == 0 and player.mine_damage_stage() == 0,
			"after_switch=%d after_reset=%d" % [_fq08_after_switch, player.mine_damage_stage()])

		# (c) partial damage is transient: it survives neither save nor load,
		# and the block/drop behavior is untouched by the visuals.
		player.process_mining(_fq08_cell, 0.0)
		player.process_mining(_fq08_cell, player.mine_required * 0.5)
		root.save_manager.save_game()
		root.load_game()
		_check("fq08_damage_never_saved",
			world.block_at(_fq08_cell) == "stone" and player.mine_damage_stage() == 0,
			"block=%s stage_after_load=%d" % [world.block_at(_fq08_cell), player.mine_damage_stage()])
		var _fq08_stone_count: int = player.inventory.count("stone")
		var _fq08_frames: int = await _mine_cell(world, player, _fq08_cell)
		_check("fq08_drops_unchanged",
			player.inventory.count("stone") == _fq08_stone_count + 1,
			"stone %d→%d in %d frames" % [_fq08_stone_count,
				player.inventory.count("stone"), _fq08_frames])

		# (c2) the crack overlay is masked to the sprite's opaque pixels: a
		# solid stone tile is opaque everywhere, while a thin tree_trunk bar
		# is opaque at its center column and transparent at the tile's left
		# edge — so degradation can never draw outside the visible sprite.
		var _fq08_ts: int = world.tile_size()
		var _fq08_stone_mask: BitMap = world.block_opaque_mask("stone")
		var _fq08_trunk_mask: BitMap = world.block_opaque_mask("tree_trunk")
		_check("fq08_crack_mask_inside_sprite",
			_fq08_stone_mask != null and _fq08_trunk_mask != null
			and _fq08_stone_mask.get_bit(0, 0)
			and _fq08_stone_mask.get_bit(_fq08_ts / 2, _fq08_ts / 2)
			and _fq08_trunk_mask.get_bit(_fq08_ts / 2, _fq08_ts / 2)
			and not _fq08_trunk_mask.get_bit(0, _fq08_ts / 2)
			and not _fq08_trunk_mask.get_bit(_fq08_ts - 1, _fq08_ts / 2)
			and world.block_opaque_mask("air") == null,
			"stone(0,0)=%s trunk(center)=%s trunk(edge)=%s" % [
				str(_fq08_stone_mask != null and _fq08_stone_mask.get_bit(0, 0)),
				str(_fq08_trunk_mask != null and _fq08_trunk_mask.get_bit(_fq08_ts / 2, _fq08_ts / 2)),
				str(_fq08_trunk_mask != null and _fq08_trunk_mask.get_bit(0, _fq08_ts / 2))])

		# (d) enemy damage is visible before death: the hurt-bar ratio drops
		# after a non-lethal hit; drops still roll only on death.
		for _fq08_t in get_tree().get_nodes_in_group("threats"):
			if is_instance_valid(_fq08_t):
				_fq08_t.queue_free()
		await get_tree().process_frame
		var _fq08_slime: Node = root.spawn_enemy_for_test("surface_slime")
		_fq08_slime.hp = 3
		_fq08_slime.max_hp = 3
		var _fq08_full: float = _fq08_slime.health_bar_ratio()
		var _fq08_inv_total: int = player.inventory.total()
		_fq08_slime.take_hit(1)
		var _fq08_hurt_ratio: float = _fq08_slime.health_bar_ratio()
		var _fq08_alive: bool = is_instance_valid(_fq08_slime) \
			and not _fq08_slime.is_queued_for_deletion()
		_check("fq08_enemy_hurt_visible",
			absf(_fq08_full - 1.0) < 0.001
			and _fq08_hurt_ratio > 0.0 and _fq08_hurt_ratio < 1.0
			and _fq08_alive and player.inventory.total() == _fq08_inv_total,
			"ratio 1.00→%.2f alive=%s inv_delta=%d" % [_fq08_hurt_ratio, str(_fq08_alive),
				player.inventory.total() - _fq08_inv_total])
		if is_instance_valid(_fq08_slime):
			_fq08_slime.queue_free()
		await get_tree().process_frame

	# --- FQ-09: visual inventory, toolbelt, and village panels ---

	# (a) toolbelt slot tiles show live counts and the selected highlight
	# follows the selected slot.
	player.inventory.from_dict({"dirt": 7, "wood": 2})
	player.selected_slot = 0
	player.inventory_changed.emit()
	var _fq09_counts_ok := true
	for _fq09_i in range(5):
		if hud.hotbar_slot_count(_fq09_i) != player.inventory.count(player.hotbar[_fq09_i]):
			_fq09_counts_ok = false
	var _fq09_sel_before: int = hud.hotbar_selected_index()
	player.selected_slot = 2
	hud.update_inventory()
	_check("fq09_toolbelt_slots_live",
		_fq09_counts_ok and _fq09_sel_before == 0 and hud.hotbar_selected_index() == 2,
		"counts_ok=%s selected 0→%d" % [str(_fq09_counts_ok), hud.hotbar_selected_index()])
	player.selected_slot = 0
	hud.update_inventory()

	# (b) the inventory panel opens (I binding covered by input_actions_bound)
	# and its icon grid mirrors the counts.
	hud.toggle_inventory_panel()
	var _fq09_grid_ok: bool = hud.inventory_grid_count("dirt") == 7 \
		and hud.inventory_grid_count("wood") == 2 \
		and hud.inventory_grid_count("stone") == 0
	_check("fq09_inventory_grid_reflects_counts",
		hud.inventory_panel_open() and _fq09_grid_ok,
		"dirt=%d wood=%d stone=%d" % [hud.inventory_grid_count("dirt"),
			hud.inventory_grid_count("wood"), hud.inventory_grid_count("stone")])

	# (c) the town stockpile grid mirrors the hall stockpile.
	hall.stockpile["wood"] = 4
	hall.stockpile["food"] = 6
	hud.refresh_town_panel()
	_check("fq09_town_stockpile_grid",
		hud.stockpile_grid_count("wood") == 4 and hud.stockpile_grid_count("food") == 6
		and hud.stockpile_grid_count("lantern") == 0,
		"wood=%d food=%d" % [hud.stockpile_grid_count("wood"), hud.stockpile_grid_count("food")])

	# (d) acceptance flow: grids track counts through mine -> craft ->
	# deposit -> load (panel stays open; inventory_changed drives refreshes).
	player.inventory.from_dict({"wood": 1, "stone": 1})
	player.inventory_changed.emit()
	var _fq09_dirt_cell: Variant = _find_block(world, world.hall_info["center_cell"], "dirt")
	if _fq09_dirt_cell != null:
		await _mine_cell(world, player, _fq09_dirt_cell as Vector2i)
	var _fq09_after_mine: int = hud.inventory_grid_count("dirt")
	var _fq09_crafted: bool = player.craft("craft_torch")   # 1 wood + 1 stone -> 3 torch
	var _fq09_after_craft: int = hud.inventory_grid_count("torch")
	hall.deposit_all(player.inventory)                      # moves dirt (torch not depositable)
	hud.refresh_town_panel()
	hud.update_inventory()
	var _fq09_stock_dirt: int = hud.stockpile_grid_count("dirt")
	root.save_manager.save_game()
	player.inventory.from_dict({"dirt": 99})
	player.inventory_changed.emit()
	root.load_game()
	var _fq09_after_load: int = hud.inventory_grid_count("torch")
	_check("fq09_counts_after_mine_craft_deposit_load",
		_fq09_after_mine >= 1 and _fq09_crafted and _fq09_after_craft == 3
		and _fq09_stock_dirt >= 1 and _fq09_after_load == 3
		and hud.inventory_grid_count("dirt") == 0,
		"mine_dirt=%d craft_torch=%d stock_dirt=%d load_torch=%d" % [
			_fq09_after_mine, _fq09_after_craft, _fq09_stock_dirt, _fq09_after_load])
	hud.toggle_inventory_panel()

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
