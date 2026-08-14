extends Node
## S-07.3 smoke domain module - liquid physics (submersion/breath/per-liquid
## tuning) + character traits/Calling effects on the player. Order-preserving;
## harness owns _check().

func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this cluster uses.
	var harness = ctx.harness
	var world = ctx.world
	var player = ctx.player
	# --- Liquid physics: level-aware submersion, per-liquid tuning, breath ---
	# (a) liquid_covering keys off the TRUE fill level, not just the block: the
	# empty top of a half-full cell reads as uncovered, the bottom as submerged.
	var _lc := Vector2i(50, 6)
	world.cells[_lc] = "water"; world.liquid_level[_lc] = 0.5
	var _lc_top: String = world.liquid_covering(Vector2(808.0, 98.0))   # above waterline
	var _lc_bot: String = world.liquid_covering(Vector2(808.0, 110.0))  # below waterline
	harness._check("lq_covering_respects_fill_level",
		_lc_top == "" and _lc_bot == "water",
		"top=%s bottom=%s" % [_lc_top, _lc_bot])
	world.cells.erase(_lc); world.liquid_level.erase(_lc); world._set_tile(_lc, "air")

	# (b) per-liquid tuning is data-driven and distinct: thick lava slows you more
	# than water, and both slow you below open air; water drains breath + drowns.
	harness._check("lq_move_tuning_per_liquid",
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
	harness._check("lq_breath_drain_drown_and_water_breathing",
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
	harness._check("character_traits_apply", absf(player.max_health - 125.0) < 0.01
		and player.effective_mine_speed() > default_speed * 1.19,
		"max_health=%.0f speed %.2f→%.2f" % [player.max_health, default_speed, player.effective_mine_speed()])
	player.apply_character(GameState.current_character)
