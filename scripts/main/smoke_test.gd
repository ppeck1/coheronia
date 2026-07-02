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
			"toggle_town", "craft", "save_game", "load_game", "debug_overlay",
			"hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5"]:
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

	var enemy_reg = load("res://scripts/data/enemy_registry.gd").new()
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
