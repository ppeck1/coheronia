extends Node
## Automated acceptance smoke test. Runs when COHERONIA_SMOKE=1, exercises
## the real gameplay code paths, prints SMOKE lines, saves a screenshot
## (windowed runs only), and quits with a nonzero exit code on failure.

## R-01: import-aware audio loader, referenced as a class for its static methods.
const MusicManifest := preload("res://scripts/audio/music_manifest.gd")
const AudioSettings := preload("res://scripts/audio/audio_settings.gd")   # R-07
const InputSettings := preload("res://scripts/shell/input_settings.gd")   # R-07
const ContractBalanceReportScript := preload("res://scripts/contracts/balance_report.gd")   # R-09.3
const HudChrome := preload("res://scripts/ui/hud/hud_chrome.gd")   # R-06.1
const HousingScript := preload("res://scripts/settlement/housing.gd")   # M2-B
const CelestialScript := preload("res://scripts/world/celestial.gd")   # M5-A
const HudEditGeometry := preload("res://scripts/ui/hud/hud_edit_geometry.gd")   # R-06.2

var _results: Array = []
var _details: Dictionary = {}
# R-03: split reporting — per-suite tallies, skipped checks, and run timing.
var _suites: Dictionary = {}   # suite -> {passed, failed, skipped}
var _skipped: Array = []       # names skipped in this environment
var _start_ms := 0


func _ready() -> void:
	call_deferred("_run")


## R-03: coarse suite for a check, from its name, so results split by
## shell / save / world / ui / presentation / progression / audio.
func _suite_for(name: String) -> String:
	if name.begins_with("shell_"):
		return "shell"
	if name.begins_with("r02_") or name.begins_with("r03_") \
			or name.begins_with("save_") or name.begins_with("load_"):
		return "save"
	if name.begins_with("fq09u") or name.begins_with("r01_export_safe_audio"):
		return "audio"
	if name.begins_with("fq05") or name.begins_with("fq06") or name.begins_with("fq09s") \
			or "perk" in name or "_xp" in name or "level" in name or "attun" in name:
		return "progression"
	if name.begins_with("player_visual") or name.begins_with("pr02") or name.begins_with("pr03") \
			or name.begins_with("pr04") or name.begins_with("pr05") or name.begins_with("pr07") \
			or name.begins_with("fq07") or name.begins_with("fq08") or name.begins_with("fq09v") \
			or name.begins_with("fq09c") or name.begins_with("fq13p") \
			or name.begins_with("r01_export_safe_visual"):
		return "presentation"
	if name.begins_with("fq09_") or name.begins_with("fq14") or name.begins_with("fq15") \
			or name.begins_with("fq16") or name.begins_with("fq17") or name.begins_with("fq18") \
			or name.begins_with("fq19") or name.begins_with("fq20") or name.begins_with("fq21") \
			or name.begins_with("pr06") or name.begins_with("pr08") \
			or name.begins_with("r07_") or "hud" in name \
			or "panel" in name or "inventory" in name or "dock" in name or name.begins_with("focus_"):
		return "ui"
	return "world"


func _suite_bucket(suite: String) -> Dictionary:
	if not _suites.has(suite):
		_suites[suite] = {"passed": 0, "failed": 0, "skipped": 0}
	return _suites[suite]


func _check(name: String, ok: bool, detail: String = "") -> void:
	_results.append([name, ok])
	_details[name] = detail
	_suite_bucket(_suite_for(name))["passed" if ok else "failed"] += 1


## R-03: record a check intentionally not run in this environment (never counted
## as pass or fail). Used for fixtures that cannot run under an exported build.
func _skip(name: String, reason: String) -> void:
	_skipped.append(name)
	_details[name] = "SKIPPED: " + reason
	_suite_bucket(_suite_for(name))["skipped"] += 1


## R-03: a check whose fixture writes into res:// (read-only in an exported PCK).
## Skipped under an exported build; runs normally (asserts) in source/editor —
## the source-run assertions are unchanged.
func _check_res_fixture(name: String, ok: bool, detail: String = "") -> void:
	if OS.has_feature("template"):
		_skip(name, "fixture writes to res:// (read-only in an exported PCK)")
	else:
		_check(name, ok, detail)
	print("SMOKE %s: %s%s" % ["PASS" if ok else "FAIL", name, (" — " + detail) if detail != "" else ""])


func _run() -> void:
	_start_ms = Time.get_ticks_msec()
	var root: Node2D = get_parent()
	var world: Node2D = root.world
	var player: CharacterBody2D = root.player
	var hall: Node2D = root.town_hall
	var settlement: Node = root.settlement
	var hud: CanvasLayer = root.hud

	# Deterministic terrain for the test run. World Depths: pin the baseline
	# gameplay world to gen_version 1 (legacy solid-fill terrain) so the ~400
	# mechanics checks run on the stable pre-arc baseline they were written for.
	# create_world now stamps gen_version 2 (caves/strata) into real new worlds;
	# that v2 generation is covered explicitly by the wd_ checks, while mining/
	# crafting/combat/settlement mechanics are terrain-agnostic and validated here.
	var _base_cfg: Dictionary = WorldConfig.from_preset("folk_kingdom")
	_base_cfg["size"] = "medium"   # keep the baseline suite fast + v1 (default is now vast)
	GameState.current_config = WorldConfig.new(_base_cfg)
	world.setup(12345)
	root._position_actors()
	settlement.compute()
	for i in range(40):
		await get_tree().physics_frame

	_check("main_scene_launches", true)
	_check("terrain_generated", world.cells.size() > 1000, "%d cells" % world.cells.size())
	# Underground-lighting rework: the per-column depth shader is live and its
	# sky-line texture spans one texel per world column.
	var _cave_tex: Texture2D = world.cave_sky_texture()
	_check("cave_depth_shading",
		world.cave_depth_shading_enabled() and _cave_tex != null
			and _cave_tex.get_width() == int(world.width),
		"enabled=%s tex_w=%d world_w=%d" % [
			str(world.cave_depth_shading_enabled()),
			(_cave_tex.get_width() if _cave_tex != null else -1),
			int(world.width)])
	_check("town_hall_exists", not world.hall_info.is_empty()
		and world.block_at(world.hall_info["core_cells"][0]) == "town_hall_core")
	_check("town_hall_core_protected", not world.can_mine(world.hall_info["core_cells"][0], 99))
	if OS.get_environment("COHERONIA_SMOKE_FOCUS") == "inventory":
		await _run_inventory_focus(player, hud)
		return

	# --- Real input bindings (programmatic action_press below bypasses the
	# InputMap, so verify keys/mouse are actually bound to the actions) ---
	var unbound := ""
	for action in ["move_left", "move_right", "jump", "mine", "place", "interact",
			"toggle_town", "craft", "save_game", "load_game", "toggle_inventory",
			"debug_overlay", "hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5",
			"eat_food", "attune_pulse", "swap_weapon", "toggle_skills"]:
		var has_device_event := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventMouseButton:
				has_device_event = true
		if not has_device_event:
			unbound += action + " "
	_check("input_actions_bound", unbound == "",
		("unbound: " + unbound) if unbound != "" else "all actions have device events")
	# Calling system: Callings are a permanent identity, not a starter kit — none
	# may grant a starting-item windfall (handoff constraint 6).
	var _callings_no_windfall := true
	for _c in BlockRegistry.callings():
		if not (_c.get("starting_items", {}) as Dictionary).is_empty():
			_callings_no_windfall = false
	_check("callings_grant_no_starter_items", _callings_no_windfall,
		"Callings grant no starting-item windfall")

	# --- Shell persistence: characters + worlds as simulation containers ---
	# PR-01: the character is created with the LEGACY id "female" to prove a
	# legacy value is accepted and re-saved as the canonical id "feminine".
	var test_char: Dictionary = GameState.create_character({
		"name": "Smoke Tester", "species": "dwarf", "body_variant": "female",
		"role": "wayfarer", "traits": ["hardy"], "appearance": "ash"})
	var df_config: Dictionary = WorldConfig.from_preset("dark_frontier")
	df_config["name"] = "Smoke Frontier"
	df_config["seed"] = 777
	df_config["size"] = "small"
	var test_world_id: String = GameState.create_world(df_config)
	GameState.load_shell()   # force a fresh read from disk
	var reloaded_char: Dictionary = GameState.get_character(str(test_char["id"]))
	var reloaded_cfg := WorldConfig.new(GameState.load_world_file(test_world_id).get("config", {}))
	_check("shell_persists_characters", not reloaded_char.is_empty()
		and str(reloaded_char.get("role", "")) == "wayfarer"
		and "hardy" in reloaded_char.get("traits", [])
		and str(reloaded_char.get("body_variant", "")) == "feminine")
	_check("player_visual_body_variant_roundtrip",
		str(reloaded_char.get("species", "")) == "dwarf"
		and str(reloaded_char.get("body_variant", "")) == "feminine")
	# PR-01: canonical ids are masculine/feminine; the legacy ids default/female
	# survive only as read-time aliases, and invalid/missing values return the
	# canonical default (masculine).
	_check("player_visual_body_variant_aliases",
		GameState.normalize_body_variant("") == "masculine"
		and GameState.normalize_body_variant("bogus") == "masculine"
		and GameState.normalize_body_variant("default") == "masculine"
		and GameState.normalize_body_variant("female") == "feminine"
		and GameState.normalize_body_variant("masculine") == "masculine"
		and GameState.normalize_body_variant("feminine") == "feminine")
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

	# The deep special blocks drop THEMSELVES (their own item), not generic stone.
	var _hs_drop: Dictionary = BlockRegistry.drops("hellstone")
	var _ob_drop: Dictionary = BlockRegistry.drops("obsidian")
	_check("wdf_hellstone_obsidian_drop_self",
		int(_hs_drop.get("hellstone", 0)) == 1 and not _hs_drop.has("stone")
			and int(_ob_drop.get("obsidian", 0)) == 1 and not _ob_drop.has("stone"),
		"hellstone=%s obsidian=%s" % [str(_hs_drop), str(_ob_drop)])

	# --- Tool tier progression (forge at Town Hall) ---
	var ore_cell: Variant = _find_block(world, hall_cell, "ore", 2)
	_check("ore_exists_in_world", ore_cell != null)
	if ore_cell != null:
		_check("ore_gated_by_tool_tier", not world.can_mine(ore_cell, player.tool_tier))
	player.inventory.add("wood", 3)
	player.inventory.add("stone", 5)
	hall.deposit_all(player.inventory)
	var forged: bool = hall.forge_pick(player)
	# Item-wiring (2.1): the forge upgrades the live pick tier and mints NO
	# tool_tier_2_pick backpack token (the recipe output is empty).
	_check("forge_pick_upgrade",
		forged and player.tool_tier == 2 and player.inventory.count("tool_tier_2_pick") == 0,
		"stock after forge=%s token=%d" % [str(hall.stockpile),
			player.inventory.count("tool_tier_2_pick")])
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
	root.housing_override = root.POPULATION_MAX   # M2-B: stub housing so the BASE-LEVEL cap is under test
	for i in range(10):
		settlement.coherence = 80.0
		root.consume_daily_food()
	_check("population_caps_at_max", hall.population == root.POPULATION_MAX,
		"pop=%d" % hall.population)
	root.housing_override = -1

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
	# Ambient weather auto-rolls off the unseeded global RNG in game_root._process,
	# so a storm may already be active on a slow host (seen on Linux CI). Quiesce it
	# first so this rule-toggle check is deterministic across platforms.
	root.storm_active = false
	root.storm_time_left = 0.0
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
	# Clear any ambient (RNG-rolled) storm first so the before/after severity
	# delta measures only the forced storm — otherwise a pre-active storm makes
	# severity flat and the check flakes across platforms (Linux CI).
	root.storm_active = false
	root.storm_time_left = 0.0
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
	_check("world_size_setting", world.width == 200 and world.height == 170,
		"%dx%d" % [world.width, world.height])
	GameState.current_config = WorldConfig.new({"generation": {"ore_abundance": 2.0}})
	world.setup(777)
	var ore_rich: int = _count_blocks(world, "ore")
	GameState.current_config = WorldConfig.new({"generation": {"ore_abundance": 0.0}})
	world.setup(777)
	var ore_none: int = _count_blocks(world, "ore")
	_check("ore_abundance_setting", ore_rich > 0 and ore_none == 0,
		"rich=%d none=%d" % [ore_rich, ore_none])
	GameState.current_config = WorldConfig.new({"size": "medium", "generation": {"ore_seed_offset": 9999}})
	world.setup(777)
	var ore_cells_alt: Array = _block_cells(world, "ore")
	GameState.current_config = WorldConfig.new({"size": "medium"})
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
	GameState.current_config = WorldConfig.new({"size": "medium"})
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
	# leaves yields no economy resource — its ONLY possible drop is a renewable
	# tree_seed (Item-wiring Phase 3), at a low chance, and nothing else.
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
	# The only permitted change is 0 or 1 tree_seed; every other stack is untouched.
	var _fq09r_econ_ok := true
	for _fq09r_k in player.inventory.counts:
		if str(_fq09r_k) == "tree_seed":
			continue
		if int(player.inventory.counts[_fq09r_k]) != int(_fq09r_inv_before.get(_fq09r_k, 0)):
			_fq09r_econ_ok = false
	for _fq09r_k in _fq09r_inv_before:
		if str(_fq09r_k) == "tree_seed":
			continue
		if int(_fq09r_inv_before[_fq09r_k]) != int(player.inventory.count(str(_fq09r_k))):
			_fq09r_econ_ok = false
	var _fq09r_seed_delta: int = player.inventory.count("tree_seed") \
		- int(_fq09r_inv_before.get("tree_seed", 0))
	_check("fq09r_leaves_clear_without_drops", _fq09r_leaf_cell != null
		and _fq09r_econ_ok and _fq09r_seed_delta >= 0 and _fq09r_seed_delta <= 1
		and world.block_at(_fq09r_leaf_cell as Vector2i) == "air",
		"seed_delta=%d econ_ok=%s" % [_fq09r_seed_delta, str(_fq09r_econ_ok)])
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

	# --- World Depths WD-1: deeper world + data-driven strata + bedrock floor +
	# gen_version legacy guard. Pure-gen checks drive WorldGen directly (isolates
	# generation cost from tilemap render); the save-independence check uses the
	# live world. All restored by the config reset below. ---
	var _wd_cfg := WorldConfig.new({"size": "vast", "gen_version": 2})
	var _wd_bt: int = WorldGen.BEDROCK_THICKNESS
	var _wd_t0 := Time.get_ticks_msec()
	var _wd_gen := WorldGen.generate(2024, _wd_cfg)
	var _wd_gen_ms := Time.get_ticks_msec() - _wd_t0
	var _wd_cells: Dictionary = _wd_gen["cells"]
	var _wd_surf: Dictionary = _wd_gen["surface"]
	var _wd_h := int(_wd_gen["height"])
	var _wd_w := int(_wd_gen["width"])
	var _wd_dims_ok: bool = _wd_w == 500 and _wd_h == 400
	var _wd_gen2 := WorldGen.generate(2024, _wd_cfg)
	var _wd_deterministic: bool = (_wd_gen2["cells"] as Dictionary).size() == _wd_cells.size()
	_check("wd_big_size_generates_within_budget",
		_wd_dims_ok and _wd_deterministic and _wd_gen_ms < 12000,
		"%dx%d gen=%dms cells=%d deterministic=%s" % [_wd_w, _wd_h,
			_wd_gen_ms, _wd_cells.size(), str(_wd_deterministic)])

	# WD-4: strata are fractions of each column's usable depth. Verify stone in
	# the shallow band, deepstone in the mid band, hellstone only in the deep band.
	var _wd_stone_shallow := false
	var _wd_deepstone_mid := false
	var _wd_hell_deep := false
	var _wd_hell_shallow := false
	for _wd_c: Vector2i in _wd_cells:
		var _wd_bid: String = str(_wd_cells[_wd_c])
		var _wd_cs: int = int(_wd_surf.get(_wd_c.x, 0))
		var _wd_cd: int = maxi(1, (_wd_h - _wd_bt) - _wd_cs)
		var _wd_f: float = float(_wd_c.y - _wd_cs) / float(_wd_cd)
		if _wd_bid == "stone" and _wd_f < 0.34:
			_wd_stone_shallow = true
		elif _wd_bid == "deepstone" and _wd_f >= 0.34 and _wd_f < 0.68:
			_wd_deepstone_mid = true
		elif _wd_bid == "hellstone":
			if _wd_f >= 0.68:
				_wd_hell_deep = true
			else:
				_wd_hell_shallow = true
	_check("wd_strata_place_by_fraction",
		_wd_stone_shallow and _wd_deepstone_mid and _wd_hell_deep and not _wd_hell_shallow,
		"stone_shallow=%s deepstone_mid=%s hell_deep=%s hell_shallow=%s" % [
			str(_wd_stone_shallow), str(_wd_deepstone_mid), str(_wd_hell_deep),
			str(_wd_hell_shallow)])

	var _wd_bedrock_floor := true
	for _wd_x in range(0, _wd_w, 37):
		if str(_wd_cells.get(Vector2i(_wd_x, _wd_h - 1), "")) != "bedrock":
			_wd_bedrock_floor = false
			break
	var _wd_bedrock_unmineable: bool = BlockRegistry.has_tag("bedrock", "protected")
	_check("wd_bedrock_floor_bounds_world",
		_wd_bedrock_floor and _wd_bedrock_unmineable,
		"bottom_row_bedrock=%s unmineable=%s" % [
			str(_wd_bedrock_floor), str(_wd_bedrock_unmineable)])

	var _wd_v1 := WorldGen.generate(2024, WorldConfig.new({"size": "large"}))
	var _wd_v1_cells: Dictionary = _wd_v1["cells"]
	var _wd_v1_leaks_new := false
	for _wd_c2: Vector2i in _wd_v1_cells:
		var _wd_b2: String = str(_wd_v1_cells[_wd_c2])
		if _wd_b2 == "deepstone" or _wd_b2 == "bedrock" or _wd_b2 == "hellstone" or _wd_b2 == "lava":
			_wd_v1_leaks_new = true
			break
	_check("wd_gen_version_preserves_legacy_world", not _wd_v1_leaks_new,
		"legacy(v1) large leaks new blocks=%s (must be false)" % str(_wd_v1_leaks_new))

	GameState.current_config = WorldConfig.new({"size": "vast", "gen_version": 2})
	world.setup(2024)
	var _wd_vast_deltas: int = world.serialize_deltas().size()
	GameState.current_config = WorldConfig.new({"size": "small"})
	world.setup(2024)
	var _wd_small_deltas: int = world.serialize_deltas().size()
	_check("wd_save_size_independent_of_world_size",
		_wd_vast_deltas == 0 and _wd_small_deltas == 0,
		"vast_deltas=%d small_deltas=%d (both 0 => base terrain regenerated, not saved)" % [
			_wd_vast_deltas, _wd_small_deltas])

	# --- World Depths WD-2: cave carve pass (mixed caverns + tunnels). Reuses
	# the vast v2 cells generated above, which now include caves. ---
	var _wd_deep_total := 0
	var _wd_deep_air := 0
	for _wd_cx in range(0, _wd_w):
		var _wd_csurf: int = int(_wd_surf.get(_wd_cx, 0))
		for _wd_cy in range(_wd_csurf + 20, mini(_wd_csurf + 120, _wd_h - 2)):
			_wd_deep_total += 1
			if not _wd_cells.has(Vector2i(_wd_cx, _wd_cy)):
				_wd_deep_air += 1
	var _wd_air_frac := float(_wd_deep_air) / maxf(1.0, float(_wd_deep_total))
	_check("wd_caves_carve_air_at_depth",
		_wd_air_frac > 0.02 and _wd_air_frac < 0.6,
		"deep air fraction=%.3f (air=%d / %d cells)" % [_wd_air_frac, _wd_deep_air, _wd_deep_total])

	var _wd_crust_solid := true
	for _wd_sx in range(0, _wd_w, 41):
		var _wd_ss: int = int(_wd_surf.get(_wd_sx, 0))
		for _wd_d in range(1, 8):
			if not _wd_cells.has(Vector2i(_wd_sx, _wd_ss + _wd_d)):
				_wd_crust_solid = false
				break
		if not _wd_crust_solid:
			break
	var _wd_hall_solid := true
	var _wd_hx := _wd_w / 2
	for _wd_hxx in range(_wd_hx - 7, _wd_hx + 8):
		var _wd_hs: int = int(_wd_surf.get(_wd_hxx, 0))
		for _wd_hd in range(1, 17):
			if not _wd_cells.has(Vector2i(_wd_hxx, _wd_hs + _wd_hd)):
				_wd_hall_solid = false
				break
		if not _wd_hall_solid:
			break
	var _wd_floor_intact: bool = str(_wd_cells.get(Vector2i(_wd_hx, _wd_h - 1), "")) == "bedrock"
	_check("wd_caves_preserve_surface_and_hall",
		_wd_crust_solid and _wd_hall_solid and _wd_floor_intact,
		"crust_solid=%s hall_solid=%s bedrock_floor=%s" % [
			str(_wd_crust_solid), str(_wd_hall_solid), str(_wd_floor_intact)])

	var _wd_ore_count := 0
	var _wd_air_stored := false
	for _wd_oc: Vector2i in _wd_cells:
		var _wd_ob: String = str(_wd_cells[_wd_oc])
		if _wd_ob == "air":
			_wd_air_stored = true
		elif _wd_ob == "ore" or _wd_ob == "coal" or _wd_ob == "iron_ore":
			_wd_ore_count += 1
	_check("wd_ore_only_in_solid_after_carve",
		_wd_ore_count > 0 and not _wd_air_stored,
		"ore-ish cells=%d air_stored_as_block=%s" % [_wd_ore_count, str(_wd_air_stored)])

	# --- World Depths WD-3: hell biome + lava hazard. Hell/obsidian/lava scanned
	# from the vast v2 cells above; the contact-damage mechanic is exercised live. ---
	var _wd_hellstone := false
	var _wd_obsidian := false
	var _wd_lava_cells := 0
	for _wd_hc: Vector2i in _wd_cells:
		var _wd_hb: String = str(_wd_cells[_wd_hc])
		if _wd_hb == "hellstone":
			_wd_hellstone = true
		elif _wd_hb == "obsidian":
			_wd_obsidian = true
		elif _wd_hb == "lava":
			_wd_lava_cells += 1
	_check("wd_hell_stratum_generates",
		_wd_hellstone and _wd_obsidian and _wd_lava_cells > 0,
		"hellstone=%s obsidian=%s lava_cells=%d" % [
			str(_wd_hellstone), str(_wd_obsidian), _wd_lava_cells])

	# WD-4: hell must appear in EVERY world size (fractional strata), not just vast.
	var _wd_all_sizes_ok := true
	var _wd_sizes_detail := ""
	for _wd_sz in ["small", "large"]:
		var _wd_szgen := WorldGen.generate(2024, WorldConfig.new({"size": _wd_sz, "gen_version": 2}))
		var _wd_szcells: Dictionary = _wd_szgen["cells"]
		var _wd_sz_hell := false
		var _wd_sz_lava := false
		for _wd_szc: Vector2i in _wd_szcells:
			var _wd_szb: String = str(_wd_szcells[_wd_szc])
			if _wd_szb == "hellstone":
				_wd_sz_hell = true
			elif _wd_szb == "lava":
				_wd_sz_lava = true
			if _wd_sz_hell and _wd_sz_lava:
				break
		if not (_wd_sz_hell and _wd_sz_lava):
			_wd_all_sizes_ok = false
		_wd_sizes_detail += "%s(hell=%s,lava=%s) " % [_wd_sz, str(_wd_sz_hell), str(_wd_sz_lava)]
	_check("wd_hell_in_all_sizes", _wd_all_sizes_ok, _wd_sizes_detail)

	# Developer "dev_descent" cheat preset: largest size, tons of ore, and a
	# staircase to a safe hellstone landing deep in hell.
	var _dev_dict: Dictionary = WorldConfig.from_preset("dev_descent")
	_dev_dict["gen_version"] = 2
	var _dev_gen := WorldGen.generate(2024, WorldConfig.new(_dev_dict))
	var _dev_cells: Dictionary = _dev_gen["cells"]
	var _dev_surf: Dictionary = _dev_gen["surface"]
	var _dev_gh := int(_dev_gen["height"])
	var _dev_gw := int(_dev_gen["width"])
	var _dev_vast: bool = _dev_gw == 500 and _dev_gh == 400
	var _dev_ore := 0
	for _dc: Vector2i in _dev_cells:
		match str(_dev_cells[_dc]):
			"ore", "coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "crystal":
				_dev_ore += 1
	var _dev_x0: int = clampi(_dev_gw / 2 + 16, 3, _dev_gw - 18)
	var _dev_sy: int = int(_dev_surf.get(_dev_x0, 0))
	var _dev_col: int = maxi(1, (_dev_gh - 2) - _dev_sy)
	var _dev_target: int = mini(_dev_sy + int(0.80 * float(_dev_col)), (_dev_gh - 2) - 3)
	var _dev_landing := false
	for _lx in range(_dev_x0 - 2, _dev_x0 + 17):
		if str(_dev_cells.get(Vector2i(_lx, _dev_target + 1), "")) == "hellstone" \
				and not _dev_cells.has(Vector2i(_lx, _dev_target)):
			_dev_landing = true
			break
	# The staircase must not appear in an ordinary world (opt-in flag only).
	var _dev_normal := WorldGen.generate(2024, WorldConfig.new({"size": "vast", "gen_version": 2}))
	var _dev_normal_ore := 0
	for _nc: Vector2i in (_dev_normal["cells"] as Dictionary):
		match str((_dev_normal["cells"] as Dictionary)[_nc]):
			"ore", "coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "crystal":
				_dev_normal_ore += 1
	_check("wd_dev_level_staircase_and_ore",
		_dev_vast and _dev_ore > 15000 and _dev_landing and _dev_ore > _dev_normal_ore * 3,
		"vast=%s dev_ore=%d normal_ore=%d landing=%s" % [
			str(_dev_vast), _dev_ore, _dev_normal_ore, str(_dev_landing)])

	var _wd_lava_def: Dictionary = BlockRegistry.get_block("lava")
	var _wd_lava_props: bool = not BlockRegistry.is_solid("lava") \
		and bool(_wd_lava_def.get("emits_light", false)) \
		and BlockRegistry.contact_damage("lava") > 0.0
	_check("wd_lava_is_walkable_glowing_hazard", _wd_lava_props,
		"non_solid=%s emits_light=%s contact_damage=%.1f" % [
			str(not BlockRegistry.is_solid("lava")),
			str(bool(_wd_lava_def.get("emits_light", false))),
			BlockRegistry.contact_damage("lava")])

	# Inject lava where the player stands and run the hazard tick directly.
	var _wd_hp_before: float = player.health
	var _wd_pcell: Vector2i = world.cell_of(player.global_position)
	world.cells[_wd_pcell] = "lava"
	player._hurt_cooldown = 0.0
	player._apply_environmental_hazard()
	var _wd_hp_after: float = player.health
	var _wd_lava_hurt: bool = _wd_hp_after < _wd_hp_before
	world.cells.erase(_wd_pcell)
	player.health = _wd_hp_before
	_check("wd_lava_contact_damages_player", _wd_lava_hurt,
		"hp %.1f -> %.1f on lava cell" % [_wd_hp_before, _wd_hp_after])

	GameState.current_config = original_config
	_check("world_restored_after_config_tests", root.load_game())

	# ===== LQ-1: liquid physics (leveled fluid cellular automaton) =====
	# The pinned v1 baseline world carries no lava, so world.liquid_mass() reflects
	# only the cells these fixtures inject. Fixtures sit in open sky (x~20, above the
	# surface, away from the hall) and clean up after themselves so later checks see
	# a clean world. Stepping is deterministic (fixed timestep + fixed cell order),
	# driven directly via world.fluid_settle rather than the frame clock.

	# (0) An undisturbed world persists zero liquid deltas — generated pools carry
	# no liquid_level entry (they read as full), so the save is size-independent.
	_check("lq_undisturbed_world_save_identical", world.serialize_liquid_level().is_empty(),
		"liquid_level entries in an undisturbed world: %d" % world.serialize_liquid_level().size())

	# (1) Mining the shelf under a resting pool wakes it; the lava pours down into
	# the freshly opened cell ("flow on disturbance").
	var _lq_origin := Vector2i(20, 5)
	var _lq_catch := Vector2i(20, 6)         # the shelf now, the catch pocket once mined
	# Box the catch cell (walls + floor) so the poured lava has somewhere to rest
	# rather than dribbling off the sides into open sky.
	world.cells[Vector2i(19, 6)] = "stone"   # left wall
	world.cells[Vector2i(21, 6)] = "stone"   # right wall
	world.cells[Vector2i(20, 7)] = "stone"   # floor
	world.cells[_lq_catch] = "stone"         # shelf the pool rests on while asleep
	world.cells[_lq_origin] = "lava"         # full (no level entry = 1.0), asleep
	world.break_block(_lq_catch)             # mine the shelf -> wakes the pool, it falls
	var _lq_pour_steps: int = world.fluid_settle(64)
	var _lq_poured: bool = world.cells.get(_lq_catch, "air") == "lava" \
		and world.cells.get(_lq_origin, "air") == "air"
	_check("lq_lava_pours_through_breached_wall", _lq_poured,
		"after %d steps: catch=%s origin=%s" % [_lq_pour_steps,
			world.cells.get(_lq_catch, "air"), world.cells.get(_lq_origin, "air")])
	for _cc in [_lq_origin, _lq_catch, Vector2i(19, 6), Vector2i(21, 6), Vector2i(20, 7)]:
		world.cells.erase(_cc); world.liquid_level.erase(_cc)
		world.deltas.erase(_cc); world._set_tile(_cc, "air")
	world._fluid.active.clear()

	# (2) A sealed 3-wide stone basin with lava stacked in one column: it must fall
	# AND spread across the floor (down-flow + sideways leveling + mass conservation
	# + solids as barriers), then go back to sleep once level.
	var _lq_region: Array = []
	for _wy in range(5, 9):                  # side walls
		world.cells[Vector2i(19, _wy)] = "stone"; _lq_region.append(Vector2i(19, _wy))
		world.cells[Vector2i(23, _wy)] = "stone"; _lq_region.append(Vector2i(23, _wy))
	for _fx in range(20, 23):                # floor
		world.cells[Vector2i(_fx, 8)] = "stone"; _lq_region.append(Vector2i(_fx, 8))
	for _iy in range(5, 8):                  # interior (track for cleanup)
		for _ix in range(20, 23):
			_lq_region.append(Vector2i(_ix, _iy))
	for _ly in range(5, 8):                  # stack 3 full lava cells in one column
		world.cells[Vector2i(20, _ly)] = "lava"
	var _lq_mass_before: float = world.liquid_mass()
	world._fluid.active.clear()
	for _ly2 in range(5, 8):
		world._fluid.wake(Vector2i(20, _ly2))
	var _lq_settle_steps: int = world.fluid_settle(800)
	var _lq_mass_after: float = world.liquid_mass()
	var _lq_floor_full: bool = world.cells.get(Vector2i(20, 7), "") == "lava" \
		and world.cells.get(Vector2i(21, 7), "") == "lava" \
		and world.cells.get(Vector2i(22, 7), "") == "lava"
	var _lq_floor_mass: float = float(world.liquid_level.get(Vector2i(20, 7), 0.0)) \
		+ float(world.liquid_level.get(Vector2i(21, 7), 0.0)) \
		+ float(world.liquid_level.get(Vector2i(22, 7), 0.0))
	var _lq_walls_intact: bool = world.cells.get(Vector2i(19, 6), "") == "stone" \
		and world.cells.get(Vector2i(23, 6), "") == "stone" \
		and world.cells.get(Vector2i(21, 8), "") == "stone"
	# Conservation is exact bar the MIN_LEVEL epsilon shed as thin cells collapse
	# to air; the bound scales with how many cells drain (here 3), so ~0.06 is the
	# realistic ceiling, not a full unit of liquid appearing/vanishing.
	_check("lq_mass_conserved",
		absf(_lq_mass_after - _lq_mass_before) < 0.08 and _lq_mass_before > 2.9,
		"mass %.3f -> %.3f over %d steps" % [_lq_mass_before, _lq_mass_after, _lq_settle_steps])
	_check("lq_puddle_levels_out", _lq_floor_full and _lq_floor_mass > 2.5,
		"floor_full=%s floor_mass=%.3f" % [str(_lq_floor_full), _lq_floor_mass])
	_check("lq_liquid_stops_at_solid", _lq_walls_intact,
		"basin walls/floor still stone: %s" % str(_lq_walls_intact))
	_check("lq_settled_world_is_asleep", world.fluid_active_count() == 0,
		"active cells after settle: %d" % world.fluid_active_count())
	for _cc in _lq_region:
		world.cells.erase(_cc); world.liquid_level.erase(_cc)
		world.deltas.erase(_cc); world._set_tile(_cc, "air")
	world._fluid.active.clear()

	# (3) Contact damage is level-independent: even a half-full lava cell burns,
	# because a liquid cell stays a normal "lava" block for the hazard sampler.
	var _lq_hp_before: float = player.health
	var _lq_pcell: Vector2i = world.cell_of(player.global_position)
	var _lq_prev: String = world.cells.get(_lq_pcell, "air")
	world.cells[_lq_pcell] = "lava"; world.liquid_level[_lq_pcell] = 0.5
	player._hurt_cooldown = 0.0
	player._apply_environmental_hazard()
	var _lq_hp_after: float = player.health
	if _lq_prev == "air":
		world.cells.erase(_lq_pcell)
	else:
		world.cells[_lq_pcell] = _lq_prev
	world.liquid_level.erase(_lq_pcell)
	world._set_tile(_lq_pcell, _lq_prev if _lq_prev != "air" else "air")
	player.health = _lq_hp_before
	_check("lq_contact_damage_still_applies", _lq_hp_after < _lq_hp_before,
		"half-full lava burns: hp %.1f -> %.1f" % [_lq_hp_before, _lq_hp_after])

	# LQ-2: a liquid cell's rendered tile is chosen by its fill level — a half-full
	# cell selects a lower bottom-anchored bucket than a full cell, and a full cell
	# selects the top (full) bucket. Proves the partial-fill rendering path.
	var _l2_cell := Vector2i(30, 4)
	var _l2_prev: String = world.cells.get(_l2_cell, "air")
	var _l2_buckets: int = (world._liquid_source_ids.get("lava", []) as Array).size()
	world.cells[_l2_cell] = "lava"
	world.liquid_level[_l2_cell] = 0.5
	world._set_tile(_l2_cell, "lava")
	var _l2_half_src: int = world._tilemap.get_cell_source_id(_l2_cell)
	world.liquid_level[_l2_cell] = 1.0
	world._set_tile(_l2_cell, "lava")
	var _l2_full_src: int = world._tilemap.get_cell_source_id(_l2_cell)
	# Each fill level now carries a per-variant source-id pool (deterministic
	# per-cell pick), so the rendered full-cell source is a MEMBER of the top
	# bucket's pool rather than a single fixed id.
	var _l2_full_pool: Array = (world._liquid_source_ids["lava"] as Array)[_l2_buckets - 1]
	if _l2_prev == "air":
		world.cells.erase(_l2_cell)
	else:
		world.cells[_l2_cell] = _l2_prev
	world.liquid_level.erase(_l2_cell)
	world._set_tile(_l2_cell, _l2_prev if _l2_prev != "air" else "air")
	_check("lq_partial_fill_tile_by_level",
		_l2_buckets >= 4 and _l2_half_src != _l2_full_src and _l2_full_src in _l2_full_pool,
		"buckets=%d half_src=%d full_src=%d (full pool %s)" % [
			_l2_buckets, _l2_half_src, _l2_full_src, str(_l2_full_pool)])

	# World-Depths fluid art: every liquid fill level now carries the block's
	# authored variant pool (deterministic per-cell pick), so the top bucket's
	# source-id pool matches the authored block-variant count and holds >1 tile.
	var _lv_lava_variants: int = BlockRegistry.visual_variant_textures("blocks", "lava").size()
	var _lv_water_variants: int = BlockRegistry.visual_variant_textures("blocks", "water").size()
	var _lv_water_pool: Array = (world._liquid_source_ids.get("water", []) as Array)
	var _lv_water_full: Array = _lv_water_pool[_lv_water_pool.size() - 1] if not _lv_water_pool.is_empty() else []
	_check("lq_liquid_carries_authored_variant_pool",
		_lv_lava_variants >= 2 and _l2_full_pool.size() == _lv_lava_variants
			and _lv_water_full.size() == _lv_water_variants and _lv_water_variants >= 2,
		"lava variants=%d full_pool=%d / water variants=%d full_pool=%d" % [
			_lv_lava_variants, _l2_full_pool.size(),
			_lv_water_variants, _lv_water_full.size()])

	# Enemies are affected by lava too: a threat standing in a lava cell burns via
	# the same contact_damage path. A small delta applies one sub-lethal tick so
	# the check proves the hazard without a death (which would spill loot).
	var _lq_threat: Node = root.spawn_enemy_for_test("surface_slime")
	var _lq_enemy_hurt := false
	if _lq_threat != null:
		var _lq_ecell := Vector2i(40, 6)
		world.cells[_lq_ecell] = "lava"
		_lq_threat.global_position = world.cell_center(_lq_ecell)
		var _lq_ehp0: int = _lq_threat.hp
		_lq_threat.apply_environmental_hazard(0.1)   # 14 dmg * 0.1 -> one 1-hp tick
		_lq_enemy_hurt = _lq_threat.hp < _lq_ehp0
		world.cells.erase(_lq_ecell)
		world.liquid_level.erase(_lq_ecell)
		world._set_tile(_lq_ecell, "air")
		if is_instance_valid(_lq_threat):
			_lq_threat.queue_free()
	_check("lq_lava_damages_enemy", _lq_enemy_hurt,
		"threat hp dropped from a lava tick")

	# LQ-3: water is a second liquid — flows like lava but is a non-hazard (no
	# contact damage, emits no light).
	var _w_def: Dictionary = BlockRegistry.get_block("water")
	_check("lq_water_is_liquid_non_hazard",
		BlockRegistry.is_liquid("water") and not BlockRegistry.is_solid("water")
			and BlockRegistry.contact_damage("water") == 0.0
			and not bool(_w_def.get("emits_light", false)),
		"is_liquid=%s solid=%s dmg=%.1f emits_light=%s" % [
			str(BlockRegistry.is_liquid("water")), str(BlockRegistry.is_solid("water")),
			BlockRegistry.contact_damage("water"), str(bool(_w_def.get("emits_light", false)))])

	# LQ-3: lava + water react into obsidian (the lava cell solidifies, the water
	# cell is consumed).
	var _rx_lava := Vector2i(42, 7)
	var _rx_water := Vector2i(42, 6)
	world.cells[_rx_lava] = "lava"
	world.cells[_rx_water] = "water"
	world._fluid.wake(_rx_lava)
	world._fluid.wake(_rx_water)
	world.fluid_settle(16)
	var _rx_lava_res: String = world.cells.get(_rx_lava, "air")
	var _rx_water_res: String = world.cells.get(_rx_water, "air")
	for _cc in [_rx_lava, _rx_water]:
		world.cells.erase(_cc); world.liquid_level.erase(_cc)
		world.deltas.erase(_cc); world._set_tile(_cc, "air")
	world._fluid.active.clear()
	_check("lq_water_plus_lava_makes_obsidian",
		_rx_lava_res == "obsidian" and _rx_water_res != "water",
		"lava->%s water->%s" % [_rx_lava_res, _rx_water_res])

	# LQ-3: v3 worlds generate water lakes; v2 (World Depths) worlds carry none, so
	# existing worlds stay byte-identical (the gen_version guard holds).
	var _wg3: Dictionary = WorldGen.generate(2024, WorldConfig.new({"size": "medium", "gen_version": 3}))
	var _wg2: Dictionary = WorldGen.generate(2024, WorldConfig.new({"size": "medium", "gen_version": 2}))
	var _w3_count := 0
	var _w3_surface := 0
	var _w3_deep := 0
	var _wg3_surf: Dictionary = _wg3["surface"]
	for _c: Vector2i in (_wg3["cells"] as Dictionary):
		if str((_wg3["cells"] as Dictionary)[_c]) == "water":
			_w3_count += 1
			if _c.y - int(_wg3_surf.get(_c.x, 0)) <= 4:
				_w3_surface += 1
			else:
				_w3_deep += 1
	var _w2_count := 0
	for _c: Vector2i in (_wg2["cells"] as Dictionary):
		if str((_wg2["cells"] as Dictionary)[_c]) == "water":
			_w2_count += 1
	_check("lq_water_lakes_generate", _w3_count > 0 and _w3_surface > 0 and _w3_deep > 0,
		"v3 water=%d (surface=%d deep=%d)" % [_w3_count, _w3_surface, _w3_deep])
	_check("lq_legacy_v2_has_no_water", _w2_count == 0,
		"v2 water cells=%d (must be 0 for save-compat)" % _w2_count)

	# LQ-3: generated underground liquid is encapsulated — no lava cell (and no
	# deep water cell) borders open air, so the player must MINE into it to release
	# it. Surface ponds (near the surface) are intentionally open, so exempt.
	var _g3: Dictionary = _wg3["cells"]
	var _g3w: int = int(_wg3["width"])
	var _g3h: int = int(_wg3["height"])
	var _enc_violations := 0
	for _c: Vector2i in _g3:
		var _id: String = str(_g3[_c])
		var _deep: bool = _c.y - int(_wg3_surf.get(_c.x, 0)) > 6
		if _id != "lava" and not (_id == "water" and _deep):
			continue
		for _nb: Vector2i in [_c + Vector2i(0, 1), _c + Vector2i(0, -1),
				_c + Vector2i(1, 0), _c + Vector2i(-1, 0)]:
			if _nb.x < 0 or _nb.x >= _g3w or _nb.y < 0 or _nb.y >= _g3h:
				continue
			if not _g3.has(_nb):
				_enc_violations += 1
				break
	_check("lq_generated_liquid_encapsulated", _enc_violations == 0,
		"underground liquid cells touching open air: %d (must be 0)" % _enc_violations)

	# LQ-3: trees don't dam liquid — a non-solid tree in the flow path is flooded
	# (background prop, not a wall), so lava/water pass through rather than stop.
	var _tr_src := Vector2i(44, 5)
	var _tr_tree := Vector2i(44, 6)
	var _tr_floor := Vector2i(44, 7)
	world.cells[_tr_floor] = "stone"
	world.cells[Vector2i(43, 6)] = "stone"   # box the tree cell so flooded lava rests
	world.cells[Vector2i(45, 6)] = "stone"
	world.cells[_tr_tree] = "tree_trunk"     # a non-solid tree in the flow path
	world.cells[_tr_src] = "lava"
	world._fluid.wake(_tr_src)
	world.fluid_settle(24)
	var _tr_result: String = world.cells.get(_tr_tree, "air")
	var _tr_flooded: bool = _tr_result == "lava"
	for _cc in [_tr_src, _tr_tree, _tr_floor, Vector2i(43, 6), Vector2i(45, 6)]:
		world.cells.erase(_cc); world.liquid_level.erase(_cc)
		world.deltas.erase(_cc); world._set_tile(_cc, "air")
	world._fluid.active.clear()
	_check("lq_liquid_floods_trees", _tr_flooded,
		"tree cell after flow -> %s (expected lava)" % _tr_result)

	# LQ-3 bucket: empty and filled buckets are DISTINCT items, so a filled one
	# shows as its own stack (HUD/inventory) and can never conflate a stack of
	# empty buckets. Scoop converts one empty `bucket` -> `bucket_<liquid>` and
	# holds it; pour converts it back. Bucket COUNT is conserved throughout.
	var _bk_water := Vector2i(46, 6)
	var _bk_pour := Vector2i(48, 6)
	world.cells[Vector2i(46, 7)] = "stone"     # floor so the scooped water is full
	world.cells[_bk_water] = "water"
	var _bk_prev_pos: Vector2 = player.global_position
	var _bk_prev_slot: int = player.selected_slot
	var _bk_prev_hotbar: Array = player.hotbar.duplicate()
	var _bk_e0: int = player.inventory.count("bucket")
	var _bk_f0: int = player.inventory.count("bucket_water")
	player.inventory.add("bucket", 2)          # two empty buckets on hand
	player.hotbar.clear()
	player.hotbar.append("bucket")
	player.selected_slot = 0
	player.global_position = world.cell_center(_bk_water)
	var _bk_scoop_ok: bool = player._try_use_bucket(_bk_water)
	# one empty consumed, one filled created + now held, the OTHER empty untouched.
	var _bk_after_scoop: bool = _bk_scoop_ok \
		and world.block_at(_bk_water) == "air" \
		and player.inventory.count("bucket_water") == _bk_f0 + 1 \
		and player.inventory.count("bucket") == _bk_e0 + 1 \
		and player.selected_item() == "bucket_water" \
		and player.bucket_liquid("bucket_water") == "water" and player.is_bucket_item("bucket")
	player.global_position = world.cell_center(_bk_pour)
	var _bk_pour_ok: bool = player._try_use_bucket(_bk_pour)
	var _bk_after_pour: bool = _bk_pour_ok \
		and world.block_at(_bk_pour) == "water" \
		and player.inventory.count("bucket_water") == _bk_f0 \
		and player.inventory.count("bucket") == _bk_e0 + 2 \
		and player.selected_item() == "bucket"
	# filled-bucket art is wired (proves the "shows as filled" fix) + names resolve.
	var _bk_icon_ok: bool = BlockRegistry.visual_texture("items", "bucket_water") != null \
		and BlockRegistry.visual_texture("items", "bucket_lava") != null \
		and BlockRegistry.display_name("bucket_water") == "Bucket of Water"
	player.inventory.remove("bucket", 2)       # restore starting counts
	player.hotbar.clear()
	for _hid in _bk_prev_hotbar:
		player.hotbar.append(_hid)
	player.selected_slot = _bk_prev_slot
	player.global_position = _bk_prev_pos
	for _cc in [_bk_water, _bk_pour, Vector2i(46, 7)]:
		world.cells.erase(_cc); world.liquid_level.erase(_cc)
		world.deltas.erase(_cc); world._set_tile(_cc, "air")
	world._fluid.active.clear()
	_check("lq_bucket_scoop_and_pour",
		_bk_after_scoop and _bk_after_pour and _bk_icon_ok,
		"scoop=%s pour=%s icon=%s" % [str(_bk_after_scoop), str(_bk_after_pour), str(_bk_icon_ok)])

	# LQ-3 fix: scoop from a SHALLOW/partial pool, not just a near-full cell.
	# Water spreads into thin films — four cells at level 0.3 (1.2 total) each sit
	# below the old 0.5 single-cell gate, yet a scoop now draws a bucketful (~1.0)
	# from the connected pool. (This was the "can't pick up water" bug.)
	world.fluid_paused = true
	var _sc_cells := [Vector2i(52, 5), Vector2i(53, 5), Vector2i(54, 5), Vector2i(55, 5)]
	for _sx in range(52, 56):
		world.cells[Vector2i(_sx, 6)] = "stone"
	for _sc in _sc_cells:
		world.cells[_sc] = "water"; world.liquid_level[_sc] = 0.3; world._set_tile(_sc, "water")
	var _sc_mass0 := 0.0
	for _sc in _sc_cells:
		_sc_mass0 += float(world.liquid_level.get(_sc, 1.0))
	var _sc_id: String = world.scoop_liquid(_sc_cells[0])
	var _sc_mass1 := 0.0
	for _sc in _sc_cells:
		if world.block_at(_sc) == "water":
			_sc_mass1 += float(world.liquid_level.get(_sc, 1.0))
	var _sc_drained := _sc_mass0 - _sc_mass1
	_check("lq_bucket_scoops_partial_pool",
		_sc_id == "water" and _sc_drained > 0.9 and _sc_drained <= 1.01,
		"id=%s drained=%.2f of %.2f" % [_sc_id, _sc_drained, _sc_mass0])
	for _sc in _sc_cells:
		world.cells.erase(_sc); world.liquid_level.erase(_sc)
		world.deltas.erase(_sc); world._set_tile(_sc, "air")
	for _sx in range(52, 56):
		var _sf := Vector2i(_sx, 6)
		world.cells.erase(_sf); world.deltas.erase(_sf); world._set_tile(_sf, "air")
	world._fluid.active.clear()
	world.fluid_paused = false

	# --- Liquid physics: level-aware submersion, per-liquid tuning, breath ---
	# (a) liquid_covering keys off the TRUE fill level, not just the block: the
	# empty top of a half-full cell reads as uncovered, the bottom as submerged.
	var _lc := Vector2i(50, 6)
	world.cells[_lc] = "water"; world.liquid_level[_lc] = 0.5
	var _lc_top: String = world.liquid_covering(Vector2(808.0, 98.0))   # above waterline
	var _lc_bot: String = world.liquid_covering(Vector2(808.0, 110.0))  # below waterline
	_check("lq_covering_respects_fill_level",
		_lc_top == "" and _lc_bot == "water",
		"top=%s bottom=%s" % [_lc_top, _lc_bot])
	world.cells.erase(_lc); world.liquid_level.erase(_lc); world._set_tile(_lc, "air")

	# (b) per-liquid tuning is data-driven and distinct: thick lava slows you more
	# than water, and both slow you below open air; water drains breath + drowns.
	_check("lq_move_tuning_per_liquid",
		BlockRegistry.liquid_move_mult("lava") < BlockRegistry.liquid_move_mult("water")
		and BlockRegistry.liquid_move_mult("water") < 1.0
		and BlockRegistry.liquid_breath_drain("water") > 0.0
		and BlockRegistry.liquid_drown_damage("water") > 0.0,
		"lava=%.2f water=%.2f drain=%.1f drown=%.1f" % [
			BlockRegistry.liquid_move_mult("lava"),
			BlockRegistry.liquid_move_mult("water"),
			BlockRegistry.liquid_breath_drain("water"),
			BlockRegistry.liquid_drown_damage("water")])

	# (c) breath drains with the head submerged, drowns (health) once empty, and a
	# water-breathing ancestry ignores it entirely.
	var _br_prev_pos: Vector2 = player.global_position
	var _br_prev_health: float = player.health
	var _br_prev_breath: float = player.breath
	var _br_prev_wb: bool = player.ancestry_water_breathing
	for _wy in [5, 6, 7]:
		world.cells[Vector2i(60, _wy)] = "water"
	player.ancestry_water_breathing = false
	player.global_position = world.cell_center(Vector2i(60, 6))   # head in the water
	player.breath = player.max_breath()
	player._update_breath(1.0)
	var _br_drained: bool = player.breath < player.max_breath()
	player.breath = 0.0
	player._drown_accum = 0.0
	player.health = player.max_health
	player._update_breath(0.5)
	var _br_drowned: bool = player.health < player.max_health
	player.ancestry_water_breathing = true
	player.breath = 12.0
	player._update_breath(1.0)
	var _br_wb_safe: bool = player.breath >= 12.0
	_check("lq_breath_drain_drown_and_water_breathing",
		_br_drained and _br_drowned and _br_wb_safe,
		"drained=%s drowned=%s wb_safe=%s" % [str(_br_drained), str(_br_drowned), str(_br_wb_safe)])
	for _wy2 in [5, 6, 7]:
		var _wc := Vector2i(60, _wy2)
		world.cells.erase(_wc); world.liquid_level.erase(_wc); world._set_tile(_wc, "air")
	player.ancestry_water_breathing = _br_prev_wb
	player.global_position = _br_prev_pos
	player.health = _br_prev_health
	player.breath = _br_prev_breath
	player.modulate = Color(1, 1, 1)

	# --- Character traits + Calling affect the player ---
	# Callings no longer grant a static health bonus (their innate effects are
	# conditional), so the baseline here is base 100 + Hardy trait 25 = 125.
	var default_speed: float = player.effective_mine_speed()
	player.apply_character({"appearance": "umber", "traits": ["hardy", "miner"], "role": "oathbound"})
	_check("character_traits_apply", absf(player.max_health - 125.0) < 0.01
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
	_check("enemies_json_loads", enemy_reg.live_defs().size() == 8,
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

	# Kill slime with forced 1.0 drop chance ON the player; R-08 slice 3 spills
	# loot onto the ground and the adjacent player collects it into the backpack.
	var inv_before: int = player.inventory.total()
	if slime_node != null and is_instance_valid(slime_node):
		slime_node.global_position = player.global_position
		slime_node.drop_chance_override = 1.0
		slime_node.take_hit(99)
	await get_tree().process_frame
	player.collect_ground_drops()
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

	# (f) a new enemy's drops reach the player on death. R-08 slice 3 routes loot
	# through a ground drop; killed on the player, the adjacent player collects it.
	var _fq13_inv_before: int = player.inventory.total()
	if _fq13_thorn_node != null and is_instance_valid(_fq13_thorn_node):
		_fq13_thorn_node.global_position = player.global_position
		_fq13_thorn_node.drop_chance_override = 1.0
		_fq13_thorn_node.take_hit(99)
	await get_tree().process_frame
	player.collect_ground_drops()
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

	# The post-FQ-15 art pass closes the three newer live enemy families too:
	# each resolves a real 3-entry pool and the spawned enemy holds one member.
	var _p1_thorn: Node = root.spawn_enemy_for_test("thornrat")
	var _p1_thorn_pool: Array = BlockRegistry.visual_variant_textures(
		"enemies", "thornrat")
	_check("fq13p1_new_enemy_pool_live",
		_p1_thorn_pool.size() == 3
		and _p1_thorn._art != null and _p1_thorn.variant_index >= 0
		and _p1_thorn.variant_index < _p1_thorn_pool.size()
		and _p1_node._art != null,
		"thorn_pool=%d thorn_idx=%d crawler_has_art=%s" % [_p1_thorn_pool.size(),
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

	# the live hotbar slot consumes frame art. FQ-21 band mode: the normal
	# frame is BAKED into the one-piece center block (the overlay stylebox is
	# deliberately empty) and the gold selection stylebox stays textured.
	# Sample a NON-selected slot — the selected one wears the gold texture.
	var _p2_slot0 = hud._hotbar_slots[(player.selected_slot + 1) % 5].get_theme_stylebox("panel")
	var _p2_normal_ok: bool = hud._slot_normal_sb is StyleBoxTexture \
		if hud._hud_kit_active else ((hud._slot_normal_sb is StyleBoxEmpty) \
		if hud._dock_band_active else (hud._slot_normal_sb is StyleBoxTexture))
	var _p2_slot0_ok: bool = _p2_slot0 is StyleBoxTexture \
		if hud._hud_kit_active else ((_p2_slot0 is StyleBoxEmpty) \
		if hud._dock_band_active else _p2_slot0 is StyleBoxTexture)
	_check("fq13p2_slot_frame_consumed",
		_p2_normal_ok
		and hud._slot_selected_sb is StyleBoxTexture
		and _p2_slot0_ok,
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
	var _p4_meat_a: Texture2D = BlockRegistry.item_icon("meat")
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

	# --- FQ-14: state-driven goal panel ---
	var _g14_script = preload("res://scripts/main/goal_tracker.gd")
	var _g14 = _g14_script.new()
	var _g14_start: String = str(_g14.current()["id"])
	_g14.note({"gather": true})
	var _g14_after_gather: String = str(_g14.current()["id"])
	_g14.note({"light": true})
	_g14.note({"deposit": true})
	_g14.note({"craft": true})
	var _g14_before_survive: String = str(_g14.current()["id"])
	_g14.note({"survive": true})
	var _g14_after_survive: String = str(_g14.current()["id"])   # M5-B: onboarding continues
	_g14.note({"house": true})
	_g14.note({"defend": true})
	_check("fq14_goals_advance_in_order",
		_g14_start == "gather" and _g14_after_gather == "light"
		and _g14_before_survive == "survive" and _g14_after_survive == "house"
		and _g14.all_done() and bool(_g14.current()["all_done"]),
		"start=%s after_gather=%s before_survive=%s after_survive=%s done=%s" % [
			_g14_start, _g14_after_gather, _g14_before_survive, _g14_after_survive,
			str(_g14.all_done())])

	# prefix-latch: a later objective latches earlier ones; a transient clear of
	# an earlier condition never regresses the panel.
	var _g14b = _g14_script.new()
	_g14b.note({"deposit": true})
	var _g14b_after: String = str(_g14b.current()["id"])
	_g14b.note({"gather": false, "light": false, "deposit": false})
	_check("fq14_goals_prefix_latch",
		_g14b.is_done("gather") and _g14b.is_done("light") and _g14b.is_done("deposit")
		and _g14b_after == "craft" and str(_g14b.current()["id"]) == "craft",
		"after=%s still_craft=%s" % [_g14b_after, str(str(_g14b.current()["id"]) == "craft")])

	# game_root derives the objectives from real state and drives the HUD panel;
	# the panel is built, populated, and unobtrusive (ignores mouse input).
	var _g14_snap: Dictionary = root._goal_snapshot()
	root._refresh_goals()
	_check("fq14_goal_panel_wired",
		_g14_snap.has("gather") and _g14_snap.has("light") and _g14_snap.has("deposit")
		and _g14_snap.has("craft") and _g14_snap.has("survive")
		and hud._goal_label != null and hud._goal_label.text != ""
		and hud._goal_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"keys=%d text=%s" % [_g14_snap.size(), hud._goal_label.text])

	# survive derives from real state (day_count); the panel hides/shows.
	var _g14_saved_day: int = root.day_count
	root.day_count = 2
	var _g14_survive: bool = bool(root._goal_snapshot().get("survive", false))
	root.day_count = _g14_saved_day
	hud._goal_visible = true
	hud._goal_panel.visible = true
	var _g14_shown: bool = hud.goal_panel_visible()
	hud._goal_visible = false
	hud._goal_panel.visible = false
	var _g14_hidden: bool = hud.goal_panel_visible()
	hud._goal_panel.visible = true
	_check("fq14_goal_survive_and_toggle",
		_g14_survive and _g14_shown and not _g14_hidden,
		"survive_day2=%s shown=%s hidden=%s" % [
			str(_g14_survive), str(_g14_shown), str(_g14_hidden)])

	# --- FQ-15: map / scouting / navigation ---
	# pure map_state: revealing a cell marks its 3x3 band, not the far world, and
	# the compact save form round-trips.
	var _m15_script = preload("res://scripts/world/map_state.gd")
	var _m15 = _m15_script.new()
	var _m15_newly: bool = _m15.reveal_around(Vector2i(50, 30), 1)
	var _m15_ser: Array = _m15.serialize()
	var _m15_round = _m15_script.parse(_m15_ser)
	_check("fq15_reveal_bands",
		_m15_newly and _m15.revealed_count() == 9
		and _m15.cell_revealed(Vector2i(50, 30))
		and not _m15.cell_revealed(Vector2i(200, 30))
		and _m15_round.size() == 9,
		"count=%d here=%s far=%s round=%d" % [_m15.revealed_count(),
			str(_m15.cell_revealed(Vector2i(50, 30))),
			str(_m15.cell_revealed(Vector2i(200, 30))), _m15_round.size()])

	# game_root snapshot: has all fields, and the hall/player markers are real
	# cells; revealing under the player exposes them on the map.
	root._map_state.reveal_around(world.cell_of(player.global_position), 1)
	var _m15_snap: Dictionary = root.map_snapshot()
	var _m15_hall: Vector2i = world.hall_info.get("center_cell", Vector2i(-1, -1))
	_check("fq15_map_snapshot_markers",
		_m15_snap.has("width") and _m15_snap.has("height") and _m15_snap.has("region")
		and _m15_snap.has("revealed") and _m15_snap.has("ore") and _m15_snap.has("threats")
		and _m15_snap.get("hall") == _m15_hall
		and int(_m15_snap.get("width", 0)) == world.width,
		"hall=%s width=%d revealed=%d" % [str(_m15_snap.get("hall")),
			int(_m15_snap.get("width", 0)), (_m15_snap.get("revealed") as Array).size()])

	# discovered bands persist: the compact list round-trips through game_root.
	root._map_state.clear()
	root._map_state.reveal_around(Vector2i(100, 20), 1)
	var _m15_g_ser: Array = root.map_revealed_serialized()
	root._map_state.clear()
	root.apply_map_revealed(_m15_g_ser)
	_check("fq15_map_persists",
		root._map_state.revealed_count() == 9
		and root._map_state.cell_revealed(Vector2i(100, 20)),
		"restored=%d has_cell=%s" % [root._map_state.revealed_count(),
			str(root._map_state.cell_revealed(Vector2i(100, 20)))])

	# the map panel opens/closes, and the biome_reveal perk widens the scouted
	# band (the scouting hook for exploration perks).
	var _m15_open0: bool = hud.map_open()
	var _m15_toggled: bool = hud.toggle_map()
	var _m15_open1: bool = hud.map_open()
	hud.toggle_map()
	# Broad Horizon is a SURFACE reveal skill, so place the player clearly above
	# the sky line for a deterministic check of the context-scoped hook.
	var _m15_sx: int = world.width / 2
	var _m15_prev_pos: Vector2 = player.global_position
	player.global_position = world.cell_center(Vector2i(_m15_sx, world.sky_line(_m15_sx) - 3))
	var _m15_had_perk: bool = "broad_horizon" in root.purchased_perks
	if _m15_had_perk:
		root.purchased_perks.erase("broad_horizon")
	var _m15_r0: int = root._scout_reveal_radius()
	root.purchased_perks.append("broad_horizon")
	var _m15_r1: int = root._scout_reveal_radius()
	if not _m15_had_perk:
		root.purchased_perks.erase("broad_horizon")
	player.global_position = _m15_prev_pos
	_check("fq15_map_toggle_and_scout_hook",
		not _m15_open0 and _m15_toggled and _m15_open1 and not hud.map_open()
		and _m15_r0 == 1 and _m15_r1 == 2,
		"toggle=%s->%s r0=%d r1=%d" % [str(_m15_open0), str(_m15_open1), _m15_r0, _m15_r1])

	hud.set_map_open(false)
	var _m15_key := InputEventKey.new()
	_m15_key.physical_keycode = KEY_M
	_m15_key.pressed = true
	var _m15_prev_edit_mode: bool = GameState.hud_edit_mode
	GameState.hud_edit_mode = false
	root._unhandled_input(_m15_key)
	var _m15_key_opens: bool = hud.map_open()
	root._unhandled_input(_m15_key)
	var _m15_key_closes: bool = not hud.map_open()
	var _m15_echo_key := InputEventKey.new()
	_m15_echo_key.physical_keycode = KEY_M
	_m15_echo_key.pressed = true
	_m15_echo_key.echo = true
	root._unhandled_input(_m15_echo_key)
	var _m15_echo_blocked: bool = not hud.map_open()
	GameState.hud_edit_mode = true
	root._unhandled_input(_m15_key)
	var _m15_key_blocked_in_edit: bool = not hud.map_open()
	GameState.hud_edit_mode = _m15_prev_edit_mode
	_check("fq15_map_key_respects_ui_boundary",
		_m15_key_opens and _m15_key_closes and _m15_echo_blocked
		and _m15_key_blocked_in_edit,
		"opens=%s closes=%s echo_blocked=%s edit_blocked=%s" % [
			str(_m15_key_opens), str(_m15_key_closes), str(_m15_echo_blocked),
			str(_m15_key_blocked_in_edit)])

	# Map and Events are independent adjacent modules; either can toggle while
	# the other remains open, and contextual chips sit below the taller one.
	# Start these geometry checks from the default layout so a HUD size/position
	# a prior run persisted into the shell profile cannot skew the panel rects
	# (fq19 event bounds, fq21 map masking); the widgets restore their own state.
	hud.reset_hud_layout()
	await get_tree().process_frame
	var _fq19_events_before: bool = hud._event_panel != null and hud._event_panel.visible
	if hud._event_panel != null:
		hud._event_panel.visible = true
		hud._save_hud_layout()
	var _fq19_map_open: bool = hud.toggle_map()
	var _fq19_together: bool = _fq19_map_open and hud._event_panel.visible
	hud._toggle_event_module()
	var _fq19_event_off_map_on: bool = not hud._event_panel.visible and hud.map_open()
	hud._toggle_event_module()
	var _fq19_event_on_map_on: bool = hud._event_panel.visible and hud.map_open()
	var _fq19_event_rect: Rect2 = hud._event_panel.get_global_rect() if hud._event_panel != null else Rect2()
	var _fq19_map_rect: Rect2 = hud._map_panel.get_global_rect() if hud._map_panel != null else Rect2()
	hud._position_context_stack()
	var _fq19_stack_clear: bool = hud._context_stack.offset_top >= \
		maxf(_fq19_event_rect.end.y, _fq19_map_rect.end.y) + 8.0
	hud.toggle_map()
	var _fq19_event_survives_close: bool = hud._event_panel.visible and not hud.map_open()
	var _fq19_viewport: Vector2 = get_viewport().get_visible_rect().size
	if hud._event_panel != null:
		hud._event_panel.visible = _fq19_events_before
		hud._save_hud_layout()
	_check("fq19_map_events_coexist",
		_fq19_together and _fq19_event_off_map_on and _fq19_event_on_map_on
		and _fq19_event_survives_close and not _fq19_event_rect.intersects(_fq19_map_rect)
		and _fq19_stack_clear
		and hud._event_panel.custom_minimum_size.x >= 320.0
		and hud._event_panel.custom_minimum_size.y >= 120.0
		and _fq19_event_rect.position.x >= 8.0
		and _fq19_event_rect.end.x <= _fq19_viewport.x - 8.0
		and _fq19_event_rect.position.y >= 8.0
		and _fq19_event_rect.end.y <= _fq19_viewport.y - 8.0,
		"together=%s event_off=%s event_on=%s survives=%s event=%s map=%s stack=%.1f viewport=%s" % [
			str(_fq19_together), str(_fq19_event_off_map_on), str(_fq19_event_on_map_on),
			str(_fq19_event_survives_close),
			str(hud._event_panel.custom_minimum_size if hud._event_panel != null else Vector2.ZERO),
			str(_fq19_map_rect), hud._context_stack.offset_top, str(_fq19_viewport)])
	hud.update_time(5, true, 2)
	var _fq19_time_ok: bool = hud._time_label == null and hud._event_time_label != null \
		and hud._event_time_label.text.contains("Day 5") \
		and hud._event_time_label.text.contains("Night")
	_check("fq19_events_time_header_live", _fq19_time_ok,
		"crest_time=%s header=%s" % [str(hud._time_label != null),
			str(hud._event_time_label.text if hud._event_time_label != null else "missing")])

	# FQ-19: exact clock — the fraction maps onto the settlement clock
	# (day 06:00-20:00, night wraps 20:00-06:00) with dawn/day/dusk/night
	# phase words in the events header.
	hud.update_time(5, true, 0, 0.7)
	var _fq19c_night: String = hud._event_time_label.text
	hud.update_time(5, false, 0, 0.05)
	var _fq19c_dawn: String = hud._event_time_label.text
	hud.update_time(5, false, 0, 0.3)
	var _fq19c_day: String = hud._event_time_label.text
	hud.update_time(5, false, 0, 0.6)
	var _fq19c_dusk: String = hud._event_time_label.text
	hud.update_time(root.day_count, root.is_night, 0, root.time_of_day)
	_check("fq19_events_exact_clock",
		_fq19c_night.contains("• Night 21:2")
		and _fq19c_dawn.contains("• Dawn 07:0")
		and _fq19c_day.contains("• Day 12:2")
		and _fq19c_dusk.contains("• Dusk 18:5"),
		"night=%s dawn=%s day=%s dusk=%s" % [_fq19c_night, _fq19c_dawn,
			_fq19c_day, _fq19c_dusk])

	# FQ-19: framed crest and goal treatment — the crest is a framed panel
	# whose C/L/R rows carry numeric values, and the goal panel exposes the
	# milestone progress strip mirroring index/total.
	hud.update_settlement(72.4, 41.0, 58.0, {}, [])
	hud.update_progression(2, 10, 100, "Hamlet")
	var _fq19_crest_ok: bool = hud._top_left_box is PanelContainer \
		and hud._crest_title != null and hud._crest_title.text.contains("Hamlet") \
		and hud._crest_title.text.contains("Lv.2") \
		and hud._bar_values.size() == 3 \
		and (hud._bar_values["coherence"] as Label).text == "72"
	hud.update_goal({"id": "light", "text": "Light the Town Hall",
		"hint": "Craft a torch.", "index": 1, "total": 5, "all_done": false})
	var _fq19_goal_ok: bool = hud._goal_progress != null \
		and is_equal_approx(hud._goal_progress.value, 1.0) \
		and is_equal_approx(hud._goal_progress.max_value, 5.0) \
		and hud._goal_label.text.contains("Light the Town Hall")
	hud.update_goal(root._goal_tracker.current())
	root._refresh_hud_progression()
	_check("fq19_crest_goal_blueprint",
		_fq19_crest_ok and _fq19_goal_ok,
		"crest=%s title=%s c_val=%s goal=%s" % [str(_fq19_crest_ok),
			str(hud._crest_title.text if hud._crest_title != null else "missing"),
			str((hud._bar_values["coherence"] as Label).text if hud._bar_values.has("coherence") else "missing"),
			str(_fq19_goal_ok)])

	# (The contextual-stack check lives at the end of the suite: its real-time
	# auto-hide waits must not shift the live music clip-switch timing.)

	# FQ-21 contract v2: the native layered kit spans the viewport, loads its
	# decorative layers from the manifest, and retains five runtime slots plus
	# four registered action controls.
	var _fq21_geometry: Dictionary = hud._load_hud_kit_layout()
	var _fq21_block: TextureRect = hud._bottom_dock.find_child("DockBackplate", true, false)
	var _fq21_trim_enabled := true
	for _fq21_layer_raw in _fq21_geometry.get("decorative_layers", []):
		if _fq21_layer_raw is Dictionary \
				and str((_fq21_layer_raw as Dictionary).get("role", "")) == "foreground_trim":
			_fq21_trim_enabled = bool((_fq21_layer_raw as Dictionary).get("enabled", true))
			break
	var _fq21_trim_node: Node = hud._bottom_dock.find_child(
		"DockForegroundTrim", true, false)
	var _fq21_trim_toggle_ok: bool = (_fq21_trim_enabled and _fq21_trim_node != null) \
		or (not _fq21_trim_enabled and _fq21_trim_node == null)
	var _fq21_pieces_ok: bool = hud._hud_kit_active and hud._dock_band_active \
		and _fq21_block != null and _fq21_block.texture != null \
		and _fq21_trim_toggle_ok \
		and hud._bottom_dock.find_child("HealthFrame", true, false) != null \
		and hud._bottom_dock.find_child("AttunementFrame", true, false) != null \
		and _fq21_block.texture.get_size().is_equal_approx(
			Vector2(float(_fq21_geometry.native_size[0]),
				float(_fq21_geometry.native_size[1])))
	var _fq21_full_width: bool = hud._bottom_dock.size.x >= \
		get_viewport().get_visible_rect().size.x - 1.0
	var _fq21_nav_found := 0
	var _fq21_child_names: Array[String] = []
	for _fq21_child in hud._bottom_dock.get_children():
		_fq21_child_names.append(str(_fq21_child.name))
	for _fq21_name in ["DockActionInventory", "DockActionCharacter",
			"DockActionSkills", "DockActionTownHall"]:
		var _fq21_btn: Node = hud._bottom_dock.find_child(_fq21_name, true, false)
		if _fq21_btn is Button and (_fq21_btn as Button).tooltip_text != "":
			_fq21_nav_found += 1
	_check("fq21_hud_kit_primary",
		_fq21_pieces_ok and _fq21_full_width and _fq21_nav_found == 4
		and hud._hotbar_slots.size() == 5,
		"pieces=%s trim_enabled=%s trim_toggle=%s full_width=%s nav=%d slots=%d children=%s" % [
			str(_fq21_pieces_ok), str(_fq21_trim_enabled), str(_fq21_trim_toggle_ok),
			str(_fq21_full_width), _fq21_nav_found, hud._hotbar_slots.size(),
			str(_fq21_child_names)])

	# Slice 4: the cursor can pick a dock slot — cells claim their clicks (STOP)
	# and are wired to the selection path (was number-keys only).
	var _dc_prev: int = player.selected_slot
	var _dc_target: int = 0 if player.selected_slot != 0 else 1
	var _dc_cells_ok: bool = hud._hotbar_cells.size() >= 5
	var _dc_stop_ok: bool = _dc_cells_ok \
		and (hud._hotbar_cells[0] as Control).mouse_filter == Control.MOUSE_FILTER_STOP
	var _dc_wired_ok: bool = _dc_cells_ok \
		and (hud._hotbar_cells[0] as Control).gui_input.get_connections().size() >= 1
	hud._select_dock_slot(_dc_target)   # the exact path a cell click invokes
	var _dc_selected_ok: bool = player.selected_slot == _dc_target \
		and hud.hotbar_selected_index() == _dc_target
	player.selected_slot = _dc_prev
	hud._refresh_dock_selection_styles()
	_check("hud_dock_click_selects",
		_dc_stop_ok and _dc_wired_ok and _dc_selected_ok,
		"stop=%s wired=%s selected=%s cells=%d" % [str(_dc_stop_ok), str(_dc_wired_ok),
			str(_dc_selected_ok), hud._hotbar_cells.size()])

	# Optional HUD themes resolve per static asset. Missing, unsafe-id, and
	# wrong-size candidates must all fall back to the required base PNG, while
	# a valid same-contract sibling is selected without changing gameplay data.
	var _fq21_theme_valid_path := \
		"res://art/generated/ui_painted/slot_normal__smoke_valid.png"
	var _fq21_theme_invalid_path := \
		"res://art/generated/ui_painted/slot_normal__smoke_invalid.png"
	for _fq21_theme_tmp in [_fq21_theme_valid_path, _fq21_theme_invalid_path]:
		if FileAccess.file_exists(_fq21_theme_tmp):
			DirAccess.remove_absolute(_fq21_theme_tmp)
	var _fq21_theme_base_before: Texture2D = BlockRegistry.visual_texture(
		"ui_painted", "slot_normal")
	var _fq21_theme_source: Image = _fq21_theme_base_before.get_image()
	_fq21_theme_source.save_png(_fq21_theme_valid_path)
	var _fq21_theme_bad := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_fq21_theme_bad.fill(Color.WHITE)
	_fq21_theme_bad.save_png(_fq21_theme_invalid_path)
	var _fq21_theme_base: Texture2D = BlockRegistry.visual_texture(
		"ui_painted", "slot_normal")
	var _fq21_theme_valid: Texture2D = hud._painted_texture_for_theme(
		"slot_normal", "smoke_valid")
	var _fq21_theme_missing: Texture2D = hud._painted_texture_for_theme(
		"slot_normal", "smoke_missing")
	var _fq21_theme_invalid: Texture2D = hud._painted_texture_for_theme(
		"slot_normal", "smoke_invalid")
	var _fq21_theme_unsafe: Texture2D = hud._painted_texture_for_theme(
		"slot_normal", "../outside")
	var _fq21_theme_contract_ok: bool = _fq21_theme_valid != _fq21_theme_base \
		and _fq21_theme_valid.get_size() == _fq21_theme_base.get_size() \
		and _fq21_theme_missing == _fq21_theme_base \
		and _fq21_theme_invalid == _fq21_theme_base \
		and _fq21_theme_unsafe == _fq21_theme_base \
		and not hud.hud_visual_theme_id().is_empty() \
		and hud.hud_visual_theme_id() == hud._normalize_hud_visual_theme(
			hud.hud_visual_theme_id())
	DirAccess.remove_absolute(_fq21_theme_valid_path)
	DirAccess.remove_absolute(_fq21_theme_invalid_path)
	_check_res_fixture("fq21_hud_theme_asset_fallback", _fq21_theme_contract_ok,
		"theme=%s valid=%s missing=%s invalid=%s unsafe=%s" % [
			hud.hud_visual_theme_id(), str(_fq21_theme_valid != _fq21_theme_base),
			str(_fq21_theme_missing == _fq21_theme_base),
			str(_fq21_theme_invalid == _fq21_theme_base),
			str(_fq21_theme_unsafe == _fq21_theme_base)])

	# R-06.1 seam: the chrome/theme resolver + slicer-geometry parsers now live
	# in HudChrome; hud.gd's facade must delegate identically (same result the
	# fq21 checks above already depend on, now sourced from the collaborator).
	var _r06_norm_ok: bool = HudChrome.normalize_hud_visual_theme("Ember Light") == "ember_light" \
		and hud._normalize_hud_visual_theme("Ember Light") == HudChrome.normalize_hud_visual_theme("Ember Light") \
		and HudChrome.normalize_hud_visual_theme("../bad") == "" \
		and hud._normalize_hud_visual_theme("../bad") == ""
	var _r06_rect_ok: bool = HudChrome.json_rect([3, 4, 5, 6]) == Rect2(3, 4, 5, 6) \
		and hud._json_rect([3, 4, 5, 6]) == HudChrome.json_rect([3, 4, 5, 6]) \
		and HudChrome.json_rect("nope") == Rect2()
	var _r06_vec_ok: bool = HudChrome.json_vec([7, 8]) == Vector2(7, 8) \
		and hud._json_vec([7, 8]) == HudChrome.json_vec([7, 8])
	var _r06_layout_ok: bool = hud._load_hud_kit_layout() == HudChrome.load_hud_kit_layout() \
		and hud._load_band_geometry() == HudChrome.load_band_geometry() \
		and not HudChrome.load_hud_kit_layout().is_empty()
	var _r06_theme_ok: bool = hud._painted_texture_for_theme("slot_normal", "") \
		== HudChrome.painted_texture_for_theme("slot_normal", "")
	_check("r06_chrome_resolver_delegates",
		_r06_norm_ok and _r06_rect_ok and _r06_vec_ok and _r06_layout_ok and _r06_theme_ok,
		"norm=%s rect=%s vec=%s layout=%s theme=%s" % [
			str(_r06_norm_ok), str(_r06_rect_ok), str(_r06_vec_ok),
			str(_r06_layout_ok), str(_r06_theme_ok)])

	# R-06.2 seam: the edit-mode geometry math now lives in HudEditGeometry;
	# hud.gd's facade (_hud_widget_size / _hud_grip_rect, driven by fq17/fq21)
	# must delegate identically, and the pure math holds on fixed inputs.
	var _r06g_widget: Control = hud._hud_widgets.get("crest")
	var _r06g_size_ok: bool = _r06g_widget != null \
		and hud._hud_widget_size(_r06g_widget) == HudEditGeometry.widget_size(_r06g_widget)
	# The wrapper returns Rect2() for a hidden widget, else the geometry rect --
	# assert delegation for whichever state the crest is in.
	var _r06g_grip_expected: Rect2 = HudEditGeometry.grip_rect(_r06g_widget.get_global_rect()) \
		if (_r06g_widget != null and _r06g_widget.visible) else Rect2()
	var _r06g_grip_ok: bool = _r06g_widget != null \
		and hud._hud_grip_rect("crest") == _r06g_grip_expected
	var _r06g_min_ok: bool = HudEditGeometry.min_size(Vector2(400.0, 200.0)) == Vector2(200.0, 100.0) \
		and HudEditGeometry.min_size(Vector2(10.0, 10.0)) == Vector2(120.0, 56.0)
	var _r06g_max_ok: bool = HudEditGeometry.max_size(Vector2(100.0, 100.0), Vector2(1280.0, 720.0)) \
		== Vector2(200.0, 200.0)
	var _r06g_clamp_slack_ok: bool = HudEditGeometry.clamp_position(
		Vector2(-50.0, -50.0), Vector2(100.0, 100.0), Vector2(1280.0, 720.0)) == Vector2(12.0, 12.0)
	# A full-width extent has no horizontal slack, so x is left untouched.
	var _r06g_clamp_noslack_ok: bool = HudEditGeometry.clamp_position(
		Vector2(0.0, 5.0), Vector2(1280.0, 40.0), Vector2(1280.0, 720.0)).x == 0.0
	_check("r06_edit_geometry_delegates",
		_r06g_size_ok and _r06g_grip_ok and _r06g_min_ok and _r06g_max_ok \
			and _r06g_clamp_slack_ok and _r06g_clamp_noslack_ok,
		"size=%s grip=%s min=%s max=%s clamp=%s noslack=%s" % [
			str(_r06g_size_ok), str(_r06g_grip_ok), str(_r06g_min_ok),
			str(_r06g_max_ok), str(_r06g_clamp_slack_ok), str(_r06g_clamp_noslack_ok)])

	# Slice 3: the settler info panel is a first-class editable HUD widget — it can
	# be moved and resized through the same edit path as the crest/goal/events.
	var _npce_registered: bool = hud._hud_widgets.get("npc") == hud._npc_panel \
		and hud._editable_hud_widget_ids().has("npc")
	# Populate the panel with a real settler so it has actual content (and thus a
	# non-zero laid-out size) — an empty panel could read a zero rect. Then reset
	# to default geometry so a persisted layout can't leave it off-screen/unsized.
	var _npce_subj = null
	for _npce_s in get_tree().get_nodes_in_group("subjects"):
		if is_instance_valid(_npce_s):
			_npce_subj = _npce_s
			break
	if _npce_subj != null:
		hud.open_npc_panel(_npce_subj)   # sets subject + refresh → real content/size
	else:
		hud._npc_panel.visible = true
	hud._npc_panel.position = hud._hud_default_positions.get("npc", hud._npc_panel.position)
	hud._npc_panel.reset_size()          # force the container to its content size now
	for _npce_f in range(3):
		await get_tree().process_frame       # let the container compute its size
	var _npce_grip: Rect2 = hud._hud_grip_rect("npc")   # non-empty only when visible
	var _npce_pos0: Vector2 = hud._npc_panel.position
	hud._hud_edit_selected = "npc"
	hud._nudge_hud_widget(Vector2(24, 12))
	var _npce_moved: bool = hud._npc_panel.position != _npce_pos0
	var _npce_size0: Vector2 = hud._hud_widget_size(hud._npc_panel)
	hud._resize_hud_widget_to_size("npc", _npce_size0 + Vector2(20, 20))
	var _npce_resized: bool = hud._hud_widget_size(hud._npc_panel) != _npce_size0
	hud.reset_hud_layout()
	hud._npc_panel.visible = false
	_check("hud_npc_panel_editable",
		_npce_registered and _npce_grip.size.x > 0.0 and _npce_moved and _npce_resized,
		"reg=%s grip=%s moved=%s resized=%s" % [str(_npce_registered),
			str(_npce_grip.size), str(_npce_moved), str(_npce_resized)])

	# R-06.3 seam: vessel/chrome texture prep now builds in HudChrome; hud.gd
	# keeps the caches + source lookup. Textures are freshly built (not
	# identity-equal), so assert resulting dimensions + null-safety.
	var _r06t_mask_src: Texture2D = BlockRegistry.visual_texture("ui", "orb_fill_mask")
	var _r06t_mask: Texture2D = HudChrome.glass_mask_from(_r06t_mask_src, 40)
	var _r06t_mask_ok: bool = _r06t_mask != null and _r06t_mask.get_size() == Vector2(40, 40) \
		and hud._glass_mask_texture(40) != null \
		and hud._glass_mask_texture(40).get_size() == Vector2(40, 40) \
		and HudChrome.glass_mask_from(null, 40) == null
	var _r06t_scaled_src: Texture2D = hud._painted_texture("slot_normal")
	var _r06t_scaled: Texture2D = HudChrome.scaled_texture_from(_r06t_scaled_src, 0.5)
	var _r06t_scaled_ok: bool = _r06t_scaled_src != null and _r06t_scaled != null \
		and _r06t_scaled.get_size() == (_r06t_scaled_src.get_size() * 0.5).round() \
		and hud._scaled_texture("slot_normal", 0.5) != null \
		and hud._scaled_texture("slot_normal", 0.5).get_size() == _r06t_scaled.get_size() \
		and HudChrome.scaled_texture_from(null, 0.5) == null
	_check("r06_texture_prep_delegates",
		_r06t_mask_ok and _r06t_scaled_ok,
		"mask=%s scaled=%s" % [str(_r06t_mask_ok), str(_r06t_scaled_ok)])

	# HUD v4: a legacy dock transform can never move/scale the anchored band.
	var _fq21_layout_before: Variant = GameState.profile.get("hud_layout", {}).duplicate(true)
	hud._bottom_dock.position += Vector2(60.0, 0.0)
	hud._bottom_dock.scale = Vector2.ONE * 1.4
	GameState.profile["hud_layout"] = {
		"version": 3,
		"dock": {"delta": [60.0, 0.0], "scale": 1.4, "visible": true},
	}
	hud._load_hud_layout()
	var _fq21_dock_rect := Rect2(hud._bottom_dock.global_position,
		hud._bottom_dock.size * hud._bottom_dock.scale)
	var _fq21_dock_invariant: bool = hud._bottom_dock.scale.is_equal_approx(Vector2.ONE) \
		and is_equal_approx(_fq21_dock_rect.position.x, 0.0) \
		and is_equal_approx(_fq21_dock_rect.end.x, get_viewport().get_visible_rect().size.x)
	GameState.profile["hud_layout"] = _fq21_layout_before
	_check("fq21_dock_layout_v5_invariant", _fq21_dock_invariant,
		"rect=%s scale=%s viewport=%s" % [_fq21_dock_rect, hud._bottom_dock.scale,
			get_viewport().get_visible_rect().size])

	# Frame-only chrome, padded map, and explicit uniform slot geometry guard
	# the masking/cushion regressions from the operator capture.
	var _fq21_plain_tex: Texture2D = hud._painted_texture("health_frame")
	var _fq21_plain_img: Image = _fq21_plain_tex.get_image() if _fq21_plain_tex != null else null
	var _fq21_frame_clear: bool = _fq21_plain_img != null and \
		_fq21_plain_img.get_pixel(int(_fq21_plain_img.get_width() / 2),
			int(_fq21_plain_img.get_height() / 2)).a <= 0.01
	var _fq21_slots: Array = _fq21_geometry.get("slots", [])
	var _fq21_slot_gap := 0.0
	if _fq21_slots.size() >= 2:
		_fq21_slot_gap = float(_fq21_slots[1][0]) - float(_fq21_slots[0][0]) \
			- float(_fq21_slots[0][2])
	var _fq21_slot_normal: Texture2D = hud._painted_texture("slot_normal")
	var _fq21_slot_selected: Texture2D = hud._painted_texture("slot_selected")
	var _fq21_slots_uniform: bool = _fq21_slot_normal != null and _fq21_slot_selected != null \
		and _fq21_slot_normal.get_size() == _fq21_slot_selected.get_size() \
		and _fq21_slot_gap >= 6.0
	var _fq21_map_padded: bool = hud._map_panel.custom_minimum_size.x >= 320.0 \
		and hud._map_panel.custom_minimum_size.y >= 168.0
	var _fq21_town_hit: Button = hud._bottom_dock.find_child(
		"DockActionTownHall", true, false) as Button
	var _fq21_full_nav_cell: bool = _fq21_town_hit != null \
		and _fq21_town_hit.size.y >= 80.0
	var _fq21_town_label: Label = _fq21_town_hit.find_child(
		"DockActionTownHallLabel", true, false) as Label if _fq21_town_hit != null else null
	var _fq21_visible_nav_label: bool = _fq21_town_label != null \
		and _fq21_town_label.text == "Town Hall"
	var _fq21_slot0: Control = hud._bottom_dock.find_child(
		"HotbarCell1", true, false) as Control
	var _fq21_slot_icon: TextureRect = _fq21_slot0.find_child(
		"RuntimeIcon", true, false) as TextureRect if _fq21_slot0 != null else null
	var _fq21_icon_rect: Rect2 = hud._json_rect(_fq21_geometry.slot_content.icon_rect)
	var _fq21_json_content: bool = int(_fq21_geometry.get("version", 0)) == 2 \
		and _fq21_slot_icon != null \
		and _fq21_slot_icon.position == _fq21_icon_rect.position \
		and _fq21_slot_icon.size == _fq21_icon_rect.size
	var _fq21_control_rail_y := float(_fq21_geometry.get("control_rail_y", -1))
	var _fq21_rail_aligned := _fq21_control_rail_y >= 0.0
	for _fq21_control_name in ["HotbarCell1", "HotbarCell2", "HotbarCell3",
			"HotbarCell4", "HotbarCell5", "DockActionInventory",
			"DockActionCharacter", "DockActionSkills", "DockActionTownHall"]:
		var _fq21_control: Control = hud._bottom_dock.find_child(
			_fq21_control_name, true, false) as Control
		if _fq21_control == null or not is_equal_approx(
				_fq21_control.position.y, _fq21_control_rail_y):
			_fq21_rail_aligned = false
			break
	var _fq21_trim_tex: Texture2D = hud._painted_texture("dock_foreground_trim")
	var _fq21_trim_img: Image = _fq21_trim_tex.get_image() if _fq21_trim_tex != null else null
	var _fq21_alpha_rules: Dictionary = _fq21_geometry.get("alpha_rules", {})
	var _fq21_trim_rule: Dictionary = _fq21_alpha_rules.get("dock_foreground_trim.png", {})
	var _fq21_trim_baseline_y := int(_fq21_trim_rule.get("alpha_baseline_y", -1))
	var _fq21_trim_used: Rect2i = _fq21_trim_img.get_used_rect() \
		if _fq21_trim_img != null else Rect2i()
	var _fq21_trim_on_upper_rail: bool = _fq21_trim_baseline_y >= 0 \
		and _fq21_trim_used.end.y == _fq21_trim_baseline_y
	var _fq21_trim_keepouts := _fq21_trim_img != null
	if _fq21_trim_img != null:
		for _fq21_vessel_name in ["health", "attunement"]:
			var _fq21_keepout: Rect2 = hud._json_rect(
				(_fq21_geometry[_fq21_vessel_name] as Dictionary).frame_rect)
			for _fq21_y in range(int(_fq21_keepout.position.y), int(_fq21_keepout.end.y)):
				for _fq21_x in range(int(_fq21_keepout.position.x), int(_fq21_keepout.end.x)):
					if _fq21_trim_img.get_pixel(_fq21_x, _fq21_y).a > 0.01:
						_fq21_trim_keepouts = false
						break
				if not _fq21_trim_keepouts:
					break
			if not _fq21_trim_keepouts:
				break
	var _fq21_native_integer: bool = _fq21_block != null \
		and _fq21_block.size == _fq21_block.texture.get_size() \
		and hud._bottom_dock.scale == Vector2.ONE
	_check("fq21_hud_masking_and_cushion_geometry",
		_fq21_frame_clear and _fq21_slots_uniform and _fq21_map_padded \
		and _fq21_full_nav_cell and _fq21_visible_nav_label \
		and _fq21_json_content and _fq21_rail_aligned \
		and _fq21_trim_on_upper_rail and _fq21_trim_keepouts \
		and _fq21_native_integer,
		"frame_clear=%s slot_size=%s selected=%s gap=%.1f map=%s nav_h=%.1f label=%s content=%s rail_y=%.1f aligned=%s trim_baseline=%d trim_end=%d trim=%s integer=%s" % [
			str(_fq21_frame_clear),
			_fq21_slot_normal.get_size() if _fq21_slot_normal != null else Vector2.ZERO,
			_fq21_slot_selected.get_size() if _fq21_slot_selected != null else Vector2.ZERO,
			_fq21_slot_gap, hud._map_panel.custom_minimum_size,
			_fq21_town_hit.size.y if _fq21_town_hit != null else 0.0,
			str(_fq21_visible_nav_label), str(_fq21_json_content),
			_fq21_control_rail_y, str(_fq21_rail_aligned),
			_fq21_trim_baseline_y, _fq21_trim_used.end.y,
			str(_fq21_trim_keepouts),
			str(_fq21_native_integer)])

	# FQ-21: vessel sockets — the future liquid mechanic's plug-in point.
	# Both sockets expose glass geometry + a Range fill, and a replacement
	# Range keeps receiving update_health values.
	var _fq21_health_socket: Dictionary = hud.vessel_socket("health")
	var _fq21_attune_socket: Dictionary = hud.vessel_socket("attunement")
	var _fq21_sockets_ok: bool = _fq21_health_socket.get("fill") is Range \
		and int(_fq21_health_socket.get("glass_diameter", 0)) > 0 \
		and _fq21_attune_socket.get("fill") is Range
	var _fq21_live_health := _fq21_health_socket.get("fill") as TextureProgressBar
	var _fq21_live_attune := _fq21_attune_socket.get("fill") as TextureProgressBar
	var _fq21_layered_vessels: bool = _fq21_live_health != null \
		and _fq21_live_health.texture_progress == hud._painted_texture("health_fill_mask") \
		and hud._bottom_dock.find_child("HealthGlass", true, false) != null \
		and _fq21_live_attune != null \
		and _fq21_live_attune.texture_under == hud._painted_texture("attunement_fill_mask") \
		and _fq21_live_attune.texture_progress == hud._painted_texture("attunement_fill_mask")
	var _fq21_stub := ProgressBar.new()
	_fq21_stub.show_percentage = false
	var _fq21_swap_ok: bool = hud.replace_vessel_fill("health", _fq21_stub)
	hud.update_health(41.0, 100.0)
	var _fq21_drive_ok: bool = is_equal_approx(_fq21_stub.value, 41.0)
	# Swap a fresh masked fill back in so later checks see the real vessel.
	var _fq21_restored := TextureProgressBar.new()
	var _fq21_mask: Texture2D = hud._painted_texture("health_fill_mask")
	_fq21_restored.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	_fq21_restored.texture_under = _fq21_mask
	_fq21_restored.tint_under = Color(0.02, 0.04, 0.08, 0.88)
	_fq21_restored.texture_progress = _fq21_mask
	_fq21_restored.tint_progress = Color(0.82, 0.12, 0.10)
	hud.replace_vessel_fill("health", _fq21_restored)
	hud.update_health(player.health, player.max_health)
	_check("fq21_vessel_socket",
		_fq21_sockets_ok and _fq21_layered_vessels \
		and _fq21_swap_ok and _fq21_drive_ok,
		"sockets=%s layered=%s swap=%s drive=%s" % [str(_fq21_sockets_ok),
			str(_fq21_layered_vessels), str(_fq21_swap_ok), str(_fq21_drive_ok)])

	# FQ-20: painted mockup chrome consumed elsewhere — painted module
	# frames on crest/events (distinct textures from the band pieces).
	var _fq20_crest_sb: StyleBox = (hud._top_left_box as PanelContainer).get_theme_stylebox("panel")
	var _fq20_events_sb: StyleBox = hud._event_panel.get_theme_stylebox("panel")
	var _fq20_map_single_frame := true
	for _fq20_map_child in hud._map_panel.get_children():
		if _fq20_map_child is NinePatchRect:
			_fq20_map_single_frame = false
			break
	var _fq22_corner: Control = hud._top_left_box.find_child(
		"CrestCornerOrnament", true, false) as Control
	var _fq22_corner_clean: bool = _fq22_corner != null \
		and _fq22_corner.position.x >= 0.0 and _fq22_corner.position.y >= 0.0 \
		and _fq22_corner.find_child("*", true, false) == null
	var _fq20_frames_ok: bool = _fq20_crest_sb is StyleBoxFlat \
		and _fq20_events_sb is StyleBoxFlat \
		and _fq20_map_single_frame \
		and _fq22_corner_clean
	_check("fq22_module_chrome_contract", _fq20_frames_ok,
		"crest=%s events=%s map_single_frame=%s corner_clean=%s" % [
			str(_fq20_crest_sb.get_class()), str(_fq20_events_sb.get_class()),
			str(_fq20_map_single_frame), str(_fq22_corner_clean)])

	# FQ-20: the dock is the command center — five module toggle chips live
	# inside the dock panel, drive the modules, and mirror external changes.
	var _fq20_module_rect: Rect2 = hud._command_center_panel.get_global_rect() \
		if hud._command_center_panel != null else Rect2()
	var _fq20_dock_rect: Rect2 = hud._bottom_dock.get_global_rect() \
		if hud._bottom_dock != null else Rect2()
	var _fq20_dock_owned: bool = hud._bottom_dock != null \
		and hud._command_center_panel != null \
		and hud._bottom_dock.is_ancestor_of(hud._command_center_panel) \
		and _fq20_dock_rect.encloses(_fq20_module_rect)
	var _fq20_module_clear := _fq20_module_rect.size.x > 0.0
	for _fq20_clear_name in ["HotbarCell1", "HotbarCell2", "HotbarCell3",
			"HotbarCell4", "HotbarCell5", "DockActionInventory",
			"DockActionCharacter", "DockActionSkills", "DockActionTownHall"]:
		var _fq20_clear_control: Control = hud._bottom_dock.find_child(
			_fq20_clear_name, true, false) as Control if hud._bottom_dock != null else null
		if _fq20_clear_control == null \
				or _fq20_module_rect.intersects(_fq20_clear_control.get_global_rect()):
			_fq20_module_clear = false
			break
	var _fq20_cc_ok: bool = hud._module_toolbar != null \
		and hud._command_center_panel != null \
		and hud._command_center_panel.is_ancestor_of(hud._module_toolbar) \
		and hud._bottom_dock.is_ancestor_of(hud._module_toolbar) \
		and _fq20_dock_owned \
		and _fq20_module_clear \
		and hud._command_toggles.size() == 5
	var _fq20_crest_chip: Button = hud._command_toggles.get("Crest")
	var _fq20_cc_before: bool = hud._top_left_box.visible
	_fq20_crest_chip.button_pressed = not _fq20_crest_chip.button_pressed
	var _fq20_cc_toggled: bool = hud._top_left_box.visible != _fq20_cc_before \
		and _fq20_crest_chip.button_pressed == hud._top_left_box.visible
	_fq20_crest_chip.button_pressed = not _fq20_crest_chip.button_pressed
	var _fq20_cc_restored: bool = hud._top_left_box.visible == _fq20_cc_before
	hud._toggle_goal_module()
	var _fq20_cc_synced: bool = (hud._command_toggles["Goal"] as Button).button_pressed \
		== hud._goal_panel.visible
	hud._toggle_goal_module()
	var _fq20_map_chip: Button = hud._command_toggles.get("Map") as Button
	hud.set_map_open(false)
	if _fq20_map_chip != null:
		_fq20_map_chip.set_pressed_no_signal(false)
		_fq20_map_chip.button_pressed = true
	var _fq20_map_chip_opens: bool = _fq20_map_chip != null \
		and hud.map_open() and _fq20_map_chip.button_pressed
	if _fq20_map_chip != null:
		_fq20_map_chip.button_pressed = false
	var _fq20_map_chip_closes: bool = _fq20_map_chip != null \
		and not hud.map_open() and not _fq20_map_chip.button_pressed
	if _fq20_map_chip != null:
		_fq20_map_chip.grab_focus()
	var _fq20_map_chip_no_focus: bool = _fq20_map_chip != null \
		and _fq20_map_chip.focus_mode == Control.FOCUS_NONE \
		and not _fq20_map_chip.has_focus()
	_check("fq20_docked_command_center",
		_fq20_cc_ok and _fq20_cc_toggled and _fq20_cc_restored and _fq20_cc_synced
		and _fq20_map_chip_opens and _fq20_map_chip_closes and _fq20_map_chip_no_focus,
		"dock_owned=%s clear=%s rect=%s toggled=%s restored=%s synced=%s map_chip=%s/%s no_focus=%s" % [
			str(_fq20_dock_owned), str(_fq20_module_clear), _fq20_module_rect,
			str(_fq20_cc_toggled), str(_fq20_cc_restored), str(_fq20_cc_synced),
			str(_fq20_map_chip_opens), str(_fq20_map_chip_closes),
			str(_fq20_map_chip_no_focus)])

	# FQ-19: resource vessels — masked liquid fill plus the damage / recovery /
	# zero / regeneration / use-pulse / full-core effect states. Overlay tints
	# are set synchronously by update_*, so each transition is observable.
	# The mask texture must be pre-sized to the control with nine-patch OFF:
	# nine-patch stretching squashes the disk instead of draining it (the
	# operator-caught "health never drops" bug).
	var _fq19v_hfill := hud._health_vessel_fill as TextureProgressBar
	var _fq19v_masked: bool = _fq19v_hfill != null \
		and hud._attunement_vessel_fill is TextureProgressBar \
		and not _fq19v_hfill.nine_patch_stretch \
		and _fq19v_hfill.texture_progress != null \
		and _fq19v_hfill.texture_progress.get_size().is_equal_approx(_fq19v_hfill.size)
	hud.update_health(80.0, 100.0)
	hud.update_health(40.0, 100.0)
	var _fq19v_damage: bool = hud._health_fx != null \
		and hud._health_fx.self_modulate.a > 0.5 \
		and hud._health_fx.self_modulate.r > hud._health_fx.self_modulate.g
	hud.update_health(60.0, 100.0)
	var _fq19v_recover: bool = hud._health_fx.self_modulate.a > 0.3 \
		and hud._health_fx.self_modulate.g > hud._health_fx.self_modulate.r
	hud.update_health(10.0, 100.0)
	var _fq19v_low: bool = hud._low_health_active
	hud.update_health(0.0, 100.0)
	var _fq19v_zero: bool = is_equal_approx(hud._health_vessel_fill.value, 0.0)
	hud.update_attunement(30.0, 50.0)
	hud.update_attunement(40.0, 50.0)
	var _fq19v_shimmer: bool = hud._attunement_fx != null \
		and hud._attunement_fx.self_modulate.a > 0.3
	hud.update_attunement(20.0, 50.0)
	var _fq19v_pulse: bool = hud._attunement_frame != null \
		and hud._attunement_frame.scale.x > 1.05
	var _fq19v_core_removed: bool = hud._attunement_core == null
	var _fq19v_constellation: bool = hud._attunement_constellation != null \
		and hud._attunement_constellation.visible
	hud.update_attunement(50.0, 50.0)
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())
	_check("fq19_vessel_liquid_and_effects",
		_fq19v_masked and _fq19v_damage and _fq19v_recover and _fq19v_low
		and _fq19v_zero and _fq19v_shimmer and _fq19v_pulse
		and _fq19v_core_removed and _fq19v_constellation,
		"masked=%s damage=%s recover=%s low=%s zero=%s shimmer=%s pulse=%s core_removed=%s constellation=%s" % [
			str(_fq19v_masked), str(_fq19v_damage), str(_fq19v_recover),
			str(_fq19v_low), str(_fq19v_zero), str(_fq19v_shimmer),
			str(_fq19v_pulse), str(_fq19v_core_removed), str(_fq19v_constellation)])

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

	# (a) equipment.json loads with the expected slots, in order.
	var _fq03_expected: Array = ["weapon", "offhand_weapon", "axe", "pickaxe", "helmet", "torso",
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
		_fq03_equip.size() == 13 and str(_fq03_equip.get("pickaxe", "")) == "pick_basic"
		and _fq03_empty_count == 12,
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

	# (d) slot/item fit is enforced; tool slots clear to tier 0 and restore
	# from item effects; equipping never touches the backpack.
	var _fq03_inv_total: int = player.inventory.total()
	var _fq03_pick_cleared: bool = player.equip_item("pickaxe", "") and player.tool_tier == 0
	var _fq03_pick_restored: bool = player.equip_item("pickaxe", "pick_forged") \
		and player.tool_tier == 2
	_check("fq03_equip_rejects_mismatch",
		not player.equip_item("helmet", "ring_band")
		and not player.equip_item("no_such_slot", "ring_band")
		and _fq03_pick_cleared
		and _fq03_pick_restored
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
	var _fq04_offhand_ok: bool = hall.forge_sword(player)
	_check("fq04_forge_sword_equips",
		_fq04_sword_ok and str(player.equipped_dict().get("weapon", "")) == "sword_crude"
		and _fq04_offhand_ok and str(player.equipped_dict().get("offhand_weapon", "")) == "sword_crude"
		and player.attack_damage() == 3
		and int(hall.stockpile.get("wood", 0)) == _fq04_wood_before - 4
		and int(hall.stockpile.get("stone", 0)) == _fq04_stone_before - 6
		and not hall.forge_sword(player),
		"attack=%d weapon=%s offhand=%s wood %d→%d stone %d→%d" % [player.attack_damage(),
			str(player.equipped_dict().get("weapon", "")),
			str(player.equipped_dict().get("offhand_weapon", "")),
			_fq04_wood_before, int(hall.stockpile.get("wood", 0)),
			_fq04_stone_before, int(hall.stockpile.get("stone", 0))])
	player.equip_item("offhand_weapon", "sword_iron")
	var _fq04_swap_to_iron: bool = player.swap_weapon()
	var _fq04_attack_iron: int = player.attack_damage()
	var _fq04_swap_back: bool = player.swap_weapon()
	_check("fq04_weapon_swap_uses_offhand",
		_fq04_swap_to_iron and _fq04_attack_iron == 5 and _fq04_swap_back
		and str(player.equipped_dict().get("weapon", "")) == "sword_crude"
		and str(player.equipped_dict().get("offhand_weapon", "")) == "sword_iron"
		and player.attack_damage() == 3,
		"active=%s offhand=%s attack_mid=%d attack_now=%d" % [
			str(player.equipped_dict().get("weapon", "")),
			str(player.equipped_dict().get("offhand_weapon", "")),
			_fq04_attack_iron, player.attack_damage()])

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
		and str(player.equipped_dict().get("offhand_weapon", "")) == "sword_iron"
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
		and "Offhand: Iron Sword" in _fq04_panel
		and "Torso: Crude Cuirass" in _fq04_panel,
		"panel_head=%s" % _fq04_panel.left(60))

	# Clear combat gear so the FQ-01 exact-damage checks below see the same
	# unarmored player they were written against.
	player.equip_item("weapon", "")
	player.equip_item("offhand_weapon", "")
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

	# (h) metal ladder: the anvil/workbench expansion forges the bronze/obsidian/
	# hellstone tiers, the ember amulet capstone, and cascades rings across slots.
	# All three stations are already built here and the weapon slot is clear.
	# ml_bronze_sword: 3 bronze_ingot -> sword_bronze (attack 4).
	player.equip_item("weapon", "")
	hall.stockpile["bronze_ingot"] = 20
	var _ml_bsword: bool = hall.craft_station("anvil_bronze_sword", player)
	_check("ml_bronze_sword",
		_ml_bsword and str(player.equipped_dict().get("weapon", "")) == "sword_bronze"
		and player.attack_damage() == 4,
		"forge=%s weapon=%s atk=%d" % [str(_ml_bsword),
			str(player.equipped_dict().get("weapon", "")), player.attack_damage()])

	# ml_bronze_armor: 5 bronze_ingot -> full bronze set (armor 2+3+2 = 7).
	player.equip_item("weapon", "")
	hall.stockpile["bronze_ingot"] = 20
	var _ml_barmor: bool = hall.craft_station("anvil_bronze_armor", player)
	_check("ml_bronze_armor",
		_ml_barmor
		and str(player.equipped_dict().get("helmet", "")) == "helmet_bronze"
		and str(player.equipped_dict().get("torso", "")) == "torso_bronze"
		and str(player.equipped_dict().get("feet", "")) == "feet_bronze"
		and int(player.armor_total()) == 7,
		"forge=%s h=%s t=%s f=%s armor=%d" % [str(_ml_barmor),
			str(player.equipped_dict().get("helmet", "")),
			str(player.equipped_dict().get("torso", "")),
			str(player.equipped_dict().get("feet", "")), int(player.armor_total())])

	# ml_obsidian_sword: obsidian + iron_ingot -> sword_obsidian (attack 7).
	player.equip_item("weapon", "")
	hall.stockpile["obsidian"] = 20
	hall.stockpile["iron_ingot"] = 20
	var _ml_osword: bool = hall.craft_station("anvil_obsidian_sword", player)
	_check("ml_obsidian_sword",
		_ml_osword and str(player.equipped_dict().get("weapon", "")) == "sword_obsidian"
		and player.attack_damage() == 7,
		"forge=%s weapon=%s atk=%d" % [str(_ml_osword),
			str(player.equipped_dict().get("weapon", "")), player.attack_damage()])

	# ml_hellstone_armor: hellstone + iron_ingot -> apex armor set (3+6+3 = 12).
	player.equip_item("helmet", "")
	player.equip_item("torso", "")
	player.equip_item("feet", "")
	hall.stockpile["hellstone"] = 20
	hall.stockpile["iron_ingot"] = 20
	var _ml_harmor: bool = hall.craft_station("anvil_hellstone_armor", player)
	_check("ml_hellstone_armor",
		_ml_harmor and int(player.armor_total()) == 12,
		"forge=%s armor=%d" % [str(_ml_harmor), int(player.armor_total())])

	# ml_ember_amulet_capstone: hellstone + obsidian + crystal -> amulet_ember at
	# the workbench (rings + amulets host there; keeps the anvil's raw-ore gate
	# strict). Its attunement_bonus (12) lifts the gear attunement total.
	player.equip_item("amulet", "")
	var _ml_att0: float = player.attunement_bonus_from_gear()
	hall.stockpile["hellstone"] = 20
	hall.stockpile["obsidian"] = 20
	hall.stockpile["crystal"] = 20
	var _ml_amulet: bool = hall.craft_station("craft_ember_amulet", player)
	_check("ml_ember_amulet_capstone",
		_ml_amulet and str(player.equipped_dict().get("amulet", "")) == "amulet_ember"
		and player.attunement_bonus_from_gear() - _ml_att0 >= 12.0,
		"forge=%s amulet=%s att %.1f->%.1f" % [str(_ml_amulet),
			str(player.equipped_dict().get("amulet", "")),
			_ml_att0, player.attunement_bonus_from_gear()])

	# ml_ring_slot_cascade: two workbench ring recipes both target ring_1, but
	# town_hall cascades an occupied ring into the next free slot (ring_1..ring_4),
	# so three crafts fill ring_1, ring_2, ring_3 with silver/crystal rings.
	player.equip_item("ring_1", "")
	player.equip_item("ring_2", "")
	player.equip_item("ring_3", "")
	player.equip_item("ring_4", "")
	hall.stockpile["silver_ingot"] = 20
	hall.stockpile["crystal"] = 20
	var _ml_r1: bool = hall.craft_station("craft_silver_ring", player)
	var _ml_r2: bool = hall.craft_station("craft_silver_ring", player)
	var _ml_r3: bool = hall.craft_station("craft_attuned_ring", player)
	var _ml_rd: Dictionary = player.equipped_dict()
	var _ml_ring_ids := ["ring_silver", "ring_crystal"]
	_check("ml_ring_slot_cascade",
		_ml_r1 and _ml_r2 and _ml_r3
		and str(_ml_rd.get("ring_1", "")) != "" and str(_ml_rd.get("ring_2", "")) != ""
		and str(_ml_rd.get("ring_3", "")) != ""
		and _ml_ring_ids.has(str(_ml_rd.get("ring_1", "")))
		and _ml_ring_ids.has(str(_ml_rd.get("ring_2", "")))
		and _ml_ring_ids.has(str(_ml_rd.get("ring_3", ""))),
		"r1=%s r2=%s r3=%s slots=[%s,%s,%s]" % [str(_ml_r1), str(_ml_r2), str(_ml_r3),
			str(_ml_rd.get("ring_1", "")), str(_ml_rd.get("ring_2", "")),
			str(_ml_rd.get("ring_3", ""))])

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
	player.equip_item("offhand_weapon", "")
	player.equip_item("helmet", "")
	player.equip_item("torso", "")
	player.equip_item("feet", "")
	player.equip_item("ring_1", "")
	player.equip_item("ring_2", "")
	player.equip_item("ring_3", "")
	player.equip_item("ring_4", "")
	player.equip_item("amulet", "")
	player.equip_item("accessory", "")
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

	# (h) plant onto soil directly: the farm action aimed at the tilled SOIL
	# plants in the open cell above it (the natural gesture, not only aiming at
	# the empty air), and a backing wall behind the bed never blocks it.
	world.cells[_fq12_soil] = "dirt"; world.deltas[_fq12_soil] = "dirt"
	world.till_soil(_fq12_soil)
	world.cells.erase(_fq12_crop); world.deltas[_fq12_crop] = "air"
	world.crop_growth.clear()
	player.global_position = world.cell_center(_fq12_soil) + Vector2(0.0, -8.0)
	player.inventory.add("crop_seeds", 1)
	var _fq12_seeds_before: int = player.inventory.count("crop_seeds")
	var _fq12_soil_plant: bool = player.try_farm(_fq12_soil)   # aim at the soil block
	_check("fq12_plant_onto_soil_aim",
		_fq12_soil_plant and world.block_at(_fq12_crop) == "crop_seedling"
		and player.inventory.count("crop_seeds") == _fq12_seeds_before - 1,
		"planted=%s above=%s seeds=%d" % [str(_fq12_soil_plant),
			world.block_at(_fq12_crop), player.inventory.count("crop_seeds")])

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

	# --- Calling system: Callings, Paths, tier gates, purchase, persistence ---
	# Drive gating with a known Calling (Wayfarer → Prospector + Trailseeker).
	var _cal_prev_role: String = str(GameState.current_character.get("role", ""))
	GameState.current_character["role"] = "wayfarer"

	# (a) perk data loads through the registry: 6 Path lanes, skills indexed to
	# their Path, and the spec tier gates (2 / 6 / 9) are present.
	var _fq06_reg = root._progression_registry
	_check("fq06_perks_json_loads",
		_fq06_reg.perk_lanes().size() == 6
		and str(_fq06_reg.get_perk("stonewise").get("lane", "")) == "prospector"
		and str(_fq06_reg.get_perk("tempered_frame").get("lane", "")) == "warden"
		and _fq06_reg.tier_gate("2") == 2 and _fq06_reg.tier_gate("3") == 6
		and _fq06_reg.tier_gate("capstone") == 9,
		"lanes=%d stonewise_lane=%s gates=%d/%d/%d" % [_fq06_reg.perk_lanes().size(),
			str(_fq06_reg.get_perk("stonewise").get("lane", "?")),
			_fq06_reg.tier_gate("2"), _fq06_reg.tier_gate("3"), _fq06_reg.tier_gate("capstone")])

	# (b) states at level 1 with nothing purchased: a Tier-I skill of the Calling's
	# Path is available; a Tier-II skill is tier-locked; a skill of another
	# Calling's Path is Calling-locked; and zero points blocks purchase.
	var _fq06_saved_level: int = root.player_level
	var _fq06_saved_perks: Array = root.purchased_perks.duplicate()
	root.purchased_perks = []
	root._apply_purchased_perk_effects()
	root.player_level = 1
	_check("fq06_states_and_zero_points",
		root.perk_points_total() == 0
		and root.perk_state("stonewise") == "available"
		and root.perk_state("clean_extraction") == "locked"
		and root.perk_state("tempered_frame") == "locked"
		and not root.try_purchase_perk("stonewise"),
		"points=%d t1=%s t2=%s cross=%s" % [root.perk_points_total(),
			root.perk_state("stonewise"), root.perk_state("clean_extraction"),
			root.perk_state("tempered_frame")])

	# (c) a real level grants points; purchasing a Path skill applies the live
	# mining-speed effect through the same join point as before.
	root.player_level = 4   # 3 points
	var _fq06_speed_before: float = player.effective_mine_speed()
	var _fq06_bought: bool = root.try_purchase_perk("stonewise")
	_check("fq06_purchase_applies_effect",
		_fq06_bought
		and root.perk_state("stonewise") == "purchased"
		and root.perk_points_available() == 2
		and absf(player.perk_mine_speed_mult - 1.15) < 0.001
		and absf(player.effective_mine_speed() - _fq06_speed_before * 1.15) < 0.001,
		"bought=%s points_left=%d mult=%.2f speed %.2f→%.2f" % [str(_fq06_bought),
			root.perk_points_available(), player.perk_mine_speed_mult,
			_fq06_speed_before, player.effective_mine_speed()])

	# (d) tier gate + Calling gate: Tier II stays locked at 1 skill in the Path,
	# opens once a 2nd Path skill is bought, while a cross-Calling skill stays locked.
	var _fq06_t2_before: String = root.perk_state("clean_extraction")
	var _fq06_bought2: bool = root.try_purchase_perk("practiced_swing")
	_check("fq06_tier_and_calling_gates",
		_fq06_t2_before == "locked"
		and _fq06_bought2
		and root.skills_purchased_in_path("prospector") == 2
		and root.perk_state("clean_extraction") == "available"
		and root.perk_state("tempered_frame") == "locked",
		"t2 before=%s after=%s in_path=%d cross=%s" % [_fq06_t2_before,
			root.perk_state("clean_extraction"),
			root.skills_purchased_in_path("prospector"),
			root.perk_state("tempered_frame")])

	# (e) purchased skills persist through the world save round-trip (stonewise +
	# practiced_swing both feed mining_speed → 1.15 * 1.10 = 1.265).
	root.save_manager.save_game()
	root.purchased_perks = []
	root._apply_purchased_perk_effects()
	root.player_level = 1
	root.load_game()
	_check("fq06_perks_persist",
		"stonewise" in root.purchased_perks
		and "practiced_swing" in root.purchased_perks
		and absf(player.perk_mine_speed_mult - 1.265) < 0.001
		and root.player_level == 4,
		"purchased=%s mult=%.3f level=%d" % [str(root.purchased_perks),
			player.perk_mine_speed_mult, root.player_level])

	# (f) the panel rebuilds for the Calling, opens, and inspects nodes with
	# tier/state rendered (purchased Tier-I skill and a tier-locked Tier-III skill).
	hud.skill_panel().setup(root)
	hud.toggle_skill_panel()
	var _fq06_open: bool = hud.skill_panel_open()
	hud.skill_panel().select_node("stonewise")
	var _fq06_info: String = hud.skill_panel().info_text()
	hud.skill_panel().select_node("tunnel_hardened")
	var _fq06_info2: String = hud.skill_panel().info_text()
	hud.toggle_skill_panel()
	# Player-language inspector only — no effect keys / support flags leak through.
	_check("fq06_panel_opens_and_inspects",
		_fq06_open and not hud.skill_panel_open()
		and "Stonewise" in _fq06_info and "Learned" in _fq06_info
		and "mined faster" in _fq06_info
		and "mining_speed" not in _fq06_info and "Support" not in _fq06_info
		and "Tunnel Hardened" in _fq06_info2 and "Locked" in _fq06_info2,
		"info=%s" % _fq06_info.left(90))

	# (g) the panel shows exactly the Calling's two Paths (2 × 12 = 24 nodes) and
	# no skills belonging to another Calling.
	_check("fq06_panel_shows_only_calling_paths",
		hud.skill_panel().node_count() == 24
		and hud.skill_panel().has_skill_node("stonewise")
		and hud.skill_panel().has_skill_node("familiar_ground")
		and not hud.skill_panel().has_skill_node("tempered_frame"),
		"nodes=%d" % hud.skill_panel().node_count())

	# --- Calling system Stage 2: wired-effect behavior ---
	# Clear any lingering test threats so threat-state context is deterministic.
	for _cs_t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_cs_t):
			_cs_t.queue_free()
	await get_tree().process_frame

	# (i) static skill effects reach the player: Tempered Frame (+20 max health,
	# idempotent delta), Armored Bearing (armor x1.15), Deep Reservoir (+15 attun).
	root.purchased_perks = []
	root._apply_purchased_perk_effects()
	var _cs_hp0: float = player.max_health
	var _cs_att0: float = player.perk_attunement_bonus
	root.purchased_perks = ["tempered_frame", "armored_bearing", "deep_reservoir"]
	root._apply_purchased_perk_effects()
	root._apply_purchased_perk_effects()   # twice: proves the health delta is idempotent
	_check("calling_static_effects_apply",
		absf(player.perk_max_health_bonus - 20.0) < 0.01
		and absf(player.max_health - (_cs_hp0 + 20.0)) < 0.01
		and absf(player.perk_armor_mult - 1.15) < 0.001
		and absf(player.perk_attunement_bonus - 15.0) < 0.01,
		"hp %.0f->%.0f armor_mult=%.2f attun_bonus=%.0f" % [_cs_hp0, player.max_health,
			player.perk_armor_mult, player.perk_attunement_bonus])

	# (j) take_damage source scoping: Oathbound Resolve reduces ENEMY damage only
	# (0.9 with no active threat); hazard/generic are unaffected without a skill;
	# a non-Oathbound Calling gets no Resolve reduction.
	root.purchased_perks = []
	var _dm_prev_role: String = str(GameState.current_character.get("role", ""))
	GameState.current_character["role"] = "oathbound"
	var _dm_enemy: float = root.calling_incoming_damage_mult("enemy")
	var _dm_hazard: float = root.calling_incoming_damage_mult("hazard")
	var _dm_generic: float = root.calling_incoming_damage_mult("generic")
	GameState.current_character["role"] = "wayfarer"
	var _dm_way_enemy: float = root.calling_incoming_damage_mult("enemy")
	GameState.current_character["role"] = _dm_prev_role
	_check("calling_damage_source_scoping",
		absf(_dm_enemy - 0.9) < 0.001 and absf(_dm_hazard - 1.0) < 0.001
		and absf(_dm_generic - 1.0) < 0.001 and absf(_dm_way_enemy - 1.0) < 0.001,
		"enemy=%.2f hazard=%.2f generic=%.2f wayfarer_enemy=%.2f" % [
			_dm_enemy, _dm_hazard, _dm_generic, _dm_way_enemy])

	# (k) Vanguard on-defeat restores: Relentless (+6 heal per XP kill) and
	# Victory's Breath (+25 health & Attunement on threat end) resolve from the
	# purchased set, and player.heal clamps correctly.
	root.purchased_perks = ["relentless", "victorys_breath"]
	player.health = 10.0
	player.heal(7.0)
	_check("calling_defeat_rewards_and_heal",
		absf(root._purchased_skill_additive("heal_on_xp_kill") - 6.0) < 0.01
		and absf(root._purchased_skill_additive("threat_end_restore") - 25.0) < 0.01
		and absf(player.health - 17.0) < 0.01,
		"heal_kill=%.0f threat_end=%.0f health=%.0f" % [
			root._purchased_skill_additive("heal_on_xp_kill"),
			root._purchased_skill_additive("threat_end_restore"), player.health])
	player.health = player.max_health

	# (l) Legacy roles map to the closest Calling (semantic migration), and any
	# unknown value falls back to the default Calling — read-time, non-destructive.
	_check("calling_legacy_role_migration",
		BlockRegistry.calling_of("warden") == "oathbound"
		and BlockRegistry.calling_of("prospector") == "wayfarer"
		and BlockRegistry.calling_of("homesteader") == "runewright"
		and BlockRegistry.calling_of("nonsense_role") == BlockRegistry.default_calling()
		and BlockRegistry.calling_of("oathbound") == "oathbound",
		"warden=%s prospector=%s homesteader=%s unknown=%s" % [
			BlockRegistry.calling_of("warden"), BlockRegistry.calling_of("prospector"),
			BlockRegistry.calling_of("homesteader"), BlockRegistry.calling_of("nonsense_role")])

	# (m) Real damage path: Oathbound Resolve actually reduces ENEMY damage through
	# take_damage (vs. a generic hit of the same size), while hazard/generic are
	# unreduced by Resolve. Uses the live take_damage, resetting the hurt cooldown.
	GameState.current_character["role"] = "oathbound"
	root.purchased_perks = []
	root._apply_purchased_perk_effects()
	player._hurt_cooldown = 0.0
	player.health = 100.0
	player.take_damage(20.0, "enemy")
	var _cd_enemy_loss: float = 100.0 - player.health
	player._hurt_cooldown = 0.0
	player.health = 100.0
	player.take_damage(20.0, "generic")
	var _cd_generic_loss: float = 100.0 - player.health
	GameState.current_character["role"] = _dm_prev_role
	_check("calling_take_damage_reduces_enemy",
		_cd_enemy_loss < _cd_generic_loss - 0.5 and _cd_generic_loss >= 19.0,
		"enemy_loss=%.1f generic_loss=%.1f" % [_cd_enemy_loss, _cd_generic_loss])

	# (n) Contextual reveal: Deep Surveying widens the scout radius only underground;
	# Broad Horizon only on the surface. Each is inert in the other context.
	var _rv_prev_role2: String = str(GameState.current_character.get("role", ""))
	GameState.current_character["role"] = "wayfarer"
	root.purchased_perks = ["deep_surveying", "broad_horizon"]
	var _rv_sx: int = world.width / 2
	var _rv_prev_pos: Vector2 = player.global_position
	player.global_position = world.cell_center(Vector2i(_rv_sx, world.sky_line(_rv_sx) - 3))
	var _rv_surface: int = root._scout_reveal_radius()   # Broad Horizon applies (+1)
	player.global_position = world.cell_center(Vector2i(_rv_sx, world.sky_line(_rv_sx) + 12))
	var _rv_underground: int = root._scout_reveal_radius()   # Deep Surveying applies (+1)
	player.global_position = _rv_prev_pos
	GameState.current_character["role"] = _rv_prev_role2
	root.purchased_perks = []
	root._apply_purchased_perk_effects()
	# Wayfarer Trailcraft innate adds +1 everywhere, so surface = 1 base +1 innate
	# +1 Broad Horizon = 3; underground = 1 +1 innate +1 Deep Surveying = 3; and each
	# reveal skill is inert in the wrong context (proven by the equality holding only
	# because exactly one context skill fires in each place).
	_check("calling_reveal_context_scoped",
		_rv_surface == 3 and _rv_underground == 3,
		"surface=%d underground=%d" % [_rv_surface, _rv_underground])
	player.health = player.max_health

	# (o) Ownership split: the CHARACTER carries personal level; the WORLD owns
	# base (settlement) level. Entering a fresh world must NOT import base level,
	# and a world's base level must NOT overwrite the character's player level.
	var _sp_prev_role: String = str(GameState.current_character.get("role", ""))
	var _sp_prev_prog: Dictionary = GameState.current_character.get("progression", {}).duplicate(true)
	GameState.current_character["role"] = "oathbound"
	GameState.current_character["progression"] = {
		"player_level": 5, "xp_totals": {}, "purchased_perks": [], "depth_hwm": 0}
	root.apply_world_progression({})   # fresh world: settlement starts at level 1
	root.apply_character_progression(GameState.current_character["progression"])
	var _sp_fresh_base: int = root.base_level
	var _sp_fresh_lvl: int = root.player_level
	root.apply_world_progression({"base_level": 3, "base_xp": 0})   # a Village-tier world
	var _sp_villagelvl: int = root.player_level   # must be unchanged by the world
	GameState.current_character["role"] = _sp_prev_role
	GameState.current_character["progression"] = _sp_prev_prog
	_check("calling_progression_ownership_split",
		_sp_fresh_base == 1 and _sp_fresh_lvl == 5 and root.base_level == 3 and _sp_villagelvl == 5,
		"fresh_base=%d fresh_lvl=%d world_base=%d lvl_after_world=%d" % [
			_sp_fresh_base, _sp_fresh_lvl, root.base_level, _sp_villagelvl])

	# (o2) Legacy migration is guarded by character_id: a legacy world (combined
	# progression) last played by "charA" must NOT hand its level to a different
	# character with empty progression — only the SAME character adopts it, and a
	# character with its own progression always keeps it. (World base level, which
	# is applied separately, is unaffected either way.)
	var _mig_state := {"character_id": "charA",
		"progression": {"player_level": 7, "base_level": 2, "xp_totals": {}, "purchased_perks": []}}
	var _mig_same: Dictionary = root.save_manager.character_progression_source(_mig_state, {}, "charA")
	var _mig_diff: Dictionary = root.save_manager.character_progression_source(_mig_state, {}, "charB")
	var _mig_own: Dictionary = root.save_manager.character_progression_source(
		_mig_state, {"player_level": 3}, "charB")
	_check("calling_legacy_migration_guarded_by_character_id",
		int(_mig_same.get("player_level", 0)) == 7
		and _mig_diff.is_empty()
		and int(_mig_own.get("player_level", 0)) == 3,
		"same_lvl=%d diff_empty=%s own_lvl=%d" % [int(_mig_same.get("player_level", 0)),
			str(_mig_diff.is_empty()), int(_mig_own.get("player_level", 0))])

	# (p) Yield perks never fire on placeable blocks (no place-and-break dupe), and
	# only unambiguously natural resources qualify.
	root.purchased_perks = ["stone_economy", "clean_extraction", "woodwise", "foragers_share"]
	var _yd_before: int = get_tree().get_nodes_in_group("item_drops").size()
	player._apply_calling_harvest_bonuses(Vector2i(0, 0), "stone", {"stone": 1})   # placed/craftable
	player._apply_calling_harvest_bonuses(Vector2i(0, 0), "dirt", {"dirt": 1})     # constructed
	player._apply_calling_harvest_bonuses(Vector2i(0, 0), "torch", {"torch": 1})   # constructed
	var _yd_after: int = get_tree().get_nodes_in_group("item_drops").size()
	_check("calling_yield_excludes_placeable_blocks",
		_yd_after == _yd_before
		and BlockRegistry.is_placeable("stone") and BlockRegistry.is_placeable("dirt")
		and not BlockRegistry.is_placeable("deepstone")
		and root.calling_extra_drop_chance("ore") > 0.0,
		"drops %d->%d stone_place=%s deepstone_place=%s" % [_yd_before, _yd_after,
			str(BlockRegistry.is_placeable("stone")), str(BlockRegistry.is_placeable("deepstone"))])

	# (q) Seedkeeper raises the actual leaf seed-return roll inside break_block: a
	# large multiplier guarantees a seed from an isolated tree_leaves cell.
	var _sk_cell := Vector2i(4, 4)
	world.cells[_sk_cell] = "tree_leaves"
	world._set_tile(_sk_cell, "tree_leaves")
	var _sk_drops: Dictionary = world.break_block(_sk_cell, 1000.0)
	_check("calling_seedkeeper_boosts_leaf_seed_roll",
		int(_sk_drops.get("tree_seed", 0)) >= 1,
		"leaf drops=%s" % str(_sk_drops))

	# (r) Threat-scoped weapon damage is per-TARGET: only an enemy in the assault
	# zone gets the bonus, not every enemy because one is near town.
	for _tg in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_tg):
			_tg.queue_free()
	await get_tree().process_frame
	GameState.current_character["role"] = "oathbound"
	root.purchased_perks = ["threat_hunter"]
	var _tg_in = root.spawn_enemy_for_test("surface_slime")
	_tg_in.global_position = root.town_hall.global_position + Vector2(16, 0)
	var _tg_out = root.spawn_enemy_for_test("surface_slime")
	_tg_out.global_position = root.town_hall.global_position + Vector2(6000, 0)
	var _tg_din: float = root.calling_weapon_damage_mult(_tg_in)
	var _tg_dout: float = root.calling_weapon_damage_mult(_tg_out)
	_check("calling_threat_damage_is_per_target",
		_tg_din > _tg_dout + 0.05 and absf(_tg_dout - 1.0) < 0.001,
		"in=%.2f out=%.2f" % [_tg_din, _tg_dout])

	# (s) Victory's Breath fires from an ACTUAL defeat that ends the assault: kill
	# the last assault enemy and the deferred refresh restores health + Attunement.
	root.purchased_perks = ["victorys_breath"]
	if is_instance_valid(_tg_out):
		_tg_out.queue_free()   # remove the far one so only the in-zone enemy remains
	await get_tree().process_frame
	player.health = 40.0
	player.attunement = 5.0
	var _vb_hp0: float = player.health
	var _vb_at0: float = player.attunement
	if is_instance_valid(_tg_in):
		_tg_in.take_hit(999999)   # defeat the last assault enemy → _on_threat_died
	for _vbf in range(4):
		await get_tree().process_frame
	_check("calling_victorys_breath_on_assault_end",
		player.health > _vb_hp0 + 1.0 and player.attunement > _vb_at0 + 1.0,
		"hp %.0f->%.0f attn %.0f->%.0f" % [_vb_hp0, player.health, _vb_at0, player.attunement])

	# (t) Resolver channels reflect purchased skills at their sites: movement
	# (outside settlement), pulse cost, build-vs-mining reach, repair output, and
	# equipment amplification.
	GameState.current_character["role"] = "wayfarer"
	root.purchased_perks = ["farwalker", "deep_reserves"]
	var _ch_prev_pos: Vector2 = player.global_position
	player.global_position = root.town_hall.global_position + Vector2(6000, 0)   # outside settlement
	var _ch_move: float = root.calling_move_speed_mult()
	player.global_position = _ch_prev_pos
	GameState.current_character["role"] = "runewright"
	root.purchased_perks = ["far_echo", "efficient_resonance", "inscribed_conduit",
		"long_measure", "practiced_repairs"]
	var _ch_reach_build: float = root.calling_reach_bonus("build")
	var _ch_reach_mine: float = root.calling_reach_bonus("mining")
	var _ch_equip_amp: float = root.calling_equip_attunement_amp()
	var _ch_repair: float = root.calling_repair_mult()
	GameState.current_character["role"] = "wayfarer"
	root.purchased_perks = ["far_echo", "efficient_resonance"]
	var _ch_pulse_r: float = root.calling_pulse_radius_mult()
	GameState.current_character["role"] = _sp_prev_role
	root.purchased_perks = []
	root._apply_purchased_perk_effects()
	_check("calling_resolver_channels_reflect_skills",
		_ch_move > 1.0 and _ch_reach_build >= 1.0 and _ch_reach_mine == 0.0
		and _ch_equip_amp > 1.0 and _ch_repair > 1.0 and _ch_pulse_r > 1.0,
		"move=%.2f reachB=%.0f reachM=%.0f equip=%.2f repair=%.2f pulseR=%.2f" % [
			_ch_move, _ch_reach_build, _ch_reach_mine, _ch_equip_amp, _ch_repair, _ch_pulse_r])
	player.health = player.max_health

	# (h) PR-08: the skill panel is viewport-relative -- it fits cleanly (with a
	# margin) at both 640x360 and 1280x720, is roomier than the old fixed 540x420
	# at 1280x720, and adapts to the live viewport rather than a fixed size.
	var _pr08_panel = hud.skill_panel()
	var _pr08_s360: Vector2 = _pr08_panel.panel_size_for(Vector2(640, 360))
	var _pr08_s720: Vector2 = _pr08_panel.panel_size_for(Vector2(1280, 720))
	var _pr08_fits_360: bool = _pr08_s360.x <= 640.0 - 8.0 and _pr08_s360.y <= 360.0 - 8.0 \
		and _pr08_s360.x > 0.0 and _pr08_s360.y > 0.0
	var _pr08_fits_720: bool = _pr08_s720.x <= 1280.0 and _pr08_s720.y <= 720.0
	# roomier than the old fixed 540x420 at 1280x720, and it grows with the view.
	var _pr08_roomier: bool = _pr08_s720.x > 540.0 and _pr08_s720.y > 420.0 \
		and _pr08_s720.x > _pr08_s360.x
	# the live panel actually adopts the computed size for the current viewport.
	var _pr08_vp: Vector2 = _pr08_panel.get_viewport_rect().size
	var _pr08_live_ok: bool = _pr08_panel.panel_size().is_equal_approx(
		_pr08_panel.panel_size_for(_pr08_vp))
	_check("pr08_skill_panel_viewport_relative",
		_pr08_fits_360 and _pr08_fits_720 and _pr08_roomier and _pr08_live_ok,
		"s360=%s s720=%s live=%s vp=%s" % [str(_pr08_s360), str(_pr08_s720),
			str(_pr08_live_ok), str(_pr08_vp)])

	# --- R-01: export-safe runtime resources ---
	# Every authored art category and every music stream must load through the
	# runtime loaders (BlockRegistry / MusicManifest), which are now import-aware
	# (ResourceLoader) so they resolve from a packed/exported build, not just a
	# plain editor run. These go through the REAL runtime loaders (not direct
	# ResourceLoader), so the packed --main-pack smoke exercises the same path.
	BlockRegistry.clear_visual_cache()
	var _r01_vis := {
		"body": BlockRegistry.visual_texture("players", "human"),
		"gear": BlockRegistry.visual_texture("player_gear", "helmet_crude_human"),
		"block": BlockRegistry.visual_texture("blocks", "dirt"),
		"item": BlockRegistry.visual_texture("items", "antlers"),
		"ui": BlockRegistry.visual_texture("ui", "button_character"),
		"hud_painted": BlockRegistry.visual_texture("ui_painted", "attunement_frame"),
		"backdrop": BlockRegistry.visual_texture("backgrounds", "surface_sky"),
	}
	var _r01_missing: Array[String] = []
	for _r01_k in _r01_vis:
		if _r01_vis[_r01_k] == null:
			_r01_missing.append(str(_r01_k))
	# prologue cels resolve through the variant-pool convention loader
	var _r01_prologue: Array = BlockRegistry.visual_variant_textures(
		"opening", "opening_01_first_star")
	# recoloring still works: the import must decompress to a manipulable image
	# (a VRAM-compressed import would make get_image()/get_pixel unusable).
	var _r01_body: Texture2D = _r01_vis["body"]
	var _r01_recolor_ok := false
	if _r01_body != null:
		var _r01_img := _r01_body.get_image()
		# a non-empty image proves the import decompresses to a usable form for
		# get_pixel-based recoloring; player_visual_appearance_palette_applies
		# exercises the actual recolor.
		_r01_recolor_ok = _r01_img != null and not _r01_img.is_empty()
	_check("r01_export_safe_visual_resources",
		_r01_missing.is_empty() and _r01_prologue.size() > 0 and _r01_recolor_ok,
		"missing=%s prologue_cels=%d recolor_ok=%s" % [str(_r01_missing),
			_r01_prologue.size(), str(_r01_recolor_ok)])

	# Audio: all 4 context loops, 6 stems, 5 stingers load import-aware, the grid
	# is stamped, and the streams are DUPLICATES so the shared cached import
	# resource is never mutated.
	var _r01_manifest: Dictionary = MusicManifest.load_manifest()
	var _r01_ctx: Dictionary = MusicManifest.load_context_streams(_r01_manifest)
	var _r01_stems: Dictionary = MusicManifest.load_stem_streams(_r01_manifest)
	var _r01_stingers: Dictionary = MusicManifest.load_stinger_streams(_r01_manifest)
	var _r01_ctx_stream: AudioStream = _r01_ctx.get("surface_day")
	var _r01_grid_ok: bool = _r01_ctx_stream != null and _r01_ctx_stream.loop \
		and _r01_ctx_stream.bpm > 0.0
	# the shared cached import resource keeps its import default (loop=false),
	# proving load_context_streams duplicated before stamping.
	var _r01_shared = ResourceLoader.load(
		"res://audio/music/rendered/contexts/coheronia_surface_day.ogg", "AudioStream")
	var _r01_no_mutate: bool = _r01_shared != null and not _r01_shared.loop
	_check("r01_export_safe_audio_resources",
		_r01_ctx.size() == 4 and _r01_stems.size() == 6 and _r01_stingers.size() == 5
		and _r01_grid_ok and _r01_no_mutate,
		"contexts=%d stems=%d stingers=%d grid=%s cache_unmutated=%s" % [
			_r01_ctx.size(), _r01_stems.size(), _r01_stingers.size(),
			str(_r01_grid_ok), str(_r01_no_mutate)])

	# --- R-02: save integrity — atomic write / validate / .bak / quarantine ---
	# The write+recover mechanism (shared by shell and world saves) is exercised
	# on an isolated scratch path so the primitive is proven without touching the
	# real profile.
	var _r02_p := "user://r02_scratch.json"
	for _r02_sfx in ["", ".bak", ".corrupt", ".tmp"]:
		if FileAccess.file_exists(_r02_p + _r02_sfx):
			DirAccess.remove_absolute(_r02_p + _r02_sfx)
	# atomic write v1, then v2 -> the prior good file is preserved as .bak.
	var _r02_w1: bool = GameState._atomic_write_json(_r02_p, {"v": 1})
	var _r02_w2: bool = GameState._atomic_write_json(_r02_p, {"v": 2})
	var _r02_live = GameState._json_object_or_null(_r02_p)
	var _r02_bak = GameState._json_object_or_null(_r02_p + ".bak")
	var _r02_backup_ok: bool = _r02_w1 and _r02_w2 \
		and _r02_live is Dictionary and int(_r02_live.get("v", -1)) == 2 \
		and _r02_bak is Dictionary and int(_r02_bak.get("v", -1)) == 1
	# corrupt the live file -> recover reads v1 from .bak and quarantines primary.
	var _r02_cf := FileAccess.open(_r02_p, FileAccess.WRITE)
	if _r02_cf != null:
		_r02_cf.store_string("{ not valid json ,,,")
		_r02_cf.close()
	var _r02_rec: Dictionary = GameState._load_json_recover(_r02_p)
	var _r02_recover_ok: bool = str(_r02_rec.get("status")) == "recovered" \
		and int((_r02_rec.get("data") as Dictionary).get("v", -1)) == 1 \
		and FileAccess.file_exists(_r02_p + ".corrupt")
	# corrupt again with NO backup -> quarantined + empty + surfaced, never silent.
	for _r02_sfx3 in [".bak", ".corrupt"]:
		if FileAccess.file_exists(_r02_p + _r02_sfx3):
			DirAccess.remove_absolute(_r02_p + _r02_sfx3)
	var _r02_cf2 := FileAccess.open(_r02_p, FileAccess.WRITE)
	if _r02_cf2 != null:
		_r02_cf2.store_string("still not json")
		_r02_cf2.close()
	var _r02_rec2: Dictionary = GameState._load_json_recover(_r02_p)
	var _r02_quarantine_ok: bool = str(_r02_rec2.get("status")) == "quarantined" \
		and (_r02_rec2.get("data") as Dictionary).is_empty() \
		and FileAccess.file_exists(_r02_p + ".corrupt")
	# a write whose temp cannot be created fails cleanly (false) and leaves no live
	# file -- this is what makes create_world observable.
	var _r02_write_fail: bool = not GameState._atomic_write_json(
		"user://r02_missing_dir/deep/x.json", {"v": 0})
	for _r02_sfx4 in ["", ".bak", ".corrupt", ".tmp"]:
		if FileAccess.file_exists(_r02_p + _r02_sfx4):
			DirAccess.remove_absolute(_r02_p + _r02_sfx4)
	_check("r02_atomic_write_backup_recover_quarantine",
		_r02_backup_ok and _r02_recover_ok and _r02_quarantine_ok and _r02_write_fail,
		"backup=%s recover=%s quarantine=%s write_fail=%s" % [str(_r02_backup_ok),
			str(_r02_recover_ok), str(_r02_quarantine_ok), str(_r02_write_fail)])

	# --- R-02: shell + world integration (recovery surfaced, schema, creation) ---
	# A corrupt profile must never read as a fresh empty one; a future schema is
	# surfaced without destroying data; failed world creation is observable.
	var _r02_saved_profile: Dictionary = GameState.profile.duplicate(true)
	var _r02_saved_chars: Array = GameState.characters.duplicate(true)
	# healthy shell + a good .bak (two saves), then truncate the live file.
	GameState.save_shell()
	GameState.save_shell()
	var _r02_scf := FileAccess.open(GameState.shell_path(), FileAccess.WRITE)
	if _r02_scf != null:
		_r02_scf.store_string("{ truncated shell")
		_r02_scf.close()
	GameState.load_shell()
	var _r02_shell_recovered: bool = GameState.shell_load_status == "recovered" \
		and GameState.characters.size() == _r02_saved_chars.size() \
		and FileAccess.file_exists(GameState.shell_path() + ".corrupt")
	# unsupported (future) schema is surfaced, data preserved (never destroyed).
	GameState._atomic_write_json(GameState.shell_path(), {
		"shell_version": "99.0", "profile": _r02_saved_profile,
		"characters": _r02_saved_chars})
	GameState.load_shell()
	var _r02_schema_surfaced: bool = GameState.shell_load_status == "unsupported_schema" \
		and GameState.characters.size() == _r02_saved_chars.size()
	# world file: create (observable success), give it a good .bak, corrupt it,
	# then recover from the backup with a surfaced status.
	var _r02_wid: String = GameState.create_world(WorldConfig.from_preset("folk_kingdom"))
	var _r02_create_ok: bool = _r02_wid != ""
	if _r02_create_ok:
		GameState._atomic_write_json(GameState.world_path(_r02_wid),
			GameState.load_world_file(_r02_wid))
		var _r02_wcf := FileAccess.open(GameState.world_path(_r02_wid), FileAccess.WRITE)
		if _r02_wcf != null:
			_r02_wcf.store_string("{ truncated world")
			_r02_wcf.close()
	var _r02_wdata: Dictionary = GameState.load_world_file(_r02_wid) if _r02_create_ok else {}
	var _r02_world_recovered: bool = _r02_create_ok \
		and GameState.world_load_status == "recovered" and not _r02_wdata.is_empty()
	if _r02_create_ok:
		GameState.delete_world(_r02_wid)
		for _r02_wsfx in [".bak", ".corrupt", ".tmp"]:
			if FileAccess.file_exists(GameState.world_path(_r02_wid) + _r02_wsfx):
				DirAccess.remove_absolute(GameState.world_path(_r02_wid) + _r02_wsfx)
	# restore the real shell state + a clean healthy shell.json (status -> ok).
	GameState.profile = _r02_saved_profile
	GameState.characters = _r02_saved_chars
	GameState.save_shell()
	GameState.load_shell()
	for _r02_ssfx in [".bak", ".corrupt", ".tmp"]:
		if FileAccess.file_exists(GameState.shell_path() + _r02_ssfx):
			DirAccess.remove_absolute(GameState.shell_path() + _r02_ssfx)
	_check("r02_shell_world_integrity",
		_r02_shell_recovered and _r02_schema_surfaced and _r02_create_ok
		and _r02_world_recovered,
		"shell_recovered=%s schema=%s create=%s world_recovered=%s" % [
			str(_r02_shell_recovered), str(_r02_schema_surfaced),
			str(_r02_create_ok), str(_r02_world_recovered)])

	# --- R-03: isolated verification (injected persistence root + split reporting) ---
	# This run must be isolated from the real profile: the persistence root is the
	# dedicated smoke root, not "user://", so nothing here can read or write the
	# player's shell/worlds. The root is re-pointable, and results split by suite.
	var _r03_root: String = GameState.persistence_root
	var _r03_isolated: bool = _r03_root != GameState.DEFAULT_PERSISTENCE_ROOT \
		and GameState.shell_path().begins_with(_r03_root) \
		and GameState.shell_path() != "user://shell.json"
	# set_persistence_root re-points shell + worlds cleanly, then restore.
	var _r03_probe := "user://r03_probe_root/"
	GameState.set_persistence_root(_r03_probe)
	var _r03_reroute: bool = GameState.shell_path() == _r03_probe.path_join("shell.json") \
		and GameState.worlds_dir() == _r03_probe.path_join("worlds")
	GameState.set_persistence_root(_r03_root)
	if DirAccess.dir_exists_absolute(_r03_probe):
		DirAccess.remove_absolute(_r03_probe.path_join("worlds"))
		DirAccess.remove_absolute(_r03_probe)
	# split reporting: names categorize into the expected suites and timing is live.
	var _r03_reporting: bool = _suite_for("shell_persists_characters") == "shell" \
		and _suite_for("r02_atomic_write_backup_recover_quarantine") == "save" \
		and _suite_for("fq09u1_live_clip_switch") == "audio" \
		and _suite_for("pr06_character_panel_runtime_render") == "ui" \
		and _suite_for("player_visual_all_ten_bodies_resolve") == "presentation" \
		and _suite_for("fq06_perks_persist") == "progression" \
		and _start_ms > 0 and _suites.size() >= 5
	_check("r03_isolated_verification",
		_r03_isolated and _r03_reroute and _r03_reporting,
		"root=%s isolated=%s reroute=%s reporting=%s suites=%s" % [_r03_root,
			str(_r03_isolated), str(_r03_reroute), str(_r03_reporting),
			str(_suites.keys())])

	# Restore progression + Calling so later sections see the pre-FQ-06 world.
	GameState.current_character["role"] = _cal_prev_role
	root.purchased_perks = _fq06_saved_perks.duplicate()
	root._apply_purchased_perk_effects()
	root.player_level = _fq06_saved_level
	hud.skill_panel().setup(root)
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
	_check_res_fixture("fq07_block_renders_from_image",
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
	_check_res_fixture("fq07_item_renders_from_image",
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
	var _pv_canonical_ok := true
	# PR-01: each body is exercised with both its canonical id and its legacy
	# alias; both must resolve to the same existing PNG filename (masculine ->
	# <species>, feminine -> <species>_female) and store the canonical id.
	for _pv_species in ["human", "dwarf", "elf", "goblin", "orc"]:
		for _pv_case in [["masculine", "", "masculine"], ["feminine", "_female", "feminine"],
				["default", "", "masculine"], ["female", "_female", "feminine"]]:
			player.apply_character({
				"species": _pv_species,
				"body_variant": str(_pv_case[0]),
				"appearance": "tan",
				"traits": [],
				"role": "homesteader",
			})
			var _pv_expected: String = "%s%s" % [_pv_species, str(_pv_case[1])]
			var _pv_snapshot: Dictionary = _pv.presentation_snapshot()
			_pv_resolved[str(_pv_snapshot.get("resolved_body_id", ""))] = true
			_pv_all_art = _pv_all_art \
				and bool(_pv_snapshot.get("using_body_art", false)) \
				and str(_pv_snapshot.get("resolved_body_id", "")) == _pv_expected
			_pv_canonical_ok = _pv_canonical_ok \
				and str(_pv_snapshot.get("body_variant", "")) == str(_pv_case[2])
	_check("player_visual_all_ten_bodies_resolve",
		_pv_all_art and _pv_canonical_ok and _pv_resolved.size() == 10,
		"resolved=%s canonical=%s" % [str(_pv_resolved.keys()), str(_pv_canonical_ok)])
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan"})
	var _pv_tan_recolored: bool = _pv.appearance_recolored()
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "pale"})
	var _pv_pale_recolored: bool = _pv.appearance_recolored()
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "umber"})
	var _pv_umber_recolored: bool = _pv.appearance_recolored()
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "ash"})
	var _pv_ash_recolored: bool = _pv.appearance_recolored()
	# Appearance is an exact-palette bridge, so exercise every authored Look,
	# not only the canonical human body. Generated near-match skin colors can
	# otherwise make alternate looks silently ignore Pale/Umber/Ash.
	var _pv_variant_palette_failures: Array[String] = []
	for _pv_species in ["human", "dwarf", "elf", "goblin", "orc"]:
		for _pv_body_variant in ["masculine", "feminine"]:
			for _pv_look in [1, 2]:
				player.apply_character({
					"species": _pv_species,
					"body_variant": _pv_body_variant,
					"visual_variant": _pv_look,
					"appearance": "pale",
				})
				if not _pv.appearance_recolored():
					_pv_variant_palette_failures.append(
						"%s/%s/look%d" % [
							_pv_species, _pv_body_variant, _pv_look])
	_check("player_visual_appearance_palette_applies",
		not _pv_tan_recolored and _pv_pale_recolored
		and _pv_umber_recolored and _pv_ash_recolored
		and _pv_variant_palette_failures.is_empty(),
		"tan=%s pale=%s umber=%s ash=%s variant_failures=%s" % [
			str(_pv_tan_recolored), str(_pv_pale_recolored),
			str(_pv_umber_recolored), str(_pv_ash_recolored),
			str(_pv_variant_palette_failures)])

	# Force the feminine dwarf miss (its <species>_female art), then both dwarf
	# misses. Resolution may step down only within dwarf; it must never
	# substitute human art.
	var _pv_player_entries: Dictionary = BlockRegistry.visual_assets["categories"]["players"]
	var _pv_had_dwarf_female := _pv_player_entries.has("dwarf_female")
	var _pv_old_dwarf_female: Variant = _pv_player_entries.get("dwarf_female")
	var _pv_had_dwarf := _pv_player_entries.has("dwarf")
	var _pv_old_dwarf: Variant = _pv_player_entries.get("dwarf")
	BlockRegistry.visual_assets["categories"]["players"]["dwarf_female"] = \
		"art/generated/players/smoke_tmp_missing_dwarf_female.png"
	BlockRegistry.clear_visual_cache()
	player.apply_character({"species": "dwarf", "body_variant": "feminine"})
	var _pv_same_species: String = _pv.resolved_body_id()
	BlockRegistry.visual_assets["categories"]["players"]["dwarf"] = \
		"art/generated/players/smoke_tmp_missing_dwarf.png"
	BlockRegistry.clear_visual_cache()
	player.apply_character({"species": "dwarf", "body_variant": "feminine"})
	var _pv_dwarf_procedural: Dictionary = _pv.presentation_snapshot()
	player.apply_character({"species": "smoke_unknown", "body_variant": "feminine"})
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

	# --- PR-02: character rendering contract surface ---
	# presentation_snapshot() is the documented surface every consumer reads;
	# pin its key set, the compositing order, and that visible_gear exposes only
	# the drawn slots (the crude gear from the block above is still equipped).
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan"})
	var _pr02_snap: Dictionary = _pv.presentation_snapshot()
	var _pr02_has_all_keys := true
	for _pr02_key in ["species", "body_variant", "visual_variant",
			"requested_body_id", "resolved_body_id", "using_body_art",
			"appearance_recolored", "facing_sign", "swing_phase", "active_tool_id",
			"visible_gear", "effective_body_id", "action_kind", "action_item",
			"swing_phase_kind", "swing_direction", "layer_order"]:
		if not _pr02_snap.has(_pr02_key):
			_pr02_has_all_keys = false
	var _pr02_layer_ok: bool = Array(_pr02_snap.get("layer_order", [])) == \
		["accessory", "body", "feet", "torso", "weapon_or_swing", "helmet"]
	var _pr02_body_ok: bool = str(_pr02_snap.get("requested_body_id", "")) == "human" \
		and str(_pr02_snap.get("resolved_body_id", "")) == "human" \
		and bool(_pr02_snap.get("using_body_art", false))
	var _pr02_gear: Dictionary = _pr02_snap.get("visible_gear", {})
	var _pr02_slots_ok := true
	for _pr02_slot in _pr02_gear.keys():
		if str(_pr02_slot) not in ["weapon", "helmet", "torso", "feet", "accessory"]:
			_pr02_slots_ok = false
	var _pr02_gear_ok: bool = _pr02_slots_ok \
		and str(_pr02_gear.get("weapon", "")) == "sword_crude" \
		and str(_pr02_gear.get("helmet", "")) == "helmet_crude" \
		and str(_pr02_gear.get("torso", "")) == "torso_crude" \
		and str(_pr02_gear.get("feet", "")) == "feet_crude"
	_check("pr02_character_render_contract",
		_pr02_has_all_keys and _pr02_layer_ok and _pr02_body_ok and _pr02_gear_ok,
		"keys=%s layer=%s body=%s gear=%s" % [str(_pr02_has_all_keys),
			str(_pr02_layer_ok), str(_pr02_body_ok), str(_pr02_gear)])

	# --- PR-03: body-specific gear overlay resolution + refresh ---
	# Every live body must resolve its authored crude gear overlay against its
	# effective body id, not silently drop to the procedural fallback.
	player.apply_equipment({})
	var _pr03_gear_failures: Array[String] = []
	for _pr03_species in ["human", "dwarf", "elf", "goblin", "orc"]:
		for _pr03_case in [["masculine", ""], ["feminine", "_female"]]:
			player.apply_character({"species": _pr03_species,
				"body_variant": str(_pr03_case[0]), "appearance": "tan"})
			player.apply_equipment({"helmet": "helmet_crude",
				"torso": "torso_crude", "feet": "feet_crude"})
			var _pr03_body_id := "%s%s" % [_pr03_species, str(_pr03_case[1])]
			var _pr03_snap: Dictionary = _pv.presentation_snapshot()
			if str(_pr03_snap.get("effective_body_id", "")) != _pr03_body_id \
					or _pv.gear_uses_procedural_fallback("helmet_crude") \
					or _pv.gear_uses_procedural_fallback("torso_crude") \
					or _pv.gear_uses_procedural_fallback("feet_crude"):
				_pr03_gear_failures.append(_pr03_body_id)
	_check("pr03_gear_overlay_resolves_all_bodies",
		_pr03_gear_failures.is_empty(),
		"failures=%s" % str(_pr03_gear_failures))

	# The intermittent defect: a valid character whose body texture is missing at
	# resolve time (a cleared cache / once-missing load) must still show its
	# authored gear, resolved via the intended body id, rather than dropping every
	# overlay to the procedural fallback. Then a refresh at the transition
	# boundary must recover both body and gear once the art is available again.
	var _pr03_had_human := _pv_player_entries.has("human")
	var _pr03_old_human: Variant = _pv_player_entries.get("human")
	_pv_player_entries["human"] = "art/generated/players/smoke_tmp_missing_human.png"
	BlockRegistry.clear_visual_cache()
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan"})
	player.apply_equipment({"helmet": "helmet_crude", "torso": "torso_crude",
		"feet": "feet_crude"})
	var _pr03_miss_snap: Dictionary = _pv.presentation_snapshot()
	var _pr03_gear_survives_miss: bool = \
		str(_pr03_miss_snap.get("resolved_body_id", "x")) == "" \
		and not bool(_pr03_miss_snap.get("using_body_art", true)) \
		and str(_pr03_miss_snap.get("effective_body_id", "")) == "human" \
		and not _pv.gear_uses_procedural_fallback("helmet_crude") \
		and not _pv.gear_uses_procedural_fallback("torso_crude") \
		and not _pv.gear_uses_procedural_fallback("feet_crude")
	if _pr03_had_human:
		_pv_player_entries["human"] = _pr03_old_human
	else:
		_pv_player_entries.erase("human")
	BlockRegistry.clear_visual_cache()
	_pv.refresh_presentation()
	var _pr03_recovered_snap: Dictionary = _pv.presentation_snapshot()
	var _pr03_recovers: bool = \
		str(_pr03_recovered_snap.get("resolved_body_id", "")) == "human" \
		and bool(_pr03_recovered_snap.get("using_body_art", false)) \
		and not _pv.gear_uses_procedural_fallback("helmet_crude")
	_check("pr03_gear_survives_body_texture_miss",
		_pr03_gear_survives_miss and _pr03_recovers,
		"miss=%s recover=%s snap=%s" % [str(_pr03_gear_survives_miss),
			str(_pr03_recovers), str(_pr03_recovered_snap)])

	# PR-03B: the data-owned per-rig gear alignment offset is read and applied.
	# The goblin/dwarf crude helmet floats ~6px above the shorter head at
	# identity, so their rig carries a +5 helmet nudge; aligned bodies and
	# unlisted slots stay at zero. (Pixel head-contact is enforced by
	# scripts/art/verify_gear_alignment.py.)
	player.apply_character({"species": "goblin", "body_variant": "masculine",
		"appearance": "tan"})
	var _pr03b_goblin_helmet: Vector2 = _pv.gear_overlay_offset("helmet")
	var _pr03b_goblin_torso: Vector2 = _pv.gear_overlay_offset("torso")
	player.apply_character({"species": "dwarf", "body_variant": "feminine",
		"appearance": "tan"})
	var _pr03b_dwarf_helmet: Vector2 = _pv.gear_overlay_offset("helmet")
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan"})
	var _pr03b_human_helmet: Vector2 = _pv.gear_overlay_offset("helmet")
	_check("pr03b_gear_overlay_offset_applied",
		_pr03b_goblin_helmet == Vector2(0, 5) \
		and _pr03b_dwarf_helmet == Vector2(0, 5) \
		and _pr03b_goblin_torso == Vector2.ZERO \
		and _pr03b_human_helmet == Vector2.ZERO,
		"goblin_helmet=%s dwarf_helmet=%s goblin_torso=%s human_helmet=%s" % [
			str(_pr03b_goblin_helmet), str(_pr03b_dwarf_helmet),
			str(_pr03b_goblin_torso), str(_pr03b_human_helmet)])

	# Restore the state the earlier gear test left for the sections below.
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan"})
	player.apply_equipment({"weapon": "sword_crude", "helmet": "helmet_crude",
		"torso": "torso_crude", "feet": "feet_crude"})

	# --- FQ-13P3: player cosmetic body variants (full-body pool) ---
	# distinct sprite per variant (human has a 2-entry pool); variant 0 canonical.
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan", "visual_variant": 0})
	var _p3_v0 = _pv._body_texture
	var _p3_snap0: Dictionary = _pv.presentation_snapshot()
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan", "visual_variant": 1})
	var _p3_v1 = _pv._body_texture
	player.apply_character({"species": "human", "body_variant": "masculine",
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
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan", "visual_variant": 0})
	var _p3_canon = _pv._body_texture
	player.apply_character({"species": "human", "body_variant": "masculine",
		"appearance": "tan", "visual_variant": 3})   # pool size 2 -> wraps to variant 1
	_check("fq13p3_variant0_canonical_and_wrap",
		_p3_canon == BlockRegistry.visual_texture("players", "human")
		and _pv._body_texture == _p3_v1,
		"canon=%s wrap=%s" % [
			str(_p3_canon == BlockRegistry.visual_texture("players", "human")),
			str(_pv._body_texture == _p3_v1)])

	# Every current body now has the same bounded two-look pool.
	player.apply_character({"species": "dwarf", "body_variant": "masculine",
		"appearance": "tan", "visual_variant": 2})
	var _p3_dwarf_pool: Array = BlockRegistry.visual_variant_textures(
		"players", "dwarf")
	_check("fq13p3_all_body_pools_live",
		_p3_dwarf_pool.size() == 2
		and _pv._body_texture == _p3_dwarf_pool[1]
		and _pv._body_texture != BlockRegistry.visual_texture("players", "dwarf")
		and _pv.using_body_art(),
		"dwarf_pool=%d alternate=%s" % [_p3_dwarf_pool.size(), str(
			_pv._body_texture != BlockRegistry.visual_texture("players", "dwarf"))])

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
	# array entry for a real block; authored convention pools stay visible.
	var _fq09v_img_a := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq09v_img_a.fill(Color(1.0, 0.0, 0.0))
	var _fq09v_img_b := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq09v_img_b.fill(Color(0.0, 0.0, 1.0))
	for _fq09v_path in _fq09v_files:
		var _fq09v_src: Image = _fq09v_img_b
		if "_a" in _fq09v_path or "_01" in _fq09v_path:
			_fq09v_src = _fq09v_img_a
		_fq09v_src.save_png(_fq09v_path)
	BlockRegistry.visual_assets["categories"]["blocks"]["town_hall_core"] = [
		"art/generated/blocks/smoke_tmp_dirt_a.png",
		"art/generated/blocks/smoke_tmp_dirt_b.png"]
	BlockRegistry.clear_visual_cache()
	_check_res_fixture("fq09v_variant_pools_resolve",
		BlockRegistry.visual_variant_textures("blocks", "smoke_tmp_vscan").size() == 2
		and BlockRegistry.visual_variant_textures("blocks", "town_hall_core").size() == 2
		and BlockRegistry.visual_variant_textures("blocks", "stone").size() == 3,
		"scan=%d pool=%d stone=%d" % [
			BlockRegistry.visual_variant_textures("blocks", "smoke_tmp_vscan").size(),
			BlockRegistry.visual_variant_textures("blocks", "town_hall_core").size(),
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

	# (d) removing the explicit test pool returns the real block to its authored
	# canonical single, and the live world state returns untouched.
	for _fq09v_path2 in _fq09v_files:
		DirAccess.remove_absolute(_fq09v_path2)
	BlockRegistry.visual_assets["categories"]["blocks"].erase("town_hall_core")
	BlockRegistry.clear_visual_cache()
	world.rebuild_tileset()
	_check("fq09v_fallback_after_removal",
		(world._source_ids["town_hall_core"] as Array).size() == 1
		and BlockRegistry.visual_variant_textures("blocks", "town_hall_core").is_empty()
		and BlockRegistry.visual_texture("blocks", "town_hall_core") != null,
		"sources=%d" % (world._source_ids["town_hall_core"] as Array).size())
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
	# Removing the explicit entry falls back to the CONVENTION pool when real
	# authored cels exist on disk (the 2026-07-15 Codex opening-art program
	# shipped them), else to the plotted rendering.
	var _fq09c_real_pool: bool = not BlockRegistry.visual_variant_textures(
		"opening", "opening_01_first_star").is_empty()
	var _fq09c_celq: Control = _fq09c_script.new()
	_fq09c_celq.autoplay = false
	add_child(_fq09c_celq)
	var _fq09c_cel_off: bool = _fq09c_celq.current_uses_cel() == _fq09c_real_pool
	_check_res_fixture("fq09c_cel_shot_hook", _fq09c_cel_on and _fq09c_cel_off,
		"pool_plays=%s removal_matches_disk=%s real_pool=%s" % [str(_fq09c_cel_on),
			str(_fq09c_cel_off), str(_fq09c_real_pool)])
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
	var _fq09c_title_backdrop_ok: bool = _fq09c_shell._title_backdrop != null \
		and _fq09c_shell._title_backdrop.visible \
		and _fq09c_shell._title_backdrop.texture != null
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
		and "Quit" in _fq09c_buttons and _fq09c_title_backdrop_ok,
		"labels=%s buttons=%s backdrop=%s" % [str(_fq09c_labels),
			str(_fq09c_buttons), str(_fq09c_title_backdrop_ok)])
	_fq09c_shell.free()

	# PR-08 follow-up: the character-create form is viewport-safe. The long form
	# (preview + selectors) lives inside a ScrollContainer, and the Create/Back
	# action row sits OUTSIDE the scroll so it can never be clipped/pushed
	# off-screen; the PR-05 live preview is preserved inside the scroll; and a
	# default character can be created straight from the screen.
	var _pr08c_shell: Control = (load("res://scripts/shell/shell_ui.gd") as GDScript).new()
	_pr08c_shell._build_base()
	_pr08c_shell._show_char_create()
	var _pr08c_scroll: ScrollContainer = null
	var _pr08c_actions: HBoxContainer = null
	for _pr08c_child in _pr08c_shell._content.get_children():
		if _pr08c_child is ScrollContainer:
			_pr08c_scroll = _pr08c_child
		elif _pr08c_child is HBoxContainer:
			_pr08c_actions = _pr08c_child
	var _pr08c_btns: Array[String] = []
	if _pr08c_actions != null:
		for _pr08c_b in _pr08c_actions.get_children():
			if _pr08c_b is Button:
				_pr08c_btns.append((_pr08c_b as Button).text)
	# actions pinned outside the scroll (never clipped by form overflow).
	var _pr08c_actions_pinned: bool = _pr08c_scroll != null and _pr08c_actions != null \
		and not _pr08c_scroll.is_ancestor_of(_pr08c_actions) \
		and "Create" in _pr08c_btns and "Back" in _pr08c_btns
	# the PR-05 live preview is preserved and lives inside the scrollable form.
	var _pr08c_preview_ok: bool = _pr08c_shell._create_preview != null \
		and _pr08c_shell._create_preview.has_meta("preview_visual") \
		and _pr08c_scroll != null and _pr08c_scroll.is_ancestor_of(_pr08c_shell._create_preview)
	# a default character can be created straight from the screen.
	var _pr08c_before: int = GameState.characters.size()
	_pr08c_shell._create_character()
	var _pr08c_made: bool = GameState.characters.size() == _pr08c_before + 1
	var _pr08c_new: Dictionary = GameState.characters[GameState.characters.size() - 1] \
		if _pr08c_made else {}
	var _pr08c_defaults_ok: bool = _pr08c_made \
		and str(_pr08c_new.get("name", "")) == "Settler" \
		and str(_pr08c_new.get("species", "")) == "human"
	if _pr08c_made:
		GameState.delete_character(str(_pr08c_new.get("id", "")))   # clean up
	_pr08c_shell.free()
	_check("pr08_char_create_form_scrolls_actions_pinned",
		_pr08c_actions_pinned and _pr08c_preview_ok and _pr08c_defaults_ok,
		"pinned=%s preview=%s created=%s btns=%s" % [str(_pr08c_actions_pinned),
			str(_pr08c_preview_ok), str(_pr08c_defaults_ok), str(_pr08c_btns)])

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

	# (f) PR-07: the backdrop contour skirt follows the ACTUAL per-column surface
	# line, not the flat average horizon -- so the distant backdrop descends to
	# meet valleys and rises to peaks with no floating seam or void, off-world
	# columns clamp to the edge (never a void past the bounds), and the cosmetic
	# guarantees (no light, behind the walls) are unchanged.
	var _pr07_tile := float(world.tile_size())
	var _pr07_peak_col := 0
	var _pr07_valley_col := 0
	var _pr07_min := 1.0e9
	var _pr07_max := -1.0e9
	for _pr07_c in world.surface:
		var _pr07_sy := float(world.surface[_pr07_c])
		if _pr07_sy < _pr07_min:
			_pr07_min = _pr07_sy
			_pr07_peak_col = int(_pr07_c)
		if _pr07_sy > _pr07_max:
			_pr07_max = _pr07_sy
			_pr07_valley_col = int(_pr07_c)
	var _pr07_peak_top: float = _fq09w_bd.contour_top_px(_pr07_peak_col)
	var _pr07_valley_top: float = _fq09w_bd.contour_top_px(_pr07_valley_col)
	# the skirt top is exactly the per-column surface line, and a peak sits higher
	# on screen (smaller y) than a valley -- it follows terrain, not a flat line.
	var _pr07_follows: bool = is_equal_approx(_pr07_peak_top, _pr07_min * _pr07_tile) \
		and is_equal_approx(_pr07_valley_top, _pr07_max * _pr07_tile) \
		and _pr07_peak_top < _pr07_valley_top
	# off-world columns clamp to the nearest edge column (no void past the world).
	var _pr07_edge0: float = _fq09w_bd.contour_top_px(0)
	var _pr07_edgeW: float = _fq09w_bd.contour_top_px(world.width - 1)
	var _pr07_clamped: bool = is_equal_approx(_fq09w_bd.contour_top_px(-8), _pr07_edge0) \
		and is_equal_approx(_fq09w_bd.contour_top_px(world.width + 8), _pr07_edgeW)
	# cosmetic guarantees unchanged: no light interaction, still behind the walls.
	var _pr07_inert: bool = _fq09w_bd.light_mask == 0 \
		and _fq09w_bd.z_index < world._walls.z_index
	_check("pr07_backdrop_contour_skirt_follows_surface",
		_pr07_follows and _pr07_clamped and _pr07_inert,
		"follows=%s clamped=%s inert=%s peak=%.1f valley=%.1f" % [
			str(_pr07_follows), str(_pr07_clamped), str(_pr07_inert),
			_pr07_peak_top, _pr07_valley_top])

	# (f-hi) PR-07 correctness at a HIGH camera: the per-column surface can dip
	# below the view's bottom edge. The under-earth backing must still be drawn
	# for the in-view columns -- the old single spanning polygon went collinear /
	# self-intersecting there, so the triangulator dropped the WHOLE region and it
	# read as void/sky behind terrain. skirt_rects emits per-column quads clamped
	# to view.end.y. Put the view bottom BETWEEN the highest peak and the deepest
	# valley so some columns are genuinely below it (the pre-fix failure trigger).
	var _pr07g_peak_px: float = _pr07_min * _pr07_tile
	var _pr07g_valley_px: float = _pr07_max * _pr07_tile
	var _pr07g_bottom: float = (_pr07g_peak_px + _pr07g_valley_px) * 0.5
	var _pr07g_top: float = _pr07g_peak_px - 300.0
	var _pr07g_view := Rect2(0.0, _pr07g_top,
		float(world.width) * _pr07_tile, _pr07g_bottom - _pr07g_top)
	var _pr07g_fills: Dictionary = _fq09w_bd.skirt_rects(_pr07g_view, _pr07g_peak_px)
	var _pr07g_earth: Array = _pr07g_fills["earth"]
	var _pr07g_max_bottom := -1.0e9
	var _pr07g_min_top := 1.0e9
	for _pr07g_r: Rect2 in _pr07g_earth:
		_pr07g_max_bottom = maxf(_pr07g_max_bottom, _pr07g_r.end.y)
		_pr07g_min_top = minf(_pr07g_min_top, _pr07g_r.position.y)
	# the scenario truly has surface below the view, the backing is present
	# (region NOT dropped), every quad stays within the view bottom (clamped), and
	# it has real fill height (not collapsed to the bottom line).
	var _pr07g_exercises: bool = _pr07g_valley_px > _pr07g_view.end.y + 1.0
	var _pr07g_bounded: bool = _pr07g_earth.size() > 0 \
		and _pr07g_max_bottom <= _pr07g_view.end.y + 0.01
	var _pr07g_present: bool = _pr07g_min_top < _pr07g_view.end.y - 1.0
	_check("pr07_skirt_earth_backing_present_at_high_camera",
		_pr07g_exercises and _pr07g_bounded and _pr07g_present,
		"exercises=%s bounded=%s present=%s rects=%d bottom=%.1f min_top=%.1f" % [
			str(_pr07g_exercises), str(_pr07g_bounded), str(_pr07g_present),
			_pr07g_earth.size(), _pr07g_max_bottom, _pr07g_min_top])

	# --- R-07 slice 1: pause menu, settings, key rebinding ---
	# (a) the pause menu genuinely freezes the simulation via get_tree().paused
	# (game_root is pausable; the menu + music run PROCESS_MODE_ALWAYS) and
	# cleanly resumes.
	var _r07_pm = root._pause_menu
	var _r07_tod0: float = root.time_of_day
	var _r07_day0: int = root.day_count
	_r07_pm.open()
	var _r07_paused_on: bool = get_tree().paused and _r07_pm.is_open()
	for _r07_i in range(20):
		await get_tree().process_frame
	var _r07_frozen: bool = is_equal_approx(root.time_of_day, _r07_tod0) \
		and root.day_count == _r07_day0
	_r07_pm.resume()
	var _r07_resumed: bool = not get_tree().paused and not _r07_pm.is_open()
	_check("r07_pause_freezes_and_resumes",
		_r07_paused_on and _r07_frozen and _r07_resumed,
		"paused=%s frozen=%s resumed=%s" % [str(_r07_paused_on), str(_r07_frozen),
			str(_r07_resumed)])

	# (b) a key rebind applies to the live InputMap and resets to default.
	var _r07_ev := InputEventKey.new()
	_r07_ev.keycode = KEY_T
	_r07_ev.physical_keycode = KEY_T
	InputSettings.rebind(GameState.profile, "jump", _r07_ev)
	var _r07_bound: bool = InputMap.action_has_event("jump", _r07_ev) \
		and InputSettings.is_changed("jump")
	InputSettings.reset(GameState.profile)
	var _r07_reset: bool = not InputSettings.is_changed("jump") \
		and not InputMap.action_has_event("jump", _r07_ev)
	_check("r07_keybind_applies_and_resets", _r07_bound and _r07_reset,
		"bound=%s reset=%s jump=%s" % [str(_r07_bound), str(_r07_reset),
			InputSettings.key_label("jump")])

	# (c) the menu rejects a duplicate key (already bound to another rebindable
	# action) and leaves the target action unchanged, with feedback. Uses two
	# keyboard-bound actions (jump=Space, toggle_goals); mine/place are mouse.
	var _r07_jump_key := InputSettings.primary_key_event("jump")
	var _r07_goals_before := InputSettings.key_label("toggle_goals")
	_r07_pm._begin_rebind("toggle_goals")
	_r07_pm._apply_rebind(_r07_jump_key)   # jump already uses this key -> reject
	var _r07_dup_ok: bool = InputSettings.key_label("toggle_goals") == _r07_goals_before \
		and not InputSettings.is_changed("toggle_goals") \
		and InputSettings.action_using_key(_r07_jump_key, "toggle_goals") == "jump"
	_check("r07_duplicate_rebind_rejected", _r07_dup_ok,
		"goals %s->%s clash=%s" % [_r07_goals_before,
			InputSettings.key_label("toggle_goals"),
			InputSettings.action_using_key(_r07_jump_key, "toggle_goals")])

	# (d) full persistence round-trip: save a rebind, wipe the live map, apply the
	# DESERIALIZED saved profile (as a fresh launch would after loading the shell),
	# and confirm the saved key is live again; then reset and confirm defaults plus
	# a cleared persisted override. Isolated smoke root, never the real profile.
	AudioSettings.set_music_volume(GameState.profile, 0.3)
	InputSettings.rebind(GameState.profile, "toggle_map", _r07_ev)   # KEY_T
	GameState.save_shell()
	var _r07_saved = JSON.parse_string(FileAccess.get_file_as_string(GameState.shell_path()))
	var _r07_saved_prof: Dictionary = _r07_saved.get("profile", {}) if _r07_saved is Dictionary else {}
	var _r07_saved_ok: bool = is_equal_approx(float(_r07_saved_prof.get("music_volume", -1.0)), 0.3) \
		and (_r07_saved_prof.get("keybinds", {}) as Dictionary).has("toggle_map")
	InputSettings.reset(GameState.profile)               # live map back to defaults
	var _r07_after_reset: bool = not InputSettings.is_changed("toggle_map")
	InputSettings.apply(_r07_saved_prof)                 # deserialized dict -> live
	var _r07_reapplied: bool = InputMap.action_has_event("toggle_map", _r07_ev) \
		and InputSettings.is_changed("toggle_map")
	# final reset + persist -> defaults live and the override cleared on disk.
	InputSettings.reset(GameState.profile)
	AudioSettings.set_music_volume(GameState.profile, 1.0)
	AudioSettings.set_sfx_volume(GameState.profile, 1.0)
	GameState.save_shell()
	var _r07_disk2 = JSON.parse_string(FileAccess.get_file_as_string(GameState.shell_path()))
	var _r07_dp2: Dictionary = _r07_disk2.get("profile", {}) if _r07_disk2 is Dictionary else {}
	var _r07_cleared: bool = not (_r07_dp2.get("keybinds", {}) as Dictionary).has("toggle_map") \
		and not InputSettings.is_changed("toggle_map")
	_check("r07_settings_persist_then_reset_apply",
		_r07_saved_ok and _r07_after_reset and _r07_reapplied and _r07_cleared,
		"saved=%s reset=%s reapplied=%s cleared=%s" % [str(_r07_saved_ok),
			str(_r07_after_reset), str(_r07_reapplied), str(_r07_cleared)])

	# (e) Save & Quit leaves ONLY after a successful save. Force a failure (no
	# current world -> save_current_world_state returns false) and confirm the
	# menu stays paused and open with an error rather than exiting to the shell.
	var _r07_world := GameState.current_world_id
	GameState.current_world_id = ""
	_r07_pm.open()
	root._on_pause_save_and_quit()
	var _r07_still_paused := get_tree().paused
	var _r07_still_open: bool = _r07_pm.is_open()
	GameState.current_world_id = _r07_world
	_r07_pm.resume()
	_check("r07_save_and_quit_requires_success",
		_r07_still_paused and _r07_still_open,
		"still_paused=%s still_open=%s" % [str(_r07_still_paused), str(_r07_still_open)])

	# (f) the Settings content fits inside a 640x360 logical viewport; only the
	# key list scrolls, so Back/Reset stay reachable at the smallest supported
	# resolution.
	_r07_pm._show_settings()
	await get_tree().process_frame
	var _r07_fit_h: float = _r07_pm.settings_content_min_height()
	_r07_pm._show_main()
	_check("r07_settings_fits_640x360", _r07_fit_h > 0.0 and _r07_fit_h <= 360.0,
		"content_min_height=%.1f (<=360)" % _r07_fit_h)

	# (g) InputSettings honors the REBINDABLE contract: rebind() ignores an action
	# outside the set, and apply() ignores a stored override for one.
	InputSettings.rebind(GameState.profile, "ui_cancel", _r07_ev)   # not rebindable
	var _r07_guard_rebind: bool = not (GameState.profile.get("keybinds", {}) as Dictionary).has("ui_cancel")
	var _r07_dbg_ev := InputSettings.primary_key_event("debug_overlay")
	var _r07_dbg_key: int = _r07_dbg_ev.physical_keycode if _r07_dbg_ev != null else 0
	InputSettings.apply({"keybinds": {"debug_overlay": {"keycode": KEY_T, "physical": KEY_T}}})
	var _r07_dbg_ev2 := InputSettings.primary_key_event("debug_overlay")
	var _r07_dbg_key2: int = _r07_dbg_ev2.physical_keycode if _r07_dbg_ev2 != null else 0
	var _r07_guard_apply: bool = _r07_dbg_key == _r07_dbg_key2 and _r07_dbg_key2 != KEY_T
	_check("r07_rebind_apply_respect_rebindable",
		_r07_guard_rebind and _r07_guard_apply,
		"rebind_ignored=%s apply_ignored=%s" % [str(_r07_guard_rebind), str(_r07_guard_apply)])

	# (h) mouse-bound actions (mine/place) show a fixed mouse label -- never
	# "(unset)" -- and are not key-rebindable.
	var _r07_mine_lbl := InputSettings.binding_label("mine")
	var _r07_place_lbl := InputSettings.binding_label("place")
	_check("r07_mouse_actions_show_fixed",
		not InputSettings.is_key_rebindable("mine") and _r07_mine_lbl.contains("Mouse") \
		and _r07_mine_lbl != "(unset)" \
		and not InputSettings.is_key_rebindable("place") and _r07_place_lbl.contains("Mouse"),
		"mine=%s place=%s" % [_r07_mine_lbl, _r07_place_lbl])

	# --- R-07 slice 2: save management ---
	# (i) a shell delete is armed by a confirm, not performed on the first click:
	# after _request_delete the target still exists; _perform_pending_delete (the
	# dialog's confirm) actually removes it. Driven off-tree (popup is guarded).
	var _r07s: Control = (load("res://scripts/shell/shell_ui.gd") as GDScript).new()
	_r07s._build_base()
	var _r07_wid: String = GameState.create_world({})
	_r07s._request_delete("world", _r07_wid, "SmokeDelete")
	var _r07_armed: bool = _r07_wid != "" \
		and not GameState.load_world_file(_r07_wid).is_empty() \
		and str(_r07s._pending_delete.get("id", "")) == _r07_wid
	_r07s._perform_pending_delete()
	var _r07_confirmed: bool = GameState.load_world_file(_r07_wid).is_empty()
	_r07s.free()
	_check("r07_shell_delete_requires_confirm", _r07_armed and _r07_confirmed,
		"armed=%s confirmed_deleted=%s" % [str(_r07_armed), str(_r07_confirmed)])

	# (j) in-game Restore reloads the last save (visible recovery, no hidden F9)
	# and is gated by a confirm: requesting it does not reload; confirming does,
	# reverting live state to the save and closing the menu.
	_r07_pm.open()
	root.save_manager.save_game()
	var _r07_day_saved: int = root.day_count
	root.day_count = _r07_day_saved + 7               # mutate live state
	_r07_pm._request_restore()                         # arms the confirm dialog only
	var _r07_gated: bool = root.day_count == _r07_day_saved + 7
	_r07_pm._confirm.hide()
	root._on_pause_restore()                            # dialog confirmed -> reload
	var _r07_restored: bool = root.day_count == _r07_day_saved and not _r07_pm.is_open()
	_check("r07_pause_restore_reloads_save", _r07_gated and _r07_restored,
		"gated=%s restored=%s day=%d" % [str(_r07_gated), str(_r07_restored),
			root.day_count])

	# --- R-07 slice 3: build preview + reasoned invalid-placement feedback ---
	# (k) place_reason is the single validity authority (valid -> ""), and a failed
	# try_place emits the reason (no silent fails). Mutations here are wiped by the
	# fq09w_world_restored load_game that follows this block.
	player.inventory.add("wood", 5)
	var _r07_pcell: Vector2i = world.cell_of(player.global_position)
	var _r07_valid: Vector2i = Vector2i(99999, 99999)
	for _r07_dy in range(-3, 2):
		for _r07_dx in range(-3, 4):
			var _r07_c: Vector2i = _r07_pcell + Vector2i(_r07_dx, _r07_dy)
			var _r07_rc: String = player.place_reason(_r07_c, "wood")
			if _r07_rc == "":
				_r07_valid = _r07_c
				break
		if _r07_valid.x != 99999:
			break
	var _r07_valid_ok: bool = _r07_valid.x != 99999
	# reach is reported before occupancy: a far cell reads out-of-reach.
	var _r07_far: String = player.place_reason(_r07_pcell + Vector2i(60, 0), "wood")
	# an AIR cell overlapping the body reports the standing-there reason for a
	# solid block. Find a body-overlapping cell and clear it to air first (the
	# feet cell is solid); the break is reverted by the fq09w reload below.
	var _r07_bodyr: String = "(none)"
	for _r07_by in range(-3, 3):
		for _r07_bx in range(-2, 3):
			var _r07_bc: Vector2i = _r07_pcell + Vector2i(_r07_bx, _r07_by)
			if player._cell_overlaps_body(_r07_bc):
				world.break_block(_r07_bc)   # guarantee air at a body cell
				_r07_bodyr = player.place_reason(_r07_bc, "wood")
				break
		if _r07_bodyr != "(none)":
			break
	# with zero stock the missing-block reason wins.
	var _r07_had: int = player.inventory.count("wood")
	while player.inventory.count("wood") > 0:
		player.inventory.remove("wood")
	var _r07_nostockr: String = player.place_reason(_r07_valid, "wood")
	player.inventory.add("wood", _r07_had)
	# a failed try_place emits the reason to player_event.
	var _r07_evt := {"m": ""}
	var _r07_cb := func(msg: String): _r07_evt["m"] = msg
	player.player_event.connect(_r07_cb)
	var _r07_placed: bool = player.try_place(_r07_valid, "wood") if _r07_valid_ok else false
	var _r07_occ: String = player.place_reason(_r07_valid, "wood")   # now occupied
	player.try_place(_r07_pcell + Vector2i(60, 0), "wood")           # invalid -> emits
	var _r07_fb: String = str(_r07_evt["m"])
	player.player_event.disconnect(_r07_cb)
	_check("r07_place_reason_feedback",
		_r07_valid_ok and _r07_placed and _r07_far.contains("reach") \
		and _r07_bodyr.contains("standing") and _r07_nostockr.begins_with("No ") \
		and _r07_occ.contains("already") and _r07_fb.contains("reach"),
		"valid=%s placed=%s far=[%s] body=[%s] nostock=[%s] occ=[%s] fb=[%s]" % [
			str(_r07_valid_ok), str(_r07_placed), _r07_far, _r07_bodyr,
			_r07_nostockr, _r07_occ, _r07_fb])

	# (l) the build preview shows only for a placeable selected item (a ghost for
	# a held block, nothing for a tool/consumable).
	var _r07_hb: Array = player.hotbar.duplicate()
	var _r07_slot: int = player.selected_slot
	player.hotbar.clear()
	player.hotbar.append("wood")
	player.selected_slot = 0
	var _r07_prev_wood: String = root._build_preview.active_item()
	player.hotbar.clear()
	player.hotbar.append("food")
	player.selected_slot = 0
	var _r07_prev_food: String = root._build_preview.active_item()
	player.hotbar.assign(_r07_hb)
	player.selected_slot = _r07_slot
	_check("r07_build_preview_active_for_placeable",
		_r07_prev_wood == "wood" and _r07_prev_food == "",
		"wood=[%s] food=[%s]" % [_r07_prev_wood, _r07_prev_food])

	# --- R-07 slice 4: unified crafting panel + Town Hall trim ---
	# (m) the panel routes by station: a hand recipe spends the player's inventory;
	# building a station spends the Town Hall stockpile. (Reverted by the fq09w
	# reload below.)
	var _cp = root._craft_panel
	player.inventory.add("wood", 2)
	player.inventory.add("stone", 2)
	var _cm_torch0: int = player.inventory.count("torch")
	root._on_craft_panel_craft("craft_torch")   # hand: 1 wood + 1 stone -> 3 torch
	var _cm_hand: bool = player.inventory.count("torch") >= _cm_torch0 + 3
	hall.stockpile["wood"] = int(hall.stockpile.get("wood", 0)) + 12
	hall.stockpile["stone"] = int(hall.stockpile.get("stone", 0)) + 6
	hall.stations_built["workbench"] = false   # earlier fq11 tests may have built it
	root._on_craft_panel_build("workbench")
	var _cm_build: bool = hall.station_built("workbench")
	# a Town Hall gear recipe routes to its special forge method (empty-output
	# craft_axe would do nothing via craft_from_stockpile), setting the tool tier.
	hall.stockpile["wood"] = int(hall.stockpile.get("wood", 0)) + 4
	hall.stockpile["stone"] = int(hall.stockpile.get("stone", 0)) + 2
	player.axe_tier = 0
	root._on_craft_panel_craft("craft_axe")
	var _cm_axe: bool = player.axe_tier >= 1
	_check("r07_craft_panel_routes_hand_town_and_build",
		_cp != null and _cm_hand and _cm_build and _cm_axe,
		"hand=%s build=%s axe=%s" % [str(_cm_hand), str(_cm_build), str(_cm_axe)])

	# (n) have/need gating: an unaffordable recipe reports a reason, and the input
	# source is correct -- inventory for hand, stockpile for stations.
	var _cn_short: String = _cp._short_reason("hand", {"wood": 99999})
	var _cn_inv: int = _cp._stock_of("hand", "wood")
	var _cn_stock: int = _cp._stock_of("furnace", "coal")
	_check("r07_craft_panel_gating_and_source",
		_cn_short.begins_with("Need more") \
		and _cn_inv == int(player.inventory.count("wood")) \
		and _cn_stock == int(hall.stockpile.get("coal", 0)),
		"short=[%s] inv=%d stock=%d" % [_cn_short, _cn_inv, _cn_stock])

	# (o) crafting/building ownership has transferred to CraftPanel: the Town Hall
	# panel's forge/lantern/station signals are gone (only Repair remains).
	_check("r07_town_panel_crafting_removed",
		root._craft_panel != null and hud.has_signal("repair_requested") \
		and not hud.has_signal("forge_requested") \
		and not hud.has_signal("lantern_requested") \
		and not hud.has_signal("build_station_requested") \
		and not hud.has_signal("craft_station_requested"),
		"craftpanel=%s repair_sig=%s forge_sig=%s build_sig=%s" % [
			str(root._craft_panel != null), str(hud.has_signal("repair_requested")),
			str(hud.has_signal("forge_requested")),
			str(hud.has_signal("build_station_requested"))])

	# (p) C-key entry point: toggle opens/closes, and while open the input-capture
	# flag is set so player gameplay (mine/place) is frozen -- no click-through.
	# (close() is what both the C toggle and Esc invoke.)
	var _cp2 = root._craft_panel
	_cp2.close()
	var _cm_base: bool = not _cp2.is_open() and not GameState.craft_panel_open
	_cp2.toggle()
	var _cm_open: bool = _cp2.is_open() and GameState.craft_panel_open
	_cp2.close()
	var _cm_reclosed: bool = not _cp2.is_open() and not GameState.craft_panel_open
	_check("r07_craft_panel_toggle_and_modal",
		_cm_base and _cm_open and _cm_reclosed,
		"base=%s open=%s reclosed=%s" % [str(_cm_base), str(_cm_open), str(_cm_reclosed)])

	# (q) icon contract: every visible craft row resolves to an item-specific icon
	# id (item_icon is always non-null, so an empty id would be a meaningless
	# shared swatch), OR carries an explicit `icon` key = a documented no-icon
	# state. The empty-output forge recipes (craft_axe/sword/armor_set) resolve via
	# `icon` metadata to REAL gear art (visual_texture, not a swatch fallback).
	var _ci_ok := true
	var _ci_bad := ""
	for _ci_st in ["hand", "town_hall", "workbench", "furnace", "anvil"]:
		for _ci_rec: Dictionary in BlockRegistry.recipes_for_station(_ci_st):
			var _ci_id: String = _cp2.recipe_icon_id(_ci_rec)
			if _ci_id == "" and not _ci_rec.has("icon"):
				_ci_ok = false
				_ci_bad += str(_ci_rec.get("recipe_id", "")) + " "
	var _ci_axe: bool = _cp2.recipe_icon_id(BlockRegistry.get_recipe("craft_axe")) == "axe" \
		and BlockRegistry.visual_texture("items", "axe") != null
	var _ci_sword: bool = _cp2.recipe_icon_id(BlockRegistry.get_recipe("craft_sword")) == "sword" \
		and BlockRegistry.visual_texture("items", "sword") != null
	var _ci_armor: bool = _cp2.recipe_icon_id(BlockRegistry.get_recipe("craft_armor_set")) == "armor" \
		and BlockRegistry.visual_texture("items", "armor") != null
	_check("r07_craft_rows_icon_contract",
		_ci_ok and _ci_axe and _ci_sword and _ci_armor,
		"ok=%s bad=[%s] axe=%s sword=%s armor=%s" % [str(_ci_ok), _ci_bad,
			str(_ci_axe), str(_ci_sword), str(_ci_armor)])

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
	_check("r08_crew_spawns_with_jobs",
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
	_check("r08_farmhand_harvests_to_stockpile",
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
	_check("r08_population_is_sole_food_charger",
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
	_check("r08_farmhand_hungry_idles_when_food_exhausted",
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
	_check("farmhand_replants", _fp_planted and _fp_no_seed,
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
	_check("subject_work_zone",
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
	_check("r08_repairer_repairs_damaged_hall",
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
	_check("r08_job_assignment_cycles_and_validates",
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
	_check("r08_crew_persists_across_save",
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
	_check("r08_repeated_apply_no_duplicate",
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
	_check("r08_legacy_state_without_subjects_loads_safely",
		_r08_legacy_ok and _r08_legacy_live == 0,
		"applied=%s live=%d" % [str(_r08_legacy_ok), _r08_legacy_live])

	# --- R-08 slice 3: ground item drops, radius auto-pickup, and the hauler job ---
	var _r08g_home: Vector2 = hall.global_position
	var _r08g_player_pos: Vector2 = player.global_position
	_r08_clear_ground_drops()

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
	_check("r08_mining_routes_through_ground_drops", _r08g_reroute_ok, _r08g_reroute_detail)

	# (g2) radius auto-pickup: a drop beyond PICKUP_RADIUS is left alone; once the
	# player stands on it, the whole stack sweeps into the backpack and it is gone.
	_r08_clear_ground_drops()
	var _r08p_far: Vector2 = player.global_position + Vector2(300.0, 0.0)
	var _r08p_drop: Node = world.spawn_item_drop(_r08p_far, "wood", 3)
	var _r08p_wood0: int = player.inventory.count("wood")
	var _r08p_no_pick: bool = not player.collect_ground_drops()
	player.global_position = _r08p_far
	var _r08p_got: bool = player.collect_ground_drops()
	var _r08p_ok: bool = _r08p_no_pick and _r08p_got \
		and player.inventory.count("wood") == _r08p_wood0 + 3 \
		and (not is_instance_valid(_r08p_drop) or _r08p_drop.is_queued_for_deletion())
	_check("r08_player_radius_autopickup", _r08p_ok,
		"no_pick=%s got=%s wood %d->%d" % [str(_r08p_no_pick), str(_r08p_got),
			_r08p_wood0, player.inventory.count("wood")])

	# (g3) the hauler job: a settler carries a loose ground drop to the stockpile.
	_r08_clear_ground_drops()
	var _r08h_pos: Vector2 = _r08g_home + Vector2(24.0, -8.0)
	var _r08h_drop: Node = world.spawn_item_drop(_r08h_pos, "stone", 2)
	var _r08h_sub: Node = root._spawn_subject_at(_r08h_pos, "hauler_test", "hauler")
	var _r08h_stock0: int = int(hall.stockpile.get("stone", 0))
	var _r08h_worked: bool = _r08h_sub.run_job(0.1)
	var _r08h_gain: bool = int(hall.stockpile.get("stone", 0)) == _r08h_stock0 + 2
	var _r08h_gone: bool = not is_instance_valid(_r08h_drop) or _r08h_drop.is_queued_for_deletion()
	_check("r08_hauler_carries_ground_drop_to_stockpile",
		str(_r08h_sub.job) == "hauler" and _r08h_worked and _r08h_gain and _r08h_gone,
		"job=%s worked=%s stone %d->%d gone=%s" % [str(_r08h_sub.job), str(_r08h_worked),
			_r08h_stock0, int(hall.stockpile.get("stone", 0)), str(_r08h_gone)])
	_r08h_sub.remove_from_group("subjects")
	_r08h_sub.queue_free()

	# (g4) enemy loot spills onto the ground (not straight into the pack): killed
	# far from the player, its drop stays loose and the backpack is untouched.
	_r08_clear_ground_drops()
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
	_check("r08_enemy_loot_drops_to_ground", _r08e_ground and _r08e_no_autocollect,
		"ground=%s inv unchanged=%s (total=%d)" % [str(_r08e_ground),
			str(_r08e_no_autocollect), player.inventory.total()])

	# (g5) ground drops persist through the world save, and a repeated apply cannot
	# duplicate them (mirrors the subject/threat serialize discipline).
	_r08_clear_ground_drops()
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
	_check("r08_ground_drops_persist_across_save",
		_r08sv_ser.size() == 2 and _r08sv_live == 2 and _r08sv_stone_ok and _r08sv_after == 2,
		"ser=%d live=%d stone_ok=%s after_double=%d" % [_r08sv_ser.size(), _r08sv_live,
			str(_r08sv_stone_ok), _r08sv_after])

	# (g6) picking up loose items raises a "+N <Item>" notification with the count.
	_r08_clear_ground_drops()
	if hud._ctx_pickup_panel != null:
		hud._ctx_pickup_panel.visible = false
		hud._ctx_pickup_counts.clear()
	world.spawn_item_drop(player.global_position, "stone", 5)
	player.collect_ground_drops()
	var _r08n_text: String = hud._ctx_pickup_label.text if hud._ctx_pickup_panel != null else ""
	var _r08n_ok: bool = hud._ctx_pickup_panel != null and hud._ctx_pickup_panel.visible \
		and ("5" in _r08n_text) and (BlockRegistry.display_name("stone") in _r08n_text)
	_check("r08_pickup_notification_shows_count", _r08n_ok,
		"text=%s visible=%s" % [_r08n_text,
			str(hud._ctx_pickup_panel.visible if hud._ctx_pickup_panel != null else false)])

	_r08_clear_ground_drops()
	player.global_position = _r08g_player_pos

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
	_check("r09_contract_definitions_valid", _r09_defs_ok,
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
	_check("r09_lifecycle_available_active_completed_claimed", _r09_life_ok,
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
	_check("r09_stockpile_at_least_first_reach", _r09_at19 and _r09_at20,
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
	_check("r09_completion_latches", _r09_latch_done and _r09_latch_kept,
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
	_check("r09_claim_transactional_no_double_pay", _r09_nodouble_ok,
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
	_check("r09_claim_inventory_cannot_accept", _r09_accept_ok,
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
	_check("r09_save_migration_0_5_to_0_6",
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
	_check("r09_claimed_state_persists", _r09_persist_ok,
		"ser_claimed=%s reloaded=%s regrant_blocked=%s" % [str(_r09_ser_has_claimed),
			str(_r09_reloaded_claimed), str(not bool(_r09_regrant.get("ok", false)))])

	# (9) accepting an already-satisfied contract completes it immediately (the
	# game_root.accept_contract edge re-evaluates on accept, no stockpile_changed).
	_r09_cm.apply([])
	hall.stockpile["stone"] = 20
	var _r09_acc: bool = root.accept_contract(_r09_id)
	var _r09_acc_completed: bool = _r09_acc and _r09_cm.status_of(_r09_id) == "completed"
	_check("r09_accept_already_satisfied_completes", _r09_acc_completed,
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
	_check("r09_load_game_re_evaluates_active_stockpile_contract",
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
	_check("r09_objective_station_built",
		_r092_station_accept and _r09_cm.status_of("workbench_charter") == "completed",
		"status=%s" % _r09_cm.status_of("workbench_charter"))

	_r09_cm.apply([])
	root.day_count = 1
	var _r092_day_accept: bool = root.accept_contract("second_dawn")
	var _r092_day_active: bool = _r09_cm.status_of("second_dawn") == "active"
	root.day_count = 2
	_r09_cm.evaluate()
	_check("r09_objective_survive_to_day",
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
	_check("r09_event_progress_after_activation_only",
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
	_check("r09_event_progress_persists_no_replay",
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
	_check("r09_multi_contract_independent",
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
	_check("r09_reward_routes_through_authority",
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
	_check("r09_contracts_panel_status_actions",
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
	_check("r09_balance_report_deterministic", _r093_deterministic,
		"scenario=%s days=%d" % [str(_r093_a.get("metadata", {}).get("scenario_id", "")),
			int(_r093_a.get("metadata", {}).get("days", 0))])

	var _r093_contracts_before := FileAccess.get_file_as_string("res://data/contracts.json")
	var _r093_xp_before := FileAccess.get_file_as_string("res://data/progression/player_xp.json")
	var _r093_recipes_before := FileAccess.get_file_as_string("res://data/recipes.json")
	_r093_runner.run_report()
	var _r093_no_mutation: bool = _r093_contracts_before == FileAccess.get_file_as_string("res://data/contracts.json") \
		and _r093_xp_before == FileAccess.get_file_as_string("res://data/progression/player_xp.json") \
		and _r093_recipes_before == FileAccess.get_file_as_string("res://data/recipes.json")
	_check("r09_balance_report_no_mutation", _r093_no_mutation,
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
	_check_res_fixture("fq09w_wall_art_hook", _fq09w_no_art and _fq09w_with_art and _fq09w_back,
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
	# Tool rendering is procedural exactly when no authored swing art exists
	# (the 2026-07-15 Codex gear program shipped body-specific swing sets).
	var _fq09m_gear_art: bool = BlockRegistry.visual_texture(
		"player_gear", "pick_basic_human_swing_0") != null
	_check("player_visual_three_swing_poses",
		_fq09m_three_poses and (_fq09m_tool_fallback != _fq09m_gear_art),
		"expected=[0, 1, 2] procedural_tool=%s gear_art=%s" % [
			str(_fq09m_tool_fallback), str(_fq09m_gear_art)])
	_check("player_visual_tool_matches_target",
		_fq09m_pick_id.begins_with("pick_") and _fq09m_axe_id == "axe_crude",
		"stone=%s tree=%s" % [_fq09m_pick_id, _fq09m_axe_id])

	# --- PR-04: directional windup -> impact -> recovery action animation ---
	# All of this reads mining/attack state and never writes gameplay timing or
	# effects (fq09m above proves the mining baselines are untouched).
	var _pr04_saved_pos: Vector2 = player.global_position
	var _pr04_saved_axe: int = player.axe_tier
	player.attack_swing_t = 0.0   # clear any leftover melee swing so mining wins

	# (a) swing_direction follows the target vector: facing tracks the horizontal
	# component, the vertical component tracks up/down, for cardinal + diagonal
	# targets (in the visual's mirror-aware space the forward x stays positive).
	var _pr04_base: Vector2i = world.hall_info["center_cell"]
	player.global_position = world.cell_center(_pr04_base)
	player.mine_required = 1.0
	player.mine_progress = 0.0
	var _pr04_dir_fail: Array[String] = []
	# name -> [dx, dy, expect_facing (0 = any), y_sign (-1/0/1), require_forward_x]
	var _pr04_cases := {
		"right": [1, 0, 1, 0, true], "left": [-1, 0, -1, 0, true],
		"up": [0, -1, 0, -1, false], "down": [0, 1, 0, 1, false],
		"up_right": [1, -1, 1, -1, true], "down_left": [-1, 1, -1, 1, true],
	}
	for _pr04_name in _pr04_cases:
		var _pr04_c: Array = _pr04_cases[_pr04_name]
		player.mine_target = _pr04_base + Vector2i(int(_pr04_c[0]) * 3, int(_pr04_c[1]) * 3)
		_pv.refresh_facing()
		var _pr04_d: Vector2 = _pv.swing_direction()
		var _pr04_ok := true
		if int(_pr04_c[2]) != 0 and _pv.facing_sign() != int(_pr04_c[2]):
			_pr04_ok = false
		var _pr04_ys := int(_pr04_c[3])
		if _pr04_ys < 0 and _pr04_d.y >= -0.2:
			_pr04_ok = false
		if _pr04_ys > 0 and _pr04_d.y <= 0.2:
			_pr04_ok = false
		if _pr04_ys == 0 and absf(_pr04_d.y) > 0.3:
			_pr04_ok = false
		if bool(_pr04_c[4]) and _pr04_d.x <= 0.0:
			_pr04_ok = false
		if not _pr04_ok:
			_pr04_dir_fail.append("%s dir=%s facing=%d" % [
				_pr04_name, str(_pr04_d), _pv.facing_sign()])
	_check("pr04_swing_direction_follows_target",
		_pr04_dir_fail.is_empty(), "failures=%s" % str(_pr04_dir_fail))

	# (b) item-owned profile timing: the pick steps windup -> impact -> recovery
	# across the cycle, and at the same swing progress the pick (windup 0.35) and
	# axe (windup 0.45) resolve to different phases.
	player.mine_required = 1.0
	if _fq09m_swing_cell != null:
		player.mine_target = _fq09m_swing_cell
	var _pr04_pick_phases: Array[String] = []
	for _pr04_mp in [0.1, 0.2, 0.3]:   # cycle 0.2 windup, 0.4 impact, 0.6 recovery
		player.mine_progress = _pr04_mp
		_pr04_pick_phases.append(_pv.swing_phase_kind())
	player.mine_progress = 0.2         # cycle 0.4
	var _pr04_pick_at: String = _pv.swing_phase_kind()
	var _pr04_axe_at := ""
	player.axe_tier = 1
	var _pr04_tree_cell: Variant = _find_block(
		world, world.hall_info["center_cell"], "tree_trunk")
	if _pr04_tree_cell != null:
		player.mine_target = _pr04_tree_cell
		player.mine_progress = 0.2     # cycle 0.4
		_pr04_axe_at = _pv.swing_phase_kind()
	player.axe_tier = _pr04_saved_axe
	_check("pr04_action_profile_phases",
		_pr04_pick_phases == ["windup", "impact", "recovery"]
		and _pr04_pick_at == "impact" and _pr04_axe_at == "windup",
		"pick=%s pick@0.4=%s axe@0.4=%s" % [
			str(_pr04_pick_phases), _pr04_pick_at, _pr04_axe_at])

	# (c) the sword uses the same action contract: an attack aims at the target,
	# steps through the profile, and renders procedurally (no authored frames).
	player._reset_mining()
	var _pr04_saved_equip: Dictionary = player.equipment.duplicate(true)
	player.apply_equipment({"weapon": "sword_crude"})
	player.start_attack_swing(Vector2(0, -1))   # attack_swing_t = full -> progress 0
	var _pr04_atk_kind: String = _pv.action_kind()
	var _pr04_atk_item: String = _pv.active_action_item()
	var _pr04_atk_proc: bool = _pv.tool_swing_uses_procedural_fallback()
	var _pr04_atk_dir: Vector2 = _pv.swing_direction()
	var _pr04_atk_windup: String = _pv.swing_phase_kind()   # progress 0 -> windup
	player.attack_swing_t *= 0.1                      # progress ~0.9 -> recovery
	var _pr04_atk_recovery: String = _pv.swing_phase_kind()
	player.attack_swing_t = 0.0
	player.apply_equipment(_pr04_saved_equip)
	_check("pr04_sword_uses_action_contract",
		_pr04_atk_kind == "attack" and _pr04_atk_item == "sword_crude"
		and _pr04_atk_proc and _pr04_atk_dir.y < -0.2
		and _pr04_atk_windup == "windup" and _pr04_atk_recovery == "recovery",
		"kind=%s item=%s proc=%s dir=%s windup=%s recovery=%s" % [
			_pr04_atk_kind, _pr04_atk_item, str(_pr04_atk_proc),
			str(_pr04_atk_dir), _pr04_atk_windup, _pr04_atk_recovery])

	# --- PR-05: creation/select preview composes through the shared render path ---
	# A parentless PlayerVisual (no live Player) must resolve the identical figure
	# the world draws for the same character -- body, appearance recolour, and
	# visible gear -- proving "what you pick == what you get". Compared through the
	# rendering-contract snapshot, on a character that exercises body art, a
	# recolour, and four gear slots so the equivalence is not a match of empty
	# fallbacks.
	player._reset_mining()
	var _pr05_char := {
		"species": "dwarf",
		"body_variant": "feminine",
		"visual_variant": 0,
		"appearance": "ash",
		"equipment": {"weapon": "sword_crude", "helmet": "helmet_crude",
			"torso": "torso_crude", "feet": "feet_crude"},
	}
	player.apply_character(_pr05_char)
	player.apply_equipment(_pr05_char["equipment"])
	var _pr05_world_snap: Dictionary = _pv.presentation_snapshot()
	var _pr05_preview = _pv.get_script().new()   # parentless PlayerVisual
	_pr05_preview.apply_preview_character(_pr05_char)
	var _pr05_preview_snap: Dictionary = _pr05_preview.presentation_snapshot()
	var _pr05_parentless: bool = _pr05_preview.get_parent() == null
	var _pr05_diffs: Array[String] = []
	for _pr05_k in ["species", "body_variant", "visual_variant", "requested_body_id",
			"resolved_body_id", "using_body_art", "appearance_recolored",
			"effective_body_id", "visible_gear", "layer_order"]:
		if str(_pr05_world_snap.get(_pr05_k)) != str(_pr05_preview_snap.get(_pr05_k)):
			_pr05_diffs.append("%s world=%s preview=%s" % [_pr05_k,
				str(_pr05_world_snap.get(_pr05_k)), str(_pr05_preview_snap.get(_pr05_k))])
	var _pr05_meaningful: bool = \
		bool(_pr05_preview_snap.get("using_body_art", false)) \
		and bool(_pr05_preview_snap.get("appearance_recolored", false)) \
		and Dictionary(_pr05_preview_snap.get("visible_gear", {})).size() == 4
	_pr05_preview.free()
	_check("pr05_preview_matches_world_render",
		_pr05_diffs.is_empty() and _pr05_parentless and _pr05_meaningful,
		"parentless=%s meaningful=%s diffs=%s" % [str(_pr05_parentless),
			str(_pr05_meaningful), str(_pr05_diffs)])
	# Restore the player to its pre-visual-block character and gear.
	player.apply_equipment(_pv_saved_equipment)
	player.apply_character(_pv_saved_character)

	# Restore the state the sections below expect.
	player._reset_mining()
	player.global_position = _pr04_saved_pos

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
	# (one bar = 3.33 s at 72 BPM). This is a REAL-TIME transition driven by the
	# audio playback position, so a cold/slow host (Linux CI) can need well over
	# the old fixed 8 s / 480-frame budget for the position to cross the next bar.
	# Poll on a wall-clock deadline (not a frame count, which under-counts real
	# time when rendering is slow) and re-arm once before failing. A warm run
	# still lands in ~4 s and exits the loop immediately.
	var _fq09u_target: int = _fq09u_dir.clip_index_of("underground")
	var _fq09u_reached := false
	for _fq09u_attempt in range(2):
		_fq09u_dir.debug_reset("surface_day")
		_fq09u_dir.evaluate(_fq09u_under, 1.0)
		var _fq09u_deadline: int = Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < _fq09u_deadline:
			_fq09u_dir._settle_pending()
			if _fq09u_dir.playback_clip_index() == _fq09u_target \
					and _fq09u_dir.current_context() == "underground":
				_fq09u_reached = true
				break
			await get_tree().process_frame
		if _fq09u_reached:
			break
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

	# (a2) bottom-dock resource vessels mirror live full and half values.
	hud.update_health(100.0, 100.0)
	hud.update_attunement(50.0, 50.0)
	var _fq16_full_ok: bool = hud._health_vessel_fill != null \
		and is_equal_approx(hud._health_vessel_fill.value, 100.0) \
		and hud._attunement_vessel_fill != null \
		and is_equal_approx(hud._attunement_vessel_fill.value, 50.0)
	hud.update_health(50.0, 100.0)
	hud.update_attunement(25.0, 50.0)
	var _fq16_half_ok: bool = hud._health_vessel_fill != null \
		and is_equal_approx(hud._health_vessel_fill.value, 50.0) \
		and hud._attunement_vessel_fill != null \
		and is_equal_approx(hud._attunement_vessel_fill.value, 25.0)
	_check("fq16_bottom_resource_vessels_live",
		_fq16_full_ok and _fq16_half_ok,
		"full=%s half=%s health=%.1f attunement=%.1f" % [
			str(_fq16_full_ok), str(_fq16_half_ok),
			hud._health_vessel_fill.value, hud._attunement_vessel_fill.value])
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())

	# (a3) nonmodal HUD edit mode: direct manipulation (FQ-20 — no locks),
	# bounded, profile-backed, with continuous corner-grip resize.
	# Start from the default layout so the baseline is deterministic regardless
	# of any HUD size/position a prior run persisted into the shell profile;
	# reset restores the crest to its default size, which is exactly what the
	# reset assertion below verifies.
	hud.reset_hud_layout()
	var _fq17_before_pos: Vector2 = hud._hud_widgets["crest"].position
	var _fq17_before_size: Vector2 = hud._hud_widget_size(hud._hud_widgets["crest"])
	hud.toggle_hud_edit_mode()
	await get_tree().process_frame
	var _fq17_enter_ok: bool = hud.is_hud_edit_mode() and GameState.hud_edit_mode \
		and hud._hud_edit_overlay != null and hud._hud_edit_overlay.visible
	var _fq17_edit_panel_rect: Rect2 = hud._hud_edit_panel.get_global_rect() \
		if hud._hud_edit_panel != null else Rect2()
	var _fq17_dock_rect: Rect2 = hud._bottom_dock.get_global_rect() \
		if hud._bottom_dock != null else Rect2()
	var _fq17_panel_above_dock: bool = _fq17_edit_panel_rect.size.x > 0.0 \
		and _fq17_edit_panel_rect.end.y <= _fq17_dock_rect.position.y - 8.0 \
		and absf(_fq17_edit_panel_rect.get_center().x
			- get_viewport().get_visible_rect().size.x / 2.0) <= 1.0
	hud._toggle_top_left_module()
	var _fq17_visibility_saved: bool = not bool(GameState.profile["hud_layout"]["crest"]["visible"])
	hud._toggle_top_left_module()
	hud._hud_edit_selected = "crest"
	hud._nudge_hud_widget(Vector2(8, 0))
	hud._scale_hud_widget(0.25)
	var _fq17_scaled_size: Vector2 = hud._hud_widget_size(hud._hud_widgets["crest"])
	var _fq17_move_size_ok: bool = hud._hud_widgets["crest"].position != _fq17_before_pos \
		and hud._hud_widgets["crest"].scale.is_equal_approx(Vector2.ONE) \
		and _fq17_scaled_size.x > _fq17_before_size.x
	# FQ-20/FQ-22 continuous grip resize: absolute size factor, clamped to
	# [0.5, 2.0], while Control.scale remains one.
	hud._resize_hud_widget("crest", 1.37)
	var _fq20_resized_size: Vector2 = hud._hud_widget_size(hud._hud_widgets["crest"])
	var _fq20_resize_ok: bool = hud._hud_widgets["crest"].scale.is_equal_approx(Vector2.ONE) \
		and is_equal_approx(_fq20_resized_size.x, roundf(_fq17_before_size.x * 1.37))
	hud._resize_hud_widget("crest", 9.0)
	var _fq20_clamped_size: Vector2 = hud._hud_widget_size(hud._hud_widgets["crest"])
	var _fq20_clamp_ok: bool = hud._hud_widgets["crest"].scale.is_equal_approx(Vector2.ONE) \
		and _fq20_clamped_size.x <= roundf(_fq17_before_size.x * 2.0)
	var _fq20_grip_ok: bool = hud._hud_grip_rect("crest").size.x > 0.0
	hud.reset_hud_layout()
	var _fq17_reset_ok: bool = hud._hud_widgets["crest"].position == hud._hud_default_positions["crest"] \
		and hud._hud_widgets["crest"].scale.is_equal_approx(Vector2.ONE) \
		and hud._hud_widget_size(hud._hud_widgets["crest"]) == _fq17_before_size
	var _fq17_escape := InputEventKey.new()
	_fq17_escape.keycode = KEY_ESCAPE
	_fq17_escape.pressed = true
	hud._input(_fq17_escape)
	var _fq17_overlay_off: bool = not hud._hud_edit_overlay.visible
	_check("fq17_hud_edit_direct_manipulation",
		_fq17_enter_ok and _fq17_visibility_saved and _fq17_move_size_ok
		and _fq20_resize_ok and _fq20_clamp_ok and _fq20_grip_ok
		and _fq17_reset_ok and _fq17_panel_above_dock and _fq17_overlay_off
		and not GameState.hud_edit_mode,
		"enter=%s visibility=%s moved_resized=%s resize=%s clamp=%s grip=%s reset=%s before_size=%s scaled_size=%s resized_size=%s clamped_size=%s scale=%s pos=%s->%s panel=%s panel_rect=%s dock_rect=%s overlay_off=%s" % [
			str(_fq17_enter_ok), str(_fq17_visibility_saved), str(_fq17_move_size_ok),
			str(_fq20_resize_ok), str(_fq20_clamp_ok), str(_fq20_grip_ok),
			str(_fq17_reset_ok), _fq17_before_size, _fq17_scaled_size,
			_fq20_resized_size, _fq20_clamped_size, hud._hud_widgets["crest"].scale,
			_fq17_before_pos, hud._hud_widgets["crest"].position,
			str(_fq17_panel_above_dock), _fq17_edit_panel_rect, _fq17_dock_rect,
			str(_fq17_overlay_off)])

	# (a4) blueprint navigation actions are present and modal panels remain
	# mutually exclusive when opened from the dock (not only keyboard input).
	var _fq18_toolbar_labels: Array[String] = []
	for _fq18_child in hud._module_toolbar.get_children():
		if _fq18_child is Button:
			_fq18_toolbar_labels.append((_fq18_child as Button).text)
	# FQ-19: the four nav actions are named glyph buttons flanking the slots
	# (Inventory/Character left, Skills/Town Hall right). Each must live in
	# the dock and carry either the final icon art or the text fallback.
	var _fq18_nav_found := 0
	for _fq18_name in ["DockActionInventory", "DockActionCharacter",
			"DockActionSkills", "DockActionTownHall"]:
		var _fq18_node: Node = hud._bottom_dock.find_child(_fq18_name, true, false) \
			if hud._bottom_dock != null else null
		# FQ-21: band-mode buttons are invisible click zones over the BAKED
		# button art — the tooltip is their visible identity.
		if _fq18_node is Button \
				and ((_fq18_node as Button).icon != null or (_fq18_node as Button).text != ""
					or (_fq18_node as Button).tooltip_text != ""):
			_fq18_nav_found += 1
	var _fq18_nav_ok := _fq18_toolbar_labels == ["Crest", "Goal", "Events", "Map", "Edit"] \
		and _fq18_nav_found == 4
	hud.toggle_character_panel()
	var _fq18_character_ok: bool = hud.character_panel_open() and not hud.inventory_panel_open() \
		and not hud.skill_panel_open() and not hud.town_panel_open() and not hud._bottom_dock.visible
	hud.toggle_skill_panel()
	var _fq18_skills_ok: bool = hud.skill_panel_open() and not hud.character_panel_open() \
		and not hud.inventory_panel_open() and not hud.town_panel_open() and not hud._bottom_dock.visible
	hud.toggle_town_panel()
	var _fq18_town_ok: bool = hud.town_panel_open() and not hud.character_panel_open() \
		and not hud.inventory_panel_open() and not hud.skill_panel_open() and not hud._bottom_dock.visible
	hud.toggle_town_panel()
	var _fq18_modal_close_ok: bool = not hud._any_modal_panel_open() and hud._bottom_dock.visible
	_check("fq18_hud_dock_navigation_modal_exclusion",
		_fq18_nav_ok and _fq18_character_ok and _fq18_skills_ok and _fq18_town_ok and _fq18_modal_close_ok,
		"nav=%s character=%s skills=%s town=%s close=%s" % [str(_fq18_nav_ok),
			str(_fq18_character_ok), str(_fq18_skills_ok), str(_fq18_town_ok), str(_fq18_modal_close_ok)])

	# --- PR-06: Character HUD rebuilt on runtime children through the shared path ---
	# The panel composes the live character through the same PlayerVisual the world
	# draws (apply_preview_character), lists all 13 equipment slots from runtime
	# state, and holds no baked values -- re-equipping + reopening updates figure,
	# equipped names, and status. (fq18 left the panel closed.)
	var _pr06_saved_equip: Dictionary = player.equipment.duplicate(true)
	var _pr06_saved_health: float = player.health
	player.apply_equipment({"weapon": "sword_crude", "helmet": "helmet_crude"})
	player.health = 42.0
	hud.toggle_character_panel()   # open + refresh
	var _pr06_open: bool = hud.character_panel_open()
	var _pr06_fig: Dictionary = hud.character_figure_snapshot()
	var _pr06_fig_gear: Dictionary = _pr06_fig.get("visible_gear", {})
	var _pr06_fig_ok: bool = bool(_pr06_fig.get("using_body_art", false)) \
		and str(_pr06_fig_gear.get("weapon", "")) == "sword_crude" \
		and str(_pr06_fig_gear.get("helmet", "")) == "helmet_crude"
	var _pr06_texts: Array[String] = []
	for _pr06_l in hud._character_panel.find_children("*", "Label", true, false):
		_pr06_texts.append((_pr06_l as Label).text)
	var _pr06_joined := "\n".join(_pr06_texts)
	var _pr06_missing_slots: Array[String] = []
	for _pr06_slot in BlockRegistry.equipment_slots():
		if str(_pr06_slot.get("display_name", "")) not in _pr06_texts:
			_pr06_missing_slots.append(str(_pr06_slot.get("display_name", "")))
	var _pr06_slots_shown: bool = _pr06_missing_slots.is_empty()
	var _pr06_live_ok: bool = ("Crude Sword" in _pr06_joined) and ("Health: 42 / " in _pr06_joined)
	# no baked values: re-equip a different weapon + change health, then reopen.
	player.apply_equipment({"weapon": "sword_iron", "helmet": "helmet_crude"})
	player.health = 7.0
	hud.toggle_character_panel()   # close
	hud.toggle_character_panel()   # reopen + refresh
	var _pr06_retexts: Array[String] = []
	for _pr06_rl in hud._character_panel.find_children("*", "Label", true, false):
		_pr06_retexts.append((_pr06_rl as Label).text)
	var _pr06_rejoined := "\n".join(_pr06_retexts)
	var _pr06_refig: Dictionary = hud.character_figure_snapshot()
	var _pr06_no_baked: bool = ("Iron Sword" in _pr06_rejoined) \
		and ("Crude Sword" not in _pr06_rejoined) \
		and ("Health: 7 / " in _pr06_rejoined) \
		and str(_pr06_refig.get("visible_gear", {}).get("weapon", "")) == "sword_iron"
	hud.toggle_character_panel()   # close
	player.apply_equipment(_pr06_saved_equip)
	player.health = _pr06_saved_health
	_check("pr06_character_panel_runtime_render",
		_pr06_open and _pr06_fig_ok and _pr06_slots_shown and _pr06_live_ok and _pr06_no_baked,
		"open=%s fig=%s slots=%s(miss=%s) live=%s no_baked=%s" % [str(_pr06_open),
			str(_pr06_fig_ok), str(_pr06_slots_shown), str(_pr06_missing_slots),
			str(_pr06_live_ok), str(_pr06_no_baked)])

	# FQ-19: contextual right-band stack — fixed priority order, event-driven
	# entries (selection change / save / interaction), auto-hide, and a top
	# edge pinned dynamically below the live Map/Events zone. Runs after the
	# music suite because the auto-hide assertions wait in real time.
	var _fq19x_order_ok: bool = hud._context_stack != null \
		and hud._context_stack.get_child(0) == hud._ctx_item_panel \
		and hud._context_stack.get_child(1) == hud._ctx_save_panel \
		and hud._context_stack.get_child(2) == hud._ctx_interact_panel \
		and hud._context_stack.get_child(3) == hud._ctx_pickup_panel   # R-08 slice 3
	var _fq19x_slot0: int = player.selected_slot
	player.selected_slot = (player.selected_slot + 1) % 5
	hud.update_inventory()
	var _fq19x_item_ok: bool = hud._ctx_item_panel.visible \
		and hud._ctx_item_label.text != ""
	hud.notify_saved()
	var _fq19x_save_ok: bool = hud._ctx_save_panel.visible
	hud.set_interaction_prompt("[E] Town Hall")
	var _fq19x_prompt_on: bool = hud._ctx_interact_panel.visible \
		and hud._ctx_interact_label.text == "[E] Town Hall"
	hud.set_interaction_prompt("")
	var _fq19x_prompt_off: bool = not hud._ctx_interact_panel.visible
	if hud._event_panel != null:
		hud._event_panel.visible = true
	hud.set_interaction_prompt("[E] Town Hall")
	await get_tree().process_frame
	var _fq19x_stack_rect: Rect2 = hud._context_stack.get_global_rect()
	var _fq19x_ev_rect: Rect2 = hud._event_panel.get_global_rect()
	var _fq19x_clear: bool = _fq19x_stack_rect.position.y >= _fq19x_ev_rect.end.y
	hud.set_interaction_prompt("")
	# Auto-hide: the save toast holds 2.2s then fades 0.4s; the item entry
	# holds 2.5s. Both must be gone shortly after.
	await get_tree().create_timer(3.4).timeout
	var _fq19x_autohide: bool = not hud._ctx_save_panel.visible \
		and not hud._ctx_item_panel.visible
	player.selected_slot = _fq19x_slot0
	hud.update_inventory()
	_check("fq19_contextual_stack",
		_fq19x_order_ok and _fq19x_item_ok and _fq19x_save_ok
		and _fq19x_prompt_on and _fq19x_prompt_off and _fq19x_clear
		and _fq19x_autohide,
		"order=%s item=%s save=%s prompt=%s/%s clear=%s autohide=%s" % [
			str(_fq19x_order_ok), str(_fq19x_item_ok), str(_fq19x_save_ok),
			str(_fq19x_prompt_on), str(_fq19x_prompt_off), str(_fq19x_clear),
			str(_fq19x_autohide)])

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
	var _fq09_board_backpack_ok: bool = hud.inventory_board_visible() \
		and hud.backpack_cell_count("dirt") == 7 \
		and hud.backpack_cell_count("wood") == 2 \
		and hud.backpack_cell_total() == 2
	_check("fq09_inventory_board_backpack_cells",
		_fq09_board_backpack_ok,
		"visible=%s dirt=%d wood=%d cells=%d" % [str(hud.inventory_board_visible()),
			hud.backpack_cell_count("dirt"), hud.backpack_cell_count("wood"),
			hud.backpack_cell_total()])
	var _fq09_board_equipment_ok: bool = hud.equipment_slot_count() == 13 \
		and hud.equipment_slot_item("pickaxe") != ""
	_check("fq09_inventory_board_equipment_slots",
		_fq09_board_equipment_ok,
		"slots=%d pickaxe=%s weapon=%s" % [hud.equipment_slot_count(),
			hud.equipment_slot_item("pickaxe"), hud.equipment_slot_item("weapon")])
	var _fq09_board_dock_ok: bool = hud.dock_slot_item(0) == "dirt" \
		and hud.dock_slot_count(0) == 7 \
		and hud.dock_slot_item(1) == "wood" \
		and hud.dock_slot_count(1) == 2 \
		and hud.dock_selected_index() == player.selected_slot
	_check("fq09_inventory_board_dock_slots",
		_fq09_board_dock_ok,
		"dock0=%s/%d dock1=%s/%d selected=%d" % [hud.dock_slot_item(0),
			hud.dock_slot_count(0), hud.dock_slot_item(1), hud.dock_slot_count(1),
			hud.dock_selected_index()])
	var _fq09_detail: String = hud.selected_item_detail_text()
	_check("fq09_inventory_board_selected_item_details",
		_fq09_detail.find("Dirt") >= 0 and _fq09_detail.find("x7") >= 0,
		"detail=%s" % _fq09_detail)
	var _fq09_original_selected: int = player.selected_slot
	hud._select_inventory_item("wood")
	var _fq09_backpack_detail: String = hud.selected_item_detail_text()
	hud._select_dock_slot(1)
	var _fq09_dock_detail: String = hud.selected_item_detail_text()
	var _fq09_click_ok: bool = player.selected_slot == 1 and hud.dock_selected_index() == 1 \
		and _fq09_backpack_detail.find("Wood") >= 0 \
		and _fq09_dock_detail.find("Wood") >= 0
	hud._select_dock_slot(_fq09_original_selected)
	_check("fq09_inventory_board_click_selects",
		_fq09_click_ok,
		"selected=%d backpack=%s dock=%s" % [
			player.selected_slot, _fq09_backpack_detail, _fq09_dock_detail])
	hud.drop_inventory_slot("backpack", 0, {
		"source": "inventory_board", "kind": "backpack", "index": 1, "item_id": "wood"})
	var _fq09_layout_swapped: Array = player.inventory.layout_to_array()
	hud.drop_inventory_slot("dock", 4, {
		"source": "inventory_board", "kind": "backpack", "index": 0, "item_id": "wood"})
	var _fq09_dock_assigned: bool = hud.dock_slot_item(4) == "wood" \
		and hud.dock_slot_item(1) == "lantern"
	hud.drop_inventory_slot("dock", 1, {
		"source": "inventory_board", "kind": "dock", "index": 4, "item_id": "wood"})
	var _fq09_dock_restored: bool = hud.dock_slot_item(1) == "wood" \
		and hud.dock_slot_item(4) == "lantern"
	await get_tree().process_frame
	var _fq09_dock_cell: Control = null
	for _fq09_dock_child in hud._dock_assignment_row.get_children():
		var _fq09_candidate := _fq09_dock_child as Control
		if _fq09_candidate != null \
				and str(_fq09_candidate.name) == "InventoryDockSlot1" \
				and not _fq09_candidate.is_queued_for_deletion():
			_fq09_dock_cell = _fq09_candidate
			break
	var _fq09_dock_drag_payload_ok := false
	if _fq09_dock_cell != null:
		_fq09_dock_drag_payload_ok = str(_fq09_dock_cell.get("slot_kind")) == "dock" \
			and int(_fq09_dock_cell.get("slot_index")) == 1 \
			and str(_fq09_dock_cell.get("item_id")) == "wood" \
			and not _fq09_dock_cell.is_queued_for_deletion()
	hud._sort_inventory_board()
	var _fq09_layout_sorted: Array = player.inventory.layout_to_array()
	var _fq09_drag_sort_ok: bool = str(_fq09_layout_swapped[0]) == "wood" \
		and str(_fq09_layout_swapped[1]) == "dirt" \
		and _fq09_dock_assigned and _fq09_dock_restored and _fq09_dock_drag_payload_ok \
		and str(_fq09_layout_sorted[0]) == "dirt" \
		and str(_fq09_layout_sorted[1]) == "wood"
	hud._select_dock_slot(_fq09_original_selected)
	_check("fq09_inventory_board_drag_and_sort",
		_fq09_drag_sort_ok,
		"swapped=%s/%s dock_assigned=%s dock_restored=%s drag_payload=%s sorted=%s/%s" % [
			str(_fq09_layout_swapped[0]), str(_fq09_layout_swapped[1]),
			str(_fq09_dock_assigned), str(_fq09_dock_restored),
			str(_fq09_dock_drag_payload_ok),
			str(_fq09_layout_sorted[0]), str(_fq09_layout_sorted[1])])
	var _fq09_wood_before_clear: int = player.inventory.count("wood")
	hud.drop_inventory_slot("backpack", 1, {
		"source": "inventory_board", "kind": "dock", "index": 1, "item_id": "wood"})
	var _fq09_dock_cleared: bool = hud.dock_slot_item(1) == "" \
		and hud.dock_slot_count(1) == 0 \
		and player.inventory.count("wood") == _fq09_wood_before_clear
	var _fq09_hotbar_empty: bool = hud.hotbar_slot_empty(1)
	var _fq09_empty_detail: String = hud.selected_item_detail_text()
	var _fq09_saved_dock: Array = player.dock_assignments_to_array()
	player.set_dock_assignments(_fq09_saved_dock)
	var _fq09_blank_survives_normalize: bool = str(player.hotbar[1]) == ""
	hud.drop_inventory_slot("dock", 1, {
		"source": "inventory_board", "kind": "backpack", "index": 1, "item_id": "wood"})
	var _fq09_dock_reassigned: bool = hud.dock_slot_item(1) == "wood" \
		and player.inventory.count("wood") == _fq09_wood_before_clear
	hud.drop_inventory_slot("backpack", 2, {
		"source": "inventory_board", "kind": "dock", "index": 2, "item_id": "stone"})
	var _fq09_zero_count_dock_cleared: bool = hud.dock_slot_item(2) == "" \
		and player.inventory.count("stone") == 0
	var _fq09_zero_count_hotbar_empty: bool = hud.hotbar_slot_empty(2)
	player.hotbar[2] = "stone"
	hud.update_inventory()
	_check("fq09_inventory_board_dock_clears",
		_fq09_dock_cleared and _fq09_blank_survives_normalize \
		and _fq09_hotbar_empty and _fq09_dock_reassigned \
		and _fq09_zero_count_dock_cleared and _fq09_zero_count_hotbar_empty,
		"cleared=%s hotbar_empty=%s normalized=%s reassigned=%s zero_count=%s zero_hotbar_empty=%s detail=%s" % [
			str(_fq09_dock_cleared), str(_fq09_hotbar_empty),
			str(_fq09_blank_survives_normalize), str(_fq09_dock_reassigned),
			str(_fq09_zero_count_dock_cleared), str(_fq09_zero_count_hotbar_empty),
			_fq09_empty_detail])
	player.equip_item("helmet", "")
	player.inventory.add("helmet_iron", 1)
	player.inventory.ensure_layout()
	var _fq09_gear_source_index: int = player.inventory.layout_to_array().find("helmet_iron")
	var _fq09_gear_before: int = player.inventory.count("helmet_iron")
	hud.update_inventory()
	var _fq09_gear_dock_payload := {
		"source": "inventory_board", "kind": "backpack",
		"index": _fq09_gear_source_index, "item_id": "helmet_iron"}
	var _fq09_gear_dock_rejected: bool = not hud.can_drop_inventory_slot(
		"dock", 0, _fq09_gear_dock_payload)
	hud.drop_inventory_slot("dock", 0, _fq09_gear_dock_payload)
	_fq09_gear_dock_rejected = _fq09_gear_dock_rejected \
		and hud.dock_slot_item(0) != "helmet_iron"
	player.inventory.add("tool_tier_2_pick", 1)
	var _fq09_legacy_pick_index: int = player.inventory.layout_to_array().find("tool_tier_2_pick")
	var _fq09_legacy_pick_payload := {
		"source": "inventory_board", "kind": "backpack",
		"index": _fq09_legacy_pick_index, "item_id": "tool_tier_2_pick"}
	var _fq09_legacy_pick_dock_rejected: bool = not hud.can_drop_inventory_slot(
		"dock", 0, _fq09_legacy_pick_payload)
	hud.drop_inventory_slot("dock", 0, _fq09_legacy_pick_payload)
	_fq09_legacy_pick_dock_rejected = _fq09_legacy_pick_dock_rejected \
		and hud.dock_slot_item(0) != "tool_tier_2_pick"
	var _fq09_legacy_pick_icon_ok: bool = BlockRegistry.item_icon("tool_tier_2_pick") \
		.get_image().get_pixel(8, 8) == BlockRegistry.item_icon("pick").get_image().get_pixel(8, 8)
	player.set_dock_assignments(["dirt", "tool_tier_2_pick", "stone", "torch", "lantern"])
	var _fq09_legacy_pick_sanitized: bool = str(player.hotbar[1]) == ""
	player.set_dock_assignments(["dirt", "wood", "stone", "torch", "lantern"])
	hud.drop_inventory_slot("equipment", -1, {
		"source": "inventory_board", "kind": "backpack",
		"index": _fq09_gear_source_index, "item_id": "helmet_iron"}, "helmet")
	var _fq09_gear_equipped: bool = hud.equipment_slot_item("helmet") == "helmet_iron" \
		and player.inventory.count("helmet_iron") == _fq09_gear_before - 1
	hud.drop_inventory_slot("backpack", _fq09_gear_source_index, {
		"source": "inventory_board", "kind": "equipment", "index": -1,
		"slot_id": "helmet", "item_id": "helmet_iron"})
	var _fq09_gear_backpack: bool = hud.equipment_slot_item("helmet") == "" \
		and player.inventory.count("helmet_iron") == _fq09_gear_before \
		and _fq09_gear_source_index >= 0 \
		and str(player.inventory.layout_to_array()[_fq09_gear_source_index]) == "helmet_iron"
	_check("fq09_inventory_board_equipment_moves",
		_fq09_gear_source_index >= 0 and _fq09_gear_equipped and _fq09_gear_backpack \
		and _fq09_gear_dock_rejected and _fq09_legacy_pick_dock_rejected \
		and _fq09_legacy_pick_icon_ok and _fq09_legacy_pick_sanitized,
		"source=%d equipped=%s backpack=%s dock_reject=%s legacy_reject=%s legacy_icon=%s sanitized=%s count=%d" % [
			_fq09_gear_source_index, str(_fq09_gear_equipped),
			str(_fq09_gear_backpack), str(_fq09_gear_dock_rejected),
			str(_fq09_legacy_pick_dock_rejected), str(_fq09_legacy_pick_icon_ok),
			str(_fq09_legacy_pick_sanitized), player.inventory.count("helmet_iron")])
	var _fq09_pick_icon_px: Color = BlockRegistry.item_icon("pick_forged") \
		.get_image().get_pixel(8, 8)
	var _fq09_pick_family_px: Color = BlockRegistry.item_icon("pick") \
		.get_image().get_pixel(8, 8)
	var _fq09_axe_icon_px: Color = BlockRegistry.item_icon("axe_crude") \
		.get_image().get_pixel(8, 8)
	var _fq09_axe_family_px: Color = BlockRegistry.item_icon("axe") \
		.get_image().get_pixel(8, 8)
	var _fq09_gear_icon_ok: bool = _fq09_pick_icon_px == _fq09_pick_family_px \
		and _fq09_axe_icon_px == _fq09_axe_family_px
	_check("fq09_inventory_board_equipment_icons",
		_fq09_gear_icon_ok,
		"pick=%s/%s axe=%s/%s" % [str(_fq09_pick_icon_px),
			str(_fq09_pick_family_px), str(_fq09_axe_icon_px), str(_fq09_axe_family_px)])
	var _fq09_tool_layout: Array = player.inventory.layout_to_array()
	var _fq09_axe_target_index: int = _fq09_tool_layout.find("")
	hud.drop_inventory_slot("backpack", _fq09_axe_target_index, {
		"source": "inventory_board", "kind": "equipment", "index": -1,
		"slot_id": "axe", "item_id": "axe_crude"})
	var _fq09_axe_stowed: bool = player.axe_tier == 0 \
		and player.inventory.count("axe_crude") == 1 \
		and hud.equipment_slot_item("axe") == ""
	hud.drop_inventory_slot("equipment", -1, {
		"source": "inventory_board", "kind": "backpack",
		"index": _fq09_axe_target_index, "item_id": "axe_crude"}, "axe")
	var _fq09_axe_restored: bool = player.axe_tier == 1 \
		and player.inventory.count("axe_crude") == 0 \
		and hud.equipment_slot_item("axe") == "axe_crude"
	_fq09_tool_layout = player.inventory.layout_to_array()
	var _fq09_pick_target_index: int = _fq09_tool_layout.find("")
	hud.drop_inventory_slot("backpack", _fq09_pick_target_index, {
		"source": "inventory_board", "kind": "equipment", "index": -1,
		"slot_id": "pickaxe", "item_id": "pick_forged"})
	var _fq09_pick_stowed: bool = player.tool_tier == 0 \
		and player.inventory.count("pick_forged") == 1 \
		and hud.equipment_slot_item("pickaxe") == ""
	hud.drop_inventory_slot("equipment", -1, {
		"source": "inventory_board", "kind": "backpack",
		"index": _fq09_pick_target_index, "item_id": "pick_forged"}, "pickaxe")
	var _fq09_pick_restored: bool = player.tool_tier == 2 \
		and player.inventory.count("pick_forged") == 0 \
		and hud.equipment_slot_item("pickaxe") == "pick_forged"
	_check("fq09_inventory_board_tool_moves",
		_fq09_axe_target_index >= 0 and _fq09_pick_target_index >= 0 \
		and _fq09_axe_stowed and _fq09_axe_restored \
		and _fq09_pick_stowed and _fq09_pick_restored,
		"axe=%s/%s pick=%s/%s" % [str(_fq09_axe_stowed),
			str(_fq09_axe_restored), str(_fq09_pick_stowed), str(_fq09_pick_restored)])
	if _finish_if_focus("inventory"):
		return

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

	# --- Item-wiring pass: deposit unification, legacy pick migration, UI-only
	# guards, and the renewable tree loop. -------------------------------------
	_r08_clear_ground_drops()

	# (iw1) one stockpile-eligibility authority: materials + loot are IN; gear,
	# UI-only surrogates, legacy tokens, world-state blocks, and carried tools are OUT.
	# Live loot marked future_use (slime_gel, wet_fiber, bronze_ingot) stays IN —
	# future_use is documentary metadata, not a stockpile exclusion.
	var _iw_in := ["dirt", "stone", "wood", "ore", "coal", "food", "iron_ingot",
		"ore_flecks", "scrap_weapons", "meat", "coins", "hellstone", "obsidian",
		"tiny_core", "slime_gel", "wet_fiber", "bronze_ingot"]
	var _iw_out := ["torch", "lantern", "bucket", "crop_seeds", "tree_seed", "grass",
		"farm_soil", "crop_ripe", "tree_sapling", "town_hall_core", "pick", "axe",
		"sword", "armor", "pick_forged", "tool_tier_2_pick"]
	var _iw_pred_ok := true
	for _m in _iw_in:
		if not BlockRegistry.is_stockpile_material(str(_m)):
			_iw_pred_ok = false
	for _m in _iw_out:
		if BlockRegistry.is_stockpile_material(str(_m)):
			_iw_pred_ok = false
	_check("iw_stockpile_material_authority", _iw_pred_ok)

	# (iw2) manual deposit routes through that same authority: a mixed backpack
	# deposits only the materials/loot and leaves tools/seeds behind.
	player.inventory.from_dict({"dirt": 2, "coins": 3, "torch": 1, "tree_seed": 1})
	var _iw_moved: Dictionary = hall.deposit_all(player.inventory)
	_check("iw_manual_deposit_unified",
		_iw_moved.has("dirt") and _iw_moved.has("coins")
		and not _iw_moved.has("torch") and not _iw_moved.has("tree_seed")
		and player.inventory.count("torch") == 1 and player.inventory.count("tree_seed") == 1
		and int(hall.stockpile.get("coins", 0)) >= 3,
		"moved=%s left=%s" % [str(_iw_moved), str(player.inventory.counts)])

	# (iw3) legacy Forged Pick token migrates on load: stripped from the backpack,
	# and the live pick tier is guaranteed >= 2 (the upgrade it represented).
	player.inventory.from_dict({"tool_tier_2_pick": 1, "dirt": 4})
	player.tool_tier = 1
	root._migrate_legacy_pick_token()
	_check("iw_legacy_pick_token_migrates",
		player.inventory.count("tool_tier_2_pick") == 0 and player.tool_tier == 2
		and player.inventory.count("dirt") == 4)

	# (iw4) UI-only surrogates cannot spawn as loot or enter the stockpile.
	var _iw_ui_drop = world.spawn_item_drop(world.cell_center(hall_cell), "pick", 1)
	_check("iw_ui_only_guards",
		_iw_ui_drop == null and BlockRegistry.is_ui_only("pick")
		and not BlockRegistry.is_stockpile_material("armor"))

	# (iw5) renewable tree loop: plant on ground, mature into a real tree, break an
	# immature sapling back into a seed, and fail safely when obstructed. Uses a
	# cleared column above the surface so terrain variance cannot interfere.
	var _tr_x: int = hall_cell.x + 14
	var _tr_surf: int = int(world.surface.get(_tr_x, hall_cell.y))
	var _tr_sapling := Vector2i(_tr_x, _tr_surf - 3)
	var _tr_ground := _tr_sapling + Vector2i(0, 1)
	for _cy in range(_tr_sapling.y - 6, _tr_ground.y + 1):
		for _cx in range(_tr_x - 1, _tr_x + 2):
			world.break_block(Vector2i(_cx, _cy))   # clear trunk column + canopy space
	world.place_block(_tr_ground, "dirt")
	var _tr_planted: bool = world.plant_sapling(_tr_sapling)
	_check("iw_tree_plants_on_ground",
		_tr_planted and world.block_at(_tr_sapling) == "tree_sapling"
		and world.tree_growth.has(_tr_sapling))

	# break the immature sapling -> one seed back (the seed is not lost if cleared).
	var _tr_seed_drop: Dictionary = world.break_block(_tr_sapling)
	_check("iw_immature_sapling_returns_seed",
		int(_tr_seed_drop.get("tree_seed", 0)) == 1 and not world.tree_growth.has(_tr_sapling))

	# replant and mature it: the timer fires and a tree_trunk stands on the cell.
	world.plant_sapling(_tr_sapling)
	world._tick_tree_growth(1000.0)   # force the timer past maturity
	_check("iw_sapling_matures_into_tree",
		world.block_at(_tr_sapling) == "tree_trunk"
		and not world.tree_growth.has(_tr_sapling),
		"grown=%s" % world.block_at(_tr_sapling))

	# obstructed growth fails safely: a blocked trunk column keeps the sapling and
	# reschedules a retry rather than growing into the obstruction. A fresh column
	# (distinct x) keeps this independent of the matured tree above.
	var _tr2_x: int = _tr_x + 6
	var _tr2 := Vector2i(_tr2_x, _tr_surf - 3)
	for _cy in range(_tr2.y - 6, _tr2.y + 2):
		for _cx in range(_tr2_x - 1, _tr2_x + 2):
			world.break_block(Vector2i(_cx, _cy))
	world.place_block(_tr2 + Vector2i(0, 1), "dirt")
	world.plant_sapling(_tr2)
	world.place_block(_tr2 + Vector2i(0, -2), "stone")   # block the trunk column
	world._tick_tree_growth(1000.0)   # force the timer past maturity
	_check("iw_obstructed_sapling_waits",
		world.block_at(_tr2) == "tree_sapling" and world.tree_growth.has(_tr2),
		"blocked=%s" % world.block_at(_tr2))

	# save/load preserves in-progress sapling growth timers, and world-gen + live
	# maturation share the one tree-geometry rule (WorldGen.tree_layout).
	var _tr_ser: Dictionary = world.serialize_tree_growth()
	var _tr_layout: Array = WorldGen.tree_layout(3, 0, 5)
	_check("iw_tree_growth_persists",
		not _tr_ser.is_empty() and not _tr_layout.is_empty()
		and world.parse_tree_growth(_tr_ser).size() == _tr_ser.size(),
		"timers=%d" % _tr_ser.size())

	# (iw6) new loot-sink recipes actually consume their loot and produce the
	# existing output, routed through the ordinary craft_station path.
	hall.stations_built["workbench"] = true
	hall.stations_built["furnace"] = true
	hall.stations_built["anvil"] = true
	hall.stockpile = {"ore_flecks": 4, "scrap_weapons": 3, "meat": 2, "coal": 3,
		"torch_heads": 2, "oil_rags": 1, "wood": 1,
		"silver_ingot": 1, "crystal": 1, "tiny_core": 1}
	player.inventory.from_dict({})
	var _iw_reclaim_ore: bool = hall.craft_station("furnace_reclaim_ore", player)
	var _iw_reclaim_iron: bool = hall.craft_station("furnace_reclaim_iron", player)
	var _iw_cook: bool = hall.craft_station("cook_meat", player)
	var _iw_raid_torch: bool = hall.craft_station("workbench_raid_torches", player)
	_check("iw_loot_reclaim_recipes",
		_iw_reclaim_ore and int(hall.stockpile.get("ore", 0)) >= 1
		and _iw_reclaim_iron and int(hall.stockpile.get("iron_ingot", 0)) >= 1
		and _iw_cook and int(hall.stockpile.get("food", 0)) >= 2
		and _iw_raid_torch and player.inventory.count("torch") >= 6,
		"stock=%s torch=%d" % [str(hall.stockpile), player.inventory.count("torch")])

	# equipment sink: Focus Amulet (silver+crystal+tiny_core) equips the existing
	# amulet_focus gear (+10 attunement) that previously had no acquisition path.
	# Hosted at the WORKBENCH — the anvil's smelted-ingot invariant is untouched.
	player.equip_item("amulet", "")
	var _iw_amulet: bool = hall.craft_station("craft_focus_amulet", player)
	_check("iw_focus_amulet_sink",
		_iw_amulet and str(player.equipped_dict().get("amulet", "")) == "amulet_focus",
		"amulet=%s" % str(player.equipped_dict().get("amulet", "")))
	player.equip_item("amulet", "")

	# (iw7) conditional placeability: hellstone/obsidian are full solid blocks whose
	# only missing connection was is_placeable. Prove the place -> persist-as-delta
	# -> mine round-trip returns the item (tier-2 mining already exists).
	var _hp_x: int = hall_cell.x + 20
	var _hp_surf: int = int(world.surface.get(_hp_x, hall_cell.y))
	var _hp_cell := Vector2i(_hp_x, _hp_surf - 4)
	world.break_block(_hp_cell)
	var _hp_placed: bool = world.place_block(_hp_cell, "hellstone")
	var _hp_is_block: bool = world.block_at(_hp_cell) == "hellstone" \
		and world.is_solid_at(_hp_cell) and str(world.deltas.get(_hp_cell, "")) == "hellstone"
	player.tool_tier = 2
	var _hp_drop: Dictionary = world.break_block(_hp_cell)
	_check("iw_hellstone_obsidian_placeable_roundtrip",
		_hp_placed and _hp_is_block and int(_hp_drop.get("hellstone", 0)) == 1
		and BlockRegistry.is_placeable("hellstone") and BlockRegistry.is_placeable("obsidian"),
		"placed=%s block=%s drop=%s" % [str(_hp_placed), str(_hp_is_block), str(_hp_drop)])
	_r08_clear_ground_drops()

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
	_check("m1_roster_matches_population",
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
	_check("m1_hard_movement_bounds",
		absf(_m1_clamped.x - float(_m1_b["min_x"])) < 0.001 and _m1_inside == _m1_inside_pos,
		"clamped_x=%.1f min_x=%.1f inside_kept=%s" % [
			_m1_clamped.x, float(_m1_b["min_x"]), str(_m1_inside == _m1_inside_pos)])

	# (m1c) the citizen's home/guard post persists through a to_dict -> from_dict
	# round-trip (save/load).
	_m1_c.set_home(Vector2(1234.0, 567.0))
	var _m1_dict: Dictionary = _m1_c.to_dict()
	var _m1_c2: Node = _m1_live[1]
	_m1_c2.from_dict(_m1_dict)
	_check("m1_home_persists",
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
	_check("m1_stuck_recovery", _m1_fired, "fired=%s" % str(_m1_fired))

	# --- Settlement Coherence (M3-A): per-citizen ancestry identity ---
	# deterministic: the same key always yields the same identity (stable faces).
	var _id_a: Dictionary = root._generate_citizen_identity(12345)
	var _id_b: Dictionary = root._generate_citizen_identity(12345)
	_check("m3_identity_deterministic",
		str(_id_a["species"]) == str(_id_b["species"])
		and str(_id_a["body_variant"]) == str(_id_b["body_variant"]),
		"a=%s b=%s" % [str(_id_a), str(_id_b)])
	# every generated species is a LIVE (art-backed) player species.
	var _id_live: Array = BlockRegistry.player_visuals.get("live_species", [])
	var _id_live_ok := true
	for _id_i in 20:
		if str(root._generate_citizen_identity(_id_i)["species"]) not in _id_live:
			_id_live_ok = false
	_check("m3_identity_species_live", _id_live_ok and not _id_live.is_empty())
	# identity persists through to_dict -> from_dict (never regenerated on load).
	var _idc: Node = _m1_live[0]
	_idc.set_identity("dwarf", "feminine", 0)
	var _idd: Dictionary = _idc.to_dict()
	var _idc2: Node = _m1_live[1]
	_idc2.from_dict(_idd)
	_check("m3_identity_persists",
		str(_idd.get("species")) == "dwarf" and str(_idd.get("body_variant")) == "feminine"
		and str(_idc2.to_dict().get("species")) == "dwarf",
		"saved=%s restored=%s" % [str(_idd.get("species")), str(_idc2.to_dict().get("species"))])
	# the ancestry sprite resolves from the live imagery (player-pipeline reuse).
	_check("m3_identity_sprite_resolves",
		BlockRegistry.visual_texture("players",
			BlockRegistry.player_body_id("dwarf", "feminine")) != null)

	# --- Citizen profile: ancestry-aligned name, days alive, stats, info panel ---
	# deterministic name/stats for a given seed+ancestry.
	var _cp_a: Dictionary = root._generate_citizen_profile(7777, "dwarf", "masculine")
	var _cp_b: Dictionary = root._generate_citizen_profile(7777, "dwarf", "masculine")
	_check("cp_profile_deterministic", str(_cp_a["name"]) == str(_cp_b["name"]))
	# the name is aligned with the ancestry: the given (first) name is in that
	# species' pool for the body variant.
	var _cp_pool: Dictionary = BlockRegistry.citizen_name_pool("dwarf")
	var _cp_given: String = str(_cp_a["name"]).split(" ")[0]
	_check("cp_name_ancestry_aligned", _cp_given in _cp_pool.get("masculine", []),
		"given=%s name=%s" % [_cp_given, str(_cp_a["name"])])
	# stats: every declared stat present and within 1..10.
	var _cp_stats: Dictionary = _cp_a["stats"]
	var _cp_stat_ids: Array = BlockRegistry.citizen_stat_ids()
	var _cp_range_ok := _cp_stats.size() == _cp_stat_ids.size()
	for _cp_sid in _cp_stat_ids:
		var _cp_v: int = int(_cp_stats.get(str(_cp_sid), 0))
		if _cp_v < 1 or _cp_v > 10:
			_cp_range_ok = false
	_check("cp_stats_in_range", _cp_range_ok, "stats=%s" % str(_cp_stats))
	# days-alive and profile persistence through save/load.
	var _cp_c: Node = _m1_live[0]
	_cp_c.set_profile("Test Dwarf", 2, {"vigor": 5})
	_check("cp_days_alive", _cp_c.days_alive(6) == 4, "days=%d" % _cp_c.days_alive(6))
	var _cp_dict: Dictionary = _cp_c.to_dict()
	var _cp_c2: Node = _m1_live[1]
	_cp_c2.from_dict(_cp_dict)
	_check("cp_profile_persists",
		str(_cp_c2.citizen_name) == "Test Dwarf" and int(_cp_c2.birth_day) == 2
		and int(_cp_c2.stats.get("vigor", 0)) == 5,
		"name=%s born=%d vigor=%d" % [str(_cp_c2.citizen_name), int(_cp_c2.birth_day),
			int(_cp_c2.stats.get("vigor", 0))])
	# the info panel opens for a settler and closes cleanly.
	hud.open_npc_panel(_cp_c)
	var _cp_open: bool = hud.npc_panel_open()
	hud.close_npc_panel()
	_check("cp_info_panel_opens", _cp_open and not hud.npc_panel_open())

	# stats drive effectiveness: higher Guard hits harder, higher Vigor moves faster.
	_cp_c.set_profile("Strong", 2, {"guard": 10, "vigor": 10}, "")
	var _cp_hi_dmg: int = _cp_c.defend_damage()
	var _cp_hi_spd: float = _cp_c.effective_move_speed()
	_cp_c.set_profile("Weak", 2, {"guard": 1, "vigor": 1}, "")
	_check("cp_stats_affect_behavior",
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
	_check("cp_report_needs_issue_want",
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
	_check("cp_report_needs_reasons",
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
	_check("m3b_roster_grows_to_population",
		_rc_grow == 6 and _rc_grow == hall.population,
		"roster=%d pop=%d" % [_rc_grow, hall.population])
	var _rc_live: Array = BlockRegistry.player_visuals.get("live_species", [])
	var _rc_born_ok := not _rc_species.is_empty()
	for _rc_k in _rc_species:
		if str(_rc_species[_rc_k]) not in _rc_live:
			_rc_born_ok = false
	_check("m3b_newcomers_born_with_identity", _rc_born_ok)
	# starve the authority; the sync removes settlers (newest first) down to target.
	hall.population = 3
	root.sync_roster_to_population()
	var _rc_shrink := 0
	for _rc_s2 in get_tree().get_nodes_in_group("subjects"):
		if not _rc_s2.is_queued_for_deletion():
			_rc_shrink += 1
	_check("m3b_roster_shrinks_to_population",
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
	_check("m3c_defender_attacks_threat_in_guard_zone", _df_engaged,
		"engaged=%s hp0=%d" % [str(_df_engaged), _df_hp0])
	if is_instance_valid(_df_threat):
		_df_threat.remove_from_group("threats")
		_df_threat.queue_free()
	# a defender ignores a threat OUTSIDE its guard radius (it returns to its post).
	var _df_far = root.spawn_enemy_for_test("surface_slime")
	_df_far.global_position = _df_home + Vector2(400.0, 0.0)
	_check("m3c_defender_ignores_out_of_zone_threat", not _df.run_job(1.0))
	_df.remove_from_group("subjects")
	_df.queue_free()
	if is_instance_valid(_df_far):
		_df_far.remove_from_group("threats")
		_df_far.queue_free()

	# --- Settlement Coherence (M4-A): raider_sapper breaches walls ---
	var _sp = root.spawn_enemy_for_test("raider_sapper")
	_check("m4_sapper_is_live",
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
		_check("m4_sapper_breaks_structural_wall", _sp_broke,
			"wall_now=%s" % world.block_at(_sp_wall))
		_check("m4_sapper_spares_protected",
			not _sp._is_sappable("town_hall_core") and not _sp._is_sappable("bedrock")
			and _sp._is_sappable("stone") and _sp._is_sappable("door"))
		_sp.remove_from_group("threats")
		_sp.queue_free()

	# --- Settlement Coherence (M4-B): lava_slime (capped bubbles + lava immunity) ---
	var _ls = root.spawn_enemy_for_test("lava_slime")
	_check("m4_lava_slime_is_live",
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
		_check("m4_lava_slime_bubbles_capped",
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
		_check("m4_lava_slime_immune_to_lava", int(_ls.hp) == _ls_hp0,
			"hp %d->%d" % [_ls_hp0, int(_ls.hp)])
		world.cells.erase(_ls_cell)
		world.deltas[_ls_cell] = "air"
		world._set_tile(_ls_cell, "air")
		_ls.remove_from_group("threats")
		_ls.queue_free()

	# --- Settlement Coherence (M5-A): sun/moon celestial renderer (presentation) ---
	_check("m5_celestial_node_present", root._celestial != null)
	var _cv := Rect2(0.0, 0.0, 1280.0, 720.0)
	var _sky_dawn: Dictionary = CelestialScript.positions(0.02, _cv)
	var _sky_noon: Dictionary = CelestialScript.positions(0.325, _cv)   # mid-day (0.65/2)
	var _sky_dusk: Dictionary = CelestialScript.positions(0.63, _cv)
	var _sky_night: Dictionary = CelestialScript.positions(0.82, _cv)
	# the sun rises left, peaks (highest = smallest y) at mid-day, and sets right.
	_check("m5_sun_arcs_across_day",
		bool(_sky_dawn["sun_visible"]) and not bool(_sky_dawn["moon_visible"])
		and float(_sky_noon["sun"].y) < float(_sky_dawn["sun"].y)
		and float(_sky_noon["sun"].y) < float(_sky_dusk["sun"].y)
		and float(_sky_dawn["sun"].x) < float(_sky_noon["sun"].x)
		and float(_sky_noon["sun"].x) < float(_sky_dusk["sun"].x),
		"dawn_y=%.0f noon_y=%.0f dusk_y=%.0f" % [
			float(_sky_dawn["sun"].y), float(_sky_noon["sun"].y), float(_sky_dusk["sun"].y)])
	# night belongs to the moon; the sun is down.
	_check("m5_moon_rules_the_night",
		bool(_sky_night["moon_visible"]) and not bool(_sky_night["sun_visible"]),
		"is_night=%s" % str(_sky_night["is_night"]))
	# continuous lunar cycle: new (dark) at phase 0.0, full at 0.5, half at 0.25.
	_check("m5_moon_phase_cycle",
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
	_check("m5_lunar_cycle_true",
		_cyc_full_days == 1 and _cyc_peak > 0.98 and _cyc_names.size() >= 6,
		"full_days=%d peak=%.2f distinct_names=%d" % [_cyc_full_days, _cyc_peak, _cyc_names.size()])
	# the full-moon gameplay hook tracks the day-driven phase.
	root._celestial.set_phase_from_day(root._celestial.FULL_MOON_DAY)
	var _fm_full: bool = root._celestial.is_full_moon()
	root._celestial.set_phase_from_day(0)   # new moon
	var _fm_new: bool = not root._celestial.is_full_moon()
	root._celestial.set_phase_from_day(root.day_count)   # restore
	_check("m5_full_moon_hook", _fm_full and _fm_new)

	# --- Settlement Coherence (M2-A): stockpile withdrawal (Town Hall authority) ---
	hall.stockpile = {"wood": 5, "stone": 4}
	player.inventory.from_dict({})
	# withdraw a chosen amount: exactly that many move, stockpile is decremented.
	var _w_take: int = hall.withdraw("wood", 2, player)
	_check("m2_withdraw_amount",
		_w_take == 2 and int(hall.stockpile.get("wood", 0)) == 3
		and player.inventory.count("wood") == 2,
		"took=%d stock=%d inv=%d" % [_w_take, int(hall.stockpile.get("wood", 0)),
			player.inventory.count("wood")])
	# a request larger than the stock takes only the remainder (atomic, clamped).
	var _w_over: int = hall.withdraw("wood", 99, player)
	_check("m2_withdraw_clamps_to_stock",
		_w_over == 3 and not hall.stockpile.has("wood") and player.inventory.count("wood") == 5,
		"took=%d has_wood=%s inv=%d" % [_w_over, str(hall.stockpile.has("wood")),
			player.inventory.count("wood")])
	# withdrawing an absent item is a safe no-op.
	_check("m2_withdraw_empty_is_noop", hall.withdraw("gold", 1, player) == 0)
	# withdraw-all empties the whole stockpile into the backpack.
	var _w_all: Dictionary = hall.withdraw_all(player)
	_check("m2_withdraw_all_empties_stockpile",
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
	_check("stockpile_drag_grid",
		_s5_deposit_ok and _s5_withdraw_ok and _s5_reject and _s5_roundtrip,
		"deposit=%s withdraw=%s reject=%s roundtrip=%s" % [str(_s5_deposit_ok),
			str(_s5_withdraw_ok), str(_s5_reject), str(_s5_roundtrip)])

	# --- Settlement Coherence (M2-B): doors — obtainable, placeable-solid, toggle ---
	player.inventory.from_dict({"wood": 4})
	var _dr_crafted: bool = player.craft("craft_door")
	_check("m2b_craft_door", _dr_crafted and player.inventory.count("door") >= 1,
		"crafted=%s door=%d" % [str(_dr_crafted), player.inventory.count("door")])
	var _dr_cell := Vector2i(hall_cell.x + 18,
		int(world.surface.get(hall_cell.x + 18, hall_cell.y)) - 3)
	world.break_block(_dr_cell)
	var _dr_placed: bool = world.place_block(_dr_cell, "door")
	_check("m2b_door_places_solid",
		_dr_placed and world.block_at(_dr_cell) == "door" and world.is_solid_at(_dr_cell)
		and BlockRegistry.blocks_light("door"),
		"placed=%s block=%s solid=%s" % [str(_dr_placed), world.block_at(_dr_cell),
			str(world.is_solid_at(_dr_cell))])
	# opening it makes it passable, lets light through, and saves as a delta.
	var _dr_open: bool = world.toggle_door(_dr_cell)
	_check("m2b_door_opens_passable",
		_dr_open and world.block_at(_dr_cell) == "door_open"
		and not world.is_solid_at(_dr_cell) and not BlockRegistry.blocks_light("door_open")
		and str(world.deltas.get(_dr_cell, "")) == "door_open",
		"open=%s block=%s solid=%s delta=%s" % [str(_dr_open), world.block_at(_dr_cell),
			str(world.is_solid_at(_dr_cell)), str(world.deltas.get(_dr_cell, ""))])
	# closing it restores a solid door; toggling a non-door is a safe no-op.
	world.toggle_door(_dr_cell)
	_check("m2b_door_closes_and_noop",
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
	_check("m6_tall_door_place_toggle_mine",
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
	_check("gravity_tree_collapse",
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
	_check("gravity_ore_falls",
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
	_check("m2b_housing_recognizes_valid_house",
		HousingScript.count_valid_houses(world, hall_cell, _hs_hw, _hs_up, _hs_dn, _hs_cfg)
			== _hs_base_count + 1,
		"base=%d with_house=%d" % [_hs_base_count,
			HousingScript.count_valid_houses(world, hall_cell, _hs_hw, _hs_up, _hs_dn, _hs_cfg)])
	_check("m2b_housing_capacity_increases",
		root.housing_capacity() == _hs_cap_before + int(_hs_cfg.get("per_house_capacity", 2)),
		"before=%d after=%d" % [_hs_cap_before, root.housing_capacity()])
	# (b) sealing the only door makes it NOT a house (>=1 door is required).
	world.break_block(_hs_door)
	world.place_block(_hs_door, "stone")
	_check("m2b_house_needs_a_door",
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
	_check("m2b_growth_gated_by_housing",
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


func _finish_if_focus(focus_id: String) -> bool:
	if OS.get_environment("COHERONIA_SMOKE_FOCUS") != focus_id:
		return false
	var failed := 0
	var failed_names: Array = []
	for r in _results:
		if not r[1]:
			failed += 1
			failed_names.append(r[0])
	_write_result_file(failed, failed_names)
	print("SMOKE FOCUS %s: %s (%d/%d passed)" % [
		focus_id, "PASS" if failed == 0 else "FAIL",
		_results.size() - failed, _results.size()])
	get_tree().quit(0 if failed == 0 else 1)
	return true


func _run_inventory_focus(player: CharacterBody2D, hud: CanvasLayer) -> void:
	player.inventory.from_dict({"dirt": 7, "wood": 2})
	player.inventory.ensure_layout()
	player.inventory.set_layout(["dirt", "wood"])
	player.set_dock_assignments(["dirt", "wood", "stone", "torch", "lantern"])
	if not hud.inventory_panel_open():
		hud.toggle_inventory_panel()
	else:
		hud.update_inventory()
	await get_tree().process_frame
	var dock_cell_ok: bool = false
	for child in hud._dock_assignment_row.get_children():
		var cell: Control = child as Control
		if cell == null or cell.is_queued_for_deletion():
			continue
		if str(cell.name) != "InventoryDockSlot1":
			continue
		dock_cell_ok = str(cell.get("slot_kind")) == "dock" \
			and int(cell.get("slot_index")) == 1 \
			and str(cell.get("item_id")) == "wood"
		break
	var wood_before: int = player.inventory.count("wood")
	hud.drop_inventory_slot("backpack", 1, {
		"source": "inventory_board", "kind": "dock", "index": 1, "item_id": "wood"})
	var normal_clear_ok: bool = hud.dock_slot_item(1) == "" \
		and hud.dock_slot_count(1) == 0 \
		and player.inventory.count("wood") == wood_before \
		and hud.hotbar_slot_empty(1)
	player.hotbar[2] = "stone"
	hud.update_inventory()
	hud.drop_inventory_slot("backpack", 2, {
		"source": "inventory_board", "kind": "dock", "index": 2, "item_id": "stone"})
	var zero_clear_ok: bool = hud.dock_slot_item(2) == "" \
		and hud.dock_slot_count(2) == 0 \
		and player.inventory.count("stone") == 0 \
		and hud.hotbar_slot_empty(2)
	_check("focus_inventory_dock_to_backpack",
		dock_cell_ok and normal_clear_ok and zero_clear_ok,
		"cell=%s normal=%s zero=%s dock1=%s dock2=%s wood=%d stone=%d" % [
			str(dock_cell_ok), str(normal_clear_ok), str(zero_clear_ok),
			hud.dock_slot_item(1), hud.dock_slot_item(2),
			player.inventory.count("wood"), player.inventory.count("stone")])
	_finish_if_focus("inventory")


func _write_result_file(failed: int, failed_names: Array) -> void:
	# R-04: CI/verifier can point the results file at a known absolute path.
	var path := "user://smoke_results.json"
	var override := OS.get_environment("COHERONIA_RESULTS_PATH")
	if override != "":
		path = override
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"result": "PASS" if failed == 0 else "FAIL",
		"passed": _results.size() - failed,
		"total": _results.size(),
		"failed": failed_names,
		# R-03: split reporting + run metadata.
		"skipped": _skipped.size(),
		"skipped_names": _skipped,
		"suites": _suites,
		"duration_sec": float(Time.get_ticks_msec() - _start_ms) / 1000.0,
		"commit": OS.get_environment("COHERONIA_COMMIT"),
		"persistence_root": GameState.persistence_root,
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


## R-08 slice 3: retire every loose ground item drop so each drop check starts on
## clean ground. remove_from_group first (queue_free is deferred) so a scan in the
## same frame cannot see the outgoing drops.
func _r08_clear_ground_drops() -> void:
	for d in get_tree().get_nodes_in_group("item_drops"):
		d.remove_from_group("item_drops")
		d.queue_free()


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
