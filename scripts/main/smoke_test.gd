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
const HudInventoryRulesScript := preload("res://scripts/ui/hud/hud_inventory_rules.gd")   # S-07.4
const SmokeAudio := preload("res://scripts/main/smoke/smoke_audio.gd")   # S-07.3
const SmokeContracts := preload("res://scripts/main/smoke/smoke_contracts.gd")   # S-07.3
const SmokeSettlerCrew := preload("res://scripts/main/smoke/smoke_settler_crew.gd")   # S-07.3
const SmokeCitizens := preload("res://scripts/main/smoke/smoke_citizens.gd")   # S-07.3
const SmokeCtx := preload("res://scripts/main/smoke/smoke_ctx.gd")   # S-07.3
const SmokePersistence := preload("res://scripts/main/smoke/smoke_persistence.gd")   # S-07.3
const SmokeCraftingFarming := preload("res://scripts/main/smoke/smoke_crafting_farming.gd")   # S-07.3
const SmokeMapScouting := preload("res://scripts/main/smoke/smoke_map_scouting.gd")   # S-07.3
const SmokeEnemies := preload("res://scripts/main/smoke/smoke_enemies.gd")   # S-07.3
const SmokeProgression := preload("res://scripts/main/smoke/smoke_progression.gd")   # S-07.3
const SmokeGoalPanel := preload("res://scripts/main/smoke/smoke_goal_panel.gd")   # S-07.3
const SmokeEquipment := preload("res://scripts/main/smoke/smoke_equipment.gd")   # S-07.3
const SmokeLiquidTraits := preload("res://scripts/main/smoke/smoke_liquid_traits.gd")   # S-07.3
const SmokeSettings := preload("res://scripts/main/smoke/smoke_settings.gd")   # S-07.3
const SmokePerception := preload("res://scripts/main/smoke/smoke_perception.gd")   # Perception + Resonance
const SubjectScript := preload("res://scripts/entities/subject.gd")   # S-07.1c defender marker
# Pinned fingerprints of the seed-2024 medium v3/v4 generated cell maps (see
# _cells_fingerprint). Any future gen change that perturbs an older world trips
# wg_gen_v3_v4_pinned_after_v5. Captured 2026-08-18 after the gen_version 5 seal fix.
const GEN_V3_FINGERPRINT := 119253797091923
const GEN_V4_FINGERPRINT := 118325105647989

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


## True when `node` is `ancestor` or lives somewhere beneath it. Used by the
## S-07.1b char-create contract to prove the action row is OUTSIDE the scroll.
func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var n: Node = node
	while n != null:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false


## Depth-first search for a Button with the given text under `node` (or null).
## Lets a check press a real in-panel button so the actual handler is exercised.
func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found: Button = _find_button_with_text(child, text)
		if found != null:
			return found
	return null


## Smallest connected same-liquid pocket (orthogonal flood fill) among UNDERGROUND
## liquid cells of `cells`, ignoring open surface ponds (depth <= 4). Returns a large
## sentinel when there is no underground liquid. Used by the v4 pool-prune check.
func _smallest_liquid_pocket(cells: Dictionary, surface: Dictionary) -> int:
	var liquids := ["lava", "water"]
	var visited: Dictionary = {}
	var smallest := 1 << 30
	for start: Vector2i in cells:
		if visited.has(start) or not (str(cells[start]) in liquids):
			continue
		var kind: String = str(cells[start])
		var comp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		visited[start] = true
		var underground := false
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			comp.append(c)
			if c.y - int(surface.get(c.x, 0)) > 4:
				underground = true
			for nb: Vector2i in [c + Vector2i(0, 1), c + Vector2i(0, -1),
					c + Vector2i(1, 0), c + Vector2i(-1, 0)]:
				if visited.has(nb):
					continue
				if str(cells.get(nb, "air")) == kind:
					visited[nb] = true
					stack.append(nb)
		if underground:
			smallest = mini(smallest, comp.size())
	return smallest


## Smallest connected pocket of a single block `kind` (orthogonal flood fill), or a
## large sentinel when none exists. Lava is always underground, so no surface filter.
func _smallest_pocket_of(cells: Dictionary, kind: String) -> int:
	var visited: Dictionary = {}
	var smallest := 1 << 30
	for start: Vector2i in cells:
		if visited.has(start) or str(cells[start]) != kind:
			continue
		var n := 0
		var stack: Array[Vector2i] = [start]
		visited[start] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			n += 1
			for nb: Vector2i in [c + Vector2i(0, 1), c + Vector2i(0, -1),
					c + Vector2i(1, 0), c + Vector2i(-1, 0)]:
				if not visited.has(nb) and str(cells.get(nb, "air")) == kind:
					visited[nb] = true
					stack.append(nb)
		smallest = mini(smallest, n)
	return smallest


## Order-independent fingerprint of a generated cell map (sum of per-cell string
## hashes), used to pin v3/v4 terrain byte-for-byte so a future gen change to a
## newer version can never silently perturb an older world's output.
func _cells_fingerprint(cells: Dictionary) -> int:
	var acc := 0
	for k: Vector2i in cells:
		acc = (acc + hash("%d,%d=%s" % [k.x, k.y, str(cells[k])])) & 0x7fffffffffffffff
	return acc


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


## Write a smoke fixture PNG under res:// only when res:// is writable
## (source/editor). In an exported PCK res:// is read-only, so the paired
## _check_res_fixture check is skipped there anyway; skipping the write too keeps
## the exported-smoke log free of the inherent, misleading engine error
## "Can't save PNG at path: 'res://...'". No-op under an exported template build;
## unchanged in source. The read-backs already tolerate the absent file.
func _res_write_png(img: Image, res_path: String) -> void:
	if OS.has_feature("template"):
		return
	img.save_png(res_path)


func _run() -> void:
	_start_ms = Time.get_ticks_msec()
	var root: Node2D = get_parent()
	var world: Node2D = root.world
	var player: CharacterBody2D = root.player
	var hall: Node2D = root.town_hall
	var settlement: Node = root.settlement
	var hud: CanvasLayer = root.hud

	# S-07.3 (ctx seam, work order §11): one shared context for the extracted
	# smoke_*.gd modules, built here where all seven handles exist. Cross-section
	# scratch (e.g. _fq01_msg_conn) is added later, at the point it becomes
	# available, before the module that reads it.
	var _ctx := SmokeCtx.new()
	_ctx.harness = self
	_ctx.root = root
	_ctx.world = world
	_ctx.player = player
	_ctx.hall = hall
	_ctx.settlement = settlement
	_ctx.hud = hud

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
	# S-07.5 (F5): the unbounded full-`cells`-scan crop/soil finders were dead
	# (only the bounded work-zone `*_in` variants have live callers) and were
	# removed. This guards against a regression re-introducing a whole-grid scan
	# in the per-frame settler search path.
	_check("s07_no_unbounded_cell_scan",
		not world.has_method("nearest_ripe_crop") and not world.has_method("nearest_plantable_soil")
			and world.has_method("nearest_ripe_crop_in") and world.has_method("nearest_plantable_soil_in"),
		"unbounded removed; bounded *_in retained")
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
	# S-07.1c: strengthen — a placed torch creates a real PointLight2D node (not
	# merely a has_light_at flag) with positive energy, parented into the world.
	_check("torch_emits_light", world.has_light_at(torch_cell)
		and world._lights[torch_cell] is PointLight2D
		and world._lights[torch_cell].energy > 0.0)
	# The foreground tileset carries occluders so the sun/moon cast terrain shadows
	# (daylight stops at the surface), but a torch is a SHADOWLESS soft glow so the
	# rock it is carved into never occludes its own light.
	_check("light_occlusion_configured",
		world._tilemap.tile_set.get_occlusion_layers_count() > 0
		and not world._lights[torch_cell].shadow_enabled)

	# S-07.1c: a torch placed UNDERGROUND (below the column sky line) still creates
	# a live PointLight2D — cave/night torches are lit, not dark. Open a pocket a
	# few cells under the surface, set a torch there via the world block path (the
	# light-creation path is world._update_light, independent of player reach),
	# assert the light, then restore the cell so later world assertions are stable.
	var _s7c_ux: int = torch_cell.x
	var _s7c_uy: int = world.sky_line(_s7c_ux) + 4
	var _s7c_ucell := Vector2i(_s7c_ux, _s7c_uy)
	var _s7c_uprev: String = world.block_at(_s7c_ucell)
	world.break_block(_s7c_ucell)   # open a pocket below the surface (no loose drop)
	var _s7c_ulit: bool = world.place_block(_s7c_ucell, "torch")
	_check("s07c_underground_torch_lit",
		_s7c_uy > world.sky_line(_s7c_ux) and _s7c_ulit
		and world.has_light_at(_s7c_ucell)
		and world._lights[_s7c_ucell] is PointLight2D
		and world._lights[_s7c_ucell].energy > 0.0,
		"depth=%d skyline=%d placed=%s" % [_s7c_uy, world.sky_line(_s7c_ux), str(_s7c_ulit)])
	# Restore the pocket to whatever was there (keeps later world assertions stable).
	world.break_block(_s7c_ucell)
	if _s7c_uprev != "air" and _s7c_uprev != "":
		world.place_block(_s7c_ucell, _s7c_uprev)

	# S-07.1c-fix: lava (liquid) lights are thinned to a sparse 2x2 grid so a lava
	# lake washes from ~1/4 the lights instead of one broad, shadowless light per
	# cell (which over-brightened and read unstable next to shadowed torch lights).
	# The grid predicate holds; a grid lava cell gets a PointLight2D, its off-grid
	# neighbour does not (covered by the broad grid light); non-liquid torches are
	# never thinned (the torch above lit regardless of its cell parity).
	var _s7c_lgrid := Vector2i(40, 8)   # even,even -> on the grid
	var _s7c_loff := Vector2i(41, 8)    # odd,even  -> off the grid
	for _s7c_lc in [_s7c_lgrid, _s7c_loff]:
		if world._lights.has(_s7c_lc):
			world._lights[_s7c_lc].queue_free()
			world._lights.erase(_s7c_lc)
	world._update_light(_s7c_lgrid, "lava")
	world._update_light(_s7c_loff, "lava")
	var _s7c_grid4 := 0
	for _s7c_gx in range(4):
		for _s7c_gy in range(4):
			if world.lava_light_cell(Vector2i(_s7c_gx, _s7c_gy)):
				_s7c_grid4 += 1
	_check("s07c_lava_lights_thinned",
		world.lava_light_cell(_s7c_lgrid) and not world.lava_light_cell(_s7c_loff)
		and world.has_light_at(_s7c_lgrid) and not world.has_light_at(_s7c_loff)
		and world._lights[_s7c_lgrid] is PointLight2D
		and _s7c_grid4 == 4,   # a 4x4 region keeps 4 of 16 lights (~1/4)
		"grid_lit=%s off_lit=%s per16=%d" % [str(world.has_light_at(_s7c_lgrid)),
			str(world.has_light_at(_s7c_loff)), _s7c_grid4])
	if world._lights.has(_s7c_lgrid):   # clean up the transient test light
		world._lights[_s7c_lgrid].queue_free()
		world._lights.erase(_s7c_lgrid)

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
	_check("load_keeps_torch_light", world.has_light_at(torch_cell)
		and world._lights[torch_cell] is PointLight2D)
	# S-07.1c: the lantern's light also survives load — re-derived from the
	# restored block as a real PointLight2D with positive energy, not just the torch.
	_check("s07c_load_keeps_lantern_light",
		world.block_at(lantern_cell) == "lantern"
		and world.has_light_at(lantern_cell)
		and world._lights[lantern_cell] is PointLight2D
		and world._lights[lantern_cell].energy > 0.0,
		"block=%s lit=%s" % [world.block_at(lantern_cell), str(world.has_light_at(lantern_cell))])
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

	# v4: liquid pool pruning drops sub-minimum pockets, so a v4 world has no lone
	# single-cell (or otherwise below-threshold) lava/water pocket, while the older
	# v3 world (no pruning) keeps them — proving both the prune and the version gate.
	var _min_pool: int = int(WorldConfig.settings().get("liquids", {}).get("min_pool_volume", 5))
	var _wg4: Dictionary = WorldGen.generate(2024, WorldConfig.new({"size": "medium", "gen_version": 4}))
	var _wg4_cells: Dictionary = _wg4["cells"]
	# Smallest connected same-liquid pocket in each world (orthogonal flood fill),
	# but ignore the open SURFACE ponds — pruning targets underground pockets only.
	var _wg4_surf: Dictionary = _wg4["surface"]
	var _v4_min_pocket: int = _smallest_liquid_pocket(_wg4_cells, _wg4_surf)
	var _v3_min_pocket: int = _smallest_liquid_pocket(_wg3["cells"], _wg3_surf)
	_check("wg4_prunes_small_liquid_pools",
		_v4_min_pocket >= _min_pool and _v3_min_pocket < _min_pool,
		"v4 smallest pocket=%d (>= %d) vs v3 smallest=%d (< %d)"
			% [_v4_min_pocket, _min_pool, _v3_min_pocket, _min_pool])

	# v4 lava must still POOL (with volume), not be pruned away: the prune-only
	# approach wiped the thin per-cell v3 lava, so v4 pools lava to a depth. Assert
	# v4 has real lava and its smallest lava pocket clears the prune floor.
	var _v4_lava_cells := 0
	for _lc: Vector2i in _wg4_cells:
		if str(_wg4_cells[_lc]) == "lava":
			_v4_lava_cells += 1
	var _v4_lava_min: int = _smallest_pocket_of(_wg4_cells, "lava")
	_check("wg4_lava_pools_survive",
		_v4_lava_cells > 0 and _v4_lava_min >= _min_pool,
		"v4 lava cells=%d smallest lava pocket=%d (>= %d)"
			% [_v4_lava_cells, _v4_lava_min, _min_pool])

	# gen_version 5 (2026-08-18): the seal pass walls EVERY flowable face, not just
	# air. Unit-test the predicate directly: a non-solid decoration (tree) neighbour
	# is an OPEN face at v5 (so it gets sealed) but was treated as closed at v4 (the
	# bug the fix targets); air is open in every version; a solid is always a barrier.
	var _seal_cells := {
		Vector2i(0, 0): "water", Vector2i(1, 0): "tree_trunk", Vector2i(2, 0): "stone"}
	var _tree_open_v5: bool = WorldGen._is_open_liquid_face(_seal_cells, Vector2i(1, 0), 5)
	var _tree_open_v4: bool = WorldGen._is_open_liquid_face(_seal_cells, Vector2i(1, 0), 4)
	var _air_open_v5: bool = WorldGen._is_open_liquid_face(_seal_cells, Vector2i(9, 9), 5)
	var _air_open_v4: bool = WorldGen._is_open_liquid_face(_seal_cells, Vector2i(9, 9), 4)
	var _solid_open_v5: bool = WorldGen._is_open_liquid_face(_seal_cells, Vector2i(2, 0), 5)
	_check("wg5_seal_predicate_gates_decorations",
		_tree_open_v5 and not _tree_open_v4 and _air_open_v5 and _air_open_v4
			and not _solid_open_v5,
		"tree v5=%s v4=%s | air v5=%s v4=%s | solid v5=%s" % [_tree_open_v5,
			_tree_open_v4, _air_open_v5, _air_open_v4, _solid_open_v5])

	# And the whole v5 world honours it: NO generated lava/deep-water cell keeps an
	# open face (air OR a flowable decoration). Same seed as the v3/v4 worlds above;
	# strict superset of lq_generated_liquid_encapsulated (which counted air faces).
	var _wg5: Dictionary = WorldGen.generate(2024, WorldConfig.new({"size": "medium", "gen_version": 5}))
	var _wg5_cells: Dictionary = _wg5["cells"]
	var _wg5_w: int = int(_wg5["width"])
	var _wg5_h: int = int(_wg5["height"])
	var _wg5_surf: Dictionary = _wg5["surface"]
	var _v5_open := 0
	for _c5: Vector2i in _wg5_cells:
		var _id5: String = str(_wg5_cells[_c5])
		var _deep5: bool = _c5.y - int(_wg5_surf.get(_c5.x, 0)) > 6
		if _id5 != "lava" and not (_id5 == "water" and _deep5):
			continue   # surface ponds are intentionally exposed at the top
		for _nb5: Vector2i in [_c5 + Vector2i(0, 1), _c5 + Vector2i(0, -1),
				_c5 + Vector2i(1, 0), _c5 + Vector2i(-1, 0)]:
			if _nb5.x < 0 or _nb5.x >= _wg5_w or _nb5.y < 0 or _nb5.y >= _wg5_h:
				continue
			if WorldGen._is_open_liquid_face(_wg5_cells, _nb5, 5):
				_v5_open += 1
				break
	_check("wg5_generated_pools_fully_sealed", _v5_open == 0,
		"v5 generated liquid cells with an open (air/decoration) face: %d (must be 0)" % _v5_open)

	# Save-compat: the v5 seal predicate is a no-op for v3/v4, so their generated
	# terrain must stay byte-identical. Pin an order-independent fingerprint of the
	# v3 and v4 cell maps (seed 2024) — any future change that perturbs older worlds
	# trips this guard. (Determinism is also implied: regenerating gives the same map.)
	var _v3_fp: int = _cells_fingerprint(_wg3["cells"])
	var _v4_fp: int = _cells_fingerprint(_wg4_cells)
	_check("wg_gen_v3_v4_pinned_after_v5",
		_v3_fp == GEN_V3_FINGERPRINT and _v4_fp == GEN_V4_FINGERPRINT,
		"v3 fp=%d (want %d) v4 fp=%d (want %d)"
			% [_v3_fp, GEN_V3_FINGERPRINT, _v4_fp, GEN_V4_FINGERPRINT])

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

	# --- Liquid physics + Character traits/Calling on the player ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_liquid_traits.gd.
	var _smoke_liquid := SmokeLiquidTraits.new()
	add_child(_smoke_liquid)
	await _smoke_liquid.run(_ctx)
	_smoke_liquid.queue_free()

	# --- Enemy registry + FQ-13 variety/variants: data-driven spawning ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_enemies.gd.
	var _smoke_enemies := SmokeEnemies.new()
	add_child(_smoke_enemies)
	await _smoke_enemies.run(_ctx)
	_smoke_enemies.queue_free()

	# --- Perception + Resonance: LOS veil + remembered-terrain memory ---
	var _smoke_perception := SmokePerception.new()
	add_child(_smoke_perception)
	await _smoke_perception.run(_ctx)
	_smoke_perception.queue_free()

	# --- FQ-14: state-driven goal panel ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_goal_panel.gd.
	var _smoke_goal := SmokeGoalPanel.new()
	add_child(_smoke_goal)
	await _smoke_goal.run(_ctx)
	_smoke_goal.queue_free()

	# --- FQ-15: map / scouting / navigation ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_map_scouting.gd.
	var _smoke_map := SmokeMapScouting.new()
	add_child(_smoke_map)
	await _smoke_map.run(_ctx)
	_smoke_map.queue_free()

	# --- Progression MVP + Ancestry Phase B + inventory Waves A-F (v0.6) ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_progression.gd.
	var _smoke_prog := SmokeProgression.new()
	add_child(_smoke_prog)
	await _smoke_prog.run(_ctx)
	_smoke_prog.queue_free()

	# --- FQ-03 / FQ-04: equipment model + first combat gear (sword/armor) ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_equipment.gd.
	var _smoke_equip := SmokeEquipment.new()
	add_child(_smoke_equip)
	await _smoke_equip.run(_ctx)
	_smoke_equip.queue_free()

	# --- FQ-11 / FQ-12 / FQ-05: station chain, farming, attunement ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_crafting_farming.gd.
	var _smoke_crafting := SmokeCraftingFarming.new()
	add_child(_smoke_crafting)
	await _smoke_crafting.run(_ctx)
	_smoke_crafting.queue_free()

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

	# (h) 2026-08-18 constellation redesign: the star-map draws constellation LINK
	# lines between the Path stars, selecting a different star switches the inspector,
	# an available star exists, and the Learn action emits its id for purchase. The
	# real purchase handler is detached around the probe so this never mutates
	# character progression mid-suite.
	var _sc = hud.skill_panel()
	_sc.setup(root)
	var _sc_links: int = _sc.link_count()
	_sc.select_node("familiar_ground")
	var _sc_info_a: String = _sc.info_text()
	_sc.select_node("stonewise")
	var _sc_info_b: String = _sc.info_text()
	var _sc_avail := ""
	for _sc_k in _sc._node_states:
		if str(_sc._node_states[_sc_k]) == "available":
			_sc_avail = str(_sc_k)
			break
	var _sc_had_real: bool = _sc.purchase_requested.is_connected(root._on_perk_purchase_requested)
	if _sc_had_real:
		_sc.purchase_requested.disconnect(root._on_perk_purchase_requested)
	var _sc_emitted := {"id": ""}
	var _sc_probe := func(pid: String) -> void: _sc_emitted["id"] = pid
	_sc.purchase_requested.connect(_sc_probe)
	if _sc_avail != "":
		_sc.select_node(_sc_avail)
		_sc._on_buy_pressed()
	_sc.purchase_requested.disconnect(_sc_probe)
	if _sc_had_real:
		_sc.purchase_requested.connect(root._on_perk_purchase_requested)
	_check("skill_constellation_links_select_purchase",
		_sc_links > 0 and _sc_info_a != _sc_info_b
			and _sc_avail != "" and str(_sc_emitted["id"]) == _sc_avail,
		"links=%d select_switch=%s avail=%s emitted=%s" % [_sc_links,
			str(_sc_info_a != _sc_info_b), _sc_avail, str(_sc_emitted["id"])])

	# (i) 2026-08-18 interior sun/moon light: the cave shader admits a body's light
	# down a clear slant path. The GDScript side of that contract: the celestial ray
	# always points UP and swings east->west across the day, day admits fully, a new
	# moon admits nothing and a full moon some, and world.set_sky_admission pushes
	# those values onto the shared cave-depth shader material.
	var _cel = CelestialScript.new()
	_cel._time = 0.32
	var _dir_noon: Vector2 = _cel.sky_direction()
	_cel._time = 0.05
	var _dir_dawn: Vector2 = _cel.sky_direction()
	_cel._time = 0.60
	var _dir_dusk: Vector2 = _cel.sky_direction()
	var _day_admit: float = _cel.sky_admit_strength()
	_cel._time = 0.80
	_cel._phase_f = 0.5
	var _full_admit: float = _cel.sky_admit_strength()
	_cel._phase_f = 0.0
	var _new_admit: float = _cel.sky_admit_strength()
	var _dir_ok: bool = _dir_noon.y < 0.0 and _dir_dawn.y < 0.0 and _dir_dusk.y < 0.0 \
		and _dir_dawn.x < 0.0 and _dir_dusk.x > 0.0 and absf(_dir_noon.x) < 0.2
	var _strength_ok: bool = is_equal_approx(_day_admit, 1.0) \
		and _full_admit > 0.4 and _new_admit < 0.05
	var _plumb_ok := true
	world.set_sky_admission(Vector2(0.3, -1.0), 0.7)
	if world._cave_material != null:
		var _u_str: float = float(world._cave_material.get_shader_parameter("sky_admit_strength"))
		var _u_dir: Vector2 = world._cave_material.get_shader_parameter("sky_dir")
		_plumb_ok = is_equal_approx(_u_str, 0.7) \
			and _u_dir.is_equal_approx(Vector2(0.3, -1.0).normalized())
	_cel.free()
	_check("s07_sky_admission_direction_strength_plumbing",
		_dir_ok and _strength_ok and _plumb_ok,
		"noon=%s dawn=%s dusk=%s day=%.2f full=%.2f new=%.2f plumb=%s" % [str(_dir_noon),
			str(_dir_dawn), str(_dir_dusk), _day_admit, _full_admit, _new_admit, str(_plumb_ok)])

	# Phase B: the sun and moon ENTER from beyond the left edge and EXIT beyond the
	# right edge — the whole body (corona/halo, bounded by SUN/MOON_MAX_EXTENT) clears
	# the frame instead of popping in mid-sky. Pure geometry off positions() (no render).
	var _celv := Rect2(0.0, 0.0, 1280.0, 720.0)
	var _cel_left: float = _celv.position.x
	var _cel_right: float = _celv.position.x + _celv.size.x
	var _cel_cx: float = _celv.position.x + _celv.size.x * 0.5
	var _cel_ns: float = CelestialScript.NIGHT_START
	var _cel_se: float = CelestialScript.SUN_MAX_EXTENT
	var _cel_me: float = CelestialScript.MOON_MAX_EXTENT
	var _cel_tol := 1.0
	var _cel_sun0: Vector2 = CelestialScript.positions(0.0, _celv)["sun"]
	var _cel_sun_set: Vector2 = CelestialScript.positions(_cel_ns - 0.0001, _celv)["sun"]
	var _cel_moon0: Vector2 = CelestialScript.positions(_cel_ns, _celv)["moon"]
	var _cel_moon_set: Vector2 = CelestialScript.positions(1.0 - 0.0001, _celv)["moon"]
	var _cel_noon: Vector2 = CelestialScript.positions(_cel_ns * 0.5, _celv)["sun"]
	var _cel_mid: Vector2 = CelestialScript.positions(_cel_ns + (1.0 - _cel_ns) * 0.5, _celv)["moon"]
	# t=0 sunrise: rightmost extent at/left of the left edge.
	var _cel_sun_enters: bool = _cel_sun0.x + _cel_se <= _cel_left + _cel_tol
	# just before NIGHT_START: leftmost extent at/right of the right edge.
	var _cel_sun_exits: bool = _cel_sun_set.x - _cel_se >= _cel_right - _cel_tol
	# t=NIGHT_START moonrise: rightmost extent at/left of the left edge.
	var _cel_moon_enters: bool = _cel_moon0.x + _cel_me <= _cel_left + _cel_tol
	# just before wrap: leftmost extent at/right of the right edge.
	var _cel_moon_exits: bool = _cel_moon_set.x - _cel_me >= _cel_right - _cel_tol
	# midday/midnight: horizontal centre AND above the baseline (arc peak).
	var _cel_noon_peak: bool = absf(_cel_noon.x - _cel_cx) <= _cel_tol and _cel_noon.y < _cel_sun0.y - 1.0
	var _cel_mid_peak: bool = absf(_cel_mid.x - _cel_cx) <= _cel_tol and _cel_mid.y < _cel_moon0.y - 1.0
	# monotonic left-to-right travel across the day (sample strictly within the day
	# branch — t=NIGHT_START would cross into night and reset to the moon's start_x).
	var _cel_mono := true
	var _cel_prevx := -1.0e20
	for _cel_i in range(0, 21):
		var _cel_x: float = (CelestialScript.positions((float(_cel_i) / 20.0) * (_cel_ns - 0.0001), _celv)["sun"] as Vector2).x
		if _cel_x < _cel_prevx:
			_cel_mono = false
		_cel_prevx = _cel_x
	_check("celestial_bodies_enter_and_exit_offscreen",
		_cel_sun_enters and _cel_sun_exits and _cel_moon_enters and _cel_moon_exits
		and _cel_noon_peak and _cel_mid_peak and _cel_mono,
		"sun_in=%s sun_out=%s moon_in=%s moon_out=%s noon=%s mid=%s mono=%s" % [
			str(_cel_sun_enters), str(_cel_sun_exits), str(_cel_moon_enters),
			str(_cel_moon_exits), str(_cel_noon_peak), str(_cel_mid_peak), str(_cel_mono)])

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

	# --- S-07.1b (F7): Calling panel never needs a horizontal scrollbar ---
	# The two Path cards are sized to fit the panel width; the card scroll disables
	# horizontal scrolling and the laid-out canvas width stays within the panel, so
	# no h-scrollbar appears (regression contract for the 640x360 fix). The panel
	# stays valid at 1280x720.
	var _s07cp = hud.skill_panel()
	var _s07cp_calling_lanes := 0
	for _s07cp_lane in root.perk_lanes():
		if str(_s07cp_lane.get("calling", "")) == str(root.current_calling()):
			_s07cp_calling_lanes += 1
	var _s07cp_720: Vector2 = _s07cp.panel_size_for(Vector2(1280, 720))
	var _s07cp_360: Vector2 = _s07cp.panel_size_for(Vector2(640, 360))
	_check("s07_calling_panel_no_hscroll",
		_s07cp.content_h_scroll_disabled()
		and _s07cp.canvas_min_width() <= _s07cp.panel_size().x + 0.5
		and _s07cp_360.x <= 640.0 and _s07cp_720.x <= 1280.0 and _s07cp_720.x > 540.0
		and _s07cp_calling_lanes == 2 and _s07cp.node_count() == 24,
		"h_disabled=%s canvas_w=%.1f panel_w=%.1f lanes=%d nodes=%d s360x=%.1f s720x=%.1f" % [
			str(_s07cp.content_h_scroll_disabled()), _s07cp.canvas_min_width(),
			_s07cp.panel_size().x, _s07cp_calling_lanes, _s07cp.node_count(),
			_s07cp_360.x, _s07cp_720.x])

	# --- S-07.1b (F9): character creation is legible/operable at 640x360 ---
	# Build the real shell char-create screen in isolation (suppressing the smoke
	# scene redirect) forced into the compact layout, and assert its contract: a
	# vertical-only scroll with the action row pinned OUTSIDE it, a typography
	# floor, usable control heights, a non-clipped in-form preview, every selector
	# present, and a creatable default character — with no horizontal scrolling.
	var _cc_ScriptCC := preload("res://scripts/shell/shell_ui.gd")
	var _cc := _cc_ScriptCC.new()
	_cc.suppress_smoke_redirect = true
	_cc._forced_compact = 1   # pin compact before _ready builds the base
	_cc.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_cc)
	_cc.size = Vector2(640, 360)
	_cc._show_char_create()
	for _cc_i in range(3):
		await get_tree().process_frame
	var _cc_scroll: ScrollContainer = _cc._cc_scroll
	var _cc_form: Control = _cc_scroll.get_child(0) if _cc_scroll != null and _cc_scroll.get_child_count() > 0 else null
	var _cc_create: Button = _find_button_with_text(_cc._content, "Create")
	var _cc_back: Button = _find_button_with_text(_cc._content, "Back")
	# structure: form scrolls vertically inside the ScrollContainer; the action row
	# is a sibling of the scroll (outside it) and reachable.
	var _cc_scroll_ok: bool = _cc_scroll != null \
		and _cc_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED \
		and _cc_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED \
		and _cc_form != null and _is_descendant_of(_cc._create_preview, _cc_form)
	var _cc_actions_ok: bool = _cc_create != null and _cc_back != null \
		and not _cc_create.disabled and not _cc_back.disabled \
		and not _is_descendant_of(_cc_create, _cc_scroll) \
		and not _is_descendant_of(_cc_back, _cc_scroll)
	# no horizontal overflow: the laid-out form fits the 640 content width.
	var _cc_form_w: float = _cc_form.get_combined_minimum_size().x if _cc_form != null else 9999.0
	var _cc_no_hscroll: bool = _cc_form_w <= 640.0
	# typography floor: every compact role sits at/above the documented floor.
	var _cc_floor: int = _cc.CC_FONT_FLOOR
	var _cc_type_ok: bool = _cc_floor >= 12 \
		and _cc._cc_fs("header") >= _cc_floor and _cc._cc_fs("body") >= _cc_floor \
		and _cc._cc_fs("note") >= _cc_floor
	# usable control heights in compact.
	var _cc_ctrls_ok: bool = _cc._species_option.custom_minimum_size.y >= 24.0 \
		and _cc._role_option.custom_minimum_size.y >= 24.0 \
		and _cc._appearance_option.custom_minimum_size.y >= 24.0 \
		and _cc._name_edit.custom_minimum_size.y >= 24.0
	# preview present, in the form, and not eating disproportionate vertical space
	# (compact draws it at half the large scale — well under this cap; the large
	# 192px preview would exceed it).
	var _cc_preview_ok: bool = _cc._create_preview != null \
		and _cc._create_preview.get_combined_minimum_size().y <= 160.0
	# every creation selector present and populated.
	var _cc_selectors_ok: bool = _cc._species_option.item_count > 0 \
		and _cc._body_variant_option.item_count > 0 \
		and _cc._appearance_option.item_count > 0 \
		and _cc._role_option.item_count > 0 \
		and _cc._visual_variant_spin != null and _cc._name_edit != null \
		and not _cc._trait_checks.is_empty()
	# a default character is still creatable: create it, confirm, then clean up.
	var _cc_made: Dictionary = GameState.create_character({
		"name": "S07_CC_Probe",
		"species": _cc._option_id(_cc._species_option, _cc._species_ids, "human"),
		"body_variant": _cc._option_id(_cc._body_variant_option, _cc._body_variant_ids, "masculine"),
		"appearance": _cc._option_id(_cc._appearance_option, _cc._appearance_ids, "tan"),
		"role": _cc._option_id(_cc._role_option, _cc._role_ids, BlockRegistry.default_calling()),
		"traits": [],
	})
	var _cc_create_ok: bool = not _cc_made.is_empty()
	if _cc_create_ok:
		GameState.delete_character(str(_cc_made.get("id", "")))
	_check("s07_char_create_640_legibility_contract",
		_cc_scroll_ok and _cc_actions_ok and _cc_no_hscroll and _cc_type_ok
		and _cc_ctrls_ok and _cc_preview_ok and _cc_selectors_ok and _cc_create_ok,
		"scroll=%s actions=%s no_hscroll=%s(form_w=%.1f) type=%s(floor=%d) ctrls=%s preview=%s selectors=%s create=%s" % [
			str(_cc_scroll_ok), str(_cc_actions_ok), str(_cc_no_hscroll), _cc_form_w,
			str(_cc_type_ok), _cc_floor, str(_cc_ctrls_ok), str(_cc_preview_ok),
			str(_cc_selectors_ok), str(_cc_create_ok)])
	_cc.queue_free()

	# --- R-01/R-02/R-03: export-safety, save integrity, isolated verification ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_persistence.gd.
	# The trailing progression/Calling restore below stays here (it reads
	# _cal_prev_role/_fq06_saved_* from earlier sections).
	var _smoke_persistence := SmokePersistence.new()
	add_child(_smoke_persistence)
	await _smoke_persistence.run(_ctx)
	_smoke_persistence.queue_free()

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
	_res_write_png(_fq07_img, "res://art/generated/blocks/smoke_tmp_dirt.png")
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
	# The dock invariant (reconcile_dock) may have cleared the default dock's
	# wood slot earlier in the run when the backpack lacked wood; this sub-check
	# asserts slot 1 = wood, so re-establish the default dock here. No
	# inventory_changed emit follows, so the slot is not reconciled away.
	player.set_dock_assignments(["dirt", "wood", "stone", "torch", "lantern"])
	var _fq07_item_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_fq07_item_img.fill(Color(0.0, 1.0, 1.0))
	_res_write_png(_fq07_item_img, "res://art/generated/items/smoke_tmp_wood.png")
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

	# S-07.1b (F10): the sword swing family now has authored overlays for every
	# live body (previously the sword had no swing art and fell back to the
	# code-drawn arc). Assert the three phase frames resolve for a couple of live
	# species; the renderer picks them up via the <tool>_<body>_swing_<phase>
	# convention. Pick/axe stay hand-authored (unchanged).
	var _sw_frames_ok := true
	for _sw_sp in ["human", "orc"]:
		for _sw_ph in range(3):
			if BlockRegistry.visual_texture("player_gear",
					"sword_crude_%s_swing_%d" % [_sw_sp, _sw_ph]) == null:
				_sw_frames_ok = false
	_check("s07_sword_swing_frames_authored", _sw_frames_ok,
		"human+orc sword_crude 3-phase overlays present=%s" % str(_sw_frames_ok))

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
		_res_write_png(_fq09v_src, _fq09v_path)
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
		_res_write_png(_fq09c_cel_img, _fq09c_cp2)
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
	# First SOLID row of the test column (skip air/water), matching the wall band.
	var _fq09w_sy := 0
	while _fq09w_sy < world.height and not BlockRegistry.is_solid(world.cells.get(Vector2i(_fq09w_x, _fq09w_sy), "air")):
		_fq09w_sy += 1
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
	# S-07.1c-fix: the wall band starts AT the surface row (mining the top block
	# reveals a dirt wall, not the dark under-earth backdrop); the row strictly
	# ABOVE the surface stays open sky (no wall).
	_check("fq09w_walls_deterministic_and_inert",
		_fq09w_same
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy)) == "dirt_wall"
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy + 1)) == "dirt_wall"
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy + _fq09w_dd + 1)) == "stone_wall"
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy - 1)) == ""
		and world.wall_at(Vector2i(_fq09w_x, _fq09w_sy - 3)) == ""
		and world._walls.tile_set.get_physics_layers_count() == 0
		and world._walls.tile_set.get_occlusion_layers_count() == 0,
		"same=%s surface=%s band=%s/%s above_empty=%s phys=%d occ=%d" % [str(_fq09w_same),
			world.wall_at(Vector2i(_fq09w_x, _fq09w_sy)),
			world.wall_at(Vector2i(_fq09w_x, _fq09w_sy + 1)),
			world.wall_at(Vector2i(_fq09w_x, _fq09w_sy + _fq09w_dd + 1)),
			str(world.wall_at(Vector2i(_fq09w_x, _fq09w_sy - 1)) == ""),
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

	# S-07.1c: from the SURFACE ROW down the backing wall ALWAYS resolves — a cell
	# never shows black void (the dark under-earth backdrop) because a wall failed
	# to cover it. Sample several columns and depths starting AT the surface row
	# (the top mineable block) and require a non-empty wall id at each.
	var _s7c_void := Vector2i(-1, -1)
	for _s7c_wx in range(_fq09w_x, mini(_fq09w_x + 12, world.width - 1)):
		var _s7c_top := 0   # first SOLID row (skip air/water), matching the wall band
		while _s7c_top < world.height and not BlockRegistry.is_solid(world.cells.get(Vector2i(_s7c_wx, _s7c_top), "air")):
			_s7c_top += 1
		for _s7c_dep in [0, 1, 4, 14, 40]:
			var _s7c_wc := Vector2i(_s7c_wx, _s7c_top + _s7c_dep)
			if _s7c_wc.y >= world.height:
				continue
			if world.wall_at(_s7c_wc) == "":
				_s7c_void = _s7c_wc
	_check("s07c_underground_walls_cover_below_skyline", _s7c_void == Vector2i(-1, -1),
		"first void cell at/below surface row: %s" % str(_s7c_void))

	# S-07.1c-fix: mining the TOP surface block reveals a dirt wall, never the dark
	# under-earth backdrop. This reproduces the operator report (fresh world, mine a
	# few top blocks -> black background) as a regression guard: find a column's
	# first solid, mine it, and require the now-air cell to expose a backing wall.
	var _s7c_topx: int = clampi(_fq09w_x + 5, 2, world.width - 2)
	var _s7c_topy: int = int(world.surface[_s7c_topx])
	while _s7c_topy < world.height and not BlockRegistry.is_solid(world.block_at(Vector2i(_s7c_topx, _s7c_topy))):
		_s7c_topy += 1   # skip any air above the true first-solid row
	var _s7c_topcell := Vector2i(_s7c_topx, _s7c_topy)
	var _s7c_topprev: String = world.block_at(_s7c_topcell)
	world.break_block(_s7c_topcell)
	_check("s07c_mined_top_block_reveals_wall",
		world.block_at(_s7c_topcell) == "air" and world.wall_at(_s7c_topcell) != "",
		"prev=%s now=%s wall=%s" % [_s7c_topprev, world.block_at(_s7c_topcell),
			world.wall_at(_s7c_topcell)])
	if _s7c_topprev != "air" and _s7c_topprev != "":
		world.place_block(_s7c_topcell, _s7c_topprev)   # restore the surface block

	# S-07.1c: a rear wall reads apart from the solid foreground of the SAME material,
	# for BOTH dirt and stone (the operator saw dirt wall == dirt block). Every wall
	# texture is pushed through wall_tint, so it is DARKER, DESATURATED (flat, not the
	# warm foreground hue), and slightly COOLER (blue-shifted) — a quiet recess, not a
	# loud colour. Averaged over the tile to be robust to per-cell mottle. The wall
	# layer DOES receive light (light_mask 1) so a torch's lit area reads against it
	# underground, but it stays occlusion-free (asserted in
	# fq09w_walls_deterministic_and_inert), so lighting it never casts shadow or
	# changes collision/shelter.
	var _s7c_t: int = world.tile_size()
	var _s7c_wd_ok := true
	var _s7c_wd_detail := ""
	for _s7c_pair in [["dirt", "dirt_wall"], ["stone", "stone_wall"]]:
		var _s7c_fg_img: Image = world._make_block_texture(_s7c_pair[0], _s7c_t).get_image()
		var _s7c_wl_img: Image = world._make_wall_texture(_s7c_pair[1], _s7c_pair[0], _s7c_t).get_image()
		var _s7c_fg := Color(0, 0, 0)
		var _s7c_wl := Color(0, 0, 0)
		var _s7c_np: float = float(_s7c_t * _s7c_t)
		for _s7c_py in range(_s7c_t):
			for _s7c_px in range(_s7c_t):
				var _s7c_cf: Color = _s7c_fg_img.get_pixel(_s7c_px, _s7c_py)
				var _s7c_cw: Color = _s7c_wl_img.get_pixel(_s7c_px, _s7c_py)
				_s7c_fg += Color(_s7c_cf.r, _s7c_cf.g, _s7c_cf.b) / _s7c_np
				_s7c_wl += Color(_s7c_cw.r, _s7c_cw.g, _s7c_cw.b) / _s7c_np
		var _s7c_fg_v: float = maxf(_s7c_fg.r, maxf(_s7c_fg.g, _s7c_fg.b))
		var _s7c_wl_v: float = maxf(_s7c_wl.r, maxf(_s7c_wl.g, _s7c_wl.b))
		# blue proportion b/(r+g+b): a brightness-independent "coolness" that holds
		# for a warm foreground (dirt) AND an already-neutral one (stone).
		var _s7c_fg_bp: float = _s7c_fg.b / maxf(_s7c_fg.r + _s7c_fg.g + _s7c_fg.b, 0.001)
		var _s7c_wl_bp: float = _s7c_wl.b / maxf(_s7c_wl.r + _s7c_wl.g + _s7c_wl.b, 0.001)
		var _s7c_this_ok: bool = _s7c_wl_v < _s7c_fg_v \
			and _s7c_wl_bp > _s7c_fg_bp          # cooler than its foreground
		if not _s7c_this_ok and _s7c_wd_detail == "":
			_s7c_wd_detail = "%s fg=(%.2f,%.2f,%.2f)bp%.2f wall=(%.2f,%.2f,%.2f)bp%.2f" % [_s7c_pair[0],
				_s7c_fg.r, _s7c_fg.g, _s7c_fg.b, _s7c_fg_bp,
				_s7c_wl.r, _s7c_wl.g, _s7c_wl.b, _s7c_wl_bp]
		_s7c_wd_ok = _s7c_wd_ok and _s7c_this_ok
	_check("s07c_wall_distinct_from_foreground",
		_s7c_wd_ok and world._walls.light_mask != 0,
		_s7c_wd_detail if not _s7c_wd_ok else ("dirt+stone walls darker/flatter/cooler; light_mask=%d" % world._walls.light_mask))

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

	# (f-water) S-07.1c: the near-black under-earth backing must begin at the
	# WALL line (first opaque row), never at a surface pond's water top — else
	# the dark tone shows THROUGH the translucent water ("black blocks above a
	# water deposit"). Invariant: no earth quad rises above its column's first
	# solid row. And where the generated world actually holds a surface pond (top
	# surface cell is a liquid, not ground), the backing sits strictly BELOW the
	# water line.
	var _s7w_view := Rect2(0.0, 0.0, float(world.width) * _pr07_tile,
		(_pr07_max + 4.0) * _pr07_tile)
	var _s7w_fills: Dictionary = _fq09w_bd.skirt_rects(_s7w_view, _fq09w_bd._horizon_py)
	var _s7w_at_wall := true
	var _s7w_detail := ""
	for _s7w_r: Rect2 in _s7w_fills["earth"]:
		var _s7w_col := int(round(_s7w_r.position.x / _pr07_tile))
		# off-world border columns clamp to the nearest edge column (matching
		# earth_top_px), so no void shows past the world bounds.
		var _s7w_cc := clampi(_s7w_col, 0, world.width - 1)
		var _s7w_wall_px: float = minf(float(int(world.sky_line(_s7w_cc))) * _pr07_tile,
			_s7w_view.end.y)
		if _s7w_r.position.y < _s7w_wall_px - 0.6:
			_s7w_at_wall = false
			if _s7w_detail == "":
				_s7w_detail = "col=%d top=%.1f wall=%.1f" % [
					_s7w_col, _s7w_r.position.y, _s7w_wall_px]
	var _s7w_pond_cols := 0
	var _s7w_pond_ok := true
	for _s7w_c in world.surface:
		var _s7w_x := int(_s7w_c)
		var _s7w_top := int(world.surface[_s7w_x])
		if BlockRegistry.is_solid(world.cells.get(Vector2i(_s7w_x, _s7w_top), "air")):
			continue   # dry column: the surface top cell is solid ground
		_s7w_pond_cols += 1
		var _s7w_earth: float = _fq09w_bd.earth_top_px(_s7w_x, _fq09w_bd._horizon_py)
		if _s7w_earth <= float(_s7w_top) * _pr07_tile + 0.5:
			_s7w_pond_ok = false
			if _s7w_detail == "":
				_s7w_detail = "pond col=%d water_top=%d earth=%.1f" % [
					_s7w_x, _s7w_top, _s7w_earth]
	_check("s07c_earth_backing_at_wall_line_not_behind_water",
		_s7w_at_wall and _s7w_pond_ok,
		"at_wall=%s pond_ok=%s ponds=%d %s" % [
			str(_s7w_at_wall), str(_s7w_pond_ok), _s7w_pond_cols, _s7w_detail])

	# --- R-07: settings/rebinding, save management, build preview, crafting panel ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_settings.gd.
	var _smoke_settings := SmokeSettings.new()
	add_child(_smoke_settings)
	await _smoke_settings.run(_ctx)
	_smoke_settings.queue_free()

	# --- R-08 (settler crew): farmhand/repairer/assignment/work-zone + hauler ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_settler_crew.gd.
	var _smoke_crew := SmokeSettlerCrew.new()
	add_child(_smoke_crew)
	await _smoke_crew.run(_ctx)
	_smoke_crew.queue_free()

	# --- R-09 (contracts): directed goals ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_contracts.gd.
	# (The fq09w wall-art/world-restore tail below stays here: it reads
	# _fq09w_storm_was declared in the earlier FQ-09W section.)
	var _smoke_contracts := SmokeContracts.new()
	add_child(_smoke_contracts)
	await _smoke_contracts.run(_ctx)
	_smoke_contracts.queue_free()

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
	_res_write_png(_fq09w_img, _fq09w_tmp)
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

	# (c) the sword uses the same action contract: an attack aims at the target and
	# steps through the profile. S-07.1b (F10): the sword now has an AUTHORED swing
	# family (was procedural-only), so it renders via overlay frames like pick/axe
	# through the same contract.
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
		and not _pr04_atk_proc and _pr04_atk_dir.y < -0.2
		and _pr04_atk_windup == "windup" and _pr04_atk_recovery == "recovery",
		"kind=%s item=%s authored=%s dir=%s windup=%s recovery=%s" % [
			_pr04_atk_kind, _pr04_atk_item, str(not _pr04_atk_proc),
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

	# S-07.1b (F10): a weapon swing spawns exactly one directional slash arc that
	# carries its aim and self-frees like every other action FX (the FX group is
	# empty here after the transient check above).
	var _sa_before: int = get_tree().get_nodes_in_group("action_fx").size()
	player.start_attack_swing(Vector2.RIGHT)
	var _sa_after: int = get_tree().get_nodes_in_group("action_fx").size()
	var _sa_node: Node = null
	for _sa_fx in get_tree().get_nodes_in_group("action_fx"):
		if str(_sa_fx.kind) == "swing_arc":
			_sa_node = _sa_fx
	# Capture presence/aim BEFORE freeing (a freed reference misreports != null).
	var _sa_spawned: bool = _sa_node != null
	var _sa_aimed: bool = _sa_spawned and _sa_node.aim.x > 0.5
	for _sa_fx in get_tree().get_nodes_in_group("action_fx"):
		if is_instance_valid(_sa_fx):
			_sa_fx._process(1.0)
	await get_tree().process_frame
	var _sa_freed := true
	for _sa_fx in get_tree().get_nodes_in_group("action_fx"):
		if str(_sa_fx.kind) == "swing_arc":
			_sa_freed = false
	_check("s07_swing_arc_fx",
		_sa_after == _sa_before + 1 and _sa_spawned and _sa_aimed and _sa_freed,
		"delta=%d spawned=%s aimed=%s freed=%s" % [
			_sa_after - _sa_before, str(_sa_spawned), str(_sa_aimed), str(_sa_freed)])

	# --- FQ-09U (audio): adaptive context music, stem layering, stingers ---
	# S-07.3: order-preserving extraction - this section's body lives verbatim in
	# scripts/main/smoke/smoke_audio.gd; the coordinator runs it in place so the
	# 24 fq09u* checks keep their names + order.
	var _smoke_audio := SmokeAudio.new()
	add_child(_smoke_audio)
	await _smoke_audio.run(_ctx)
	_smoke_audio.queue_free()

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
	# Re-establish the default dock; the toolbar invariant then clears the unheld
	# stone/torch/lantern slots on the emit, leaving dirt/wood live.
	player.set_dock_assignments(["dirt", "wood", "stone", "torch", "lantern"])
	player.selected_slot = 0
	player.inventory_changed.emit()
	var _fq09_counts_ok := true
	for _fq09_i in range(5):
		if str(player.hotbar[_fq09_i]) == "":
			continue   # a cleared (unheld) slot shows no count, by the invariant
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
	# Phase C: the HUD-edit subject is the Goal panel — a still-free-floating widget —
	# because Crest/Events are now docked into the dock wings and are intentionally NOT
	# movable HUD-edit widgets (ownership covered by hud_dock_wings_ownership below).
	var _fq17_before_pos: Vector2 = hud._hud_widgets["goal"].position
	var _fq17_before_size: Vector2 = hud._hud_widget_size(hud._hud_widgets["goal"])
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
	hud._toggle_goal_module()
	var _fq17_visibility_saved: bool = not bool(GameState.profile["hud_layout"]["goal"]["visible"])
	hud._toggle_goal_module()
	hud._hud_edit_selected = "goal"
	hud._nudge_hud_widget(Vector2(8, 0))
	hud._scale_hud_widget(0.25)
	var _fq17_scaled_size: Vector2 = hud._hud_widget_size(hud._hud_widgets["goal"])
	var _fq17_move_size_ok: bool = hud._hud_widgets["goal"].position != _fq17_before_pos \
		and hud._hud_widgets["goal"].scale.is_equal_approx(Vector2.ONE) \
		and _fq17_scaled_size.x > _fq17_before_size.x
	# FQ-20/FQ-22 continuous grip resize: absolute size factor, clamped to
	# [0.5, 2.0], while Control.scale remains one.
	hud._resize_hud_widget("goal", 1.37)
	var _fq20_resized_size: Vector2 = hud._hud_widget_size(hud._hud_widgets["goal"])
	var _fq20_resize_ok: bool = hud._hud_widgets["goal"].scale.is_equal_approx(Vector2.ONE) \
		and is_equal_approx(_fq20_resized_size.x, roundf(_fq17_before_size.x * 1.37))
	hud._resize_hud_widget("goal", 9.0)
	var _fq20_clamped_size: Vector2 = hud._hud_widget_size(hud._hud_widgets["goal"])
	var _fq20_clamp_ok: bool = hud._hud_widgets["goal"].scale.is_equal_approx(Vector2.ONE) \
		and _fq20_clamped_size.x <= roundf(_fq17_before_size.x * 2.0)
	var _fq20_grip_ok: bool = hud._hud_grip_rect("goal").size.x > 0.0
	hud.reset_hud_layout()
	var _fq17_reset_ok: bool = hud._hud_widgets["goal"].position == hud._hud_default_positions["goal"] \
		and hud._hud_widgets["goal"].scale.is_equal_approx(Vector2.ONE) \
		and hud._hud_widget_size(hud._hud_widgets["goal"]) == _fq17_before_size
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
			_fq20_resized_size, _fq20_clamped_size, hud._hud_widgets["goal"].scale,
			_fq17_before_pos, hud._hud_widgets["goal"].position,
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
	# Phase C: Crest/Events are docked into the wings (opened by clicking the wing), so
	# their toolbar chips are removed — the module toolbar keeps Goal / Map / Edit.
	var _fq18_nav_ok := _fq18_toolbar_labels == ["Goal", "Map", "Edit"] \
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

	# S-07.1 (F6/D2): modal occlusion — a full-screen panel sets one global flag
	# (GameState.modal_panel_open) that BOTH the player input freeze
	# (player.gd _physics_process) and the build-preview ghost
	# (build_preview.suppressed()) read, so gameplay input and the placement
	# square are suppressed while a modal is open. Authority: WORK_ORDER_S07.
	var _s07_modal_rest: bool = not GameState.modal_panel_open \
		and root._build_preview != null and not root._build_preview.suppressed()
	hud.toggle_skill_panel()
	var _s07_modal_open: bool = GameState.modal_panel_open and hud._any_modal_panel_open() \
		and root._build_preview.suppressed()
	hud.toggle_skill_panel()
	var _s07_modal_closed: bool = not GameState.modal_panel_open \
		and not root._build_preview.suppressed()
	_check("s07_modal_occludes_hud",
		_s07_modal_rest and _s07_modal_open and _s07_modal_closed,
		"rest=%s open=%s closed=%s" % [str(_s07_modal_rest), str(_s07_modal_open), str(_s07_modal_closed)])

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

	# Negative surface contract (replaces the old positive contextual-stack test): the
	# legacy top-right contextual popup surface is fully removed. Its producer/infra methods
	# no longer exist, and NO floating "<Item> ×N" / "[E] Town Hall" / "✓ Game saved" popup
	# appears after any producing action — while the underlying actions still work and the
	# docked journal stays functional. Do not re-introduce the surface to satisfy this.
	var _ns_api_gone: bool = not hud.has_method("notify_saved") \
		and not hud.has_method("set_interaction_prompt") \
		and not hud.has_method("_build_context_stack") \
		and not hud.has_method("_make_context_entry") \
		and not hud.has_method("_show_context_entry") \
		and not hud.has_method("_position_context_stack")
	# Scan every visible HUD label OUTSIDE the dock (hotbar counts) and inventory board
	# (both legitimately show "×N") for any floating popup text. Returns the offender.
	var _ns_scan := func() -> String:
		for _l in hud.find_children("*", "Label", true, false):
			var _lab: Label = _l
			if _lab == null or not _lab.is_visible_in_tree():
				continue
			if (hud._bottom_dock != null and hud._bottom_dock.is_ancestor_of(_lab)) \
					or (hud._inv_panel != null and hud._inv_panel.is_ancestor_of(_lab)):
				continue
			var _t: String = _lab.text
			if _t == "[E] Town Hall" or _t == "✓ Game saved" or _t.contains(" ×"):
				return _t
		return ""
	var _ns_start_clear: bool = _ns_scan.call() == ""
	# Selection changes, INCLUDING a zero-quantity stack, raise no popup and still update.
	var _ns_slot0: int = player.selected_slot
	var _ns_sel_clear := true
	for _ns_rep in range(2):                      # repeated passes
		for _ns_s in range(player.hotbar.size()):
			player.selected_slot = _ns_s
			hud.update_inventory()
			if _ns_scan.call() != "":
				_ns_sel_clear = false
	var _ns_sel_works: bool = hud._hotbar_selected == player.selected_slot
	player.selected_slot = _ns_slot0
	hud.update_inventory()
	# F5 save path: the save machinery serializes state and the docked journal records the
	# save (exactly as the F5 handler does on success), with no toast produced. (Disk-write
	# success is covered by the dedicated save/load contracts; the smoke sandbox has no
	# persisted shell, so we assert the serialization contract here.)
	var _ns_state: Dictionary = root.save_manager.collect_state()
	root.log_event("Game saved (F5).")   # the real F5 success branch's journal line
	await get_tree().process_frame
	# The newest journal entry is the save line (the history caps at 6, so assert identity,
	# not a growing count).
	var _ns_save_ok: bool = not _ns_state.is_empty() \
		and str(hud._log_entries[hud._log_entries.size() - 1].get("full", "")).contains("Game saved") \
		and _ns_scan.call() == ""
	# Town Hall interaction still opens the correct screen; no "[E] Town Hall" prompt.
	if hud.town_panel_open():
		hud.toggle_town_panel()
	hud.toggle_town_panel()
	var _ns_town_ok: bool = hud.town_panel_open() and _ns_scan.call() == ""
	hud.toggle_town_panel()
	# The docked right-wing journal remains functional.
	hud.log_event("Contextual surface removal probe.", "Probe", "generic")
	await get_tree().process_frame
	var _ns_journal_ok: bool = hud._events_module() != null \
		and hud._event_lines.size() == 3 and hud._event_lines[0].text == "Probe"
	_check("fq19_no_contextual_popup_surface",
		_ns_api_gone and _ns_start_clear and _ns_sel_clear and _ns_sel_works \
		and _ns_save_ok and _ns_town_ok and _ns_journal_ok,
		"api_gone=%s start=%s sel=%s sel_works=%s save=%s town=%s journal=%s offender=\"%s\"" % [
			str(_ns_api_gone), str(_ns_start_clear), str(_ns_sel_clear), str(_ns_sel_works),
			str(_ns_save_ok), str(_ns_town_ok), str(_ns_journal_ok), _ns_scan.call()])

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

	# Phase C-A: the dock stays CENTRED on the viewport at any width — the central
	# hotbar is centred (within 2 logical px) and the left/right outer orb gaps match
	# (within 2 px) — at 1280x720, 1600x900, 1920x1000 (wide expand), and 640x360, and
	# after a live resize (measured on live global rects; the window is restored).
	var _dc_orig_size: Vector2i = DisplayServer.window_get_size()
	var _dc_ok := true
	var _dc_detail := ""
	for _dc_sz in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1000), Vector2i(640, 360)]:
		DisplayServer.window_set_size(_dc_sz)
		await get_tree().process_frame
		await get_tree().process_frame
		var _dc_w: float = get_viewport().get_visible_rect().size.x
		var _dc_center: float = _dc_w * 0.5
		var _dc_hb_off := 999.0
		if hud._hotbar_slots.size() >= 2:
			var _dc_first: Rect2 = (hud._hotbar_slots[0] as Control).get_global_rect()
			var _dc_last: Rect2 = (hud._hotbar_slots[hud._hotbar_slots.size() - 1] as Control).get_global_rect()
			_dc_hb_off = absf((_dc_first.position.x + _dc_last.end.x) * 0.5 - _dc_center)
		var _dc_gap_diff := 999.0
		var _dc_hfill: Control = hud._health_vessel_fill
		var _dc_afill: Control = hud._attunement_vessel_fill
		if _dc_hfill != null and _dc_afill != null:
			var _dc_lgap: float = _dc_hfill.get_global_rect().position.x
			var _dc_rgap: float = _dc_w - _dc_afill.get_global_rect().end.x
			_dc_gap_diff = absf(_dc_lgap - _dc_rgap)
		if _dc_hb_off > 2.0 or _dc_gap_diff > 2.0:
			_dc_ok = false
		_dc_detail += "[%dx%d hb_off=%.1f gap_diff=%.1f]" % [_dc_sz.x, _dc_sz.y, _dc_hb_off, _dc_gap_diff]
	DisplayServer.window_set_size(_dc_orig_size)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("hud_dock_centered_symmetric", _dc_ok, _dc_detail)

	# Phase C review-correction: there is NO persistent summary surface above the dock.
	# The SelectedItemChip node and its rect are gone from the runtime and BOTH layouts;
	# giving the player ore+food produces no persistent label/chrome; the five slot counts
	# still update. (There is no floating selected-item popup either — see the negative
	# contextual-surface contract above.)
	var _nss_inv_before: Dictionary = player.inventory.to_dict()
	var _nss_no_node: bool = hud.find_child("SelectedItemChip", true, false) == null
	var _nss_no_rect := true
	for _nss_path in ["res://art/source_templates/hud_dock/hud_dock_layout.json",
			"res://art/generated/ui_painted/hud_dock_layout.json"]:
		var _nss_f := FileAccess.open(_nss_path, FileAccess.READ)
		if _nss_f != null:
			if "selected_item_chip_rect" in _nss_f.get_as_text():
				_nss_no_rect = false
			_nss_f.close()
	player.inventory.from_dict({"dirt": 6, "wood": 3, "stone": 2, "ore": 4, "food": 8})
	player.selected_slot = 0
	player.inventory_changed.emit()
	hud.update_inventory()
	var _nss_no_text := true
	for _nss_lbl in hud.find_children("*", "Label", true, false):
		var _nss_l := _nss_lbl as Label
		if _nss_l != null and _nss_l.visible \
				and ("Food ×" in _nss_l.text or "Ore ×" in _nss_l.text):
			_nss_no_text = false
	var _nss_counts_ok := true
	for _nss_i in range(5):
		if str(player.hotbar[_nss_i]) == "":
			continue   # a cleared (unheld) dock slot shows no count, by the invariant
		if hud.hotbar_slot_count(_nss_i) != player.inventory.count(player.hotbar[_nss_i]):
			_nss_counts_ok = false
	player.inventory.from_dict(_nss_inv_before)
	player.inventory_changed.emit()
	hud.update_inventory()
	_check("hud_no_persistent_summary_surface",
		_nss_no_node and _nss_no_rect and _nss_no_text and _nss_counts_ok,
		"no_node=%s no_rect=%s no_text=%s counts=%s" % [str(_nss_no_node),
			str(_nss_no_rect), str(_nss_no_text), str(_nss_counts_ok)])

	# S-07.4: the inventory/loadout policy moved to HudInventoryRules must stay
	# behaviour-identical through hud.gd's delegating wrappers AND produce the
	# expected policy results (layout removal, empty-slot, valid-index, tool-slot,
	# deterministic sort, item + equipment tooltips, equipment-slot order).
	var _hir := HudInventoryRulesScript
	var _hir_layout: Array = ["dirt", "wood", "dirt", ""]
	var _hir_removed: Array = hud._layout_without_item(_hir_layout, "dirt")
	var _hir_slot := {"id": "weapon", "display_name": "Weapon"}
	var _hir_parity: bool = \
		_hir_removed == _hir.layout_without_item(_hir_layout, "dirt") \
		and hud._first_empty_layout_index(_hir_layout) == _hir.first_empty_layout_index(_hir_layout) \
		and hud._valid_layout_index(2, _hir_layout) == _hir.valid_layout_index(2, _hir_layout) \
		and hud._is_tool_slot("pickaxe") == _hir.is_tool_slot("pickaxe") \
		and hud._inventory_sort_key("wood") == _hir.inventory_sort_key("wood") \
		and hud._item_tooltip("wood") == _hir.item_tooltip("wood") \
		and hud._equipment_short_label("weapon", "") == _hir.equipment_short_label("weapon", "") \
		and hud._equipment_tooltip(_hir_slot, "") == _hir.equipment_tooltip(_hir_slot, "") \
		and hud._equipment_board_slots() == _hir.equipment_board_slots()
	var _hir_board: Array = _hir.equipment_board_slots()
	var _hir_correct: bool = \
		_hir_removed == ["", "wood", "", ""] \
		and _hir.first_empty_layout_index(_hir_layout) == 3 \
		and _hir.first_empty_layout_index(["a", "b"]) == 2 \
		and not _hir.valid_layout_index(4, _hir_layout) \
		and _hir.is_tool_slot("pickaxe") and _hir.is_tool_slot("axe") \
		and not _hir.is_tool_slot("weapon") \
		and _hir.inventory_sort_key("dirt") < _hir.inventory_sort_key("iron_ore") \
		and _hir.item_tooltip("wood").begins_with(BlockRegistry.display_name("wood")) \
		and _hir.equipment_tooltip(_hir_slot, "").ends_with("Empty") \
		and _hir_board.size() == hud.equipment_slot_count() \
		and str(_hir_board[0].get("id", "")) == "weapon"
	_check("s07_hud_inventory_rules_delegates", _hir_parity and _hir_correct,
		"parity=%s correct=%s removed=%s empty=%d slots=%d" % [str(_hir_parity),
			str(_hir_correct), str(_hir_removed),
			_hir.first_empty_layout_index(_hir_layout), _hir_board.size()])
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
	# Assign wood (held) to dock slot 4: _assign_dock_item moves it out of its
	# current dock slot (1) and puts that slot's previous item back — which is
	# empty here, because the default dock's stone/torch/lantern slots were
	# cleared by the toolbar invariant (those items are not held). So slot 1 is
	# left empty rather than showing lantern (the pre-invariant behaviour).
	hud.drop_inventory_slot("dock", 4, {
		"source": "inventory_board", "kind": "backpack", "index": 0, "item_id": "wood"})
	var _fq09_dock_assigned: bool = hud.dock_slot_item(4) == "wood" \
		and hud.dock_slot_item(1) == ""
	hud.drop_inventory_slot("dock", 1, {
		"source": "inventory_board", "kind": "dock", "index": 4, "item_id": "wood"})
	var _fq09_dock_restored: bool = hud.dock_slot_item(1) == "wood" \
		and hud.dock_slot_item(4) == ""
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
	# Per-tier tool icons (2026-08-12 art pass): a pick/axe is one upgradeable tool,
	# but the character/equipment panel shows its CURRENT tier via pick_item_for_tier
	# / axe_item_for_tier, and those tiered ids now resolve their OWN authored icon —
	# a forged pick reads apart from a basic one — instead of every tier reusing the
	# generic tool-family swatch. (The legacy `tool_tier_*` token still maps to the
	# family icon; that is asserted separately above.) Assert each tiered tool icon
	# resolves and is visibly DISTINCT from the generic family icon.
	var _fq09_pick_icon: Texture2D = BlockRegistry.item_icon("pick_forged")
	var _fq09_axe_icon: Texture2D = BlockRegistry.item_icon("axe_crude")
	var _fq09_pick_icon_px: Color = _fq09_pick_icon.get_image().get_pixel(8, 8)
	var _fq09_pick_family_px: Color = BlockRegistry.item_icon("pick") \
		.get_image().get_pixel(8, 8)
	var _fq09_axe_icon_px: Color = _fq09_axe_icon.get_image().get_pixel(8, 8)
	var _fq09_axe_family_px: Color = BlockRegistry.item_icon("axe") \
		.get_image().get_pixel(8, 8)
	var _fq09_gear_icon_ok: bool = _fq09_pick_icon != null and _fq09_axe_icon != null \
		and _fq09_pick_icon_px != _fq09_pick_family_px \
		and _fq09_axe_icon_px != _fq09_axe_family_px
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

	# --- Slice C: zero-count dock reconciliation ---
	# player.reconcile_dock (wired to inventory_changed, running BEFORE the HUD
	# render) is the single owner of the toolbar invariant: a non-empty dock slot
	# must reference a dock-assignable item the backpack holds (count > 0). It
	# clears exhausted/unheld slots in place — no shift, no auto-reassign, the
	# selection stays put. Self-contained: full inventory/hotbar state is restored.
	var _zc_inv0: Dictionary = player.inventory.to_dict()
	var _zc_hot0: Array = player.hotbar.duplicate()
	var _zc_slot0: int = player.selected_slot
	var _zc_layout0: Array = player.inventory.layout_to_array()
	var _zc_equip0: Dictionary = player.equipped_dict()

	# Defaults sanitized: applying the default dock against a backpack missing
	# stone/lantern clears exactly those two slots and keeps the possessed three.
	player.inventory.from_dict({"dirt": 1, "wood": 3, "torch": 2})
	player.set_dock_assignments(["dirt", "wood", "stone", "torch", "lantern"])
	player.selected_slot = 0                      # points at dirt (count 1)
	player.inventory_changed.emit()
	var _zc_defaults_sanitized: bool = str(player.hotbar[0]) == "dirt" \
		and str(player.hotbar[1]) == "wood" and str(player.hotbar[2]) == "" \
		and str(player.hotbar[3]) == "torch" and str(player.hotbar[4]) == ""
	# Consume the LAST dirt while its slot is selected: the slot clears, stays
	# selected, selected_item() is empty, and the HUD slot renders empty.
	player.inventory.remove("dirt", 1)
	player.inventory_changed.emit()
	var _zc_final_clears: bool = str(player.hotbar[0]) == "" \
		and player.selected_slot == 0 and player.selected_item() == "" \
		and hud.hotbar_slot_empty(0)
	# Neighbours never shifted.
	var _zc_no_shift: bool = str(player.hotbar[1]) == "wood" \
		and str(player.hotbar[3]) == "torch"
	# Consuming one from a stack > 1 keeps the assignment and updates the count.
	player.inventory.remove("torch", 1)
	player.inventory_changed.emit()
	var _zc_stack_retains: bool = str(player.hotbar[3]) == "torch" \
		and player.inventory.count("torch") == 1 and hud.hotbar_slot_count(3) == 1
	# Reacquiring dirt returns it to the backpack but does NOT repopulate the dock.
	player.inventory.add("dirt", 5)
	player.inventory_changed.emit()
	var _zc_no_auto_readd: bool = str(player.hotbar[0]) == "" \
		and player.inventory.count("dirt") == 5
	# Manual reassignment of the cleared slot still works.
	player.hotbar[0] = "dirt"
	player.inventory_changed.emit()
	var _zc_manual_reassign: bool = str(player.hotbar[0]) == "dirt" \
		and player.selected_item() == "dirt"
	# Save/load cannot restore a stale zero-count reference: a saved dock naming an
	# unheld item reconciles to empty when the carried state is (re)applied+emitted.
	player.set_dock_assignments(["dirt", "wood", "stone", "torch", "lantern"])
	player.inventory.from_dict({"wood": 2})
	player.inventory_changed.emit()
	var _zc_save_load_clean: bool = str(player.hotbar[0]) == "" \
		and str(player.hotbar[1]) == "wood" and str(player.hotbar[3]) == ""
	# Bucket exception: conversion redirects the selected slot to the replacement
	# bucket BEFORE its emit, so reconciliation keeps that (count > 0) slot rather
	# than clearing the just-emptied source id — for the FINAL bucket both ways.
	player.inventory.from_dict({"bucket": 1})
	player.set_dock_assignments(["bucket", "", "", "", ""])
	player.selected_slot = 0
	player.inventory_changed.emit()
	player.inventory.remove("bucket", 1)
	player.inventory.add("bucket_water", 1)
	player._hold_bucket_item("bucket_water")
	player.inventory_changed.emit()
	var _zc_bucket_fill: bool = player.selected_item() == "bucket_water" \
		and str(player.hotbar[0]) == "bucket_water"
	player.inventory.remove("bucket_water", 1)
	player.inventory.add("bucket", 1)
	player._hold_bucket_item("bucket")
	player.inventory_changed.emit()
	var _zc_bucket_empty: bool = player.selected_item() == "bucket" \
		and str(player.hotbar[0]) == "bucket"
	# Equipment ownership is untouched by dock reconciliation.
	var _zc_equip_intact: bool = player.equipped_dict() == _zc_equip0
	_check("dock_zero_count_reconciliation",
		_zc_defaults_sanitized and _zc_final_clears and _zc_no_shift \
		and _zc_stack_retains and _zc_no_auto_readd and _zc_manual_reassign \
		and _zc_save_load_clean and _zc_bucket_fill and _zc_bucket_empty \
		and _zc_equip_intact,
		"defaults=%s final=%s no_shift=%s stack=%s no_readd=%s manual=%s saveload=%s bucket_fill=%s bucket_empty=%s equip=%s" % [
			str(_zc_defaults_sanitized), str(_zc_final_clears), str(_zc_no_shift),
			str(_zc_stack_retains), str(_zc_no_auto_readd), str(_zc_manual_reassign),
			str(_zc_save_load_clean), str(_zc_bucket_fill), str(_zc_bucket_empty),
			str(_zc_equip_intact)])
	# Restore prior inventory/hotbar/selection exactly (direct hotbar restore so
	# reconciliation does not re-filter the pre-existing dock row).
	player.inventory.from_dict(_zc_inv0)
	player.inventory.set_layout(_zc_layout0)
	player.hotbar.clear()
	for _zc_h in _zc_hot0:
		player.hotbar.append(str(_zc_h))
	player.selected_slot = _zc_slot0
	hud.update_inventory()

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

	# --- Settlement Coherence (M1-M5): citizens, roster, defender, raiders, sky, doors, housing ---
	# S-07.3: order-preserving extraction to scripts/main/smoke/smoke_citizens.gd.
	# _fq01_msg_conn is a Callable connected in the FQ-01 section above; it cannot
	# be recomputed, so it rides in ctx.scratch (work order §11.3).
	_ctx.scratch["_fq01_msg_conn"] = _fq01_msg_conn
	var _smoke_citizens := SmokeCitizens.new()
	add_child(_smoke_citizens)
	await _smoke_citizens.run(_ctx)
	_smoke_citizens.queue_free()

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
