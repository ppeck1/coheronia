extends Node
## S-07.3 smoke domain module - enemies (registry + data-driven spawning, FQ-13
## enemy variety, FQ-13P1 sprite variant pools, FQ-13P2 UI placeholders, FQ-13P4
## item-icon/frame semantics). Order-preserving extraction; harness owns _check()
## (via harness.*). SubjectScript is a harness class-local preload const (§11.4a
## category 4), re-preloaded here.

const SubjectScript := preload("res://scripts/entities/subject.gd")
const EnemySpawnDirector := preload("res://scripts/data/enemy_spawn_director.gd")
const EnemyRegistryClass := preload("res://scripts/data/enemy_registry.gd")
const EnemyFactoryClass := preload("res://scripts/data/enemy_factory.gd")


func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this cluster uses.
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player
	var hall = ctx.hall
	var settlement = ctx.settlement
	var hud = ctx.hud
	# --- Enemy registry and data-driven spawning (v0.5) ---
	# Clear any threats left from earlier phases before spawning test enemies.
	for t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(t):
			t.queue_free()
	await get_tree().process_frame

	# Fix 16: use root's shared registry instances instead of creating duplicates.
	var enemy_reg = root._enemy_registry
	harness._check("enemies_json_loads", enemy_reg.live_defs().size() == 12,
		"%d live defs" % enemy_reg.live_defs().size())

	# S-07.1c: every FRESH enemy spawns at full health — hp == max_hp and the hurt
	# bar reads exactly 1.0 across ALL live enemy ids. A frail thornrat/ore_tick
	# (hp_mult < 1) must never spawn already showing a partial bar. Regression
	# guard for the spawner's `threat.max_hp = threat.hp` fix.
	var _s7c_fresh_ok := true
	var _s7c_fresh_bad := ""
	for _s7c_def in enemy_reg.live_defs():
		var _s7c_id := str(_s7c_def.get("id", ""))
		var _s7c_e: Node = root.spawn_enemy_for_test(_s7c_id)
		var _s7c_good: bool = _s7c_e != null and _s7c_e.hp == _s7c_e.max_hp \
			and is_equal_approx(_s7c_e.health_bar_ratio(), 1.0)
		if not _s7c_good:
			_s7c_fresh_ok = false
			if _s7c_fresh_bad == "":
				_s7c_fresh_bad = "%s hp=%s max=%s ratio=%s" % [_s7c_id,
					str(_s7c_e.hp) if _s7c_e != null else "null",
					str(_s7c_e.max_hp) if _s7c_e != null else "null",
					("%.2f" % _s7c_e.health_bar_ratio()) if _s7c_e != null else "n/a"]
		if _s7c_e != null and is_instance_valid(_s7c_e):
			_s7c_e.queue_free()
	await get_tree().process_frame
	harness._check("s07c_fresh_enemy_full_health", _s7c_fresh_ok,
		_s7c_fresh_bad if not _s7c_fresh_ok else "all live ids: hp==max_hp, ratio==1.0")

	# S-07.1c: the defender job marker is a sword held BLADE-UP with the crossguard
	# and grip down near the hand — never inverted. Assert the presentation-contract
	# geometry: blade tip is the highest point (most negative y), the crossguard
	# sits below the tip, and the grip is below the crossguard (in the hand).
	var _s7c_sw: Dictionary = SubjectScript.defender_sword_marker()
	var _s7c_tip: Vector2 = _s7c_sw["blade_tip"]
	var _s7c_base: Vector2 = _s7c_sw["blade_base"]
	var _s7c_cg: Vector2 = _s7c_sw["crossguard_l"]
	var _s7c_grip: Vector2 = _s7c_sw["grip_end"]
	harness._check("s07c_defender_sword_blade_up",
		_s7c_tip.y < _s7c_base.y and _s7c_base.y <= _s7c_cg.y \
			and _s7c_grip.y > _s7c_cg.y,
		"tip.y=%.0f base.y=%.0f crossguard.y=%.0f grip.y=%.0f" % [
			_s7c_tip.y, _s7c_base.y, _s7c_cg.y, _s7c_grip.y])

	var slime_node: Node = root.spawn_enemy_for_test("surface_slime")
	harness._check("surface_slime_spawns", slime_node != null
		and str(slime_node.enemy_id) == "surface_slime",
		"id=%s" % (str(slime_node.enemy_id) if slime_node != null else "null"))

	var crawler_node: Node = root.spawn_enemy_for_test("cave_crawler")
	harness._check("cave_crawler_spawns", crawler_node != null
		and str(crawler_node.enemy_id) == "cave_crawler",
		"family=%s" % (str(crawler_node.family) if crawler_node != null else "null"))

	var raider_node: Node = root.spawn_enemy_for_test("raider_basic")
	harness._check("raider_basic_spawns", raider_node != null
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
	harness._check("enemy_drop_on_death", player.inventory.total() > inv_before,
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
	harness._check("save_load_enemy_id", raider_restored,
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
	harness._check("raider_save_load_hall_dps_and_max_hp", raider_hall_dps_ok and raider_max_hp_ok,
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
	harness._check("fq13_new_enemies_live",
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
	harness._check("fq13_thornrat_eats_crop",
		bool(_fq13_thorn.get("targets_crops", false))
		and _fq13_found == _fq13_crop and _fq13_ate
		and world.block_at(_fq13_crop) == "air"
		and player.inventory.count("food") == _fq13_food_before,
		"targets=%s found=%s ate=%s food_delta=%d" % [
			str(_fq13_thorn.get("targets_crops", false)), str(_fq13_found),
			str(_fq13_ate), player.inventory.count("food") - _fq13_food_before])

	# (c) a spawned thornrat carries the crop-eating flag and its fast profile.
	var _fq13_thorn_node: Node = root.spawn_enemy_for_test("thornrat")
	harness._check("fq13_thornrat_profile",
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
	harness._check("fq13_ore_tick_near_ore",
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
	harness._check("fq13_torchbearer_burns_faster",
		_fq13_torch_node != null and _fq13_basic_node != null
		and _fq13_torch_node.hall_dps > _fq13_basic_node.hall_dps
		and _fq13_torch_node.contact_damage > _fq13_basic_node.contact_damage,
		"torch_dps=%.1f basic_dps=%.1f torch_atk=%.1f basic_atk=%.1f" % [
			_fq13_torch_node.hall_dps, _fq13_basic_node.hall_dps,
			_fq13_torch_node.contact_damage, _fq13_basic_node.contact_damage])
	harness._check("fq13_enemy_hp_profile",
		_fq13_torch_node != null and _fq13_thorn_node != null
		and _fq13_torch_node.hp > _fq13_thorn_node.hp,
		"torch_hp=%d thorn_hp=%d" % [
			_fq13_torch_node.hp, _fq13_thorn_node.hp])

	# S-07.1c: the raider_torchbearer carries a PRESENTATION-ONLY torch light that
	# moves with it (a child PointLight2D), while a basic raider stays dark — and
	# spawning it changes NO settlement scoring (light_score) or the world light
	# grid (world._lights). Capture the world/scoring state, spawn fresh, compare.
	var _s7c_ls_before: float = settlement.inputs.get("light_score", 0.0)
	var _s7c_wl_before: int = world._lights.size()
	var _s7c_tb: Node = root.spawn_enemy_for_test("raider_torchbearer")
	var _s7c_rb: Node = root.spawn_enemy_for_test("raider_basic")
	await get_tree().process_frame
	var _s7c_tb_child: bool = _s7c_tb != null and _s7c_tb.has_carried_light() \
		and _s7c_tb._carried_light is PointLight2D \
		and _s7c_tb._carried_light.get_parent() == _s7c_tb
	harness._check("s07c_torchbearer_carries_light",
		_s7c_tb_child and _s7c_rb != null and not _s7c_rb.has_carried_light(),
		"tb_light=%s child=%s rb_light=%s" % [
			str(_s7c_tb.has_carried_light()) if _s7c_tb != null else "null",
			str(_s7c_tb_child),
			str(_s7c_rb.has_carried_light()) if _s7c_rb != null else "null"])
	harness._check("s07c_carried_light_visual_only",
		world._lights.size() == _s7c_wl_before
		and is_equal_approx(settlement.inputs.get("light_score", 0.0), _s7c_ls_before),
		"worldlights %d→%d light_score %.3f→%.3f" % [
			_s7c_wl_before, world._lights.size(),
			_s7c_ls_before, settlement.inputs.get("light_score", 0.0)])
	for _s7c_n in [_s7c_tb, _s7c_rb]:
		if _s7c_n != null and is_instance_valid(_s7c_n):
			_s7c_n.queue_free()
	await get_tree().process_frame

	# (f) a new enemy's drops reach the player on death. R-08 slice 3 routes loot
	# through a ground drop; killed on the player, the adjacent player collects it.
	var _fq13_inv_before: int = player.inventory.total()
	if _fq13_thorn_node != null and is_instance_valid(_fq13_thorn_node):
		_fq13_thorn_node.global_position = player.global_position
		_fq13_thorn_node.drop_chance_override = 1.0
		_fq13_thorn_node.take_hit(99)
	await get_tree().process_frame
	player.collect_ground_drops()
	harness._check("fq13_new_enemy_drops", player.inventory.total() > _fq13_inv_before,
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
	harness._check("fq13p1_enemy_pool_discovered", _p1_pool.size() >= 2,
		"cave_crawler pool=%d" % _p1_pool.size())

	# more than one variant is selectable across different deterministic inputs.
	var _p1_seen := {}
	for _pi in range(40):
		_p1_seen[_p1_script.variant_for("cave_crawler", Vector2i(_pi, 0), 4242, _p1_pool.size())] = true
	harness._check("fq13p1_variants_differ", _p1_seen.size() >= 2,
		"distinct=%d over 40 cells" % _p1_seen.size())

	# same inputs always yield the same choice.
	harness._check("fq13p1_selection_deterministic",
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
	harness._check("fq13p1_selection_stable",
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
	harness._check("fq13p1_new_enemy_pool_live",
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
	harness._check("fq13p2_ui_placeholders_present",
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
	harness._check("fq13p2_slot_frame_consumed",
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
	harness._check("fq13p2_missing_ui_falls_back",
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
	harness._check("fq13p4_item_icon_stable",
		_p4_dirt_a != null and _p4_dirt_a == _p4_dirt_b
		and _p4_meat_a != null and _p4_meat_a == _p4_meat_b
		and BlockRegistry.visual_variant_textures("items", "dirt").is_empty(),
		"dirt_same=%s swatch_same=%s no_item_pool=%s" % [
			str(_p4_dirt_a == _p4_dirt_b), str(_p4_meat_a == _p4_meat_b),
			str(BlockRegistry.visual_variant_textures("items", "dirt").is_empty())])

	# the shared <id>_NN convention is consumed two DISTINCT ways; the manifest
	# documents variant (pick-one) vs animation (ordered opening frames).
	var _p4_fs: String = str(BlockRegistry.visual_assets.get("frame_semantics", ""))
	harness._check("fq13p4_frame_semantics_documented",
		BlockRegistry.visual_assets.has("frame_semantics")
		and "opening" in _p4_fs and "VARIANT" in _p4_fs and "ANIMATION" in _p4_fs,
		"has=%s" % str(BlockRegistry.visual_assets.has("frame_semantics")))

	await _s08_enemy_foundation_baseline(ctx)


## ---------------------------------------------------------------------------
## S-08.0 Enemy Expansion Foundation — parity baseline.
##
## Pins the eight live enemies' effective RUNTIME values so the foundation
## refactor (registry / factory / director) can prove behavior parity. The
## expected profile below is the balance contract (authored in data/enemies.json);
## the numeric HP/contact/hall values are recomputed live from the same inputs the
## spawner uses (threat_hp() baseline, enemy-difficulty axis) so the assertions are
## robust to the harness difficulty rather than hard-coding a single number.
## All checks are additive; no existing check is renamed.
## ---------------------------------------------------------------------------
func _s08_enemy_foundation_baseline(ctx) -> void:
	var harness = ctx.harness
	var root = ctx.root
	var enemy_reg = root._enemy_registry

	# The live set is EXACTLY these eight, and this is the parity contract.
	var _s08_expect := {
		"surface_slime": {
			"family": "surface", "hp_mult": 1.0, "contact": 8.0, "speed": 38.0,
			"hall_mult": 1.0, "crops": false, "walls": false, "lava": false,
			"bubbles": false, "light": false},
		"thornrat": {
			"family": "surface", "hp_mult": 0.7, "contact": 4.0, "speed": 66.0,
			"hall_mult": 1.0, "crops": true, "walls": false, "lava": false,
			"bubbles": false, "light": false},
		"cave_crawler": {
			"family": "underground", "hp_mult": 1.0, "contact": 8.0, "speed": 38.0,
			"hall_mult": 1.0, "crops": false, "walls": false, "lava": false,
			"bubbles": false, "light": false},
		"ore_tick": {
			"family": "underground", "hp_mult": 0.7, "contact": 3.0, "speed": 30.0,
			"hall_mult": 1.0, "crops": false, "walls": false, "lava": false,
			"bubbles": false, "light": false},
		"lava_slime": {
			"family": "underground", "hp_mult": 1.2, "contact": 10.0, "speed": 26.0,
			"hall_mult": 1.0, "crops": false, "walls": false, "lava": true,
			"bubbles": true, "light": false},
		"raider_basic": {
			"family": "raider", "hp_mult": 1.0, "contact": 8.0, "speed": 38.0,
			"hall_mult": 1.0, "crops": false, "walls": false, "lava": false,
			"bubbles": false, "light": false},
		"raider_torchbearer": {
			"family": "raider", "hp_mult": 1.5, "contact": 10.0, "speed": 34.0,
			"hall_mult": 2.5, "crops": false, "walls": false, "lava": false,
			"bubbles": false, "light": true},
		"raider_sapper": {
			"family": "raider", "hp_mult": 1.3, "contact": 9.0, "speed": 32.0,
			"hall_mult": 1.5, "crops": false, "walls": true, "lava": false,
			"bubbles": false, "light": false},
	}

	# (1) the eight FOUNDING enemies must all remain live (parity). S-08.1 activates a
	# ninth (lantern_leech), so this asserts the eight are preserved as a subset rather
	# than that the total is exactly eight; the ninth activation + total live count are
	# checked separately by s08_1_lantern_leech_activated.
	var _s08_live_ids := {}
	for _d in enemy_reg.live_defs():
		_s08_live_ids[str(_d.get("id", ""))] = true
	var _s08_set_ok := true
	for _eid in _s08_expect:
		if not _s08_live_ids.has(_eid):
			_s08_set_ok = false
	harness._check("s08_live_set_is_the_eight", _s08_set_ok,
		"founding %d all live=%s live_total=%d ids=%s" % [_s08_expect.size(), str(_s08_set_ok),
			_s08_live_ids.size(), str(_s08_live_ids.keys())])

	# (2) every live enemy's effective runtime values match the parity contract,
	# recomputed from the live threat_hp() baseline and the enemy-difficulty axis.
	var _s08_diff: float = root.config().difficulty("enemy")
	var _s08_base_hp: int = root.threat_hp()
	var _s08_parity_ok := true
	var _s08_first_bad := ""
	var _s08_sev_ok := true
	for _eid in _s08_expect:
		var _ex: Dictionary = _s08_expect[_eid]
		var _n: Node = root.spawn_enemy_for_test(_eid)
		if _n == null:
			_s08_parity_ok = false
			if _s08_first_bad == "":
				_s08_first_bad = "%s: null actor" % _eid
			continue
		var _exp_hp: int = maxi(1, int(round(float(_s08_base_hp) * float(_ex["hp_mult"]))))
		var _exp_contact: float = float(_ex["contact"]) * _s08_diff
		var _exp_hall: float = 4.0 * _s08_diff * float(_ex["hall_mult"])
		var _bad_fields: Array[String] = []
		if str(_n.enemy_id) != _eid:
			_bad_fields.append("id(%s)" % _n.enemy_id)
		if str(_n.family) != str(_ex["family"]):
			_bad_fields.append("family(%s!=%s)" % [_n.family, _ex["family"]])
		if _n.hp != _exp_hp or _n.max_hp != _exp_hp:
			_bad_fields.append("hp(%d/%d!=%d)" % [_n.hp, _n.max_hp, _exp_hp])
		if not is_equal_approx(float(_n.contact_damage), _exp_contact):
			_bad_fields.append("contact(%.3f!=%.3f)" % [_n.contact_damage, _exp_contact])
		if not is_equal_approx(float(_n.hall_dps), _exp_hall):
			_bad_fields.append("hall(%.3f!=%.3f)" % [_n.hall_dps, _exp_hall])
		if not is_equal_approx(float(_n.move_speed), float(_ex["speed"])):
			_bad_fields.append("speed(%.3f!=%.3f)" % [_n.move_speed, float(_ex["speed"])])
		if bool(_n.targets_crops) != bool(_ex["crops"]):
			_bad_fields.append("crops")
		if bool(_n.breaks_walls) != bool(_ex["walls"]):
			_bad_fields.append("walls")
		if bool(_n.lava_immune) != bool(_ex["lava"]):
			_bad_fields.append("lava")
		if bool(_n.emits_bubbles) != bool(_ex["bubbles"]):
			_bad_fields.append("bubbles")
		if (not _n.visual_light.is_empty()) != bool(_ex["light"]):
			_bad_fields.append("light")
		if not _bad_fields.is_empty():
			_s08_parity_ok = false
			if _s08_first_bad == "":
				_s08_first_bad = "%s: %s" % [_eid, ", ".join(_bad_fields)]
		# severity is a shared constant today (documented truthfulness gap).
		if not is_equal_approx(float(_n.SEVERITY), 10.0):
			_s08_sev_ok = false
		if is_instance_valid(_n):
			_n.queue_free()
	await get_tree().process_frame
	harness._check("s08_enemy_runtime_parity", _s08_parity_ok,
		_s08_first_bad if not _s08_parity_ok else "all 8 match contract (base_hp=%d diff=%.2f)" % [_s08_base_hp, _s08_diff])
	harness._check("s08_enemy_severity_shared_constant", _s08_sev_ok,
		"every live enemy .SEVERITY == 10.0 (shared)")

	# (3) the registry validates the shipped data clean (fail-closed authority).
	var _s08_verr: Array = enemy_reg.validation_errors()
	harness._check("s08_registry_validation_clean", _s08_verr.is_empty(),
		"errors=%d %s" % [_s08_verr.size(), str(_s08_verr).substr(0, 200)])

	# (4) classification: the four categories resolve, unknown ids resolve to "".
	var _s08_cls_ok: bool = enemy_reg.category_of("surface_slime") == "live" \
		and enemy_reg.category_of("ash_wasp") == "planned" \
		and enemy_reg.category_of("broodmother_crawler") == "mini_boss" \
		and enemy_reg.category_of("hollow_king") == "boss" \
		and enemy_reg.category_of("definitely_not_an_enemy") == ""
	harness._check("s08_registry_classification", _s08_cls_ok,
		"slime=%s wasp=%s brood=%s king=%s unknown=%s" % [
			enemy_reg.category_of("surface_slime"), enemy_reg.category_of("ash_wasp"),
			enemy_reg.category_of("broodmother_crawler"), enemy_reg.category_of("hollow_king"),
			"'%s'" % enemy_reg.category_of("definitely_not_an_enemy")])

	# (5) fail-closed spawn queries: only a live id is spawnable; def_for_spawn
	# returns an INDEPENDENT copy for live and {} for planned/mini-boss/unknown,
	# so a typo can never coerce into a default enemy and no caller can mutate the
	# shared authority dict.
	var _s08_live_copy: Dictionary = enemy_reg.def_for_spawn("surface_slime")
	_s08_live_copy["family"] = "TAMPERED"   # mutate the copy...
	var _s08_independent: bool = str(enemy_reg.get_def("surface_slime").get("family", "")) == "surface"
	var _s08_failclosed_ok: bool = enemy_reg.is_spawnable("surface_slime") \
		and not _s08_live_copy.is_empty() and _s08_independent \
		and enemy_reg.def_for_spawn("ash_wasp").is_empty() \
		and not enemy_reg.is_spawnable("ash_wasp") \
		and enemy_reg.def_for_spawn("broodmother_crawler").is_empty() \
		and not enemy_reg.is_spawnable("broodmother_crawler") \
		and enemy_reg.def_for_spawn("definitely_not_an_enemy").is_empty() \
		and not enemy_reg.is_spawnable("definitely_not_an_enemy")
	harness._check("s08_registry_fail_closed_queries", _s08_failclosed_ok,
		"live_spawnable=%s copy_independent=%s planned_empty=%s unknown_empty=%s" % [
			str(enemy_reg.is_spawnable("surface_slime")), str(_s08_independent),
			str(enemy_reg.def_for_spawn("ash_wasp").is_empty()),
			str(enemy_reg.def_for_spawn("definitely_not_an_enemy").is_empty())])

	# (6) the factory is the single construction path and fails closed at SPAWN:
	# an unknown or planned id builds NO actor (never a default Surface Slime).
	for _t0 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t0):
			_t0.queue_free()
	await get_tree().process_frame
	var _s08_unknown_node: Node = root.spawn_enemy_for_test("definitely_not_an_enemy")
	var _s08_planned_node: Node = root.spawn_enemy_for_test("ash_wasp")
	await get_tree().process_frame
	var _s08_after: int = get_tree().get_nodes_in_group("threats").size()
	harness._check("s08_factory_unknown_and_planned_no_actor",
		_s08_unknown_node == null and _s08_planned_node == null and _s08_after == 0,
		"unknown=%s planned=%s live_threats=%d" % [
			str(_s08_unknown_node == null), str(_s08_planned_node == null), _s08_after])

	# (7) save restoration fails closed too: a save array mixing a live id with a
	# non-live/typo id restores ONLY the live actor (no phantom Surface Slime).
	root.apply_threats([
		{"x": 100.0, "y": 100.0, "hp": 2, "max_hp": 3, "enemy_id": "raider_basic"},
		{"x": 120.0, "y": 100.0, "hp": 2, "max_hp": 3, "enemy_id": "ghost_of_typo"},
	])
	await get_tree().process_frame
	var _s08_restored: Array = get_tree().get_nodes_in_group("threats")
	var _s08_ids: Array[String] = []
	for _r in _s08_restored:
		_s08_ids.append(str(_r.enemy_id))
	harness._check("s08_factory_save_restore_fail_closed",
		_s08_restored.size() == 1 and _s08_ids == ["raider_basic"],
		"restored=%d ids=%s" % [_s08_restored.size(), str(_s08_ids)])
	for _r in _s08_restored:
		if is_instance_valid(_r):
			_r.queue_free()
	await get_tree().process_frame

	# (8) the spawn director's decisions match the previously-inlined logic:
	# surface count clamp, raid eligibility (day OR stockpile lure), the roll
	# threshold product, and the cave cap — pure, so checked directly.
	var _s08_dir_ok: bool = \
		EnemySpawnDirector.surface_spawn_count(0, 3.0) == 0 \
		and EnemySpawnDirector.surface_spawn_count(2, 1.0) == 2 \
		and EnemySpawnDirector.surface_spawn_count(2, 3.0) == 5 \
		and EnemySpawnDirector.raid_eligible(3, 5, 30, 25) == true \
		and EnemySpawnDirector.raid_eligible(3, 5, 10, 25) == false \
		and EnemySpawnDirector.raid_eligible(6, 5, 0, 25) == true \
		and is_equal_approx(EnemySpawnDirector.roll_threshold(0.3, 1.0, 1.0), 0.3) \
		and is_equal_approx(EnemySpawnDirector.roll_threshold(0.2, 0.6, 1.4), 0.2 * 0.6 * 1.4) \
		and EnemySpawnDirector.cave_at_cap(3, 3) == true \
		and EnemySpawnDirector.cave_at_cap(2, 3) == false
	harness._check("s08_spawn_director_decisions", _s08_dir_ok,
		"count/eligibility/threshold/cap all match inlined logic")

	# (9) cave enemy selection: lava dweller > ore tick > default crawler, fail-closed
	# against the real registry (only spawnable variants selected).
	var _s08_sel_ok: bool = \
		EnemySpawnDirector.select_cave_enemy_id(true, false, enemy_reg) == "lava_slime" \
		and EnemySpawnDirector.select_cave_enemy_id(false, true, enemy_reg) == "ore_tick" \
		and EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg) == "cave_crawler" \
		and EnemySpawnDirector.select_cave_enemy_id(true, true, enemy_reg) == "lava_slime"
	harness._check("s08_spawn_director_cave_selection", _s08_sel_ok,
		"lava=%s ore=%s none=%s" % [
			EnemySpawnDirector.select_cave_enemy_id(true, false, enemy_reg),
			EnemySpawnDirector.select_cave_enemy_id(false, true, enemy_reg),
			EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg)])

	# (10) explicit dawn/despawn lifecycle policy matches the prior family behavior
	# for all eight live enemies (underground persists; surface/raid recede).
	var _s08_dawn_ok := true
	var _s08_dawn_bad := ""
	for _eid2 in _s08_expect:
		var _n2: Node = root.spawn_enemy_for_test(_eid2)
		var _want_persist: bool = str(_s08_expect[_eid2]["family"]) == "underground"
		if _n2 == null or _n2.persists_through_dawn() != _want_persist:
			_s08_dawn_ok = false
			if _s08_dawn_bad == "":
				_s08_dawn_bad = "%s persist=%s want=%s" % [_eid2,
					(str(_n2.persists_through_dawn()) if _n2 != null else "null"), str(_want_persist)]
		if _n2 != null and is_instance_valid(_n2):
			_n2.queue_free()
	await get_tree().process_frame
	harness._check("s08_dawn_policy_explicit", _s08_dawn_ok,
		_s08_dawn_bad if not _s08_dawn_ok else "underground persists, surface/raid recede (all 8)")

	# (11) the defeat contract carries the defeated enemy's identity/context.
	for _t2 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t2):
			_t2.queue_free()
	await get_tree().process_frame
	var _s08_victim: Node = root.spawn_enemy_for_test("raider_basic")
	_s08_victim.take_hit(999)
	await get_tree().process_frame
	var _s08_ctx: Dictionary = root.last_defeat_context()
	harness._check("s08_defeat_context_identity",
		str(_s08_ctx.get("enemy_id", "")) == "raider_basic"
		and str(_s08_ctx.get("family", "")) == "raider"
		and _s08_ctx.has("position"),
		"ctx=%s" % str(_s08_ctx))

	# (12) the saved-state extension seam does NOT change the save format: a live
	# enemy serializes exactly the base keys (no "extra" block) and its extension
	# state is empty today.
	for _t3 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t3):
			_t3.queue_free()
	await get_tree().process_frame
	var _s08_se: Node = root.spawn_enemy_for_test("surface_slime")
	await get_tree().process_frame
	var _s08_ser: Array = root.serialize_threats()
	var _s08_keys_ok := false
	if _s08_ser.size() >= 1:
		var _keys: Array = _s08_ser[0].keys()
		_keys.sort()
		_s08_keys_ok = _keys == ["enemy_id", "hp", "max_hp", "x", "y"]
	harness._check("s08_save_extension_no_format_change",
		_s08_keys_ok and _s08_se.extra_save_state().is_empty(),
		"keys=%s extra_empty=%s" % [
			(str(_s08_ser[0].keys()) if _s08_ser.size() >= 1 else "none"),
			str(_s08_se.extra_save_state().is_empty())])
	for _t4 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t4):
			_t4.queue_free()
	await get_tree().process_frame

	# (13) FAIL-CLOSED VALIDATION via injected fixture: malformed and duplicate LIVE
	# defs are neither spawnable nor able to reach the factory (pure validation, no
	# nodes created — def_for_spawn returns {} so the factory returns null).
	var _bad_reg = EnemyRegistryClass.new({
		"enemies": [
			{"id": "good_guy", "status": "live", "family": "surface", "contact_damage": 5, "speed": 30, "drops": []},
			{"id": "no_speed", "status": "live", "family": "surface", "contact_damage": 5, "drops": []},
			{"id": "bad_family", "status": "live", "family": "floating", "contact_damage": 5, "speed": 30},
			{"id": "bad_range", "status": "live", "family": "surface", "contact_damage": 5, "speed": -4},
			{"id": "bad_drop", "status": "live", "family": "surface", "contact_damage": 5, "speed": 30, "drops": [{"item_id": "", "chance": 0.5}]},
			{"id": "bad_kind", "status": "live", "family": "surface", "contact_damage": 5, "speed": 30, "actor_kind": "flying_unknown"},
			{"id": "dup", "status": "live", "family": "surface", "contact_damage": 5, "speed": 30},
			{"id": "dup", "status": "live", "family": "raider", "contact_damage": 9, "speed": 30},
		]
	})
	var _bad_ids: Array[String] = ["no_speed", "bad_family", "bad_range", "bad_drop", "bad_kind", "dup"]
	var _bad_ok: bool = _bad_reg.is_spawnable("good_guy") \
		and not _bad_reg.def_for_spawn("good_guy").is_empty() \
		and not _bad_reg.validation_errors().is_empty()
	var _bad_first := ""
	for _bid in _bad_ids:
		var _closed: bool = not _bad_reg.is_spawnable(_bid) \
			and _bad_reg.def_for_spawn(_bid).is_empty() \
			and EnemyFactoryClass.build(_bad_reg.def_for_spawn(_bid), Vector2.ZERO, {}) == null
		if not _closed:
			_bad_ok = false
			if _bad_first == "":
				_bad_first = _bid
	harness._check("s08_registry_rejects_malformed_and_duplicate", _bad_ok,
		"good_spawnable=%s errors=%d first_leak=%s" % [
			str(_bad_reg.is_spawnable("good_guy")), _bad_reg.validation_errors().size(),
			(_bad_first if _bad_first != "" else "none")])

	# (14) UNKNOWN ACTOR/CONTROLLER KIND fails closed at the factory: a live def with
	# an unknown actor_kind builds no actor, while the default simple_ground path
	# (surface_slime) builds normally.
	var _uk_def := {"id": "x", "status": "live", "family": "surface", "contact_damage": 5, "speed": 30, "actor_kind": "burrower_TODO"}
	var _uk_node = EnemyFactoryClass.build(_uk_def, Vector2.ZERO, {})
	var _dk_node: Node = root.spawn_enemy_for_test("surface_slime")
	harness._check("s08_factory_unknown_actor_kind_fails_closed",
		_uk_node == null and _dk_node != null
		and EnemyFactoryClass.actor_kind_known("simple_ground")
		and not EnemyFactoryClass.actor_kind_known("burrower_TODO"),
		"unknown_null=%s default_built=%s known(simple_ground)=%s" % [
			str(_uk_node == null), str(_dk_node != null),
			str(EnemyFactoryClass.actor_kind_known("simple_ground"))])
	if _dk_node != null and is_instance_valid(_dk_node):
		_dk_node.queue_free()
	await get_tree().process_frame

	# (15) SPAWN PATHS USE def_for_spawn, not the raw get_def view: a planned id is
	# present in get_def but empty in def_for_spawn, and the test spawn path (a
	# construction route) builds no actor for it.
	harness._check("s08_spawn_paths_use_def_for_spawn",
		not enemy_reg.get_def("ash_wasp").is_empty()
		and enemy_reg.def_for_spawn("ash_wasp").is_empty()
		and root.spawn_enemy_for_test("ash_wasp") == null,
		"getdef_present=%s def_for_spawn_empty=%s test_spawn_null=%s" % [
			str(not enemy_reg.get_def("ash_wasp").is_empty()),
			str(enemy_reg.def_for_spawn("ash_wasp").is_empty()),
			str(root.spawn_enemy_for_test("ash_wasp") == null)])

	# (16) DIRECTOR RAID INTENTS reproduce the previously-inlined decisions across the
	# raid contexts (day/stockpile eligibility + injected-roll threshold), and the
	# non-lure candidate (thornrat) is day-gated only.
	var _rb_rule: Dictionary = enemy_reg.def_for_spawn("raider_basic").get("spawn_rule", {})
	var _rb_ctx := {
		"enemy_id": "raider_basic", "day": 6,
		"day_threshold": int(_rb_rule.get("day_threshold", 5)),
		"stock": 0, "stock_threshold": int(_rb_rule.get("stockpile_threshold", 25)),
		"uses_stock_lure": true, "base_chance": float(_rb_rule.get("base_chance", 0.3)),
		"density_mult": 1.0, "difficulty": 1.0,
	}
	var _rb_thresh: float = float(_rb_rule.get("base_chance", 0.3))
	var _intent_ok: bool = \
		EnemySpawnDirector.raid_candidate_eligible(_rb_ctx) == true \
		and EnemySpawnDirector.raid_candidate_eligible({"day": 3, "day_threshold": 5, "uses_stock_lure": true, "stock": 30, "stock_threshold": 25}) == true \
		and EnemySpawnDirector.raid_candidate_eligible({"day": 3, "day_threshold": 5, "uses_stock_lure": true, "stock": 10, "stock_threshold": 25}) == false \
		and EnemySpawnDirector.raid_candidate_eligible({"day": 3, "day_threshold": 5, "uses_stock_lure": false}) == false \
		and EnemySpawnDirector.raid_candidate_eligible({"day": 5, "day_threshold": 5, "uses_stock_lure": false}) == true \
		and bool(EnemySpawnDirector.raid_intent(_rb_ctx, _rb_thresh - 0.001).get("spawn")) == true \
		and bool(EnemySpawnDirector.raid_intent(_rb_ctx, _rb_thresh + 0.001).get("spawn")) == false \
		and str(EnemySpawnDirector.raid_intent(_rb_ctx, 0.0).get("enemy_id")) == "raider_basic"
	harness._check("s08_director_raid_intents", _intent_ok,
		"eligibility (day/stock/lure) + roll-threshold intents match inlined logic")

	# --- S-08.1: Lantern Leech vertical slice ---------------------------------
	# (17) lantern_leech is the ninth live enemy with the expected cave-pool profile
	# (underground, frail, cool carried light, underground dawn persistence) without
	# disturbing the founding eight (checked above by s08_enemy_runtime_parity).
	for _llc in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_llc):
			_llc.queue_free()
	await get_tree().process_frame
	var _ll: Node = root.spawn_enemy_for_test("lantern_leech")
	await get_tree().process_frame
	var _ll_diff: float = root.config().difficulty("enemy")
	var _ll_hp: int = maxi(1, int(round(float(root.threat_hp()) * 0.8)))
	var _ll_ok: bool = enemy_reg.is_spawnable("lantern_leech") and enemy_reg.is_valid("lantern_leech") \
		and _ll != null and str(_ll.enemy_id) == "lantern_leech" \
		and str(_ll.family) == "underground" \
		and _ll.hp == _ll_hp and _ll.max_hp == _ll_hp \
		and is_equal_approx(float(_ll.contact_damage), 5.0 * _ll_diff) \
		and is_equal_approx(float(_ll.move_speed), 22.0) \
		and not _ll.visual_light.is_empty() and _ll.has_carried_light() \
		and _ll.persists_through_dawn()
	harness._check("s08_1_lantern_leech_activated", _ll_ok,
		"spawnable=%s live=%d hp=%d/%d(exp %d) light=%s persists=%s" % [
			str(enemy_reg.is_spawnable("lantern_leech")), enemy_reg.live_defs().size(),
			(_ll.hp if _ll != null else -1), (_ll.max_hp if _ll != null else -1), _ll_hp,
			str(_ll != null and _ll.has_carried_light()),
			str(_ll != null and _ll.persists_through_dawn())])

	# (18) the director selects lantern_leech near a cave pool when under cap, and
	# falls back deterministically (crawler at cap / no water; lava wins; water > ore).
	var _ll_sel_ok: bool = \
		EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, true, true) == "lantern_leech" \
		and EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, true, false) == "cave_crawler" \
		and EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, false, true) == "cave_crawler" \
		and EnemySpawnDirector.select_cave_enemy_id(true, false, enemy_reg, true, true) == "lava_slime" \
		and EnemySpawnDirector.select_cave_enemy_id(false, true, enemy_reg, true, true) == "lantern_leech" \
		and EnemySpawnDirector.select_cave_enemy_id(false, true, enemy_reg, false, true) == "ore_tick" \
		and EnemySpawnDirector.select_cave_enemy_id(false, true, enemy_reg, true, false) == "ore_tick"
	harness._check("s08_1_lantern_leech_cave_selection", _ll_sel_ok,
		"water+cap=lantern; at-cap/no-water=crawler; lava wins; water>ore; ore when no water; water+ore at-cap falls back to ore")

	# (19) the SAVE CONTRACT round-trips: a damaged lantern leech restores its id, hp,
	# max_hp, carried light, and dawn policy (not just the id + light).
	_ll.hp = 1   # damage it so the hp/max_hp round-trip is meaningful (max_hp stays 2)
	var _ll_ser: Array = root.serialize_threats()
	root.apply_threats(_ll_ser)
	await get_tree().process_frame
	var _ll_restored: Node = null
	for _r in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_r) and str(_r.enemy_id) == "lantern_leech":
			_ll_restored = _r
	harness._check("s08_1_lantern_leech_saves",
		_ll_restored != null and _ll_restored.hp == 1 and _ll_restored.max_hp == 2
		and _ll_restored.has_carried_light() and _ll_restored.persists_through_dawn(),
		"restored=%s hp=%s max=%s light=%s" % [
			str(_ll_restored != null),
			(str(_ll_restored.hp) if _ll_restored != null else "n/a"),
			(str(_ll_restored.max_hp) if _ll_restored != null else "n/a"),
			str(_ll_restored != null and _ll_restored.has_carried_light())])

	# (20) both drops are REAL loot with a live consumer: a killed lantern leech spills
	# glow_gland + oil as ground drops the player collects, and the craft_lantern_glow
	# recipe actually consumes both from the stockpile to yield a lantern.
	for _lc in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_lc):
			_lc.queue_free()
	await get_tree().process_frame
	var _pl = root.player
	var _hall = root.town_hall
	var _glow_before: int = _pl.inventory.count("glow_gland")
	var _oil_before: int = _pl.inventory.count("oil")
	var _ll_kill: Node = root.spawn_enemy_for_test("lantern_leech")
	_ll_kill.global_position = _pl.global_position
	_ll_kill.drop_chance_override = 1.0
	_ll_kill.take_hit(99)
	await get_tree().process_frame
	_pl.collect_ground_drops()
	var _dropped_ok: bool = _pl.inventory.count("glow_gland") > _glow_before \
		and _pl.inventory.count("oil") > _oil_before
	# craft the lantern from the two materials via the town_hall stockpile path
	_hall.stockpile["glow_gland"] = 1
	_hall.stockpile["oil"] = 1
	var _lantern_before: int = _pl.inventory.count("lantern")
	var _crafted: bool = _hall.craft_from_stockpile("craft_lantern_glow", _pl)
	var _craft_ok: bool = _crafted \
		and _pl.inventory.count("lantern") > _lantern_before \
		and int(_hall.stockpile.get("glow_gland", 0)) == 0 \
		and int(_hall.stockpile.get("oil", 0)) == 0
	harness._check("s08_1_lantern_leech_loot_consumer",
		_dropped_ok and _craft_ok
		and BlockRegistry.item_icon("glow_gland") != null
		and BlockRegistry.item_icon("oil") != null,
		"dropped(glow+oil)=%s crafted=%s lantern_gained=%s inputs_consumed=%s" % [
			str(_dropped_ok), str(_crafted),
			str(_pl.inventory.count("lantern") > _lantern_before),
			str(int(_hall.stockpile.get("glow_gland", 0)) == 0 and int(_hall.stockpile.get("oil", 0)) == 0)])

	for _llc2 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_llc2):
			_llc2.queue_free()
	await get_tree().process_frame

	# --- S-08.2: Sporekin vertical slice --------------------------------------
	# (21) sporekin is the tenth live enemy: underground, frail, NO carried light,
	# underground dawn persistence — without disturbing the earlier live enemies.
	for _sc in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_sc):
			_sc.queue_free()
	await get_tree().process_frame
	var _sk: Node = root.spawn_enemy_for_test("sporekin")
	await get_tree().process_frame
	var _sk_diff: float = root.config().difficulty("enemy")
	var _sk_hp: int = maxi(1, int(round(float(root.threat_hp()) * 0.7)))
	harness._check("s08_2_sporekin_activated",
		enemy_reg.is_spawnable("sporekin") and enemy_reg.is_valid("sporekin")
		and enemy_reg.live_defs().size() == 12
		and _sk != null and str(_sk.enemy_id) == "sporekin"
		and str(_sk.family) == "underground"
		and _sk.hp == _sk_hp and _sk.max_hp == _sk_hp
		and is_equal_approx(float(_sk.contact_damage), 3.0 * _sk_diff)
		and is_equal_approx(float(_sk.move_speed), 30.0)
		and _sk.visual_light.is_empty() and not _sk.has_carried_light()
		and _sk.persists_through_dawn(),
		"spawnable=%s live=%d hp=%d/%d(exp %d) no_light=%s persists=%s" % [
			str(enemy_reg.is_spawnable("sporekin")), enemy_reg.live_defs().size(),
			(_sk.hp if _sk != null else -1), (_sk.max_hp if _sk != null else -1), _sk_hp,
			str(_sk != null and _sk.visual_light.is_empty()),
			str(_sk != null and _sk.persists_through_dawn())])

	# (22) deep-cave selection + cluster sizing: a deep cave with no closer context
	# is sporekin, shallow is crawler; lava/water/ore keep priority; the cluster is
	# clamped to the remaining slots under the underground cap.
	var _sk_sel_ok: bool = \
		EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, false, false, true) == "sporekin" \
		and EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, false, false, false) == "cave_crawler" \
		and EnemySpawnDirector.select_cave_enemy_id(true, false, enemy_reg, false, false, true) == "lava_slime" \
		and EnemySpawnDirector.select_cave_enemy_id(false, true, enemy_reg, false, false, true) == "ore_tick" \
		and EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, true, true, true) == "lantern_leech" \
		and EnemySpawnDirector.cluster_size(0, 2, 3) == 2 \
		and EnemySpawnDirector.cluster_size(1, 2, 3) == 1 \
		and EnemySpawnDirector.cluster_size(2, 2, 3) == 0
	harness._check("s08_2_sporekin_deep_cave_selection", _sk_sel_ok,
		"deep=sporekin; shallow=crawler; lava/water/ore keep priority; cluster clamps to cap")

	# (23) a real deep-cave cluster spawns more than one sporekin at once but never
	# exceeds the underground cap; a cap-full cave spawns none.
	for _sc2 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_sc2):
			_sc2.queue_free()
	await get_tree().process_frame
	var _sk_def: Dictionary = enemy_reg.def_for_spawn("sporekin")
	var _w = root.world
	var _hc: Vector2i = _w.hall_info.get("center_cell", Vector2i(int(_w.width) / 2, 0))
	var _air_cell := Vector2i(_hc.x + 40, int(_w.surface.get(_hc.x + 40, _hc.y)) - 4)
	root._spawn_sporekin_cluster(_sk_def, _air_cell, 0)
	await get_tree().process_frame
	var _cluster_n := 0
	for _t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t) and str(_t.enemy_id) == "sporekin":
			_cluster_n += 1
	for _t2 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t2):
			_t2.queue_free()
	await get_tree().process_frame
	root._spawn_sporekin_cluster(_sk_def, _air_cell, 2)   # existing == cap -> spawns none
	await get_tree().process_frame
	var _capfull_n: int = get_tree().get_nodes_in_group("threats").size()
	harness._check("s08_2_sporekin_cluster",
		_cluster_n == 2 and _capfull_n == 0,
		"cluster=%d (want 2) capfull_adds=%d (want 0)" % [_cluster_n, _capfull_n])

	# (23b) the cluster draws only from the spawn cell's CONNECTED cave space: build a
	# two-cell chamber (A-B) walled off from a separate air pocket, and confirm
	# _connected_air_cells returns {A, B} and never the disconnected island.
	var _ca_A := Vector2i(120, 50)
	var _ca_B := _ca_A + Vector2i(1, 0)
	var _ca_island := _ca_A + Vector2i(3, 0)   # air, but across a wall at A+(2,0)
	var _ca_air: Array[Vector2i] = [_ca_A, _ca_B, _ca_island]
	var _ca_stone: Array[Vector2i] = [
		_ca_A + Vector2i(-1, 0), _ca_A + Vector2i(0, -1), _ca_A + Vector2i(0, 1),
		_ca_B + Vector2i(0, -1), _ca_B + Vector2i(0, 1), _ca_A + Vector2i(2, 0),
		_ca_island + Vector2i(1, 0), _ca_island + Vector2i(0, -1), _ca_island + Vector2i(0, 1)]
	var _ca_saved := {}
	for _c in (_ca_air + _ca_stone):
		_ca_saved[_c] = [_w.cells.get(_c), _w.deltas.get(_c)]
	for _c in _ca_air:
		_w.cells[_c] = "air"
		_w.deltas[_c] = "air"
	for _c in _ca_stone:
		_w.cells[_c] = "stone"
		_w.deltas[_c] = "stone"
	var _ca_out: Array = root._connected_air_cells(_ca_A, 10)
	var _ca_ok: bool = _ca_out.size() == 2 and _ca_out.has(_ca_A) and _ca_out.has(_ca_B) \
		and not _ca_out.has(_ca_island)
	for _c in _ca_saved:
		var _sv: Array = _ca_saved[_c]
		if _sv[0] == null:
			_w.cells.erase(_c)
		else:
			_w.cells[_c] = _sv[0]
		if _sv[1] == null:
			_w.deltas.erase(_c)
		else:
			_w.deltas[_c] = _sv[1]
	harness._check("s08_2_cluster_connected_air", _ca_ok,
		"connected={A,B}=%s island_excluded=%s out=%s" % [
			str(_ca_out.size() == 2), str(not _ca_out.has(_ca_island)), str(_ca_out)])

	# (24) culinary_mushroom is real loot with a FOOD use: a killed sporekin drops it,
	# the player collects it, and cook_culinary_mushroom turns it into food.
	for _t3 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t3):
			_t3.queue_free()
	await get_tree().process_frame
	var _mush_before: int = _pl.inventory.count("culinary_mushroom")
	var _sk_kill: Node = root.spawn_enemy_for_test("sporekin")
	_sk_kill.global_position = _pl.global_position
	_sk_kill.drop_chance_override = 1.0
	_sk_kill.take_hit(99)
	await get_tree().process_frame
	_pl.collect_ground_drops()
	var _mush_dropped: bool = _pl.inventory.count("culinary_mushroom") > _mush_before
	_hall.stockpile["culinary_mushroom"] = 2
	var _food_before: int = _pl.inventory.count("food")
	var _cooked: bool = _hall.craft_from_stockpile("cook_culinary_mushroom", _pl)
	var _cook_ok: bool = _cooked and _pl.inventory.count("food") > _food_before \
		and int(_hall.stockpile.get("culinary_mushroom", 0)) == 0
	harness._check("s08_2_sporekin_loot_food",
		_mush_dropped and _cook_ok and BlockRegistry.item_icon("culinary_mushroom") != null,
		"dropped=%s cooked=%s food_gained=%s" % [str(_mush_dropped), str(_cooked),
			str(_pl.inventory.count("food") > _food_before)])

	# (25) sporekin id + hp round-trip through save.
	for _t4 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t4):
			_t4.queue_free()
	await get_tree().process_frame
	var _sk2: Node = root.spawn_enemy_for_test("sporekin")
	_sk2.hp = 1
	await get_tree().process_frame
	root.apply_threats(root.serialize_threats())
	await get_tree().process_frame
	var _sk_restored: Node = null
	for _t5 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t5) and str(_t5.enemy_id) == "sporekin":
			_sk_restored = _t5
	harness._check("s08_2_sporekin_saves",
		_sk_restored != null and _sk_restored.hp == 1 and _sk_restored.persists_through_dawn(),
		"restored=%s hp=%s" % [str(_sk_restored != null),
			(str(_sk_restored.hp) if _sk_restored != null else "n/a")])

	for _t6 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_t6):
			_t6.queue_free()
	await get_tree().process_frame

	# --- S-08.3: Stoneback Beetle vertical slice -------------------------------
	# (26) stoneback_beetle is the eleventh live enemy: an ARMORED, SLOW underground
	# bruiser (high hp_mult, lowest cave speed), NO carried light, underground dawn
	# persistence — without disturbing the earlier live enemies (parity checked above).
	for _sb in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_sb):
			_sb.queue_free()
	await get_tree().process_frame
	var _bt: Node = root.spawn_enemy_for_test("stoneback_beetle")
	await get_tree().process_frame
	var _bt_diff: float = root.config().difficulty("enemy")
	var _bt_hp: int = maxi(1, int(round(float(root.threat_hp()) * 1.8)))
	harness._check("s08_3_stoneback_beetle_activated",
		enemy_reg.is_spawnable("stoneback_beetle") and enemy_reg.is_valid("stoneback_beetle")
		and enemy_reg.live_defs().size() == 12
		and _bt != null and str(_bt.enemy_id) == "stoneback_beetle"
		and str(_bt.family) == "underground"
		and _bt.hp == _bt_hp and _bt.max_hp == _bt_hp
		and is_equal_approx(float(_bt.contact_damage), 7.0 * _bt_diff)
		and is_equal_approx(float(_bt.move_speed), 16.0)
		and _bt.visual_light.is_empty() and not _bt.has_carried_light()
		and _bt.persists_through_dawn(),
		"spawnable=%s live=%d hp=%d/%d(exp %d) speed=%s no_light=%s persists=%s" % [
			str(enemy_reg.is_spawnable("stoneback_beetle")), enemy_reg.live_defs().size(),
			(_bt.hp if _bt != null else -1), (_bt.max_hp if _bt != null else -1), _bt_hp,
			(str(_bt.move_speed) if _bt != null else "n/a"),
			str(_bt != null and _bt.visual_light.is_empty()),
			str(_bt != null and _bt.persists_through_dawn())])

	# (27) selection priority: a rare stone-cavern cell (stone_rare, not deep) is the
	# beetle; the branch sits BELOW deep/sporekin (a deep cell is still sporekin) and
	# only ever replaces the crawler fallback. lava/water/ore/leech keep priority; a
	# non-rare or at-cap cell (stone_rare=false) falls back to the crawler.
	var _bt_sel_ok: bool = \
		EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, false, false, false, true) == "stoneback_beetle" \
		and EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, false, false, false, false) == "cave_crawler" \
		and EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, false, false, true, true) == "sporekin" \
		and EnemySpawnDirector.select_cave_enemy_id(true, false, enemy_reg, false, false, false, true) == "lava_slime" \
		and EnemySpawnDirector.select_cave_enemy_id(false, true, enemy_reg, false, false, false, true) == "ore_tick" \
		and EnemySpawnDirector.select_cave_enemy_id(false, false, enemy_reg, true, true, false, true) == "lantern_leech"
	harness._check("s08_3_stoneback_cave_selection", _bt_sel_ok,
		"stone_rare=beetle; deep still sporekin; lava/water/ore/leech keep priority; not-rare/at-cap=crawler")

	# (28) the rarity gate is deterministic and portable (no RNG draw): rarity<=0
	# disables it, rarity==1 marks every cell, the same cell always returns the same
	# bucket, and a real rarity yields BOTH beetle and non-beetle cells (genuinely rare).
	var _bt_r_off: bool = not EnemySpawnDirector.stone_cavern_rare(Vector2i(3, 7), 0) \
		and not EnemySpawnDirector.stone_cavern_rare(Vector2i(3, 7), -4)
	var _bt_r_all: bool = EnemySpawnDirector.stone_cavern_rare(Vector2i(3, 7), 1) \
		and EnemySpawnDirector.stone_cavern_rare(Vector2i(-9, 2), 1)
	var _bt_r_det: bool = EnemySpawnDirector.stone_cavern_rare(Vector2i(11, 5), 8) \
		== EnemySpawnDirector.stone_cavern_rare(Vector2i(11, 5), 8)
	var _bt_true := 0
	var _bt_false := 0
	for _bx in range(0, 40):
		for _by in range(0, 40):
			if EnemySpawnDirector.stone_cavern_rare(Vector2i(_bx, _by), 8):
				_bt_true += 1
			else:
				_bt_false += 1
	var _bt_mixed: bool = _bt_true > 0 and _bt_false > 0 and _bt_true < _bt_false
	harness._check("s08_3_stoneback_rarity_gate",
		_bt_r_off and _bt_r_all and _bt_r_det and _bt_mixed,
		"off=%s all=%s deterministic=%s mixed(true=%d<false=%d)=%s" % [
			str(_bt_r_off), str(_bt_r_all), str(_bt_r_det), _bt_true, _bt_false, str(_bt_mixed)])

	# (29) loot is REAL, already-consumed material (no new item/recipe/mechanic): a
	# killed beetle spills its primary drop `stone` as a ground drop the player collects,
	# and an EXISTING sink consumes it — build_station("workbench") spends stone from the
	# stockpile. Stockpile + station state are snapshotted and restored so no cross-module
	# state leaks.
	for _bc in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_bc):
			_bc.queue_free()
	await get_tree().process_frame
	var _stone_before: int = _pl.inventory.count("stone")
	var _bt_kill: Node = root.spawn_enemy_for_test("stoneback_beetle")
	_bt_kill.global_position = _pl.global_position
	_bt_kill.drop_chance_override = 1.0
	_bt_kill.take_hit(99)
	await get_tree().process_frame
	_pl.collect_ground_drops()
	var _stone_dropped: bool = _pl.inventory.count("stone") > _stone_before
	var _wb_was_built: bool = bool(_hall.stations_built.get("workbench", false))
	var _sp_stone_prev: Variant = _hall.stockpile.get("stone", null)
	var _sp_wood_prev: Variant = _hall.stockpile.get("wood", null)
	_hall.stations_built["workbench"] = false
	_hall.stockpile["stone"] = 6
	_hall.stockpile["wood"] = 12
	var _built: bool = _hall.build_station("workbench")
	var _stone_consumed: bool = _built and int(_hall.stockpile.get("stone", 0)) == 0
	_hall.stations_built["workbench"] = _wb_was_built
	if _sp_stone_prev == null:
		_hall.stockpile.erase("stone")
	else:
		_hall.stockpile["stone"] = _sp_stone_prev
	if _sp_wood_prev == null:
		_hall.stockpile.erase("wood")
	else:
		_hall.stockpile["wood"] = _sp_wood_prev
	harness._check("s08_3_stoneback_loot_consumer",
		_stone_dropped and _stone_consumed and BlockRegistry.item_icon("stone") != null,
		"stone_dropped=%s built=%s stone_consumed=%s" % [
			str(_stone_dropped), str(_built), str(_stone_consumed)])

	# (30) stoneback_beetle id + hp/max_hp round-trip through save.
	for _bt4 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_bt4):
			_bt4.queue_free()
	await get_tree().process_frame
	var _bt2: Node = root.spawn_enemy_for_test("stoneback_beetle")
	_bt2.hp = 1
	await get_tree().process_frame
	root.apply_threats(root.serialize_threats())
	await get_tree().process_frame
	var _bt_restored: Node = null
	for _bt5 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_bt5) and str(_bt5.enemy_id) == "stoneback_beetle":
			_bt_restored = _bt5
	harness._check("s08_3_stoneback_saves",
		_bt_restored != null and _bt_restored.hp == 1 and _bt_restored.max_hp == _bt_hp
		and _bt_restored.persists_through_dawn(),
		"restored=%s hp=%s max=%s(exp %d)" % [str(_bt_restored != null),
			(str(_bt_restored.hp) if _bt_restored != null else "n/a"),
			(str(_bt_restored.max_hp) if _bt_restored != null else "n/a"), _bt_hp])

	for _bt6 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_bt6):
			_bt6.queue_free()
	await get_tree().process_frame

	# --- S-08.4: Hollow Stag vertical slice ------------------------------------
	# (31) hollow_stag is the twelfth live enemy: a rare, NON-aggressive SURFACE
	# premium-food quarry (low contact, nimble, no carried light) that — unlike the three
	# underground slices — RECEDES at dawn (surface family). The eleven earlier enemies are
	# unchanged (parity checked above).
	for _hs0 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_hs0):
			_hs0.queue_free()
	await get_tree().process_frame
	var _hs: Node = root.spawn_enemy_for_test("hollow_stag")
	await get_tree().process_frame
	var _hs_diff: float = root.config().difficulty("enemy")
	var _hs_hp: int = maxi(1, int(round(float(root.threat_hp()) * 1.5)))
	harness._check("s08_4_hollow_stag_activated",
		enemy_reg.is_spawnable("hollow_stag") and enemy_reg.is_valid("hollow_stag")
		and enemy_reg.live_defs().size() == 12
		and _hs != null and str(_hs.enemy_id) == "hollow_stag"
		and str(_hs.family) == "surface"
		and _hs.hp == _hs_hp and _hs.max_hp == _hs_hp
		and is_equal_approx(float(_hs.contact_damage), 2.0 * _hs_diff)
		and is_equal_approx(float(_hs.move_speed), 44.0)
		and _hs.visual_light.is_empty() and not _hs.has_carried_light()
		and not _hs.persists_through_dawn(),
		"spawnable=%s live=%d hp=%d/%d(exp %d) speed=%s no_light=%s recedes=%s" % [
			str(enemy_reg.is_spawnable("hollow_stag")), enemy_reg.live_defs().size(),
			(_hs.hp if _hs != null else -1), (_hs.max_hp if _hs != null else -1), _hs_hp,
			(str(_hs.move_speed) if _hs != null else "n/a"),
			str(_hs != null and _hs.visual_light.is_empty()),
			str(_hs != null and not _hs.persists_through_dawn())])

	# (32) surface selection: a rare forest-edge night (stag_rare + spawnable) is the stag;
	# otherwise the baseline surface slime. Fail-closed, mirroring select_cave_enemy_id.
	var _hs_sel_ok: bool = \
		EnemySpawnDirector.select_surface_enemy_id(enemy_reg, true) == "hollow_stag" \
		and EnemySpawnDirector.select_surface_enemy_id(enemy_reg, false) == "surface_slime"
	harness._check("s08_4_hollow_stag_surface_selection", _hs_sel_ok,
		"stag_rare=hollow_stag; otherwise surface_slime")

	# (33) the generalized rarity gate is deterministic and portable (no RNG draw):
	# rarity<=0 disables, rarity==1 marks every cell, the same cell is stable, and a real
	# rarity yields BOTH stag and non-stag cells. The S-08.3 stone_cavern_rare alias must
	# delegate byte-identically so the shipped beetle gate is unchanged.
	var _hs_r_off: bool = not EnemySpawnDirector.rare_cell(Vector2i(3, 7), 0) \
		and not EnemySpawnDirector.rare_cell(Vector2i(3, 7), -4)
	var _hs_r_all: bool = EnemySpawnDirector.rare_cell(Vector2i(3, 7), 1) \
		and EnemySpawnDirector.rare_cell(Vector2i(-9, 2), 1)
	var _hs_r_det: bool = EnemySpawnDirector.rare_cell(Vector2i(11, 5), 6) \
		== EnemySpawnDirector.rare_cell(Vector2i(11, 5), 6)
	var _hs_true := 0
	var _hs_false := 0
	var _hs_alias_ok := true
	for _hx in range(0, 40):
		for _hd in range(1, 41):
			if EnemySpawnDirector.rare_cell(Vector2i(_hx, _hd), 6):
				_hs_true += 1
			else:
				_hs_false += 1
			if EnemySpawnDirector.stone_cavern_rare(Vector2i(_hx, _hd), 6) \
					!= EnemySpawnDirector.rare_cell(Vector2i(_hx, _hd), 6):
				_hs_alias_ok = false
	var _hs_mixed: bool = _hs_true > 0 and _hs_false > 0 and _hs_true < _hs_false
	harness._check("s08_4_hollow_stag_rarity_gate",
		_hs_r_off and _hs_r_all and _hs_r_det and _hs_mixed and _hs_alias_ok,
		"off=%s all=%s deterministic=%s mixed(true=%d<false=%d)=%s alias_identical=%s" % [
			str(_hs_r_off), str(_hs_r_all), str(_hs_r_det), _hs_true, _hs_false,
			str(_hs_mixed), str(_hs_alias_ok)])

	# (34) venison is REAL loot with a PREMIUM food use (operator: premium food only): a
	# killed stag drops venison, the player collects it, and cook_venison turns 1 venison
	# into 2 food at the Town Hall (premium vs the mushroom's 2 -> 1). Stockpile state is
	# restored so no cross-module state leaks.
	for _hs1 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_hs1):
			_hs1.queue_free()
	await get_tree().process_frame
	var _ven_before: int = _pl.inventory.count("venison")
	var _hs_kill: Node = root.spawn_enemy_for_test("hollow_stag")
	_hs_kill.global_position = _pl.global_position
	_hs_kill.drop_chance_override = 1.0
	_hs_kill.take_hit(99)
	await get_tree().process_frame
	_pl.collect_ground_drops()
	var _ven_dropped: bool = _pl.inventory.count("venison") > _ven_before
	var _ven_sp_prev: Variant = _hall.stockpile.get("venison", null)
	_hall.stockpile["venison"] = 1
	var _food_before2: int = _pl.inventory.count("food")
	var _ven_cooked: bool = _hall.craft_from_stockpile("cook_venison", _pl)
	var _ven_cook_ok: bool = _ven_cooked \
		and _pl.inventory.count("food") == _food_before2 + 2 \
		and int(_hall.stockpile.get("venison", 0)) == 0
	if _ven_sp_prev == null:
		_hall.stockpile.erase("venison")
	else:
		_hall.stockpile["venison"] = _ven_sp_prev
	harness._check("s08_4_hollow_stag_loot_food",
		_ven_dropped and _ven_cook_ok and BlockRegistry.item_icon("venison") != null,
		"dropped=%s cooked=%s premium_food(+2)=%s" % [str(_ven_dropped), str(_ven_cooked),
			str(_ven_cook_ok)])

	# (35) hollow_stag id + hp/max_hp round-trip through save; a restored stag still RECEDES
	# at dawn (surface lifecycle preserved across save/load).
	for _hs2 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_hs2):
			_hs2.queue_free()
	await get_tree().process_frame
	var _hs3: Node = root.spawn_enemy_for_test("hollow_stag")
	_hs3.hp = 1
	await get_tree().process_frame
	root.apply_threats(root.serialize_threats())
	await get_tree().process_frame
	var _hs_restored: Node = null
	for _hs4 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_hs4) and str(_hs4.enemy_id) == "hollow_stag":
			_hs_restored = _hs4
	harness._check("s08_4_hollow_stag_saves",
		_hs_restored != null and _hs_restored.hp == 1 and _hs_restored.max_hp == _hs_hp
		and not _hs_restored.persists_through_dawn(),
		"restored=%s hp=%s max=%s(exp %d) recedes=%s" % [str(_hs_restored != null),
			(str(_hs_restored.hp) if _hs_restored != null else "n/a"),
			(str(_hs_restored.max_hp) if _hs_restored != null else "n/a"), _hs_hp,
			str(_hs_restored != null and not _hs_restored.persists_through_dawn())])

	for _hs5 in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(_hs5):
			_hs5.queue_free()
	await get_tree().process_frame
