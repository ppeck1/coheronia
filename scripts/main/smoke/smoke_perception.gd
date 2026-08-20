extends Node
## Perception + Resonance smoke — the tile line-of-sight veil and its persistent
## remembered-terrain memory. Most checks run on the PURE perception.gd model (fast,
## deterministic, no renderer); a final integration check enables the veil on the live
## world, verifies the wiring, then restores the shared world so later modules see it
## exactly as before.

const PerceptionScript := preload("res://scripts/world/perception.gd")


func run(ctx) -> void:
	var harness = ctx.harness
	var root = ctx.root
	var world = ctx.world
	var player = ctx.player

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
	pin.recompute(Vector2i(5, 5), 6, corner)
	var _pin_blocked: bool = pin.state_at(Vector2i(6, 6)) == PerceptionScript.UNSEEN
	var _pin_walls_seen: bool = pin.state_at(Vector2i(6, 5)) == PerceptionScript.VISIBLE \
		and pin.state_at(Vector2i(5, 6)) == PerceptionScript.VISIBLE
	var open2 = PerceptionScript.new(W, W)
	var nowall := func(_c: Vector2i) -> bool: return false
	open2.recompute(Vector2i(5, 5), 6, nowall)
	var _pin_open_ok: bool = open2.state_at(Vector2i(6, 6)) == PerceptionScript.VISIBLE
	harness._check("perception_no_diagonal_leak",
		_pin_blocked and _pin_walls_seen and _pin_open_ok,
		"blocked=%s walls_seen=%s open=%s" % [str(_pin_blocked), str(_pin_walls_seen),
			str(_pin_open_ok)])

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

	# --- Live-world wiring: off by default (COHERONIA_PERCEPTION unset), so the API
	# is inert until enabled. Enable it, seed LOS at the player, verify the player's
	# own cell is visible and the seen set persists, then RESTORE the shared world.
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
