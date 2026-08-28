extends Node
## Perception + Resonance smoke — the tile line-of-sight veil and its persistent
## remembered-terrain memory. Most checks run on the PURE perception.gd model (fast,
## deterministic, no renderer); a final integration check enables the veil on the live
## world, verifies the wiring, then restores the shared world so later modules see it
## exactly as before.

const PerceptionScript := preload("res://scripts/world/perception.gd")
const SubjectScript := preload("res://scripts/entities/subject.gd")   # E2E resonance target


func run(ctx) -> void:
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player
	var hud = ctx.hud

	# --- Pure LOS: a full wall column occludes; the wall itself is seen; open
	# vertical space is seen. 21x21 grid, wall column at x=10, origin (5,10), r=6
	# (the far corner (20,0) is out of range so it stays genuinely unseen).
	const W := 21
	var p = PerceptionScript.new(W, W)
	var wall := func(c: Vector2i) -> bool: return c.x == 10
	p.recompute(Vector2i(5, 10), 6, wall)
	var _los_front: bool = p.state_at(Vector2i(6, 10)) == PerceptionScript.VISIBLE
	var _los_wall: bool = p.state_at(Vector2i(10, 10)) == PerceptionScript.VISIBLE  # see the wall
	var _los_behind: bool = p.state_at(Vector2i(11, 10)) == PerceptionScript.UNSEEN # blocked
	var _los_open: bool = p.state_at(Vector2i(5, 13)) == PerceptionScript.VISIBLE    # open column
	var _los_origin: bool = p.state_at(Vector2i(5, 10)) == PerceptionScript.VISIBLE
	var _los_far: bool = p.state_at(Vector2i(20, 0)) == PerceptionScript.UNSEEN      # out of range
	harness._check("perception_los_occlusion",
		_los_front and _los_wall and _los_behind and _los_open and _los_origin and _los_far,
		"front=%s wall=%s behind=%s open=%s origin=%s far=%s" % [str(_los_front),
			str(_los_wall), str(_los_behind), str(_los_open), str(_los_origin), str(_los_far)])

	# --- Diagonal 1x1 leak is closed: two blocks meeting at a corner must not let
	# sight slip through the zero-width gap between them, while the walls themselves
	# stay visible and an unobstructed diagonal is still seen.
	var pin = PerceptionScript.new(W, W)
	var corner := func(c: Vector2i) -> bool: return c == Vector2i(6, 5) or c == Vector2i(5, 6)
	pin.recompute(Vector2i(5, 5), 8, corner)
	# The cell behind the pinch AND everything further along the sealed diagonal must be
	# unseen — not just the first cell (the earlier single-cell cleanup leaked past it).
	var _pin_blocked: bool = pin.state_at(Vector2i(6, 6)) == PerceptionScript.UNSEEN \
		and pin.state_at(Vector2i(7, 7)) == PerceptionScript.UNSEEN \
		and pin.state_at(Vector2i(8, 8)) == PerceptionScript.UNSEEN
	var _pin_walls_seen: bool = pin.state_at(Vector2i(6, 5)) == PerceptionScript.VISIBLE \
		and pin.state_at(Vector2i(5, 6)) == PerceptionScript.VISIBLE
	# Sight still reaches OPEN space beside the barrier (the near-side cells are visible),
	# so the cull is the diagonal pinch only, not a blanket quadrant wipe.
	var _pin_side_ok: bool = pin.state_at(Vector2i(6, 4)) == PerceptionScript.VISIBLE \
		and pin.state_at(Vector2i(4, 6)) == PerceptionScript.VISIBLE
	var open2 = PerceptionScript.new(W, W)
	var nowall := func(_c: Vector2i) -> bool: return false
	open2.recompute(Vector2i(5, 5), 8, nowall)
	var _pin_open_ok: bool = open2.state_at(Vector2i(6, 6)) == PerceptionScript.VISIBLE \
		and open2.state_at(Vector2i(8, 8)) == PerceptionScript.VISIBLE
	harness._check("perception_no_diagonal_leak",
		_pin_blocked and _pin_walls_seen and _pin_side_ok and _pin_open_ok,
		"blocked=%s walls_seen=%s side=%s open=%s" % [str(_pin_blocked), str(_pin_walls_seen),
			str(_pin_side_ok), str(_pin_open_ok)])

	# --- Remembered vs visible: recomputing from the far side of the wall leaves the
	# old region seen-but-not-visible (REMEMBERED); the seen set is the union of both.
	p.recompute(Vector2i(15, 10), 6, wall)
	var _mem_now_vis: bool = p.state_at(Vector2i(15, 10)) == PerceptionScript.VISIBLE
	var _mem_remembered: bool = p.state_at(Vector2i(6, 10)) == PerceptionScript.REMEMBERED
	var _mem_still_seen: bool = p.is_seen(Vector2i(6, 10))
	harness._check("perception_remembered_terrain",
		_mem_now_vis and _mem_remembered and _mem_still_seen,
		"now_vis=%s remembered=%s seen=%s" % [str(_mem_now_vis),
			str(_mem_remembered), str(_mem_still_seen)])

	# --- Mask bytes: 255 visible / 128 remembered / 0 unseen. Cell (x,y) -> y*W + x.
	var buf := PackedByteArray()
	p.fill_mask(buf)
	var _i_vis: int = 10 * W + 15     # (15,10) currently visible (origin of 2nd recompute)
	var _i_mem: int = 10 * W + 6      # (6,10) remembered
	var _i_unseen: int = 0 * W + 20   # (20,0) never seen
	var _mask_vis: bool = buf[_i_vis] == 255
	var _mask_mem: bool = buf[_i_mem] == 128
	var _mask_unseen: bool = buf[_i_unseen] == 0
	harness._check("perception_mask_bytes",
		_mask_vis and _mask_mem and _mask_unseen,
		"vis=%d mem=%d unseen=%d" % [buf[_i_vis], buf[_i_mem], buf[_i_unseen]])

	# --- Serialize round-trip: the persistent seen set survives base64, VISIBLE is
	# transient (a fresh model loads seen cells as REMEMBERED, none visible).
	var ser: Dictionary = p.serialize()
	var q = PerceptionScript.new(W, W)
	q.load_from(ser)
	var _rt_seen: bool = q.is_seen(Vector2i(6, 10)) and q.is_seen(Vector2i(15, 10))
	var _rt_unseen: bool = not q.is_seen(Vector2i(20, 0))
	var _rt_no_visible: bool = q.state_at(Vector2i(6, 10)) == PerceptionScript.REMEMBERED
	var _rt_dims: bool = int(ser.get("w", 0)) == W and int(ser.get("h", 0)) == W \
		and str(ser.get("seen", "")) != ""
	harness._check("perception_seen_roundtrip",
		_rt_seen and _rt_unseen and _rt_no_visible and _rt_dims,
		"seen=%s unseen=%s no_vis=%s dims=%s" % [str(_rt_seen), str(_rt_unseen),
			str(_rt_no_visible), str(_rt_dims)])

	# --- Live-world wiring: the world-level veil API is inert until enable_perception()
	# is called. In NORMAL gameplay game_root enables it per the `fog_of_war` world rule
	# (default ON — see perception_fog_rule_default_contract); the deterministic
	# smoke/screenshot/HUD-QA harnesses deliberately SUPPRESS that default (they never
	# auto-enable it), so this check drives it explicitly, seeds LOS at the player,
	# verifies the player's cell is visible and the seen set persists, then RESTORES the
	# shared world.
	var _off_default: bool = not world.perception_enabled() \
		and world.perception_serialized().is_empty()
	# Snapshot entity visibility so enabling the veil (which hides off-screen
	# entities) leaves the shared world exactly as later modules expect it.
	var _vis_snapshot: Array = []
	for _grp in ["threats", "subjects", "item_drops"]:
		for _n in get_tree().get_nodes_in_group(_grp):
			if _n is Node2D:
				_vis_snapshot.append([_n, (_n as Node2D).visible])
	world.enable_perception()
	var pcell: Vector2i = world.cell_of(player.global_position)
	world.update_perception(pcell, 10)
	var _on_ok: bool = world.perception_enabled() and world.perception_is_visible(pcell)
	var _on_ser: Dictionary = world.perception_serialized()
	var _on_ser_ok: bool = int(_on_ser.get("w", 0)) == world.width \
		and int(_on_ser.get("h", 0)) == world.height
	# set_perception_seen_pending adopts a restored blob while enabled.
	world.set_perception_seen_pending(_on_ser)
	var _reload_ok: bool = world.perception_is_visible(pcell) or world.perception_state_at(pcell) >= PerceptionScript.REMEMBERED
	# Spawn-under-fog: an entity spawned OUT of sight is hidden the moment it joins its
	# group (spawn gating), not left visible until the next recompute. A cell far from
	# the player (well beyond the radius-10 sight) is unseen.
	var _far_cell := pcell + Vector2i(40, 0)
	var _far_drop = world.spawn_item_drop(world.cell_center(_far_cell), "stone", 1)
	world.gate_entity_visibility(_far_drop)   # the synchronous path node_added defers to
	var _spawn_hidden: bool = _far_drop != null and not (_far_drop as Node2D).visible
	if _far_drop != null and is_instance_valid(_far_drop):
		_far_drop.queue_free()
	harness._check("perception_spawn_gated", _spawn_hidden,
		"far_drop_visible=%s" % [str(_far_drop != null and (_far_drop as Node2D).visible)])
	world.disable_perception()
	for _entry in _vis_snapshot:
		if is_instance_valid(_entry[0]):
			(_entry[0] as Node2D).visible = _entry[1]
	var _restored: bool = not world.perception_enabled()
	harness._check("perception_world_wiring",
		_off_default and _on_ok and _on_ser_ok and _reload_ok and _restored,
		"off_default=%s on=%s ser=%s reload=%s restored=%s" % [str(_off_default),
			str(_on_ok), str(_on_ser_ok), str(_reload_ok), str(_restored)])

	# --- Composable sight resolver: a dark-adapted ancestry keeps extra reach in the
	# dark. Compare the radius WITH vs WITHOUT the ancestry bonus at full darkness
	# (daylight would mask it), then restore the player's real ancestry.
	var _prev_vd: float = root._viewer_darkness_smooth
	root._viewer_darkness_smooth = 1.0   # full dark
	player.apply_ancestry_effects({"dark_sight": 6.0})
	var _ds_set: bool = is_equal_approx(player.perception_dark_sight, 6.0)
	var _r_with: int = root._perception_radius()
	player.apply_ancestry_effects({})
	var _r_without: int = root._perception_radius()
	var _ds_reset: bool = is_equal_approx(player.perception_dark_sight, 0.0)
	root._viewer_darkness_smooth = _prev_vd
	root.apply_ancestry_for_species(player.species_id)   # restore real ancestry effects
	harness._check("perception_ancestry_dark_sight",
		_ds_set and _r_with > _r_without and _ds_reset,
		"set=%s with=%d without=%d reset=%s" % [str(_ds_set), _r_with, _r_without,
			str(_ds_reset)])

	# --- Resonance ping (Phase B): an Attunement pulse marks nearby objects of interest
	# with temporary contours on the undimmed resonance layer (independent of fog). Drop
	# an item at the player's feet, fire the resonance handler, and confirm a contour
	# appeared, then clean up so later modules see a clear layer.
	var _res_layer = root._resonance_layer
	var _res_before: int = _res_layer.get_child_count() if _res_layer != null else -1
	var _res_drop = world.spawn_item_drop(player.global_position, "wood", 1)
	root._on_attunement_resonance()
	var _res_after: int = _res_layer.get_child_count() if _res_layer != null else -1
	var _res_ok: bool = _res_layer != null and _res_after > _res_before
	# Resonance registered a live "resonance" status effect on the new status model.
	var _res_dur: float = root._resonance_duration()
	var _stat_has_res := false
	for _se in root._status_effects:
		if str(_se.get("id", "")) == "resonance":
			_stat_has_res = true
	if _res_drop != null and is_instance_valid(_res_drop):
		_res_drop.queue_free()
	# Stop the pulse travelling (Phase B travel) before clearing so a later frame's
	# re-scan can't repopulate the layer the following modules expect clear.
	root._resonance_remaining = 0.0
	root._resonance_terrain_node = null
	root._resonance_highlights.clear()
	if _res_layer != null:
		for _rc in _res_layer.get_children():
			_rc.queue_free()
	harness._check("perception_resonance_marks_targets", _res_ok,
		"before=%d after=%d" % [_res_before, _res_after])

	# --- Status-effect model (new HUD element): add / count down / expire, generic by
	# id, and resonance's long lifetime composes from the pulse-duration resolver.
	root.add_status_effect("smoke_status", "Smoke", 5.0, Color.WHITE)
	var _stat_added := false
	for _se in root._status_effects:
		if str(_se.get("id", "")) == "smoke_status":
			_stat_added = true
	root._tick_status_effects(6.0)   # advance past its lifetime
	var _stat_expired := true
	for _se in root._status_effects:
		if str(_se.get("id", "")) == "smoke_status":
			_stat_expired = false
	root._status_effects.clear()
	root._refresh_status_hud()
	var _dur_ok: bool = is_equal_approx(_res_dur, 10.0 * root.calling_pulse_duration_mult())
	harness._check("perception_status_effects_model",
		_stat_has_res and _stat_added and _stat_expired and _dur_ok,
		"has_res=%s added=%s expired=%s dur=%.1f" % [str(_stat_has_res),
			str(_stat_added), str(_stat_expired), _res_dur])

	# --- Status HUD layout contract: the widget is owned by the HUD, visible with an
	# active effect, on-screen, and does NOT overlap the top-right Events module.
	var _sh = hud.status_hud()
	var _ev_was: bool = hud._event_panel != null and hud._event_panel.visible
	if hud._event_panel != null:
		hud._event_panel.visible = true
	root.add_status_effect("layout_probe", "Probe", 8.0, Color(0.4, 0.8, 1.0))
	await get_tree().process_frame
	await get_tree().process_frame
	var _sh_owned: bool = _sh != null and hud.is_ancestor_of(_sh)
	var _sh_visible: bool = _sh != null and _sh.visible
	var _sh_rect: Rect2 = _sh.get_global_rect() if _sh != null else Rect2()
	var _ev_rect: Rect2 = hud._event_panel.get_global_rect() if hud._event_panel != null else Rect2()
	var _sh_clear: bool = not _sh_rect.intersects(_ev_rect)
	var _vp: Vector2 = get_viewport().get_visible_rect().size
	var _sh_onscreen: bool = _sh_rect.position.x >= 0.0 and _sh_rect.position.y >= 0.0 \
		and _sh_rect.end.x <= _vp.x and _sh_rect.end.y <= _vp.y
	root._status_effects.clear()
	root._refresh_status_hud()
	if hud._event_panel != null:
		hud._event_panel.visible = _ev_was
	harness._check("perception_status_hud_layout",
		_sh_owned and _sh_visible and _sh_clear and _sh_onscreen,
		"owned=%s vis=%s clear=%s onscreen=%s sh=%s ev=%s" % [str(_sh_owned),
			str(_sh_visible), str(_sh_clear), str(_sh_onscreen), str(_sh_rect), str(_ev_rect)])

	# --- fog_of_war world-rule contract: normal gameplay defaults ON; an explicit
	# saved/custom false stays OFF. game_root._perception_should_enable() suppresses the
	# default under the smoke/screenshot/HUD-QA harnesses — it does NOT change this rule.
	var _fog_default: bool = WorldConfig.new({}).rule("fog_of_war")
	var _fog_custom_off: bool = WorldConfig.new({"rules": {"fog_of_war": false}}).rule("fog_of_war")
	harness._check("perception_fog_rule_default_contract",
		_fog_default and not _fog_custom_off,
		"default=%s custom_off=%s" % [str(_fog_default), str(_fog_custom_off)])

	# --- End-to-end Attunement through the veil. Stage an ore cell, an enemy, an NPC
	# (subject), and a dropped item INSIDE the visible resonance region but behind a
	# solid wall (out of line of sight). Assert the full contract: hidden before the
	# pulse; a pulse highlights all four categories and force-shows the dynamic three
	# THROUGH the veil while the ore joins the terrain batch; the fog itself is NOT
	# lifted; re-pulsing refreshes rather than stacking; and after the pulse expires the
	# highlights clear, the forced-visible set empties, and the three re-hide. Restores
	# the shared world (terrain, player, entity visibility) exactly for later modules.
	var _e2e_vis_snap: Array = []
	for _e2e_grp in ["threats", "subjects", "item_drops"]:
		for _e2e_n in get_tree().get_nodes_in_group(_e2e_grp):
			if _e2e_n is Node2D:
				_e2e_vis_snap.append([_e2e_n, (_e2e_n as Node2D).visible])
	var _e2e_layer = root._resonance_layer
	var _e2e_player_pos: Vector2 = player.global_position
	var _e2e_hall: Vector2i = world.hall_info.get("center_cell", Vector2i(int(world.width / 2.0), 0))
	# Keep the staged threat well outside settlement defenders' 150px guard
	# radius. At the old hall.x - 14 origin the threat landed only eight tiles
	# (128px) from the hall and defenders legitimately killed the 3-HP fixture
	# during the awaited resonance expiry, producing `vis=freed/null` instead of
	# testing re-hiding. The targets remain only 5-7 cells from the staged player.
	var _e2e_x: int = _e2e_hall.x - 30
	var _e2e_prow: int = int(world.surface.get(_e2e_x, _e2e_hall.y)) - 1   # air row just above ground
	var _e2e_pcell := Vector2i(_e2e_x, _e2e_prow)
	var _e2e_wall: Array = [Vector2i(_e2e_x + 3, _e2e_prow), Vector2i(_e2e_x + 3, _e2e_prow - 1)]
	var _e2e_ore_cell := Vector2i(_e2e_x + 6, _e2e_prow)
	var _e2e_enemy_cell := Vector2i(_e2e_x + 6, _e2e_prow - 1)
	var _e2e_subj_cell := Vector2i(_e2e_x + 7, _e2e_prow)
	var _e2e_item_cell := Vector2i(_e2e_x + 5, _e2e_prow)
	var _e2e_touched: Array = _e2e_wall.duplicate()
	_e2e_touched.append(_e2e_ore_cell)
	var _e2e_orig: Dictionary = {}
	for _tc in _e2e_touched:
		_e2e_orig[_tc] = str(world.cells.get(_tc, ""))   # "" == was air (absent)
	var _e2e_ore_id: String = str(world.ORE_IDS[4]) if world.ORE_IDS.size() > 4 else str(world.ORE_IDS[0])
	# enable the veil, seat the player, clear any stale forced-visible set, centre camera.
	world.enable_perception()
	world.set_perception_force_visible({})
	player.global_position = world.cell_center(_e2e_pcell)
	player.velocity = Vector2.ZERO
	var _e2e_cam: Camera2D = player.get_node("Camera2D")
	_e2e_cam.reset_smoothing()
	await get_tree().physics_frame
	await get_tree().physics_frame
	# build the occluding wall + the ore vein behind it.
	for _wc in _e2e_wall:
		world.cells[_wc] = "stone"
		world._set_tile(_wc, "stone")
	world.cells[_e2e_ore_cell] = _e2e_ore_id
	world._set_tile(_e2e_ore_cell, _e2e_ore_id)
	world.update_perception(_e2e_pcell, 16)
	# Stage the dynamic three behind the wall. Use an underground-family enemy so
	# the awaited pulse-expiry frames cannot cross dawn and legitimately delete
	# the fixture via game_root._on_dawn(). The check remains strict: the enemy
	# must survive and re-hide after resonance expires.
	var _e2e_enemy: Node = root.spawn_enemy_for_test("cave_crawler")
	var _e2e_subj = SubjectScript.new()
	world.add_child(_e2e_subj)                       # _ready() joins the "subjects" group
	_e2e_subj.set_physics_process(false); _e2e_subj.set_process(false)
	var _e2e_item: Node = world.spawn_item_drop(world.cell_center(_e2e_item_cell), "wood", 1)
	if _e2e_item != null and _e2e_item is Node2D:
		# Pin the drop and freeze its physics/bob so it can't drift into a visible cell
		# during the awaited expiry frames (else it re-shows via is_visible, not force).
		(_e2e_item as Node2D).global_position = world.cell_center(_e2e_item_cell)
		_e2e_item.set_physics_process(false)
		_e2e_item.set_process(false)
	if _e2e_enemy != null and _e2e_enemy is Node2D:
		(_e2e_enemy as Node2D).global_position = world.cell_center(_e2e_enemy_cell)
		_e2e_enemy.set_physics_process(false); _e2e_enemy.set_process(false)
		if "velocity" in _e2e_enemy:
			_e2e_enemy.set("velocity", Vector2.ZERO)
	(_e2e_subj as Node2D).global_position = world.cell_center(_e2e_subj_cell)
	for _gn in [_e2e_enemy, _e2e_subj, _e2e_item]:
		if _gn != null:
			world.gate_entity_visibility(_gn)
	world.refresh_entity_visibility()
	var _e2e_enemy_iid: int = _e2e_enemy.get_instance_id() if _e2e_enemy != null else 0
	var _e2e_subj_iid: int = _e2e_subj.get_instance_id()
	var _e2e_item_iid: int = _e2e_item.get_instance_id() if _e2e_item != null else 0
	# BEFORE: the four target cells are out of LOS and the dynamic three are hidden.
	var _e2e_cells_unseen: bool = not world.perception_is_visible(_e2e_ore_cell) \
		and not world.perception_is_visible(_e2e_enemy_cell) \
		and not world.perception_is_visible(_e2e_subj_cell) \
		and not world.perception_is_visible(_e2e_item_cell)
	var _e2e_hidden_before: bool = _e2e_enemy != null and not (_e2e_enemy as Node2D).visible \
		and not (_e2e_subj as Node2D).visible \
		and _e2e_item != null and not (_e2e_item as Node2D).visible
	# FIRE the pulse.
	root._on_attunement_resonance()
	var _e2e_hl_enemy = root._resonance_highlights.get(_e2e_enemy_iid)
	var _e2e_hl_subj = root._resonance_highlights.get(_e2e_subj_iid)
	var _e2e_hl_item = root._resonance_highlights.get(_e2e_item_iid)
	var _e2e_marked: bool = is_instance_valid(_e2e_hl_enemy) and is_instance_valid(_e2e_hl_subj) \
		and is_instance_valid(_e2e_hl_item)
	# ore joins the terrain resonance batch, in the ore category colour.
	var _e2e_ore_center: Vector2 = world.cell_center(_e2e_ore_cell)
	var _e2e_ore_in_batch := false
	if root._resonance_terrain_node != null and is_instance_valid(root._resonance_terrain_node):
		for _be in root._resonance_terrain_node._cells:
			if (_be[0] as Vector2).is_equal_approx(_e2e_ore_center):
				_e2e_ore_in_batch = (_be[1] as Color).is_equal_approx(root.RESONANCE_ORE_COLOR)
				break
	# the dynamic three are force-shown THROUGH the veil.
	var _e2e_forced_visible: bool = (_e2e_enemy as Node2D).visible \
		and (_e2e_subj as Node2D).visible and (_e2e_item as Node2D).visible
	# the fog itself is NOT lifted — the underlying cells stay out of LOS.
	var _e2e_fog_intact: bool = not world.perception_is_visible(_e2e_ore_cell) \
		and not world.perception_is_visible(_e2e_enemy_cell) \
		and not world.perception_is_visible(_e2e_subj_cell)
	# RE-PULSE refreshes, does not stack (same highlight count + same nodes).
	var _e2e_hl_count: int = root._resonance_highlights.size()
	root._on_attunement_resonance()
	var _e2e_no_stack: bool = root._resonance_highlights.size() == _e2e_hl_count \
		and root._resonance_highlights.get(_e2e_enemy_iid) == _e2e_hl_enemy \
		and root._resonance_highlights.get(_e2e_item_iid) == _e2e_hl_item
	# EXPIRE: age each highlight past its life, drop the pulse, reconcile visibility.
	var _e2e_dur: float = root._resonance_duration()
	for _hk in root._resonance_highlights.keys():
		var _hn = root._resonance_highlights[_hk]
		if is_instance_valid(_hn):
			_hn._process(_e2e_dur + 1.0)
	if root._resonance_terrain_node != null and is_instance_valid(root._resonance_terrain_node):
		root._resonance_terrain_node._process(_e2e_dur + 1.0)
	root._advance_resonance_travel(_e2e_dur + 1.0)
	# Let the aged highlight nodes' queue_free() actually flush before reconciling — a
	# single frame is enough in the editor renderer but not always under the exported
	# build, where the deferred free lands a frame or two later (else _reconcile would
	# still see a valid highlight and keep its entity force-visible).
	for _e2e_ef in range(6):
		await get_tree().process_frame
	root._reconcile_resonance_visibility()
	world.refresh_entity_visibility()
	var _e2e_hl_gone: bool = not is_instance_valid(_e2e_hl_enemy) \
		and not is_instance_valid(_e2e_hl_subj) and not is_instance_valid(_e2e_hl_item)
	var _e2e_force_empty: bool = world._force_visible_ids.is_empty()
	var _e2e_hidden_after: bool = _e2e_enemy != null and not (_e2e_enemy as Node2D).visible \
		and not (_e2e_subj as Node2D).visible \
		and _e2e_item != null and not (_e2e_item as Node2D).visible
	# Diagnostic-only: sample the immediate post-refresh state of each staged entity (before
	# cleanup) so an intermittent hid1 failure can identify WHICH entity stayed visible and
	# the surrounding perception state. No await / retry / polling / assertion change here.
	# Highlight validity is precomputed to bools so no (by-now freed) highlight reference is
	# ever copied into an array/typed var, and each entity is read through an untyped param.
	var _e2e_diag_one := func(nm: String, en, iid: int, grp: String, hlv: bool) -> String:
		var vis := "freed/null"
		var cell := Vector2i.ZERO
		var pvis := false
		var ingroup := false
		if en != null and is_instance_valid(en):
			vis = str((en as Node2D).visible)
			cell = world.cell_of((en as Node2D).global_position)
			pvis = world.perception_is_visible(cell)
			ingroup = (en as Node).is_in_group(grp)
		return " | %s: vis=%s grp=%s cell=%s cell_pvis=%s forced_id=%s hl_valid=%s" % [
			nm, vis, str(ingroup), str(cell), str(pvis),
			str(world._force_visible_ids.has(iid)), str(hlv)]
	var _e2e_ent_diag: String = "player_cell=%s player_pos=%s forced_last=%s" % [
		str(world.cell_of(player.global_position)), str(player.global_position),
		str(root._resonance_forced_last)] \
		+ str(_e2e_diag_one.call("enemy", _e2e_enemy, _e2e_enemy_iid, "threats", is_instance_valid(_e2e_hl_enemy))) \
		+ str(_e2e_diag_one.call("subj", _e2e_subj, _e2e_subj_iid, "subjects", is_instance_valid(_e2e_hl_subj))) \
		+ str(_e2e_diag_one.call("item", _e2e_item, _e2e_item_iid, "item_drops", is_instance_valid(_e2e_hl_item)))
	# CLEANUP — free the staged three, clear the layer/state, restore terrain, player,
	# the veil, and the entity-visibility snapshot so later modules are undisturbed.
	for _fn in [_e2e_enemy, _e2e_subj, _e2e_item]:
		if _fn != null and is_instance_valid(_fn):
			for _g in ["threats", "subjects", "item_drops"]:
				if _fn.is_in_group(_g):
					_fn.remove_from_group(_g)
			_fn.queue_free()
	root._resonance_remaining = 0.0
	root._resonance_terrain_node = null
	root._resonance_highlights.clear()
	if _e2e_layer != null:
		for _rc in _e2e_layer.get_children():
			_rc.queue_free()
	root._status_effects.clear()
	root._refresh_status_hud()
	for _tc in _e2e_touched:
		var _o: String = str(_e2e_orig[_tc])
		if _o == "":
			world.cells.erase(_tc); world._set_tile(_tc, "air")
		else:
			world.cells[_tc] = _o; world._set_tile(_tc, _o)
	world.disable_perception()
	if player.has_method("teleport"):
		player.teleport(_e2e_player_pos)
	else:
		player.global_position = _e2e_player_pos
		player.velocity = Vector2.ZERO
	await get_tree().process_frame
	for _entry in _e2e_vis_snap:
		if is_instance_valid(_entry[0]):
			(_entry[0] as Node2D).visible = _entry[1]
	if root.settlement != null and root.settlement.has_method("compute"):
		root.settlement.compute()
	if root.has_method("_refresh_threat_display"):
		root._refresh_threat_display()
	var _e2e_ok: bool = _e2e_cells_unseen and _e2e_hidden_before and _e2e_marked \
		and _e2e_ore_in_batch and _e2e_forced_visible and _e2e_fog_intact and _e2e_no_stack \
		and _e2e_hl_gone and _e2e_force_empty and _e2e_hidden_after
	var _e2e_detail := "unseen=%s hid0=%s marked=%s ore=%s forced=%s fog=%s nostack=%s gone=%s empty=%s hid1=%s || %s" % [
		str(_e2e_cells_unseen), str(_e2e_hidden_before), str(_e2e_marked), str(_e2e_ore_in_batch),
		str(_e2e_forced_visible), str(_e2e_fog_intact), str(_e2e_no_stack),
		str(_e2e_hl_gone), str(_e2e_force_empty), str(_e2e_hidden_after), _e2e_ent_diag]
	# Diagnostic: this check protects a feature that recently regressed and fails rarely and
	# non-deterministically. Print the complete field breakdown on failure so the next local
	# or CI occurrence is actionable straight from the log (before the results JSON is
	# overwritten by a later run).
	if not _e2e_ok:
		print("SMOKE_FIELD_BREAKDOWN perception_resonance_e2e_through_fog: %s" % _e2e_detail)
	harness._check("perception_resonance_e2e_through_fog", _e2e_ok, _e2e_detail)
