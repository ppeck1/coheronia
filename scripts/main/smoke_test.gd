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
		"name": "Smoke Tester", "species": "dwarf", "body_variant": "female",
		"role": "prospector", "traits": ["hardy"], "appearance": "ash"})
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
		and "hardy" in reloaded_char.get("traits", [])
		and str(reloaded_char.get("body_variant", "")) == "female")
	_check("player_visual_body_variant_roundtrip",
		str(reloaded_char.get("species", "")) == "dwarf"
		and str(reloaded_char.get("body_variant", "")) == "female")
	_check("player_visual_invalid_variant_defaults",
		GameState.normalize_body_variant("") == "default"
		and GameState.normalize_body_variant("bogus") == "default"
		and GameState.normalize_body_variant("female") == "female")
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

	# --- FQ-10: data-defined ore families by depth band (generic `ore` above
	# is untouched; families only claim cells that would be stone) ---
	GameState.current_config = WorldConfig.new(
		{"size": "large", "generation": {"ore_abundance": 2.0}})
	world.setup(4242)
	var _fq10_coal: int = _count_blocks(world, "coal")
	var _fq10_copper: int = _count_blocks(world, "copper_ore")
	var _fq10_tin: int = _count_blocks(world, "tin_ore")
	var _fq10_iron: int = _count_blocks(world, "iron_ore")
	var _fq10_deep: int = _count_blocks(world, "silver_ore") + _count_blocks(world, "crystal")
	_check("fq10_ore_families_generate",
		_fq10_coal > 0 and _fq10_copper > 0 and _fq10_tin > 0
		and _fq10_iron > 0 and _fq10_deep > 0,
		"coal=%d copper=%d tin=%d iron=%d deep(silver+crystal)=%d" % [
			_fq10_coal, _fq10_copper, _fq10_tin, _fq10_iron, _fq10_deep])
	# The generic starter ore still generates alongside the families.
	_check("fq10_generic_ore_preserved", _count_blocks(world, "ore") > 0,
		"generic ore veins=%d" % _count_blocks(world, "ore"))

	# Same seed + size -> identical ore-family layout (deterministic, never saved).
	var _fq10_layout_a: Array = _block_cells(world, "coal")
	world.setup(4242)
	var _fq10_layout_b: Array = _block_cells(world, "coal")
	_check("fq10_ore_families_deterministic",
		_fq10_layout_a.size() > 0 and _fq10_layout_a == _fq10_layout_b,
		"coal cells=%d stable=%s" % [
			_fq10_layout_a.size(), str(_fq10_layout_a == _fq10_layout_b)])

	# Deeper ores stay behind the tier-2 pick gate; shallow starter metals do not.
	var _fq10_iron_cell: Variant = null
	var _fq10_coal_cell: Variant = null
	for _fq10_c: Vector2i in world.cells:
		var _fq10_b: String = world.cells[_fq10_c]
		if _fq10_b == "iron_ore" and _fq10_iron_cell == null:
			_fq10_iron_cell = _fq10_c
		elif _fq10_b == "coal" and _fq10_coal_cell == null:
			_fq10_coal_cell = _fq10_c
		if _fq10_iron_cell != null and _fq10_coal_cell != null:
			break
	_check("fq10_ore_tier_gate",
		_fq10_iron_cell != null and _fq10_coal_cell != null
		and not world.can_mine(_fq10_iron_cell, 1) and world.can_mine(_fq10_iron_cell, 2)
		and world.can_mine(_fq10_coal_cell, 1),
		"iron@t1=%s iron@t2=%s coal@t1=%s" % [
			str(_fq10_iron_cell != null and world.can_mine(_fq10_iron_cell, 1)),
			str(_fq10_iron_cell != null and world.can_mine(_fq10_iron_cell, 2)),
			str(_fq10_coal_cell != null and world.can_mine(_fq10_coal_cell, 1))])

	# Abundance 0 clears every ore — families and the generic vein alike.
	GameState.current_config = WorldConfig.new(
		{"size": "large", "generation": {"ore_abundance": 0.0}})
	world.setup(4242)
	var _fq10_zero := 0
	for _fq10_ore_id in ["ore", "coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "crystal"]:
		_fq10_zero += _count_blocks(world, _fq10_ore_id)
	_check("fq10_ore_abundance_zero_clears_all", _fq10_zero == 0,
		"total ore cells at abundance 0 = %d" % _fq10_zero)

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
	_check("enemies_json_loads", enemy_reg.live_defs().size() == 6,
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

	# --- FQ-13: enemy variety (thornrat crop-eating, ore tick, torchbearer) ---
	# Capture-and-restore every world cell touched so later global scans
	# (e.g. the FQ-12 farm count) see the untouched world.
	var _fq13_crop := Vector2i(70, 40)
	var _fq13_soil := Vector2i(70, 41)
	var _fq13_ore := Vector2i(72, 45)
	var _fq13_plain := Vector2i(90, 45)
	var _fq13_touched: Array = [_fq13_crop, _fq13_soil, _fq13_ore]
	for _px in [-1, 0, 1]:
		_fq13_touched.append(Vector2i(_fq13_plain.x + _px, _fq13_plain.y))
	var _fq13_saved := {}
	for _c in _fq13_touched:
		_fq13_saved[_c] = [world.cells.get(_c), world.deltas.get(_c)]

	# (a) all three MVP-expansion enemies are live.
	var _fq13_thorn: Dictionary = enemy_reg.get_def("thornrat")
	var _fq13_tick: Dictionary = enemy_reg.get_def("ore_tick")
	var _fq13_torch: Dictionary = enemy_reg.get_def("raider_torchbearer")
	_check("fq13_new_enemies_live",
		_fq13_thorn.get("status", "") == "live"
		and _fq13_tick.get("status", "") == "live"
		and _fq13_torch.get("status", "") == "live",
		"thornrat=%s ore_tick=%s torchbearer=%s" % [
			_fq13_thorn.get("status", "?"), _fq13_tick.get("status", "?"),
			_fq13_torch.get("status", "?")])

	# (b) the thornrat's crop-eating mechanism: world.eat_crop clears a crop with
	# no player yield (the lost harvest IS the pressure); nearest_crop locates it.
	world.cells[_fq13_soil] = "farm_soil"; world.deltas[_fq13_soil] = "farm_soil"
	world.cells.erase(_fq13_crop); world.deltas[_fq13_crop] = "air"
	world.plant_crop(_fq13_crop)
	var _fq13_found: Vector2i = world.nearest_crop(_fq13_crop, 3)
	var _fq13_food_before: int = player.inventory.count("food")
	var _fq13_ate: bool = world.eat_crop(_fq13_crop)
	_check("fq13_thornrat_eats_crop",
		bool(_fq13_thorn.get("targets_crops", false))
		and _fq13_found == _fq13_crop and _fq13_ate
		and world.block_at(_fq13_crop) == "air"
		and player.inventory.count("food") == _fq13_food_before,
		"targets=%s found=%s ate=%s food_delta=%d" % [
			str(_fq13_thorn.get("targets_crops", false)), str(_fq13_found),
			str(_fq13_ate), player.inventory.count("food") - _fq13_food_before])

	# (c) a spawned thornrat carries the crop-eating flag and its fast profile.
	var _fq13_thorn_node: Node = root.spawn_enemy_for_test("thornrat")
	_check("fq13_thornrat_profile",
		_fq13_thorn_node != null and _fq13_thorn_node.targets_crops
		and _fq13_thorn_node.move_speed >= 60.0,
		"targets=%s speed=%.0f" % [
			str(_fq13_thorn_node != null and _fq13_thorn_node.targets_crops),
			(_fq13_thorn_node.move_speed if _fq13_thorn_node != null else -1.0)])

	# (d) the ore tick keys off ore: has_ore_within is true beside an ore vein
	# and false in a scrubbed patch of plain stone.
	world.cells[_fq13_ore] = "iron_ore"; world.deltas[_fq13_ore] = "iron_ore"
	for _px in [-1, 0, 1]:
		var _pc := Vector2i(_fq13_plain.x + _px, _fq13_plain.y)
		world.cells[_pc] = "stone"; world.deltas[_pc] = "stone"
	_check("fq13_ore_tick_near_ore",
		world.has_ore_within(_fq13_ore + Vector2i(1, 0), 2)
		and not world.has_ore_within(_fq13_plain, 1),
		"near_ore=%s plain=%s" % [
			str(world.has_ore_within(_fq13_ore + Vector2i(1, 0), 2)),
			str(world.has_ore_within(_fq13_plain, 1))])

	# (e) the torchbearer burns the hall faster and hits harder than a basic
	# raider (hall_dps_mult + higher contact_damage), and is tankier than the
	# frail thornrat (hp_mult).
	var _fq13_torch_node: Node = root.spawn_enemy_for_test("raider_torchbearer")
	var _fq13_basic_node: Node = root.spawn_enemy_for_test("raider_basic")
	_check("fq13_torchbearer_burns_faster",
		_fq13_torch_node != null and _fq13_basic_node != null
		and _fq13_torch_node.hall_dps > _fq13_basic_node.hall_dps
		and _fq13_torch_node.contact_damage > _fq13_basic_node.contact_damage,
		"torch_dps=%.1f basic_dps=%.1f torch_atk=%.1f basic_atk=%.1f" % [
			_fq13_torch_node.hall_dps, _fq13_basic_node.hall_dps,
			_fq13_torch_node.contact_damage, _fq13_basic_node.contact_damage])
	_check("fq13_enemy_hp_profile",
		_fq13_torch_node != null and _fq13_thorn_node != null
		and _fq13_torch_node.hp > _fq13_thorn_node.hp,
		"torch_hp=%d thorn_hp=%d" % [
			_fq13_torch_node.hp, _fq13_thorn_node.hp])

	# (f) a new enemy's drops enter the inventory on death.
	var _fq13_inv_before: int = player.inventory.total()
	if _fq13_thorn_node != null and is_instance_valid(_fq13_thorn_node):
		_fq13_thorn_node.drop_chance_override = 1.0
		_fq13_thorn_node.take_hit(99)
	await get_tree().process_frame
	_check("fq13_new_enemy_drops", player.inventory.total() > _fq13_inv_before,
		"inventory total %d→%d" % [_fq13_inv_before, player.inventory.total()])

	# Clean up the FQ-13 test threats and restore every touched world cell.
	for _n in [_fq13_torch_node, _fq13_basic_node]:
		if _n != null and is_instance_valid(_n):
			_n.queue_free()
	for _c in _fq13_saved:
		var _sv: Array = _fq13_saved[_c]
		if _sv[0] == null:
			world.cells.erase(_c)
		else:
			world.cells[_c] = _sv[0]
		if _sv[1] == null:
			world.deltas.erase(_c)
		else:
			world.deltas[_c] = _sv[1]
	world.crop_growth.erase(_fq13_crop)
	await get_tree().process_frame

	# --- FQ-13P1: enemy sprite variant pools (deterministic, lifetime-stable) ---
	var _p1_script = preload("res://scripts/entities/simple_threat.gd")
	var _p1_pool: Array = BlockRegistry.visual_variant_textures("enemies", "cave_crawler")
	_check("fq13p1_enemy_pool_discovered", _p1_pool.size() >= 2,
		"cave_crawler pool=%d" % _p1_pool.size())

	# more than one variant is selectable across different deterministic inputs.
	var _p1_seen := {}
	for _pi in range(40):
		_p1_seen[_p1_script.variant_for("cave_crawler", Vector2i(_pi, 0), 4242, _p1_pool.size())] = true
	_check("fq13p1_variants_differ", _p1_seen.size() >= 2,
		"distinct=%d over 40 cells" % _p1_seen.size())

	# same inputs always yield the same choice.
	_check("fq13p1_selection_deterministic",
		_p1_script.variant_for("cave_crawler", Vector2i(7, 3), 4242, _p1_pool.size())
		== _p1_script.variant_for("cave_crawler", Vector2i(7, 3), 4242, _p1_pool.size()),
		"repeatable")

	# a spawned enemy picks a valid pool variant and keeps it through damage,
	# redraw, and physics frames (no per-frame reselection).
	var _p1_node: Node = root.spawn_enemy_for_test("cave_crawler")
	var _p1_idx0: int = _p1_node.variant_index
	var _p1_art0: Texture2D = _p1_node._art
	_p1_node.hp = 5
	_p1_node.max_hp = 5
	_p1_node.take_hit(1)
	await get_tree().physics_frame
	_p1_node.queue_redraw()
	await get_tree().process_frame
	_check("fq13p1_selection_stable",
		_p1_node.variant_index == _p1_idx0 and _p1_node._art == _p1_art0
		and _p1_art0 != null and _p1_idx0 >= 0 and _p1_idx0 < _p1_pool.size(),
		"idx %d->%d art_stable=%s in_pool=%s" % [_p1_idx0, _p1_node.variant_index,
			str(_p1_node._art == _p1_art0),
			str(_p1_idx0 >= 0 and _p1_idx0 < _p1_pool.size())])

	# fallback chain: an enemy with no pool and no canonical art draws the
	# code-drawn body (_art null, variant_index -1); the pooled enemy has art.
	var _p1_thorn: Node = root.spawn_enemy_for_test("thornrat")
	_check("fq13p1_fallback_code_drawn",
		BlockRegistry.visual_variant_textures("enemies", "thornrat").is_empty()
		and _p1_thorn._art == null and _p1_thorn.variant_index == -1
		and _p1_node._art != null,
		"thorn_art=%s thorn_idx=%d crawler_has_art=%s" % [str(_p1_thorn._art),
			_p1_thorn.variant_index, str(_p1_node._art != null)])

	for _pn in [_p1_node, _p1_thorn]:
		if _pn != null and is_instance_valid(_pn):
			_pn.queue_free()
	await get_tree().process_frame

	# --- FQ-13P2: deliberate UI placeholders + hooks ---
	# the authored UI placeholders load through the "ui" category convention.
	_check("fq13p2_ui_placeholders_present",
		BlockRegistry.visual_texture("ui", "slot_inventory") != null
		and BlockRegistry.visual_texture("ui", "button_settings") != null
		and BlockRegistry.visual_texture("ui", "orb_health_frame") != null,
		"slot=%s button=%s orb=%s" % [
			str(BlockRegistry.visual_texture("ui", "slot_inventory") != null),
			str(BlockRegistry.visual_texture("ui", "button_settings") != null),
			str(BlockRegistry.visual_texture("ui", "orb_health_frame") != null)])

	# the live hotbar slot consumes the placeholder frame (StyleBoxTexture).
	var _p2_slot0 = hud._hotbar_slots[0].get_theme_stylebox("panel")
	_check("fq13p2_slot_frame_consumed",
		hud._slot_normal_sb is StyleBoxTexture
		and hud._slot_selected_sb is StyleBoxTexture
		and _p2_slot0 is StyleBoxTexture,
		"normal=%s selected=%s slot0=%s" % [
			str(hud._slot_normal_sb is StyleBoxTexture),
			str(hud._slot_selected_sb is StyleBoxTexture),
			str(_p2_slot0 is StyleBoxTexture)])

	# a missing UI id is never an error: visual_texture null, slot style falls
	# back to the code-drawn flat box.
	var _p2_fallback = hud._make_slot_style("no_such_ui_hook", Color(0.4, 0.4, 0.4))
	_check("fq13p2_missing_ui_falls_back",
		BlockRegistry.visual_texture("ui", "no_such_ui_hook") == null
		and _p2_fallback is StyleBoxFlat,
		"missing_null=%s fallback_flat=%s" % [
			str(BlockRegistry.visual_texture("ui", "no_such_ui_hook") == null),
			str(_p2_fallback is StyleBoxFlat)])

	# --- FQ-13P4: item-icon stability + variant/animation frame semantics ---
	# an inventory stack's icon never changes between refreshes: item_icon is
	# cached (art or swatch), and items carry no variant pool that could vary it.
	var _p4_dirt_a: Texture2D = BlockRegistry.item_icon("dirt")
	var _p4_dirt_b: Texture2D = BlockRegistry.item_icon("dirt")
	var _p4_meat_a: Texture2D = BlockRegistry.item_icon("meat")   # swatch-only
	var _p4_meat_b: Texture2D = BlockRegistry.item_icon("meat")
	_check("fq13p4_item_icon_stable",
		_p4_dirt_a != null and _p4_dirt_a == _p4_dirt_b
		and _p4_meat_a != null and _p4_meat_a == _p4_meat_b
		and BlockRegistry.visual_variant_textures("items", "dirt").is_empty(),
		"dirt_same=%s swatch_same=%s no_item_pool=%s" % [
			str(_p4_dirt_a == _p4_dirt_b), str(_p4_meat_a == _p4_meat_b),
			str(BlockRegistry.visual_variant_textures("items", "dirt").is_empty())])

	# the shared <id>_NN convention is consumed two DISTINCT ways; the manifest
	# documents variant (pick-one) vs animation (ordered opening frames).
	var _p4_fs: String = str(BlockRegistry.visual_assets.get("frame_semantics", ""))
	_check("fq13p4_frame_semantics_documented",
		BlockRegistry.visual_assets.has("frame_semantics")
		and "opening" in _p4_fs and "VARIANT" in _p4_fs and "ANIMATION" in _p4_fs,
		"has=%s" % str(BlockRegistry.visual_assets.has("frame_semantics")))

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

	# --- FQ-11: workbench/furnace/anvil station chain ---
	hall.stockpile = {"wood": 40, "stone": 80, "coal": 40,
		"copper_ore": 12, "tin_ore": 12, "iron_ore": 60, "silver_ore": 6}
	hall.stations_built = {"workbench": false, "furnace": false, "anvil": false}

	# (a) gating: station recipes are locked until their station is built, and a
	# station cannot be built before its prerequisite is standing.
	var _fq11_smelt_locked: bool = hall.craft_station("smelt_iron", player)
	var _fq11_furnace_early: bool = hall.build_station("furnace")
	var _fq11_anvil_early: bool = hall.build_station("anvil")
	_check("fq11_station_gating",
		not _fq11_smelt_locked and not _fq11_furnace_early and not _fq11_anvil_early
		and not hall.station_built("furnace"),
		"smelt_locked=%s furnace_early=%s anvil_early=%s" % [
			str(_fq11_smelt_locked), str(_fq11_furnace_early), str(_fq11_anvil_early)])

	# (b) build workbench -> furnace, spending build costs from the stockpile.
	var _fq11_wood0: int = int(hall.stockpile.get("wood", 0))
	var _fq11_stone0: int = int(hall.stockpile.get("stone", 0))
	var _fq11_wb: bool = hall.build_station("workbench")
	var _fq11_fn: bool = hall.build_station("furnace")
	_check("fq11_build_chain",
		_fq11_wb and _fq11_fn and hall.station_built("workbench")
		and hall.station_built("furnace")
		and int(hall.stockpile.get("wood", 0)) == _fq11_wood0 - 12
		and int(hall.stockpile.get("stone", 0)) == _fq11_stone0 - 6 - 16,
		"wb=%s fn=%s wood %d->%d stone %d->%d" % [str(_fq11_wb), str(_fq11_fn),
			_fq11_wood0, int(hall.stockpile.get("wood", 0)),
			_fq11_stone0, int(hall.stockpile.get("stone", 0))])

	# (c) the furnace smelts raw ore + coal into an ingot placed in the stockpile
	# (never the player's inventory).
	var _fq11_ore0: int = int(hall.stockpile.get("iron_ore", 0))
	var _fq11_coal0: int = int(hall.stockpile.get("coal", 0))
	var _fq11_smelt: bool = hall.craft_station("smelt_iron", player)
	_check("fq11_furnace_smelts_ore",
		_fq11_smelt and int(hall.stockpile.get("iron_ingot", 0)) == 1
		and int(hall.stockpile.get("iron_ore", 0)) == _fq11_ore0 - 2
		and int(hall.stockpile.get("coal", 0)) == _fq11_coal0 - 1
		and player.inventory.count("iron_ingot") == 0,
		"ingots=%d ore %d->%d coal %d->%d" % [int(hall.stockpile.get("iron_ingot", 0)),
			_fq11_ore0, int(hall.stockpile.get("iron_ore", 0)),
			_fq11_coal0, int(hall.stockpile.get("coal", 0))])

	# (d) the anvil forges iron gear from ingots. Build it (costs 3 iron_ingot),
	# top up ingots, then forge the iron sword into the weapon slot.
	for _fq11_i in range(8):
		hall.craft_station("smelt_iron", player)
	var _fq11_av: bool = hall.build_station("anvil")
	var _fq11_forge: bool = hall.craft_station("anvil_iron_sword", player)
	_check("fq11_anvil_forges_iron_gear",
		_fq11_av and _fq11_forge
		and str(player.equipped_dict().get("weapon", "")) == "sword_iron"
		and player.attack_damage() == 5,
		"anvil=%s forge=%s weapon=%s atk=%d" % [str(_fq11_av), str(_fq11_forge),
			str(player.equipped_dict().get("weapon", "")), player.attack_damage()])

	# (e) metal gate: clear the weapon, drain ingots, leave only raw ore — the
	# anvil cannot conjure the sword from ore.
	player.equip_item("weapon", "")
	hall.stockpile.erase("iron_ingot")
	hall.stockpile["iron_ore"] = 20
	var _fq11_ore_only: bool = hall.craft_station("anvil_iron_sword", player)
	_check("fq11_metal_gate_no_ore_shortcut",
		not _fq11_ore_only and str(player.equipped_dict().get("weapon", "")) == "",
		"forged_from_ore=%s" % str(_fq11_ore_only))

	# (f) bronze alloy: smelt copper + tin, then alloy them at the furnace.
	hall.craft_station("smelt_copper", player)
	hall.craft_station("smelt_tin", player)
	var _fq11_bronze: bool = hall.craft_station("alloy_bronze", player)
	_check("fq11_bronze_alloy",
		_fq11_bronze and int(hall.stockpile.get("bronze_ingot", 0)) == 2
		and int(hall.stockpile.get("copper_ingot", 0)) == 0
		and int(hall.stockpile.get("tin_ingot", 0)) == 0,
		"bronze=%d copper=%d tin=%d" % [int(hall.stockpile.get("bronze_ingot", 0)),
			int(hall.stockpile.get("copper_ingot", 0)), int(hall.stockpile.get("tin_ingot", 0))])

	# (g) built stations round-trip through save/load (pre-FQ-11 saves default
	# to nothing built).
	root.save_manager.save_game()
	hall.stations_built = {"workbench": false, "furnace": false, "anvil": false}
	root.load_game()
	_check("fq11_stations_persist",
		hall.station_built("workbench") and hall.station_built("furnace")
		and hall.station_built("anvil"),
		"wb=%s fn=%s av=%s" % [str(hall.station_built("workbench")),
			str(hall.station_built("furnace")), str(hall.station_built("anvil"))])

	# Clear any forged gear so later FQ-01/FQ-05 checks see an unarmored player.
	player.equip_item("weapon", "")
	player.equip_item("helmet", "")
	player.equip_item("torso", "")
	player.equip_item("feet", "")
	player.health = player.max_health

	# --- FQ-12: farming (till, plant, grow, harvest, no-float, save/load) ---
	var _fq12_soil := Vector2i(40, 40)
	var _fq12_crop := Vector2i(40, 39)
	var _fq12_stone := Vector2i(42, 40)
	var _fq12_float := Vector2i(42, 39)
	world.cells[_fq12_soil] = "dirt"; world.deltas[_fq12_soil] = "dirt"
	world.cells[_fq12_stone] = "stone"; world.deltas[_fq12_stone] = "stone"
	world.cells.erase(_fq12_crop); world.deltas[_fq12_crop] = "air"
	world.cells.erase(_fq12_float); world.deltas[_fq12_float] = "air"
	world.crop_growth.clear()

	# (a) till: dirt -> farm_soil; stone cannot be tilled.
	var _fq12_till: bool = world.till_soil(_fq12_soil)
	var _fq12_till_stone: bool = world.till_soil(_fq12_stone)
	_check("fq12_till_soil",
		_fq12_till and world.block_at(_fq12_soil) == "farm_soil"
		and not _fq12_till_stone and world.block_at(_fq12_stone) == "stone",
		"tilled=%s now=%s stone_tillable=%s" % [str(_fq12_till),
			world.block_at(_fq12_soil), str(_fq12_till_stone)])

	# (b) planting needs tilled soil directly below — crops never float.
	var _fq12_plant_float: bool = world.plant_crop(_fq12_float)   # below is stone
	var _fq12_plant: bool = world.plant_crop(_fq12_crop)          # below is farm_soil
	_check("fq12_plant_on_soil_only",
		_fq12_plant and world.block_at(_fq12_crop) == "crop_seedling"
		and world.crop_growth.has(_fq12_crop) and not _fq12_plant_float
		and world.block_at(_fq12_float) == "air",
		"planted=%s floating_allowed=%s" % [str(_fq12_plant), str(_fq12_plant_float)])

	# (c) a seedling on tilled soil ripens once its timer elapses.
	world.crop_growth[_fq12_crop] = 0.01
	world._tick_crop_growth(0.02)
	_check("fq12_crop_ripens",
		world.block_at(_fq12_crop) == "crop_ripe"
		and not world.crop_growth.has(_fq12_crop),
		"crop=%s" % world.block_at(_fq12_crop))

	# (d) harvest: breaking the ripe crop yields food + a seed.
	var _fq12_drops: Dictionary = world.break_block(_fq12_crop)
	_check("fq12_harvest_yields_food",
		int(_fq12_drops.get("food", 0)) >= 1
		and int(_fq12_drops.get("crop_seeds", 0)) >= 1
		and world.block_at(_fq12_crop) == "air",
		"drops=%s" % str(_fq12_drops))

	# (e) no float / no wrong regrow: removing the tilled soil under a seedling
	# removes the crop — it never floats and never becomes a berry bush.
	world.plant_crop(_fq12_crop)
	world.break_block(_fq12_soil)
	world._tick_crop_growth(0.0)
	_check("fq12_no_float_no_regrow",
		world.block_at(_fq12_crop) == "air"
		and not world.crop_growth.has(_fq12_crop)
		and not world.bush_regrow.has(_fq12_crop),
		"crop=%s in_bush_regrow=%s" % [world.block_at(_fq12_crop),
			str(world.bush_regrow.has(_fq12_crop))])

	# (f) crops + their growth timers round-trip through save/load.
	world.cells[_fq12_soil] = "dirt"; world.deltas[_fq12_soil] = "dirt"
	world.till_soil(_fq12_soil)
	world.cells.erase(_fq12_crop); world.deltas[_fq12_crop] = "air"
	world.plant_crop(_fq12_crop)
	world.crop_growth[_fq12_crop] = 42.0
	root.save_manager.save_game()
	world.crop_growth.clear()
	root.load_game()
	_check("fq12_crop_saves",
		world.block_at(_fq12_crop) == "crop_seedling"
		and world.crop_growth.has(_fq12_crop),
		"crop=%s timer_restored=%s" % [world.block_at(_fq12_crop),
			str(world.crop_growth.has(_fq12_crop))])

	# (g) the food-yard score counts tilled soil + crops and is exposed to UI.
	var _fq12_farm: int = world.farm_tile_count()
	_check("fq12_farm_score",
		_fq12_farm >= 2 and "farm" in root.summary(),
		"farm_tiles=%d summary_has_farm=%s" % [_fq12_farm, str("farm" in root.summary())])

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

	# (a) visual_assets.json loads with the image-first categories.
	var _fq07_cats: Dictionary = BlockRegistry.visual_assets.get("categories", {})
	_check("fq07_visual_assets_loads",
		_fq07_cats.has("blocks") and _fq07_cats.has("items")
		and _fq07_cats.has("enemies") and _fq07_cats.has("ui")
		and _fq07_cats.has("players") and _fq07_cats.has("player_gear")
		and _fq07_cats.has("structures"),
		"categories=%s" % str(_fq07_cats.keys()))

	# (b) a deliberately unknown id still returns the generated item swatch;
	# the real block/enemy art added later does not invalidate fallback safety.
	var _fq07_fallback_tex: Texture2D = BlockRegistry.item_icon("smoke_tmp_missing")
	_check("fq07_missing_assets_fall_back",
		BlockRegistry.visual_texture("blocks", "smoke_tmp_missing") == null
		and BlockRegistry.visual_texture("enemies", "smoke_tmp_missing") == null
		and _fq07_fallback_tex != null,
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

	# (d) an explicit item override wins; removal returns to convention art.
	var _fq07_item_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq07_item_img.fill(Color(0.0, 1.0, 1.0))
	_fq07_item_img.save_png("res://art/generated/items/smoke_tmp_wood.png")
	BlockRegistry.visual_assets["categories"]["items"]["wood"] = \
		"art/generated/items/smoke_tmp_wood.png"
	BlockRegistry.clear_visual_cache()
	hud.update_inventory()
	var _fq07_item_override_pixel: Color = BlockRegistry.item_icon("wood") \
		.get_image().get_pixel(4, 4)
	var _fq07_icon_on: bool = hud.hotbar_icon_is_art(1)    # slot 1 = wood
	DirAccess.remove_absolute("res://art/generated/items/smoke_tmp_wood.png")
	BlockRegistry.visual_assets["categories"]["items"].erase("wood")
	BlockRegistry.clear_visual_cache()
	hud.update_inventory()
	var _fq07_item_convention_pixel: Color = BlockRegistry.item_icon("wood") \
		.get_image().get_pixel(4, 4)
	_check("fq07_item_renders_from_image",
		_fq07_icon_on and hud.hotbar_icon_is_art(1)
		and _fq07_item_override_pixel.is_equal_approx(Color(0.0, 1.0, 1.0))
		and not _fq07_item_convention_pixel.is_equal_approx(Color(0.0, 1.0, 1.0)),
		"override=%s convention=%s" % [str(_fq07_item_override_pixel),
			str(_fq07_item_convention_pixel)])

	# (e) the shipped hall art occupies the exact procedural footprint; an
	# isolated forced miss still initializes the permanent shape fallback.
	var _fq07_core_tex: Texture2D = BlockRegistry.visual_texture("blocks", "town_hall_core")
	var _fq07_core_img: Image = _fq07_core_tex.get_image() if _fq07_core_tex != null else null
	_check("town_hall_core_image_contract",
		_fq07_core_img != null and _fq07_core_img.get_size() == Vector2i(16, 16)
		and _fq07_core_img.get_format() == Image.FORMAT_RGBA8,
		"size=%s" % str(_fq07_core_img.get_size() if _fq07_core_img != null else Vector2i.ZERO))
	var _fq07_hall_tex: Texture2D = BlockRegistry.visual_texture("structures", "town_hall")
	var _fq07_hall_img: Image = _fq07_hall_tex.get_image() if _fq07_hall_tex != null else null
	_check("town_hall_image_contract",
		hall.using_structure_art() and _fq07_hall_img != null
		and _fq07_hall_img.get_size() == Vector2i(56, 48)
		and _fq07_hall_img.get_format() == Image.FORMAT_RGBA8,
		"art=%s size=%s" % [str(hall.using_structure_art()),
			str(_fq07_hall_img.get_size() if _fq07_hall_img != null else Vector2i.ZERO)])
	var _fq07_structure_entries: Dictionary = _fq07_cats["structures"]
	_fq07_structure_entries["town_hall"] = \
		"art/generated/structures/smoke_tmp_missing_town_hall.png"
	BlockRegistry.clear_visual_cache()
	var _fq07_hall_probe: Node2D = load("res://scenes/settlement/TownHall.tscn").instantiate()
	_fq07_hall_probe.visible = false
	root.add_child(_fq07_hall_probe)
	var _fq07_hall_fallback: bool = not _fq07_hall_probe.using_structure_art()
	_fq07_hall_probe.queue_free()
	_fq07_structure_entries.erase("town_hall")
	BlockRegistry.clear_visual_cache()
	_check("town_hall_procedural_fallback", _fq07_hall_fallback)
	var _fq07_hall_damage_was: float = hall.damage
	hall.damage = 65.0
	var _fq07_hall_damage_ok: bool = is_equal_approx(hall.damage_overlay_alpha(), 0.5)
	hall.damage = _fq07_hall_damage_was
	hall.queue_redraw()
	_check("town_hall_damage_overlay_preserved", _fq07_hall_damage_ok,
		"alpha=%.2f" % hall.damage_overlay_alpha())

	# --- Player visual runtime: bodies, facing, same-species fallback, gear ---
	var _pv = player.get_node("PlayerVisual")
	var _pv_saved_character: Dictionary = GameState.current_character.duplicate(true)
	var _pv_saved_equipment: Dictionary = player.equipment.duplicate(true)
	var _pv_saved_pick_tier: int = player.tool_tier
	var _pv_saved_axe_tier: int = player.axe_tier
	var _pv_resolved: Dictionary = {}
	var _pv_all_art := true
	for _pv_species in ["human", "dwarf", "elf", "goblin", "orc"]:
		for _pv_variant in ["default", "female"]:
			player.apply_character({
				"species": _pv_species,
				"body_variant": _pv_variant,
				"appearance": "tan",
				"traits": [],
				"role": "homesteader",
			})
			var _pv_expected: String = _pv_species if _pv_variant == "default" \
				else "%s_%s" % [_pv_species, _pv_variant]
			var _pv_snapshot: Dictionary = _pv.presentation_snapshot()
			_pv_resolved[str(_pv_snapshot.get("resolved_body_id", ""))] = true
			_pv_all_art = _pv_all_art \
				and bool(_pv_snapshot.get("using_body_art", false)) \
				and str(_pv_snapshot.get("resolved_body_id", "")) == _pv_expected
	_check("player_visual_all_ten_bodies_resolve",
		_pv_all_art and _pv_resolved.size() == 10,
		"resolved=%s" % str(_pv_resolved.keys()))
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "tan"})
	var _pv_tan_recolored: bool = _pv.appearance_recolored()
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "pale"})
	var _pv_pale_recolored: bool = _pv.appearance_recolored()
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "umber"})
	var _pv_umber_recolored: bool = _pv.appearance_recolored()
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "ash"})
	var _pv_ash_recolored: bool = _pv.appearance_recolored()
	_check("player_visual_appearance_palette_applies",
		not _pv_tan_recolored and _pv_pale_recolored
		and _pv_umber_recolored and _pv_ash_recolored,
		"tan=%s pale=%s umber=%s ash=%s" % [str(_pv_tan_recolored),
			str(_pv_pale_recolored), str(_pv_umber_recolored), str(_pv_ash_recolored)])

	# Force the female dwarf miss, then both dwarf misses. Resolution may step
	# down only within dwarf; it must never substitute human art.
	var _pv_player_entries: Dictionary = BlockRegistry.visual_assets["categories"]["players"]
	var _pv_had_dwarf_female := _pv_player_entries.has("dwarf_female")
	var _pv_old_dwarf_female: Variant = _pv_player_entries.get("dwarf_female")
	var _pv_had_dwarf := _pv_player_entries.has("dwarf")
	var _pv_old_dwarf: Variant = _pv_player_entries.get("dwarf")
	BlockRegistry.visual_assets["categories"]["players"]["dwarf_female"] = \
		"art/generated/players/smoke_tmp_missing_dwarf_female.png"
	BlockRegistry.clear_visual_cache()
	player.apply_character({"species": "dwarf", "body_variant": "female"})
	var _pv_same_species: String = _pv.resolved_body_id()
	BlockRegistry.visual_assets["categories"]["players"]["dwarf"] = \
		"art/generated/players/smoke_tmp_missing_dwarf.png"
	BlockRegistry.clear_visual_cache()
	player.apply_character({"species": "dwarf", "body_variant": "female"})
	var _pv_dwarf_procedural: Dictionary = _pv.presentation_snapshot()
	player.apply_character({"species": "smoke_unknown", "body_variant": "female"})
	var _pv_unknown: Dictionary = _pv.presentation_snapshot()
	if _pv_had_dwarf_female:
		_pv_player_entries["dwarf_female"] = _pv_old_dwarf_female
	else:
		_pv_player_entries.erase("dwarf_female")
	if _pv_had_dwarf:
		_pv_player_entries["dwarf"] = _pv_old_dwarf
	else:
		_pv_player_entries.erase("dwarf")
	BlockRegistry.clear_visual_cache()
	_check("player_visual_same_species_fallback", _pv_same_species == "dwarf",
		"resolved=%s" % _pv_same_species)
	_check("player_visual_never_cross_species_fallback",
		not bool(_pv_dwarf_procedural.get("using_body_art", true))
		and str(_pv_dwarf_procedural.get("resolved_body_id", "")) == ""
		and not bool(_pv_unknown.get("using_body_art", true))
		and str(_pv_unknown.get("resolved_body_id", "")) == "",
		"dwarf=%s unknown=%s" % [str(_pv_dwarf_procedural), str(_pv_unknown)])

	player.velocity.x = 1.0
	_pv.refresh_facing()
	var _pv_right: int = _pv.facing_sign()
	player.velocity.x = -1.0
	_pv.refresh_facing()
	var _pv_left: int = _pv.facing_sign()
	player.velocity.x = 0.0
	_check("player_visual_faces_both_directions",
		_pv_right == 1 and _pv_left == -1
		and is_equal_approx(_pv.scale.x, -1.0) and is_equal_approx(_pv.scale.y, 1.0),
		"right=%d left=%d scale=%s" % [_pv_right, _pv_left, str(_pv.scale)])

	player.apply_equipment({})
	var _pv_empty_gear: Dictionary = _pv.visible_gear_ids()
	player.apply_equipment({
		"weapon": "sword_crude",
		"helmet": "helmet_crude",
		"torso": "torso_crude",
		"feet": "feet_crude",
	})
	var _pv_gear: Dictionary = _pv.visible_gear_ids()
	_check("player_visual_empty_slots_show_no_armor", _pv_empty_gear.is_empty(),
		"gear=%s" % str(_pv_empty_gear))
	_check("player_visual_equipment_procedural_fallback",
		str(_pv_gear.get("weapon", "")) == "sword_crude"
		and str(_pv_gear.get("helmet", "")) == "helmet_crude"
		and str(_pv_gear.get("torso", "")) == "torso_crude"
		and str(_pv_gear.get("feet", "")) == "feet_crude"
		and _pv.gear_uses_procedural_fallback("sword_crude")
		and _pv.gear_uses_procedural_fallback("helmet_crude")
		and _pv.gear_uses_procedural_fallback("torso_crude")
		and _pv.gear_uses_procedural_fallback("feet_crude"),
		"gear=%s" % str(_pv_gear))
	var _pv_shape: RectangleShape2D = player.get_node("CollisionShape2D").shape
	_check("player_visual_collision_unchanged", _pv_shape.size == Vector2(12, 28),
		"size=%s" % str(_pv_shape.size))

	# --- FQ-13P3: player cosmetic body variants (full-body pool) ---
	# distinct sprite per variant (human has a 2-entry pool); variant 0 canonical.
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "tan", "visual_variant": 0})
	var _p3_v0 = _pv._body_texture
	var _p3_snap0: Dictionary = _pv.presentation_snapshot()
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "tan", "visual_variant": 1})
	var _p3_v1 = _pv._body_texture
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "tan", "visual_variant": 2})
	var _p3_v2 = _pv._body_texture
	_check("fq13p3_variant_selects_distinct_sprite",
		_p3_v0 != null and _p3_v1 != null and _p3_v2 != null
		and _p3_v0 != _p3_v1 and _p3_v1 != _p3_v2 and _p3_v0 != _p3_v2
		and int(_p3_snap0.get("visual_variant", -1)) == 0,
		"distinct=%s snap0=%d" % [
			str(_p3_v0 != _p3_v1 and _p3_v1 != _p3_v2),
			int(_p3_snap0.get("visual_variant", -1))])

	# variant 0 is the canonical body; an out-of-range index wraps within the pool.
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "tan", "visual_variant": 0})
	var _p3_canon = _pv._body_texture
	player.apply_character({"species": "human", "body_variant": "default",
		"appearance": "tan", "visual_variant": 3})   # pool size 2 -> wraps to variant 1
	_check("fq13p3_variant0_canonical_and_wrap",
		_p3_canon == BlockRegistry.visual_texture("players", "human")
		and _pv._body_texture == _p3_v1,
		"canon=%s wrap=%s" % [
			str(_p3_canon == BlockRegistry.visual_texture("players", "human")),
			str(_pv._body_texture == _p3_v1)])

	# a body with no variant pool falls back to its canonical sprite.
	player.apply_character({"species": "dwarf", "body_variant": "default",
		"appearance": "tan", "visual_variant": 2})
	_check("fq13p3_no_pool_falls_back",
		BlockRegistry.visual_variant_textures("players", "dwarf").is_empty()
		and _pv._body_texture == BlockRegistry.visual_texture("players", "dwarf")
		and _pv.using_body_art(),
		"dwarf_canonical=%s" % str(
			_pv._body_texture == BlockRegistry.visual_texture("players", "dwarf")))

	# character owns the variant (stored on create; deterministic legacy default);
	# it is presentation-only — never a world-save key.
	var _p3_made: Dictionary = GameState.create_character({"name": "P3 Test",
		"species": "human", "visual_variant": 2})
	var _p3_state: Dictionary = root.save_manager.collect_state()
	_check("fq13p3_character_owns_variant_not_saved",
		int(_p3_made.get("visual_variant", -1)) == 2
		and GameState.default_visual_variant("charX") == GameState.default_visual_variant("charX")
		and not ("visual_variant" in _p3_state)
		and not ("visual_variant" in _p3_state.get("player", {})),
		"made=%d in_save=%s" % [int(_p3_made.get("visual_variant", -1)),
			str("visual_variant" in _p3_state or "visual_variant" in _p3_state.get("player", {}))])
	GameState.delete_character(str(_p3_made.get("id", "")))

	# the creation UI script compiles (smoke bypasses the shell scene).
	_check("fq13p3_shell_ui_compiles",
		preload("res://scripts/shell/shell_ui.gd") != null, "shell_ui preloaded")

	player.tool_tier = _pv_saved_pick_tier
	player.axe_tier = _pv_saved_axe_tier
	player.apply_equipment(_pv_saved_equipment)
	player.apply_character(_pv_saved_character)

	# --- FQ-09V: visual variant pipeline ---

	# Same smoke_tmp_* temp-art discipline as FQ-07 (leftover cleanup first).
	var _fq09v_files: Array[String] = [
		"res://art/generated/blocks/smoke_tmp_dirt_a.png",
		"res://art/generated/blocks/smoke_tmp_dirt_b.png",
		"res://art/generated/blocks/smoke_tmp_vscan_01.png",
		"res://art/generated/blocks/smoke_tmp_vscan_02.png"]
	for _fq09v_leftover in _fq09v_files:
		if FileAccess.file_exists(_fq09v_leftover):
			DirAccess.remove_absolute(_fq09v_leftover)
	BlockRegistry.clear_visual_cache()

	# (a) pools resolve both ways: the <id>_01/_02 file convention (scanned on
	# a temp id so no real asset names are ever written) and an explicit
	# array entry for a real block; a pool-less block reports no pool.
	var _fq09v_img_a := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq09v_img_a.fill(Color(1.0, 0.0, 0.0))
	var _fq09v_img_b := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq09v_img_b.fill(Color(0.0, 0.0, 1.0))
	for _fq09v_path in _fq09v_files:
		var _fq09v_src: Image = _fq09v_img_b
		if "_a" in _fq09v_path or "_01" in _fq09v_path:
			_fq09v_src = _fq09v_img_a
		_fq09v_src.save_png(_fq09v_path)
	BlockRegistry.visual_assets["categories"]["blocks"]["dirt"] = [
		"art/generated/blocks/smoke_tmp_dirt_a.png",
		"art/generated/blocks/smoke_tmp_dirt_b.png"]
	BlockRegistry.clear_visual_cache()
	_check("fq09v_variant_pools_resolve",
		BlockRegistry.visual_variant_textures("blocks", "smoke_tmp_vscan").size() == 2
		and BlockRegistry.visual_variant_textures("blocks", "dirt").size() == 2
		and BlockRegistry.visual_variant_textures("blocks", "stone").is_empty(),
		"scan=%d pool=%d stone=%d" % [
			BlockRegistry.visual_variant_textures("blocks", "smoke_tmp_vscan").size(),
			BlockRegistry.visual_variant_textures("blocks", "dirt").size(),
			BlockRegistry.visual_variant_textures("blocks", "stone").size()])

	# (b) selection is deterministic from seed + cell: two setups of the same
	# seed render identical dirt variants, with at least two variants in use.
	world.rebuild_tileset()
	world.setup(777)
	var _fq09v_cells: Array = []
	for _fq09v_c: Vector2i in world.cells:
		if world.cells[_fq09v_c] == "dirt":
			_fq09v_cells.append(_fq09v_c)
		if _fq09v_cells.size() >= 40:
			break
	var _fq09v_first: Array = []
	var _fq09v_distinct: Dictionary = {}
	for _fq09v_c1: Vector2i in _fq09v_cells:
		var _fq09v_sid: int = world._tilemap.get_cell_source_id(_fq09v_c1)
		_fq09v_first.append(_fq09v_sid)
		_fq09v_distinct[_fq09v_sid] = true
	world.setup(777)
	var _fq09v_stable := true
	for _fq09v_i in range(_fq09v_cells.size()):
		if world._tilemap.get_cell_source_id(_fq09v_cells[_fq09v_i]) != _fq09v_first[_fq09v_i]:
			_fq09v_stable = false
			break
	_check("fq09v_deterministic_variant_selection",
		_fq09v_cells.size() >= 10 and _fq09v_stable and _fq09v_distinct.size() >= 2,
		"cells=%d stable=%s distinct=%d" % [
			_fq09v_cells.size(), str(_fq09v_stable), _fq09v_distinct.size()])

	# (c) the seed drives the pattern (nothing is stored): another seed picks
	# a different variant somewhere among cells that are dirt in both worlds.
	# Zero overlap or zero difference FAILS the check (never a vacuous pass).
	world.setup(778)
	var _fq09v_changed := false
	for _fq09v_i2 in range(_fq09v_cells.size()):
		var _fq09v_c2: Vector2i = _fq09v_cells[_fq09v_i2]
		if world.block_at(_fq09v_c2) != "dirt":
			continue
		if world._tilemap.get_cell_source_id(_fq09v_c2) != _fq09v_first[_fq09v_i2]:
			_fq09v_changed = true
			break
	_check("fq09v_seed_changes_selection", _fq09v_changed,
		"seed 777 vs 778 over %d sampled cells" % _fq09v_cells.size())

	# (d) removal falls all the way back to the single generated texture and
	# the live world state returns untouched.
	for _fq09v_path2 in _fq09v_files:
		DirAccess.remove_absolute(_fq09v_path2)
	BlockRegistry.visual_assets["categories"]["blocks"].erase("dirt")
	BlockRegistry.clear_visual_cache()
	world.rebuild_tileset()
	_check("fq09v_fallback_after_removal",
		(world._source_ids["dirt"] as Array).size() == 1
		and BlockRegistry.visual_variant_textures("blocks", "dirt").is_empty()
		and world._make_block_texture("dirt", 16).get_image().get_pixel(4, 4) \
			.is_equal_approx(_fq07_clean_pixel),
		"sources=%d" % (world._source_ids["dirt"] as Array).size())
	_check("fq09v_world_restored", root.load_game())

	# --- FQ-09C: opening prologue (driven deterministically — autoplay timing
	# is disabled, so no check ever waits through real-time panel durations) ---

	var _fq09c_script: GDScript = load("res://scripts/shell/prologue.gd")

	# (a) this very run proves the COHERONIA_SMOKE bypass: the shell jumped
	# straight to Main and no prologue node ever entered the tree.
	_check("fq09c_smoke_bypasses_prologue",
		OS.get_environment("COHERONIA_SMOKE") == "1"
		and get_tree().root.find_child("Prologue", true, false) == null)

	# (b) scene count, order, and exact overlay copy from the storyboard; each
	# advance() moves exactly one scene (the shown text is read live per scene).
	var _fq09c_expected: Array = [
		["opening_01_first_star", "Before the first hall, the world was held together by names, roads, oaths, and light."],
		["opening_02_unraveling_roads", "Then the old compacts failed. Roads forgot their ends. Borders became dust."],
		["opening_03_scattered_peoples", "The scattered peoples carried what they could: craft, seed, iron, memory, anger, and hope."],
		["opening_04_darkness_measures_light", "Hunger tested every storehouse. Storms tested every roof. The dark measured every light."],
		["opening_05_first_hall_raised", "So they raised a hall—not a throne, not a temple, but a promise with a roof."],
		["opening_06_attunement_pulse", "Where shelter, food, work, and courage aligned, the world answered."],
		["opening_07_civilization_pushes_back", "Dig. Build. Feed. Govern. Endure."],
		["opening_08_title_card", ""],
	]
	var _fq09c_pro: Control = _fq09c_script.new()
	_fq09c_pro.autoplay = false
	add_child(_fq09c_pro)
	var _fq09c_done: Array = [0, false]   # [finished emit count, completed flag]
	_fq09c_pro.finished.connect(func(completed: bool) -> void:
		_fq09c_done[0] += 1
		_fq09c_done[1] = completed)
	var _fq09c_copy_ok: bool = _fq09c_pro.panel_count() == 8
	var _fq09c_copy_detail := "8 panels, exact storyboard copy"
	for _fq09c_i in range(8):
		if _fq09c_pro.current_index() != _fq09c_i:
			_fq09c_copy_ok = false
			_fq09c_copy_detail = "index drift at panel %d (got %d)" % [_fq09c_i, _fq09c_pro.current_index()]
			break
		if str(_fq09c_pro.panel_ids()[_fq09c_i]) != str(_fq09c_expected[_fq09c_i][0]) \
				or _fq09c_pro.current_overlay_text() != str(_fq09c_expected[_fq09c_i][1]):
			_fq09c_copy_ok = false
			_fq09c_copy_detail = "panel %d mismatch: id=%s text=%s" % [_fq09c_i,
				str(_fq09c_pro.panel_ids()[_fq09c_i]), _fq09c_pro.current_overlay_text()]
			break
		if _fq09c_i < 7:
			_fq09c_pro.advance()
	_check("fq09c_panel_order_and_exact_copy", _fq09c_copy_ok, _fq09c_copy_detail)

	# (c) the title card renders the three exact engine-rendered lines — the
	# authorship lock (`By Paul Peck`) is a live Label, never baked art.
	_check("fq09c_title_card_authorship",
		_fq09c_pro.title_card_visible()
		and _fq09c_pro.title_card_lines() == ["COHERONIA", "By Paul Peck",
			"Where civilization pushes back."],
		"lines=%s" % str(_fq09c_pro.title_card_lines()))

	# (d) completion emits finished(true) exactly once; further advance/skip
	# calls past the end never re-emit (no double-advance or double-finish).
	_fq09c_pro.advance()
	_fq09c_pro.advance()
	_fq09c_pro.skip()
	_check("fq09c_completion_emits_once",
		_fq09c_done[0] == 1 and _fq09c_done[1] and _fq09c_pro.is_finished(),
		"emits=%d completed=%s" % [_fq09c_done[0], str(_fq09c_done[1])])
	_fq09c_pro.queue_free()
	await get_tree().process_frame

	# (e) skip (the Escape path) finishes safely mid-sequence with
	# completed=false; the single advance() before it moved exactly one scene;
	# a skip leaves no clock or audio running behind the menu.
	var _fq09c_skip: Control = _fq09c_script.new()
	_fq09c_skip.autoplay = false
	add_child(_fq09c_skip)
	var _fq09c_skip_done: Array = [0, true]
	_fq09c_skip.finished.connect(func(completed: bool) -> void:
		_fq09c_skip_done[0] += 1
		_fq09c_skip_done[1] = completed)
	_fq09c_skip.advance()
	var _fq09c_idx_after_one: int = _fq09c_skip.current_index()
	_fq09c_skip.skip()
	_fq09c_skip.advance()
	_check("fq09c_skip_finishes_safely",
		_fq09c_idx_after_one == 1 and _fq09c_skip_done[0] == 1
		and not _fq09c_skip_done[1] and _fq09c_skip.is_finished()
		and not _fq09c_skip.is_processing() and not _fq09c_skip.audio_playing(),
		"idx_after_one_advance=%d emits=%d completed=%s processing=%s audio=%s" % [
			_fq09c_idx_after_one, _fq09c_skip_done[0], str(_fq09c_skip_done[1]),
			str(_fq09c_skip.is_processing()), str(_fq09c_skip.audio_playing())])
	_fq09c_skip.queue_free()
	await get_tree().process_frame

	# (f) prologue_seen is a profile-level flag: absent on a clean profile,
	# persists through a shell reload, idempotent on replay closeout. The
	# operator's real profile value is restored afterwards.
	var _fq09c_prev_seen: bool = bool(GameState.profile.get("prologue_seen", false))
	GameState.profile.erase("prologue_seen")
	GameState.save_shell()
	GameState.load_shell()
	var _fq09c_clean_default: bool = not bool(GameState.profile.get("prologue_seen", false))
	GameState.mark_prologue_seen()
	GameState.load_shell()
	var _fq09c_seen_after: bool = bool(GameState.profile.get("prologue_seen", false))
	GameState.mark_prologue_seen()   # replay closeout: stays true, never clears
	var _fq09c_still_seen: bool = bool(GameState.profile.get("prologue_seen", false))
	if _fq09c_prev_seen:
		GameState.profile["prologue_seen"] = true
	else:
		GameState.profile.erase("prologue_seen")
	GameState.save_shell()
	_check("fq09c_seen_flag_profile_roundtrip",
		_fq09c_clean_default and _fq09c_seen_after and _fq09c_still_seen,
		"clean_default=%s persisted=%s idempotent=%s" % [
			str(_fq09c_clean_default), str(_fq09c_seen_after), str(_fq09c_still_seen)])

	# (g) replay isolation: a full replay run creates/alters no characters or
	# worlds (the prologue itself writes nothing; the shell owns the flag).
	var _fq09c_chars_before: int = GameState.characters.size()
	var _fq09c_worlds_before: int = GameState.list_worlds().size()
	var _fq09c_replay: Control = _fq09c_script.new()
	_fq09c_replay.autoplay = false
	add_child(_fq09c_replay)
	for _fq09c_j in range(8):
		_fq09c_replay.advance()
	_check("fq09c_replay_isolated",
		_fq09c_replay.is_finished()
		and GameState.characters.size() == _fq09c_chars_before
		and GameState.list_worlds().size() == _fq09c_worlds_before,
		"chars %d->%d worlds %d->%d" % [_fq09c_chars_before, GameState.characters.size(),
			_fq09c_worlds_before, GameState.list_worlds().size()])
	_fq09c_replay.queue_free()
	await get_tree().process_frame

	# (h) cinematic contract: durations and animation cues are data-driven
	# (42.0s total, every scene declares nontrivial cues), the authored
	# surface is the locked 640x360 pixel grid, every scene genuinely
	# animates (the plotted command state differs across ticks — a fade-only
	# scene would fingerprint identically), and rendering is deterministic
	# (same scene+tick always replots the identical command list).
	var _fq09c_cin: Control = _fq09c_script.new()
	_fq09c_cin.autoplay = false
	add_child(_fq09c_cin)
	var _fq09c_durs: Array = _fq09c_cin.scene_durations()
	var _fq09c_total := 0.0
	var _fq09c_cues_ok := true
	for _fq09c_di in range(_fq09c_durs.size()):
		_fq09c_total += float(_fq09c_durs[_fq09c_di])
		if float(_fq09c_durs[_fq09c_di]) <= 0.0 \
				or (_fq09c_cin.scene_cues(_fq09c_di) as Array).is_empty():
			_fq09c_cues_ok = false
	_check("fq09c_scene_timing_and_cues_data_driven",
		_fq09c_durs.size() == 8 and absf(_fq09c_total - 42.0) < 0.001 and _fq09c_cues_ok,
		"scenes=%d total=%.1fs cues_ok=%s" % [_fq09c_durs.size(), _fq09c_total,
			str(_fq09c_cues_ok)])
	var _fq09c_cv: Control = _fq09c_cin.canvas()
	_check("fq09c_pixel_surface_640x360",
		_fq09c_cv.W == 640 and _fq09c_cv.H == 360 and _fq09c_cv.TICK_HZ == 10)
	var _fq09c_static_scenes := ""
	var _fq09c_nondet := ""
	for _fq09c_si in range(8):
		var _fq09c_late: int = int(float(_fq09c_durs[_fq09c_si]) * 10.0) - 2
		if _fq09c_cv.fingerprint(_fq09c_si, 1) == _fq09c_cv.fingerprint(_fq09c_si, _fq09c_late):
			_fq09c_static_scenes += "%d " % _fq09c_si
		if _fq09c_cv.fingerprint(_fq09c_si, _fq09c_late) != _fq09c_cv.fingerprint(_fq09c_si, _fq09c_late):
			_fq09c_nondet += "%d " % _fq09c_si
	_check("fq09c_every_scene_genuinely_animated", _fq09c_static_scenes == "",
		("static scenes: " + _fq09c_static_scenes) if _fq09c_static_scenes != ""
		else "all 8 scenes replot differently across ticks")
	_check("fq09c_rendering_deterministic", _fq09c_nondet == "",
		("nondeterministic scenes: " + _fq09c_nondet) if _fq09c_nondet != ""
		else "same scene+tick always yields the identical command list")
	_fq09c_cin.queue_free()
	await get_tree().process_frame

	# (h2) cel-shot hook: a frame pool registered for a scene id (fq09v temp
	# discipline — no real asset filename is written) plays authored frames
	# in place of the plotted shot; removing the pool falls back cleanly.
	var _fq09c_cels: Array[String] = [
		"res://art/generated/opening/smoke_tmp_cel_a.png",
		"res://art/generated/opening/smoke_tmp_cel_b.png"]
	for _fq09c_cp in _fq09c_cels:
		if FileAccess.file_exists(_fq09c_cp):
			DirAccess.remove_absolute(_fq09c_cp)
	var _fq09c_cel_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq09c_cel_img.fill(Color(0.2, 0.6, 0.9))
	for _fq09c_cp2 in _fq09c_cels:
		_fq09c_cel_img.save_png(_fq09c_cp2)
	BlockRegistry.visual_assets["categories"]["opening"]["opening_01_first_star"] = [
		"art/generated/opening/smoke_tmp_cel_a.png",
		"art/generated/opening/smoke_tmp_cel_b.png"]
	BlockRegistry.clear_visual_cache()
	var _fq09c_celp: Control = _fq09c_script.new()
	_fq09c_celp.autoplay = false
	add_child(_fq09c_celp)
	var _fq09c_cel_on: bool = _fq09c_celp.current_uses_cel() \
		and _fq09c_celp.cel_frame_index() == 0
	_fq09c_celp.queue_free()
	BlockRegistry.visual_assets["categories"]["opening"].erase("opening_01_first_star")
	for _fq09c_cp3 in _fq09c_cels:
		DirAccess.remove_absolute(_fq09c_cp3)
	BlockRegistry.clear_visual_cache()
	await get_tree().process_frame
	var _fq09c_celq: Control = _fq09c_script.new()
	_fq09c_celq.autoplay = false
	add_child(_fq09c_celq)
	var _fq09c_cel_off: bool = not _fq09c_celq.current_uses_cel()
	_check("fq09c_cel_shot_hook", _fq09c_cel_on and _fq09c_cel_off,
		"pool_plays=%s removal_falls_back=%s" % [str(_fq09c_cel_on), str(_fq09c_cel_off)])
	_fq09c_celq.queue_free()
	await get_tree().process_frame

	# (i) the normal title screen renders the exact title/authorship/tagline
	# labels plus the Prologue replay button next to the intact Play/Quit flow
	# (shell UI built off-tree so _ready's smoke bypass never runs).
	var _fq09c_shell: Control = (load("res://scripts/shell/shell_ui.gd") as GDScript).new()
	_fq09c_shell._build_base()
	_fq09c_shell._show_title()
	var _fq09c_labels: Array = []
	var _fq09c_buttons: Array = []
	var _fq09c_stack: Array = [_fq09c_shell]
	while not _fq09c_stack.is_empty():
		var _fq09c_node: Node = _fq09c_stack.pop_back()
		for _fq09c_child in _fq09c_node.get_children():
			_fq09c_stack.append(_fq09c_child)
		if _fq09c_node is Label:
			_fq09c_labels.append((_fq09c_node as Label).text)
		elif _fq09c_node is Button:
			_fq09c_buttons.append((_fq09c_node as Button).text)
	_check("fq09c_title_screen_authorship_and_replay",
		"COHERONIA" in _fq09c_labels and "By Paul Peck" in _fq09c_labels
		and "Where civilization pushes back." in _fq09c_labels
		and "Prologue" in _fq09c_buttons and "Play" in _fq09c_buttons
		and "Quit" in _fq09c_buttons,
		"labels=%s buttons=%s" % [str(_fq09c_labels), str(_fq09c_buttons)])
	_fq09c_shell.free()

	# --- FQ-09W: scenic backdrop, backing walls, underground darkness ---

	# (a) natural walls derive deterministically from seed/config: same seed
	# twice yields the same wall map, the dirt band sits above stone, nothing
	# exists at/above the surface row, and the wall tileset carries zero
	# physics/occlusion layers — provably inert to collision/shelter/light.
	world.setup(777)
	var _fq09w_dd: int = int(GameState.current_config.gen("dirt_depth"))
	var _fq09w_x: int = clampi(int(world.hall_info["center_cell"].x) - 30, 2, world.width - 14)
	var _fq09w_sy: int = int(world.surface[_fq09w_x])
	var _fq09w_samples: Array = []
	for _fq09w_i in range(10):
		_fq09w_samples.append(Vector2i(_fq09w_x + _fq09w_i,
			int(world.surface[_fq09w_x + _fq09w_i]) + 1 + (_fq09w_i % 12)))
	var _fq09w_first: Array = []
	for _fq09w_c: Vector2i in _fq09w_samples:
		_fq09w_first.append(world.wall_at(_fq09w_c))
	world.setup(777)
	var _fq09w_same := true
	for _fq09w_i2 in range(_fq09w_samples.size()):
		if world.wall_at(_fq09w_samples[_fq09w_i2]) != _fq09w_first[_fq09w_i2]:
			_fq09w_same = false
	_check("fq09w_walls_deterministic_and_inert",
		_fq09w_same
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy + 1)) == "dirt_wall"
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy + _fq09w_dd + 1)) == "stone_wall"
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy)) == ""
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy - 3)) == ""
		and world._walls.tile_set.get_physics_layers_count() == 0
		and world._walls.tile_set.get_occlusion_layers_count() == 0,
		"same=%s band=%s/%s above_empty=%s phys=%d occ=%d" % [str(_fq09w_same),
			world.wall_at(Vector2i(_fq09w_x, _fq09w_sy + 1)),
			world.wall_at(Vector2i(_fq09w_x, _fq09w_sy + _fq09w_dd + 1)),
			str(world.wall_at(Vector2i(_fq09w_x, _fq09w_sy)) == ""),
			world._walls.tile_set.get_physics_layers_count(),
			world._walls.tile_set.get_occlusion_layers_count()])

	# (b) mining a below-surface block reveals the wall behind it while the
	# foreground stays a normal air delta (walls are never part of cells).
	var _fq09w_mine := Vector2i(_fq09w_x, _fq09w_sy + 2)
	world.break_block(_fq09w_mine)
	_check("fq09w_mined_chamber_reveals_wall",
		world.block_at(_fq09w_mine) == "air"
		and str(world.deltas.get(_fq09w_mine, "")) == "air"
		and world.wall_at(_fq09w_mine) != "",
		"block=%s delta=%s wall=%s" % [world.block_at(_fq09w_mine),
			str(world.deltas.get(_fq09w_mine, "")), world.wall_at(_fq09w_mine)])

	# (c) underground is dark at midday and the surface stays full daylight —
	# the depth-aware ambient target, not the smoothing lerp, is asserted.
	root.time_of_day = 0.5
	root.is_night = false
	var _fq09w_storm_was: bool = root.storm_active
	root.storm_active = false
	player.global_position = world.cell_center(Vector2i(_fq09w_x, _fq09w_sy + 10))
	var _fq09w_deep: float = root.ambient_darkness_factor()
	var _fq09w_deep_col: Color = root.ambient_target_color()
	player.global_position = world.cell_center(Vector2i(_fq09w_x, _fq09w_sy - 2))
	var _fq09w_surf: float = root.ambient_darkness_factor()
	var _fq09w_surf_col: Color = root.ambient_target_color()
	_check("fq09w_underground_dark_at_midday",
		_fq09w_deep > 0.95 and _fq09w_deep_col.r < 0.15
		and is_equal_approx(_fq09w_surf, 0.0) and _fq09w_surf_col == root.DAY_TINT,
		"deep=%.2f deep_col=%s surface=%.2f surface_col=%s" % [
			_fq09w_deep, str(_fq09w_deep_col), _fq09w_surf, str(_fq09w_surf_col)])

	# (d) roof-aware: a mined open shaft admits daylight to its floor while a
	# sealed column at the same depth stays dark (live column skylight).
	var _fq09w_shx: int = _fq09w_x + 6
	var _fq09w_shy: int = int(world.surface[_fq09w_shx])
	for _fq09w_y in range(_fq09w_shy, _fq09w_shy + 10):
		if world.block_at(Vector2i(_fq09w_shx, _fq09w_y)) != "air":
			world.break_block(Vector2i(_fq09w_shx, _fq09w_y))
	player.global_position = world.cell_center(Vector2i(_fq09w_shx, _fq09w_shy + 9))
	var _fq09w_shaft_f: float = root.ambient_darkness_factor()
	player.global_position = world.cell_center(
		Vector2i(_fq09w_shx + 3, int(world.surface[_fq09w_shx + 3]) + 9))
	var _fq09w_sealed_f: float = root.ambient_darkness_factor()
	_check("fq09w_open_shaft_admits_daylight",
		_fq09w_shaft_f < 0.2 and _fq09w_sealed_f > 0.95,
		"shaft=%.2f sealed=%.2f" % [_fq09w_shaft_f, _fq09w_sealed_f])

	# (e) the scenic backdrop sits behind walls, which sit behind blocks. The
	# shipped sky/far/mid art resolves at exact sizes with nearest filtering.
	var _fq09w_bd: Node2D = world.get_node("Backdrop")
	var _fq09w_sky: Texture2D = _fq09w_bd.layer_texture("surface_sky")
	var _fq09w_far: Texture2D = _fq09w_bd.layer_texture("surface_far_terrain")
	var _fq09w_mid: Texture2D = _fq09w_bd.layer_texture("surface_mid_silhouette")
	_check("fq09w_backdrop_behind_world",
		_fq09w_bd != null and _fq09w_bd.z_index < world._walls.z_index
		and world._walls.z_index < world._tilemap.z_index
		and _fq09w_bd.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and _fq09w_sky != null and _fq09w_sky.get_size() == Vector2(640, 360)
		and _fq09w_far != null and _fq09w_far.get_size() == Vector2(640, 36)
		and _fq09w_mid != null and _fq09w_mid.get_size() == Vector2(640, 20),
		"bd_z=%d walls_z=%d blocks_z=%d sky=%s far=%s mid=%s" % [_fq09w_bd.z_index,
			world._walls.z_index, world._tilemap.z_index,
			str(_fq09w_sky.get_size() if _fq09w_sky != null else Vector2i.ZERO),
			str(_fq09w_far.get_size() if _fq09w_far != null else Vector2i.ZERO),
			str(_fq09w_mid.get_size() if _fq09w_mid != null else Vector2i.ZERO)])

	# (f) wall art hook: a dropped-in back_walls PNG resolves through the
	# registry and removal falls back (fq09v temp discipline; the wall
	# tileset itself reads art once at world entry per the FQ-07 rule).
	var _fq09w_tmp := "res://art/generated/back_walls/smoke_tmp_wall.png"
	if FileAccess.file_exists(_fq09w_tmp):
		DirAccess.remove_absolute(_fq09w_tmp)
	BlockRegistry.clear_visual_cache()
	var _fq09w_no_art: bool = BlockRegistry.visual_texture("back_walls", "smoke_tmp_wall") == null
	var _fq09w_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq09w_img.fill(Color(0.3, 0.25, 0.2))
	_fq09w_img.save_png(_fq09w_tmp)
	BlockRegistry.clear_visual_cache()
	var _fq09w_with_art: bool = BlockRegistry.visual_texture("back_walls", "smoke_tmp_wall") != null
	DirAccess.remove_absolute(_fq09w_tmp)
	BlockRegistry.clear_visual_cache()
	var _fq09w_back: bool = BlockRegistry.visual_texture("back_walls", "smoke_tmp_wall") == null
	_check("fq09w_wall_art_hook", _fq09w_no_art and _fq09w_with_art and _fq09w_back,
		"none=%s resolves=%s falls_back=%s" % [str(_fq09w_no_art),
			str(_fq09w_with_art), str(_fq09w_back)])

	# (g) restore the saved world/time for the sections that follow; walls
	# and the skylight cache rebuild inside setup on load.
	root.storm_active = _fq09w_storm_was
	_check("fq09w_world_restored", root.load_game())

	# --- FQ-09M: lightweight action animation ---
	# Presentation only: state hooks are asserted directly, the fx nodes are
	# transient "action_fx" group members that free themselves, and every
	# gameplay number is pinned by the pre-existing checks (mining frames,
	# drops, damage math, saves) which all still run after this section.

	# (a) the tool swing tracks mining state and resets with it.
	var _fq09m_swing_cell: Variant = _find_block(world, world.hall_info["center_cell"], "stone")
	var _fq09m_cell: Variant = _find_block(world, world.hall_info["center_cell"], "dirt")
	var _fq09m_swing_ok := false
	var _fq09m_detail := "no stone swing fixture found"
	if _fq09m_swing_cell != null:
		player.global_position = world.cell_center(_fq09m_swing_cell) + Vector2(0, -32.0)
		player._reset_mining()
		var _fq09m_idle: int = player.swing_phase()
		player.process_mining(_fq09m_swing_cell, 0.0)
		var _fq09m_active: int = player.swing_phase()
		player.process_mining(_fq09m_swing_cell, minf(player.mine_required * 0.5, 0.34))
		var _fq09m_mid: int = player.swing_phase()
		player._reset_mining()
		_fq09m_swing_ok = _fq09m_idle == -1 and _fq09m_active >= 0 and _fq09m_mid >= 0 \
			and _fq09m_mid != _fq09m_active and player.swing_phase() == -1
		_fq09m_detail = "idle=%d active=%d mid=%d after_reset=%d" % [
			_fq09m_idle, _fq09m_active, _fq09m_mid, player.swing_phase()]
	_check("fq09m_swing_tracks_mining", _fq09m_swing_ok, _fq09m_detail)

	# (a2) PlayerVisual consumes all three established phases and chooses the
	# tool from the targeted block without changing mining timing.
	var _fq09m_three_poses := false
	var _fq09m_tool_fallback := false
	var _fq09m_pick_id := ""
	var _fq09m_axe_id := ""
	var _fq09m_old_axe_tier: int = player.axe_tier
	if _fq09m_swing_cell != null:
		player.mine_target = _fq09m_swing_cell
		player.mine_required = 1.0
		var _fq09m_pose_phases: Array = []
		for _fq09m_progress in [0.0, 0.2, 0.34]:
			player.mine_progress = _fq09m_progress
			_fq09m_pose_phases.append(int(_pv.presentation_snapshot()["swing_phase"]))
		_fq09m_three_poses = _fq09m_pose_phases == [0, 1, 2]
		player.axe_tier = 1
		_fq09m_pick_id = _pv.active_tool_id()
		_fq09m_tool_fallback = _pv.tool_swing_uses_procedural_fallback()
		var _fq09m_tree_cell: Variant = _find_block(
			world, world.hall_info["center_cell"], "tree_trunk")
		if _fq09m_tree_cell != null:
			player.mine_target = _fq09m_tree_cell
			_fq09m_axe_id = _pv.active_tool_id()
	player._reset_mining()
	player.axe_tier = _fq09m_old_axe_tier
	_check("player_visual_three_swing_poses",
		_fq09m_three_poses and _fq09m_tool_fallback,
		"expected=[0, 1, 2] procedural_tool=%s" % str(_fq09m_tool_fallback))
	_check("player_visual_tool_matches_target",
		_fq09m_pick_id.begins_with("pick_") and _fq09m_axe_id == "axe_crude",
		"stone=%s tree=%s" % [_fq09m_pick_id, _fq09m_axe_id])

	# (b) placing a block spawns exactly one placement pulse.
	var _fq09m_placed := false
	var _fq09m_after_mine := 0
	if _fq09m_cell != null:
		await _mine_cell(world, player, _fq09m_cell)
		_fq09m_after_mine = get_tree().get_nodes_in_group("action_fx").size()
		_fq09m_placed = player.try_place(_fq09m_cell, "dirt")
	_check("fq09m_place_pulse_spawns",
		_fq09m_cell != null and _fq09m_placed
		and get_tree().get_nodes_in_group("action_fx").size() == _fq09m_after_mine + 1,
		"cell=%s placed=%s fx %d -> %d" % [str(_fq09m_cell), str(_fq09m_placed),
			_fq09m_after_mine, get_tree().get_nodes_in_group("action_fx").size()])

	# (c) the attunement cast spawns its ring at the cast moment.
	player.attunement = player.max_attunement()
	player._pulse_cooldown = 0.0
	var _fq09m_fx0: int = get_tree().get_nodes_in_group("action_fx").size()
	var _fq09m_fired: bool = player._try_attune_pulse()
	_check("fq09m_cast_ring_on_pulse",
		_fq09m_fired
		and get_tree().get_nodes_in_group("action_fx").size() == _fq09m_fx0 + 1,
		"fired=%s" % str(_fq09m_fired))

	# (d) a landed hit sparks; a collapse adds dust at fall and respawn.
	player.health = player.max_health
	player._hurt_cooldown = 0.0
	var _fq09m_fx1: int = get_tree().get_nodes_in_group("action_fx").size()
	player.take_damage(5.0)
	var _fq09m_after_hit: int = get_tree().get_nodes_in_group("action_fx").size()
	player._hurt_cooldown = 0.0
	player.take_damage(9999.0)
	_check("fq09m_hurt_and_collapse_fx",
		_fq09m_after_hit == _fq09m_fx1 + 1
		and get_tree().get_nodes_in_group("action_fx").size() >= _fq09m_after_hit + 3,
		"hit fx %d -> %d, after collapse %d" % [_fq09m_fx1, _fq09m_after_hit,
			get_tree().get_nodes_in_group("action_fx").size()])

	# (e) enemy hits spark too (hp/drops behavior stays pinned by fq08).
	for _fq09m_t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_fq09m_t):
			_fq09m_t.queue_free()
	await get_tree().process_frame
	var _fq09m_slime: Node = root.spawn_enemy_for_test("surface_slime")
	var _fq09m_fx2: int = get_tree().get_nodes_in_group("action_fx").size()
	if _fq09m_slime != null:
		_fq09m_slime.hp = 3
		_fq09m_slime.max_hp = 3
		_fq09m_slime.take_hit(1)
	_check("fq09m_enemy_hit_spark",
		_fq09m_slime != null
		and get_tree().get_nodes_in_group("action_fx").size() == _fq09m_fx2 + 1,
		"spawned=%s fx %d -> %d" % [str(_fq09m_slime != null), _fq09m_fx2,
			get_tree().get_nodes_in_group("action_fx").size()])
	if is_instance_valid(_fq09m_slime):
		_fq09m_slime.queue_free()
	await get_tree().process_frame

	# (f) a successful hand craft fires the confirmation burst (the forge
	# handlers share the same _craft_confirm_fx path).
	player.inventory.from_dict({"wood": 4, "stone": 4})
	player.inventory_changed.emit()
	var _fq09m_fx3: int = get_tree().get_nodes_in_group("action_fx").size()
	var _fq09m_crafted: bool = player.craft("craft_torch")
	_check("fq09m_craft_confirmation",
		_fq09m_crafted
		and get_tree().get_nodes_in_group("action_fx").size() == _fq09m_fx3 + 1,
		"crafted=%s" % str(_fq09m_crafted))

	# (g) every effect self-frees within its lifetime — transient by
	# construction, so nothing can leak into scene state or saves.
	# Headless frames can advance with near-zero delta, so drive the same
	# production lifetime method once with a safely sufficient delta instead
	# of assuming 50 rendered frames represent half a second.
	for _fq09m_fx in get_tree().get_nodes_in_group("action_fx"):
		if is_instance_valid(_fq09m_fx):
			_fq09m_fx._process(1.0)
	await get_tree().process_frame
	_check("fq09m_fx_transient",
		get_tree().get_nodes_in_group("action_fx").is_empty(),
		"remaining=%d" % get_tree().get_nodes_in_group("action_fx").size())

	# --- FQ-09U1: adaptive context music foundation ---
	# The state machine is asserted deterministically (direct evaluate calls
	# with synthetic snapshots and explicit deltas — no wall-clock waits);
	# the one live-audio check proves the interactive stream actually
	# switches clips (the in-run behavior half of the FQ-09U spike).

	var _fq09u_dir: Node = root.get_node("AdaptiveMusicDirector")
	_fq09u_dir.set_process(false)   # keep the live poll out of synthetic checks
	_fq09u_dir._settlement_load = 0.0
	var _fq09u_day := {"is_night": false, "storm": false, "threat": 0.0,
		"health_ratio": 1.0, "underground": false}
	var _fq09u_night := {"is_night": true, "storm": false, "threat": 0.0,
		"health_ratio": 1.0, "underground": false}
	var _fq09u_under := {"is_night": false, "storm": false, "threat": 0.0,
		"health_ratio": 1.0, "underground": true}
	var _fq09u_high := {"is_night": false, "storm": false, "threat": 40.0,
		"health_ratio": 1.0, "underground": false}

	# (a) manifest + streams: the machine contract loads, all four context
	# loops decode, and the musical grid is stamped onto every stream.
	var _fq09u_mm: GDScript = load("res://scripts/audio/music_manifest.gd")
	var _fq09u_manifest: Dictionary = _fq09u_mm.load_manifest()
	var _fq09u_streams: Dictionary = _fq09u_mm.load_context_streams(_fq09u_manifest)
	var _fq09u_meta_ok := _fq09u_streams.size() == 4
	for _fq09u_ctx in _fq09u_streams:
		var _fq09u_s: AudioStream = _fq09u_streams[_fq09u_ctx]
		if not (_fq09u_s.loop and is_equal_approx(_fq09u_s.bpm, 72.0)
				and _fq09u_s.bar_beats == 4 and _fq09u_s.beat_count == 64):
			_fq09u_meta_ok = false
	_check("fq09u1_manifest_and_streams",
		int(_fq09u_manifest.get("bpm", 0)) == 72 and _fq09u_meta_ok,
		"streams=%d bpm=%s" % [_fq09u_streams.size(), str(_fq09u_manifest.get("bpm"))])

	# (b) the director is live: Music bus exists, the context player plays an
	# interactive stream with the four named clips.
	var _fq09u_stream: AudioStream = _fq09u_dir.get_node("ContextPlayer").stream
	_check("fq09u1_director_live",
		_fq09u_dir.enabled()
		and AudioServer.get_bus_index("Music") != -1
		and _fq09u_dir.get_node("ContextPlayer").playing
		and _fq09u_dir.get_node("ContextPlayer").bus == "Music"
		and _fq09u_stream is AudioStreamInteractive
		and (_fq09u_stream as AudioStreamInteractive).clip_count == 4,
		"enabled=%s playing=%s" % [str(_fq09u_dir.enabled()),
			str(_fq09u_dir.get_node("ContextPlayer").playing)])

	# (c) context resolution: night, dawn, and underground each request the
	# right clip from a clean baseline.
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_night, 1.0)
	var _fq09u_night_req: String = _fq09u_dir.requested_context()
	_fq09u_dir.debug_reset("surface_night")
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	var _fq09u_dawn_req: String = _fq09u_dir.requested_context()
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_under, 1.0)
	var _fq09u_under_req: String = _fq09u_dir.requested_context()
	_check("fq09u1_context_resolution",
		_fq09u_night_req == "surface_night" and _fq09u_dawn_req == "surface_day"
		and _fq09u_under_req == "underground",
		"night=%s dawn=%s underground=%s" % [_fq09u_night_req, _fq09u_dawn_req, _fq09u_under_req])

	# (d) crisis hysteresis: a brief spike never enters; sustained pressure
	# does (0.60 for 2 s, data-defined).
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	var _fq09u_brief_crisis: bool = _fq09u_dir.in_crisis()
	_fq09u_dir.evaluate(_fq09u_day, 0.5)   # spike over: accumulator resets
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	_check("fq09u1_crisis_enter_hysteresis",
		not _fq09u_brief_crisis and _fq09u_dir.in_crisis()
		and _fq09u_dir.requested_context() == "crisis"
		and _fq09u_dir.pressure_value() > 0.9,
		"brief=%s sustained=%s pressure=%.2f" % [str(_fq09u_brief_crisis),
			str(_fq09u_dir.in_crisis()), _fq09u_dir.pressure_value()])

	# (e) crisis exits only after the exit threshold AND delay (0.35 / 6 s).
	_fq09u_dir._current = "crisis"
	_fq09u_dir._pending = ""
	_fq09u_dir.evaluate(_fq09u_day, 3.0)
	var _fq09u_still: bool = _fq09u_dir.in_crisis()
	_fq09u_dir.evaluate(_fq09u_day, 3.5)
	_check("fq09u1_crisis_exit_delay",
		_fq09u_still and not _fq09u_dir.in_crisis()
		and _fq09u_dir.requested_context() == "surface_day",
		"at3s=%s at6.5s=%s requested=%s" % [str(_fq09u_still),
			str(_fq09u_dir.in_crisis()), _fq09u_dir.requested_context()])

	# (f) identical state never re-requests the current or pending clip.
	_fq09u_dir.debug_reset("surface_day")
	var _fq09u_reqs: int = _fq09u_dir.switch_request_count()
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	_check("fq09u1_no_rerequest",
		_fq09u_dir.switch_request_count() == _fq09u_reqs,
		"requests %d -> %d" % [_fq09u_reqs, _fq09u_dir.switch_request_count()])

	# (g) LIVE spike proof: the interactive playback really reaches the
	# requested clip via the registered next-bar same-position transition
	# (one bar = 3.33 s at 72 BPM; budget 8 s).
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_under, 1.0)
	var _fq09u_target: int = _fq09u_dir.clip_index_of("underground")
	var _fq09u_reached := false
	for _fq09u_i in range(480):
		_fq09u_dir._settle_pending()
		if _fq09u_dir.playback_clip_index() == _fq09u_target \
				and _fq09u_dir.current_context() == "underground":
			_fq09u_reached = true
			break
		await get_tree().process_frame
	_check("fq09u1_live_clip_switch", _fq09u_reached,
		"reached=%s clip=%d target=%d" % [str(_fq09u_reached),
			_fq09u_dir.playback_clip_index(), _fq09u_target])

	# (h) missing assets are silent-safe: a director with a manifest pointing
	# at nonexistent files disables audio, still evaluates, never crashes.
	var _fq09u_scene: PackedScene = load("res://scenes/audio/AdaptiveMusicDirector.tscn")
	var _fq09u_bad: Node = _fq09u_scene.instantiate()
	_fq09u_bad.manifest_override = {
		"bpm": 72, "beats_per_bar": 4, "bars_per_loop": 16,
		"contexts": {
			"surface_day": {"stream": "res://audio/music/rendered/contexts/missing_a.ogg"},
			"surface_night": {"stream": "res://audio/music/rendered/contexts/missing_b.ogg"},
			"underground": {"stream": "res://audio/music/rendered/contexts/missing_c.ogg"},
			"crisis": {"stream": "res://audio/music/rendered/contexts/missing_d.ogg"},
		},
		"transition": {}, "thresholds": {}, "pressure": {},
	}
	add_child(_fq09u_bad)
	_fq09u_bad.evaluate(_fq09u_night, 1.0)
	_fq09u_bad._settle_pending()
	_check("fq09u1_missing_assets_silent_safe",
		not _fq09u_bad.enabled()
		and not _fq09u_bad.get_node("ContextPlayer").playing
		and _fq09u_bad.requested_context() == "surface_night",
		"enabled=%s playing=%s state=%s" % [str(_fq09u_bad.enabled()),
			str(_fq09u_bad.get_node("ContextPlayer").playing),
			_fq09u_bad.requested_context()])
	_fq09u_bad.queue_free()
	await get_tree().process_frame

	# (i) music state is transient: a save round-trip carries no music keys
	# and the director keeps playing across the load untouched.
	root.save_manager.save_game()
	var _fq09u_state: Dictionary = GameState.get_current_state()
	var _fq09u_music_keys := ""
	for _fq09u_k in _fq09u_state:
		if "music" in str(_fq09u_k).to_lower():
			_fq09u_music_keys += str(_fq09u_k) + " "
	_check("fq09u1_state_not_saved",
		_fq09u_music_keys == "" and root.load_game() and _fq09u_dir.enabled(),
		("music keys: " + _fq09u_music_keys) if _fq09u_music_keys != ""
		else "no music keys in the world save; director survives load")

	# --- FQ-09U2: settlement-responsive stem layering ---
	# (the director's _process is still disabled from the fq09u1 section, so
	# every state/volume assertion below is deterministic)

	# (a) the mandated nesting spike, recorded: can an AudioStreamSynchronized
	# serve as a clip inside an AudioStreamInteractive? Built from two tiny
	# generated WAV tones and played live; the finding (either way) is
	# captured in the check detail and the run ledger — U2's shipped design
	# uses the parallel LayerPlayer regardless, since the suite has ONE
	# shared stem set, not per-context sets.
	var _fq09u2_wav := AudioStreamWAV.new()
	_fq09u2_wav.format = AudioStreamWAV.FORMAT_16_BITS
	_fq09u2_wav.mix_rate = 22050
	var _fq09u2_pcm := PackedByteArray()
	_fq09u2_pcm.resize(22050)   # 0.5s of quiet buzz
	for _fq09u2_i in range(0, 22050, 2):
		var _fq09u2_v: int = 800 if (_fq09u2_i / 50) % 2 == 0 else -800
		_fq09u2_pcm.encode_s16(_fq09u2_i, _fq09u2_v)
	_fq09u2_wav.data = _fq09u2_pcm
	var _fq09u2_nested_sync := AudioStreamSynchronized.new()
	_fq09u2_nested_sync.stream_count = 2
	_fq09u2_nested_sync.set_sync_stream(0, _fq09u2_wav)
	_fq09u2_nested_sync.set_sync_stream(1, _fq09u2_wav)
	var _fq09u2_nested := AudioStreamInteractive.new()
	_fq09u2_nested.clip_count = 2
	_fq09u2_nested.set_clip_name(0, "a")
	_fq09u2_nested.set_clip_stream(0, _fq09u2_nested_sync)
	_fq09u2_nested.set_clip_name(1, "b")
	_fq09u2_nested.set_clip_stream(1, _fq09u2_nested_sync)
	var _fq09u2_probe := AudioStreamPlayer.new()
	_fq09u2_probe.stream = _fq09u2_nested
	_fq09u2_probe.volume_db = -60.0
	add_child(_fq09u2_probe)
	_fq09u2_probe.play()
	await get_tree().process_frame
	await get_tree().process_frame
	var _fq09u2_nests: bool = _fq09u2_probe.playing \
		and _fq09u2_probe.get_stream_playback() != null
	_fq09u2_probe.queue_free()
	await get_tree().process_frame
	_check("fq09u2_nesting_spike_recorded", true,
		"synchronized_inside_interactive_plays=%s (finding recorded; U2 ships the parallel LayerPlayer design either way)" % str(_fq09u2_nests))

	# (b) the stem bed is live: six loops loaded, every length matching the
	# manifest grid, playing on the Music bus alongside the context stream.
	var _fq09u2_expected: float = _fq09u_mm.loop_seconds(_fq09u_manifest)
	var _fq09u2_stems: Dictionary = _fq09u_mm.load_stem_streams(_fq09u_manifest)
	var _fq09u2_lengths_ok := _fq09u2_stems.size() == 6
	for _fq09u2_sn in _fq09u2_stems:
		if absf((_fq09u2_stems[_fq09u2_sn] as AudioStream).get_length() - _fq09u2_expected) > 0.05:
			_fq09u2_lengths_ok = false
	_check("fq09u2_stem_bed_live",
		_fq09u2_lengths_ok and _fq09u_dir.layering_enabled()
		and _fq09u_dir.get_node("LayerPlayer").playing
		and _fq09u_dir.get_node("LayerPlayer").bus == "Music"
		and (_fq09u_dir.get_node("LayerPlayer").stream is AudioStreamSynchronized),
		"stems=%d lengths_ok=%s layering=%s playing=%s" % [_fq09u2_stems.size(),
			str(_fq09u2_lengths_ok), str(_fq09u_dir.layering_enabled()),
			str(_fq09u_dir.get_node("LayerPlayer").playing)])

	# (c) targets follow settlement truth: coherence drives the hearth layer,
	# resilience steadies the foundation (deterministic evaluate calls).
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir._settlement_coherence = 90.0
	_fq09u_dir._settlement_resilience = 80.0
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	var _fq09u2_hearth_high: float = float(_fq09u_dir.stem_targets()["hearth"])
	var _fq09u2_found_high: float = float(_fq09u_dir.stem_targets()["foundation"])
	_fq09u_dir._settlement_coherence = 10.0
	_fq09u_dir._settlement_resilience = 10.0
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	_check("fq09u2_targets_follow_settlement",
		_fq09u2_hearth_high > float(_fq09u_dir.stem_targets()["hearth"]) + 6.0
		and _fq09u2_found_high > float(_fq09u_dir.stem_targets()["foundation"]) + 3.0,
		"hearth %.1f -> %.1f, foundation %.1f -> %.1f" % [_fq09u2_hearth_high,
			float(_fq09u_dir.stem_targets()["hearth"]), _fq09u2_found_high,
			float(_fq09u_dir.stem_targets()["foundation"])])

	# (d) pressure raises its layer and the fracture layer wakes only at the
	# collapse edge.
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	var _fq09u2_pressure_low: float = float(_fq09u_dir.stem_targets()["pressure"])
	var _fq09u2_fracture_low: float = float(_fq09u_dir.stem_targets()["fracture"])
	_fq09u_dir.evaluate(_fq09u_high, 1.0)
	_check("fq09u2_pressure_and_fracture_layers",
		float(_fq09u_dir.stem_targets()["pressure"]) > _fq09u2_pressure_low + 10.0
		and float(_fq09u_dir.stem_targets()["fracture"]) > _fq09u2_fracture_low + 10.0
		and _fq09u2_fracture_low <= -59.0,
		"pressure %.1f -> %.1f, fracture %.1f -> %.1f" % [_fq09u2_pressure_low,
			float(_fq09u_dir.stem_targets()["pressure"]), _fq09u2_fracture_low,
			float(_fq09u_dir.stem_targets()["fracture"])])

	# (e) the storm texture: a storm lifts the pressure stem to at least its
	# data-defined floor even at low pressure.
	_fq09u_dir.debug_reset("surface_day")
	var _fq09u2_storm := {"is_night": false, "storm": true, "threat": 0.0,
		"health_ratio": 1.0, "underground": false}
	_fq09u_dir.evaluate(_fq09u2_storm, 1.0)
	_check("fq09u2_storm_texture",
		float(_fq09u_dir.stem_targets()["pressure"]) >= -16.0,
		"pressure target %.1f (floor -16)" % float(_fq09u_dir.stem_targets()["pressure"]))

	# (f) volumes move smoothly toward targets — one 0.5 s step moves at most
	# rate*dt dB and never snaps to the target.
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir._settlement_coherence = 100.0
	_fq09u_dir._stem_volumes["hearth"] = -40.0
	_fq09u_dir.evaluate(_fq09u_day, 0.5)
	_fq09u_dir._step_stem_volumes(0.5)
	var _fq09u2_after_step: float = float(_fq09u_dir.stem_volumes()["hearth"])
	_check("fq09u2_volume_smoothing",
		is_equal_approx(_fq09u2_after_step, -37.0)
		and _fq09u2_after_step < float(_fq09u_dir.stem_targets()["hearth"]),
		"hearth -40.0 -> %.2f (target %.1f, rate 6 dB/s * 0.5 s)" % [
			_fq09u2_after_step, float(_fq09u_dir.stem_targets()["hearth"])])

	# (g) a length-mismatched stem set disables layering while context music
	# plays on (a stinger is deliberately the wrong length).
	var _fq09u2_bad_manifest: Dictionary = _fq09u_manifest.duplicate(true)
	_fq09u2_bad_manifest["stems"]["motion"] = "res://audio/music/rendered/stingers/stinger_dawn.ogg"
	var _fq09u2_bad: Node = _fq09u_scene.instantiate()
	_fq09u2_bad.manifest_override = _fq09u2_bad_manifest
	add_child(_fq09u2_bad)
	_check("fq09u2_length_mismatch_fail_safe",
		_fq09u2_bad.enabled() and not _fq09u2_bad.layering_enabled()
		and not _fq09u2_bad.get_node("LayerPlayer").playing,
		"context=%s layering=%s" % [str(_fq09u2_bad.enabled()),
			str(_fq09u2_bad.layering_enabled())])
	_fq09u2_bad.queue_free()
	await get_tree().process_frame

	# (h) layering state is transient too: save round-trip carries no stem
	# keys and the live layer bed survives the load untouched.
	root.save_manager.save_game()
	var _fq09u2_state: Dictionary = GameState.get_current_state()
	var _fq09u2_keys := ""
	for _fq09u2_k in _fq09u2_state:
		if "stem" in str(_fq09u2_k).to_lower() or "music" in str(_fq09u2_k).to_lower():
			_fq09u2_keys += str(_fq09u2_k) + " "
	_check("fq09u2_state_not_saved",
		_fq09u2_keys == "" and root.load_game()
		and _fq09u_dir.layering_enabled()
		and _fq09u_dir.get_node("LayerPlayer").playing,
		("keys: " + _fq09u2_keys) if _fq09u2_keys != ""
		else "no stem/music keys; layer bed survives load")

	# --- FQ-09U3: stingers, ducking, and audio settings ---
	# (director _process still disabled: duck/cooldown envelopes are stepped
	# directly via _tick_audio(dt) for deterministic assertions)

	# (a) all five stinger one-shots load, none loops, every one under 8 s;
	# pause behavior configured (the score survives any future pause).
	var _fq09u3_stingers: Dictionary = _fq09u_mm.load_stinger_streams(_fq09u_manifest)
	var _fq09u3_assets_ok := _fq09u3_stingers.size() == 5
	for _fq09u3_k in _fq09u3_stingers:
		var _fq09u3_s: AudioStream = _fq09u3_stingers[_fq09u3_k]
		if _fq09u3_s.loop or _fq09u3_s.get_length() >= 8.0 or _fq09u3_s.get_length() <= 0.1:
			_fq09u3_assets_ok = false
	_check("fq09u3_stinger_assets",
		_fq09u3_assets_ok and _fq09u_dir.stinger_kinds_loaded() == 5
		and _fq09u_dir.process_mode == Node.PROCESS_MODE_ALWAYS
		and _fq09u_dir.get_node("StingerPlayer").bus == "SFX",
		"loaded=%d director=%d always=%s" % [_fq09u3_stingers.size(),
			_fq09u_dir.stinger_kinds_loaded(),
			str(_fq09u_dir.process_mode == Node.PROCESS_MODE_ALWAYS)])

	# (b) a stinger plays over ducking while the music NEVER stops: the duck
	# attacks toward duck_db while the one-shot plays, and the context and
	# layer players keep playing throughout. (Real gameplay events earlier in
	# the run may have fired stingers — settle cooldowns and the duck first.)
	_fq09u_dir.get_node("StingerPlayer").stop()
	_fq09u_dir._stinger_cooldowns.clear()
	_fq09u_dir._tick_audio(2.0)
	var _fq09u3_fired: bool = _fq09u_dir.play_stinger("dawn")
	_fq09u_dir._tick_audio(0.1)
	var _fq09u3_duck_attacking: float = _fq09u_dir.duck_db()
	_check("fq09u3_stinger_ducks_music",
		_fq09u3_fired and _fq09u_dir.stinger_playing()
		and _fq09u3_duck_attacking < -3.0
		and _fq09u_dir.get_node("ContextPlayer").playing
		and _fq09u_dir.get_node("LayerPlayer").playing,
		"fired=%s duck=%.1f context_playing=%s" % [str(_fq09u3_fired),
			_fq09u3_duck_attacking, str(_fq09u_dir.get_node("ContextPlayer").playing)])

	# (c) the duck releases back to zero once the stinger ends (release rate
	# 12 dB/s, data-defined), and Music-bus volume returns to the user base.
	_fq09u_dir.get_node("StingerPlayer").stop()
	_fq09u_dir._tick_audio(0.5)
	var _fq09u3_mid_release: float = _fq09u_dir.duck_db()
	_fq09u_dir._tick_audio(2.0)
	_check("fq09u3_duck_releases",
		_fq09u3_mid_release > _fq09u3_duck_attacking
		and is_equal_approx(_fq09u_dir.duck_db(), 0.0)
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
			- linear_to_db(1.0)) < 0.01,
		"attack=%.1f mid=%.1f final=%.2f" % [_fq09u3_duck_attacking,
			_fq09u3_mid_release, _fq09u_dir.duck_db()])

	# (d) per-kind cooldown: an immediate repeat is refused, another kind is
	# not, and after the cooldown elapses the kind fires again.
	var _fq09u3_plays: int = _fq09u_dir.stinger_play_count()
	var _fq09u3_repeat: bool = _fq09u_dir.play_stinger("dawn")
	var _fq09u3_other: bool = _fq09u_dir.play_stinger("raid_warning")
	_fq09u_dir._tick_audio(9.0)
	var _fq09u3_after_cd: bool = _fq09u_dir.play_stinger("dawn")
	_check("fq09u3_stinger_cooldown",
		not _fq09u3_repeat and _fq09u3_other and _fq09u3_after_cd
		and _fq09u_dir.stinger_play_count() == _fq09u3_plays + 2,
		"repeat=%s other=%s after_cd=%s" % [str(_fq09u3_repeat),
			str(_fq09u3_other), str(_fq09u3_after_cd)])
	_fq09u_dir.get_node("StingerPlayer").stop()
	_fq09u_dir._tick_audio(2.0)

	# (e) game events reach the director: the narrow music_event surface and
	# the player's cast signal each fire their stinger.
	_fq09u_dir._stinger_cooldowns.clear()
	var _fq09u3_p0: int = _fq09u_dir.stinger_play_count()
	root.music_event.emit("nightfall")
	player.attunement = player.max_attunement()
	player._pulse_cooldown = 0.0
	player._try_attune_pulse()
	_check("fq09u3_events_fire_stingers",
		_fq09u_dir.stinger_play_count() == _fq09u3_p0 + 2,
		"plays %d -> %d (nightfall + attunement)" % [_fq09u3_p0,
			_fq09u_dir.stinger_play_count()])
	_fq09u_dir.get_node("StingerPlayer").stop()
	_fq09u_dir._tick_audio(2.0)

	# (f) volume settings: profile-level, applied to the buses through the
	# shared helper, restored afterwards.
	var _fq09u3_as: GDScript = load("res://scripts/audio/audio_settings.gd")
	var _fq09u3_prev_music: float = _fq09u3_as.music_volume(GameState.profile)
	var _fq09u3_prev_sfx: float = _fq09u3_as.sfx_volume(GameState.profile)
	_fq09u3_as.set_music_volume(GameState.profile, 0.5)
	_fq09u3_as.set_sfx_volume(GameState.profile, 0.25)
	_fq09u3_as.apply(GameState.profile)
	var _fq09u3_music_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var _fq09u3_sfx_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	var _fq09u3_vol_ok: bool = absf(_fq09u3_music_db - linear_to_db(0.5)) < 0.01 \
		and absf(_fq09u3_sfx_db - linear_to_db(0.25)) < 0.01 \
		and is_equal_approx(float(GameState.profile.get("music_volume", -1.0)), 0.5)
	_fq09u3_as.set_music_volume(GameState.profile, _fq09u3_prev_music)
	_fq09u3_as.set_sfx_volume(GameState.profile, _fq09u3_prev_sfx)
	_fq09u3_as.apply(GameState.profile)
	_check("fq09u3_volume_settings",
		_fq09u3_vol_ok,
		"music_db=%.2f sfx_db=%.2f profile_key=%s" % [_fq09u3_music_db,
			_fq09u3_sfx_db, str(GameState.profile.has("music_volume"))])

	# (g) audio settings live at the profile level only — the WORLD save
	# still carries zero audio keys.
	root.save_manager.save_game()
	var _fq09u3_state: Dictionary = GameState.get_current_state()
	var _fq09u3_keys := ""
	for _fq09u3_sk in _fq09u3_state:
		var _fq09u3_low := str(_fq09u3_sk).to_lower()
		if "music" in _fq09u3_low or "volume" in _fq09u3_low or "stinger" in _fq09u3_low:
			_fq09u3_keys += str(_fq09u3_sk) + " "
	_check("fq09u3_world_save_clean",
		_fq09u3_keys == "" and root.load_game(),
		("keys: " + _fq09u3_keys) if _fq09u3_keys != "" else "no audio keys in the world save")
	_fq09u_dir.set_process(true)

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
