extends Node
## S-07.3 smoke domain module - enemies (registry + data-driven spawning, FQ-13
## enemy variety, FQ-13P1 sprite variant pools, FQ-13P2 UI placeholders, FQ-13P4
## item-icon/frame semantics). Order-preserving extraction; harness owns _check()
## (via harness.*). SubjectScript is a harness class-local preload const (§11.4a
## category 4), re-preloaded here.

const SubjectScript := preload("res://scripts/entities/subject.gd")


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
	harness._check("enemies_json_loads", enemy_reg.live_defs().size() == 8,
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

	# (1) the live enemy set is exactly the expected eight ids.
	var _s08_live_ids := {}
	for _d in enemy_reg.live_defs():
		_s08_live_ids[str(_d.get("id", ""))] = true
	var _s08_set_ok: bool = _s08_live_ids.size() == _s08_expect.size()
	for _eid in _s08_expect:
		if not _s08_live_ids.has(_eid):
			_s08_set_ok = false
	harness._check("s08_live_set_is_the_eight", _s08_set_ok,
		"live=%d expected=%d ids=%s" % [_s08_live_ids.size(), _s08_expect.size(),
			str(_s08_live_ids.keys())])

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
