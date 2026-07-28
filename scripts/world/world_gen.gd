class_name WorldGen
extends RefCounted
## Deterministic terrain generation, driven by a WorldConfig. Same seed +
## same generation settings -> same terrain. Each block type generates on
## its own seed channel (seed + per-type offset from the config), so the
## variation of ore/trees/bushes within one seed is independently tunable.

const TREE_MIN_H := 3
const TREE_MAX_H := 5

## World Depths: bump this when the generator changes in a way that alters the
## terrain a given seed produces. New worlds are stamped with it at creation
## (game_state.create_world); worlds created earlier keep their stored version
## (absent -> 1) so their seed+delta terrain regenerates unchanged.
##   v1 = legacy (dirt over stone, ore families, solid fill, no caves/hell)
##   v2 = World Depths (data-driven strata, deepstone, unmineable bedrock floor;
##        caves + hell land under this same version as WD-2/WD-3 add them)
const CURRENT_GEN_VERSION := 2

## v2 only: unmineable floor rows at the very bottom so a deep world (and, later,
## caves) can never expose the world's lower edge.
const BEDROCK_THICKNESS := 2


## Returns { "cells": {Vector2i: block_id}, "surface": {int x: int y},
##           "width": int, "height": int }.
## FQ-09R: every tree follows one rule — a tree_trunk column topped by a small
## tree_leaves canopy, both non-solid cells the player walks in front of and
## harvests through the normal mining/axe path (trunks drop wood).
static func generate(world_seed: int, config: WorldConfig) -> Dictionary:
	var dims: Dictionary = config.size_dims()
	var width := int(dims.get("width", 240))
	var height := int(dims.get("height", 80))
	var surface_base := int(dims.get("surface_base", 30))
	var amplitude := 9.0 * config.gen("terrain_amplitude")
	var dirt_depth := maxi(1, int(config.gen("dirt_depth")))
	# World Depths: v2 fills below the topsoil from a data-driven strata table and
	# caps the world with an unmineable bedrock floor. v1 is untouched.
	var gen_version := config.gen_version()
	var strata: Array = WorldConfig.settings().get("strata", []) if gen_version >= 2 else []
	# WD-4: obsidian is scattered through the hell stratum on its own channel.
	var hell_cfg: Dictionary = WorldConfig.settings().get("hell", {}) if gen_version >= 2 else {}
	var obsidian_noise := FastNoiseLite.new()
	obsidian_noise.seed = world_seed + int(hell_cfg.get("obsidian_seed_offset", 743))
	obsidian_noise.frequency = float(hell_cfg.get("obsidian_frequency", 0.06))
	var obsidian_thr := float(hell_cfg.get("obsidian_threshold", 0.5))

	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.02 * config.gen("terrain_frequency")
	var ore_noise := FastNoiseLite.new()
	ore_noise.seed = world_seed + int(config.gen("ore_seed_offset"))
	ore_noise.frequency = 0.09
	# Higher abundance lowers the noise threshold -> more ore veins.
	var ore_abundance := config.gen("ore_abundance")
	var ore_threshold := 0.75 - 0.13 * ore_abundance
	# FQ-10: data-defined ore families placed by depth band on independent noise
	# channels (data/world_settings.json `ore_table`). The generic `ore` vein
	# above is untouched — families only claim cells that would be stone.
	var ore_families := _build_ore_families(world_seed, ore_abundance)

	var cells: Dictionary = {}
	var surface: Dictionary = {}

	var bedrock_top := height - BEDROCK_THICKNESS
	for x in range(width):
		var surf_y := surface_base + int(round(noise.get_noise_1d(float(x)) * amplitude))
		surf_y = clampi(surf_y, 6, height - 10)
		surface[x] = surf_y
		# WD-4: usable depth of this column (surface -> last cell above bedrock),
		# used to place strata/hell as fractions so every world size has hell.
		var col_depth := maxi(1, bedrock_top - surf_y)
		for y in range(surf_y, height):
			var pos := Vector2i(x, y)
			if y == surf_y:
				cells[pos] = "grass"
			elif y <= surf_y + dirt_depth:
				cells[pos] = "dirt"
			else:
				var depth := y - surf_y
				if gen_version >= 2:
					cells[pos] = _v2_deep_block(x, y, depth, height,
						float(depth) / float(col_depth), strata,
						obsidian_noise, obsidian_thr,
						ore_families, ore_noise, ore_abundance, ore_threshold)
				elif ore_abundance > 0.0 and depth > 8 \
						and ore_noise.get_noise_2d(float(x), float(y)) > ore_threshold:
					cells[pos] = "ore"
				else:
					cells[pos] = _ore_family_at(ore_families, x, y, depth)

	# World Depths (v2, WD-2): carve cave systems out of the filled underground.
	# Runs after the fill so ore is only ever placed in solid rock; carved cells
	# become air (absent), which also shrinks the in-RAM grid.
	if gen_version >= 2:
		var caves_cfg: Dictionary = WorldConfig.settings().get("caves", {})
		if not caves_cfg.is_empty():
			_carve_caves(cells, surface, width, height, world_seed, caves_cfg, dirt_depth)
		# WD-3: pool lava on the floors of hell cavities (after carving). Reuses
		# hell_cfg from the strata setup above.
		if not hell_cfg.is_empty():
			_place_hell_lava(cells, surface, width, height, world_seed, hell_cfg)
		# Developer cheat: carve a switchback staircase from the surface down to a
		# safe hellstone landing in the hell biome (opt-in via the dev_descent preset).
		if config.gen_flag("dev_staircase"):
			_carve_dev_staircase(cells, surface, width, height, hell_cfg)

	# Trees, on their own seed channel. FQ-09R: one unified tree rule — every
	# tree site grows a tree_trunk column topped by a tree_leaves canopy. Both
	# blocks are non-solid (walk in front of/past) and mineable (trunks drop
	# wood through the normal axe-preferred path).
	var tree_density := config.gen("tree_density")
	if tree_density > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = world_seed + int(config.gen("tree_seed_offset"))
		var x_cursor := 4
		while x_cursor < width - 4:
			if rng.randf() < 0.55 * tree_density:
				_grow_tree(cells, rng, x_cursor, surface[x_cursor])
			x_cursor += rng.randi_range(7, 14)

	# Berry bushes: surface food source, own seed channel. Trees occupy the
	# cell above the surface, so the cells guard also keeps bushes out of trunks.
	var bush_density := config.gen("bush_density")
	if bush_density > 0.0:
		var bush_rng := RandomNumberGenerator.new()
		bush_rng.seed = world_seed + int(config.gen("bush_seed_offset"))
		for x in range(2, width - 2):
			var above := Vector2i(x, surface[x] - 1)
			if bush_rng.randf() < 0.07 * bush_density and not cells.has(above):
				cells[above] = "berry_bush"

	return {"cells": cells, "surface": surface,
		"width": width, "height": height}


## FQ-10: builds the per-family noise generators for this seed from the
## `ore_table` authority. Returns [] when ore_abundance is 0 (no ore at all,
## matching the generic-vein rule). Higher abundance lowers each family's
## threshold, so richer worlds expose more of every ore.
static func _build_ore_families(world_seed: int, ore_abundance: float) -> Array:
	if ore_abundance <= 0.0:
		return []
	var out: Array = []
	for entry in WorldConfig.settings().get("ore_table", []):
		var fam_noise := FastNoiseLite.new()
		fam_noise.seed = world_seed + int(entry.get("seed_offset", 0))
		fam_noise.frequency = float(entry.get("frequency", 0.09))
		out.append({
			"id": str(entry.get("id", "")),
			"min_depth": int(entry.get("min_depth", 0)),
			"max_depth": int(entry.get("max_depth", 9999)),
			"threshold": clampf(float(entry.get("threshold", 0.8))
				- 0.10 * (ore_abundance - 1.0), 0.05, 0.99),
			"noise": fam_noise,
		})
	return out


## FQ-10: first ore family (in table order) whose depth band contains this cell
## and whose channel clears its threshold; the stratum base block when none match.
## Deterministic from seed+cell, so the same world always yields the same ore
## layout. `base_block` defaults to "stone" so the legacy (v1) call is unchanged.
static func _ore_family_at(families: Array, x: int, y: int, depth: int,
		base_block := "stone") -> String:
	for fam in families:
		if depth >= int(fam["min_depth"]) and depth <= int(fam["max_depth"]) \
				and (fam["noise"] as FastNoiseLite).get_noise_2d(float(x), float(y)) \
					> float(fam["threshold"]):
			return str(fam["id"])
	return base_block


## World Depths (v2): the base block for a below-topsoil cell. Bedrock floors the
## bottom rows (unmineable); the strata base is chosen by the column depth
## FRACTION `f` (WD-4, so every world size has stone -> deepstone -> hell); in
## the hell stratum an obsidian-noise channel scatters obsidian. The generic ore
## vein and ore families overlay. Deterministic from seed+cell.
static func _v2_deep_block(x: int, y: int, depth: int, height: int, f: float,
		strata: Array, obsidian_noise: FastNoiseLite, obsidian_thr: float,
		families: Array, ore_noise: FastNoiseLite, ore_abundance: float,
		ore_threshold: float) -> String:
	if y >= height - BEDROCK_THICKNESS:
		return "bedrock"
	if ore_abundance > 0.0 and depth > 8 \
			and ore_noise.get_noise_2d(float(x), float(y)) > ore_threshold:
		return "ore"
	var base := _stratum_base_frac(strata, f)
	if base == "hellstone" and obsidian_noise.get_noise_2d(float(x), float(y)) > obsidian_thr:
		base = "obsidian"
	return _ore_family_at(families, x, y, depth, base)


## World Depths (v2, WD-4): the strata base for a column depth FRACTION f (0 at
## the surface, ~1 at bedrock). Bands are ordered by max_frac ascending; the
## first whose max_frac > f wins. "stone" when the table is empty. Fraction-based
## so every world size gets the full stone -> deepstone -> hell progression.
static func _stratum_base_frac(strata: Array, f: float) -> String:
	for s in strata:
		if f < float((s as Dictionary).get("max_frac", 2.0)):
			return str((s as Dictionary).get("base", "stone"))
	return "stone"


## World Depths (v2, WD-2): carve mixed caverns + tunnels out of the filled
## underground. Deterministic from seed. Safety rules (never violated):
##   - keep a solid crust of `surface_crust` cells below each column's surface,
##   - never carve the Town Hall spawn column near the surface,
##   - never carve the bedrock floor.
## Caverns are the above-threshold region of a low-frequency channel (open
## chambers); tunnels are the near-zero band of a second channel (its zero level
## set is a winding curve). A cell is carved if it is in either.
static func _carve_caves(cells: Dictionary, surface: Dictionary, width: int,
		height: int, world_seed: int, caves_cfg: Dictionary, dirt_depth: int) -> void:
	var crust: int = int(caves_cfg.get("surface_crust", 8))
	# Never carve within the topsoil/crust; keep the whole spawn-adjacent surface intact.
	var min_depth: int = maxi(int(caves_cfg.get("min_depth", 0)), maxi(crust, dirt_depth + 1))
	var cav := FastNoiseLite.new()
	cav.seed = world_seed + int(caves_cfg.get("cavern_seed_offset", 0))
	cav.frequency = float(caves_cfg.get("cavern_frequency", 0.05))
	var cav_thr := float(caves_cfg.get("cavern_threshold", 0.42))
	var tun := FastNoiseLite.new()
	tun.seed = world_seed + int(caves_cfg.get("tunnel_seed_offset", 0))
	tun.frequency = float(caves_cfg.get("tunnel_frequency", 0.08))
	var tun_w := float(caves_cfg.get("tunnel_width", 0.05))
	var hall_x := width / 2   # stamp_town_hall places the hall at width / 2
	var bedrock_top := height - BEDROCK_THICKNESS
	for x in range(width):
		var surf_y: int = int(surface.get(x, 0))
		for y in range(surf_y + min_depth, bedrock_top):
			var pos := Vector2i(x, y)
			if not cells.has(pos):
				continue
			# Keep the spawn column solid near the surface so the hall footprint
			# and the descent directly under spawn never open into a void.
			if absi(x - hall_x) <= 7 and (y - surf_y) <= 16:
				continue
			if cav.get_noise_2d(float(x), float(y)) > cav_thr \
					or absf(tun.get_noise_2d(float(x), float(y))) < tun_w:
				cells.erase(pos)


## World Depths (v2, WD-3): pool lava on the floors of hell cavities. A carved
## (air) cell in the hell band that sits directly on solid rock becomes lava
## where a lava-noise channel clears its threshold. Lava is stored (non-solid,
## light-emitting, contact-damage). Deterministic from seed.
static func _place_hell_lava(cells: Dictionary, surface: Dictionary, width: int,
		height: int, world_seed: int, hell_cfg: Dictionary) -> void:
	var start_frac := float(hell_cfg.get("start_frac", 0.68))
	var lava := FastNoiseLite.new()
	lava.seed = world_seed + int(hell_cfg.get("lava_seed_offset", 0))
	lava.frequency = float(hell_cfg.get("lava_frequency", 0.07))
	var lava_thr := float(hell_cfg.get("lava_threshold", 0.0))
	var bedrock_top := height - BEDROCK_THICKNESS
	for x in range(width):
		var surf_y: int = int(surface.get(x, 0))
		# WD-4: hell begins at start_frac of this column's usable depth.
		var col_depth := maxi(1, bedrock_top - surf_y)
		var hell_start_y := surf_y + int(start_frac * float(col_depth))
		for y in range(hell_start_y, bedrock_top):
			var pos := Vector2i(x, y)
			if cells.has(pos):
				continue   # solid rock, not a cavity
			# A cavity floor: air resting directly on a solid cell below.
			if not cells.has(Vector2i(x, y + 1)):
				continue
			if lava.get_noise_2d(float(x), float(y)) > lava_thr:
				cells[pos] = "lava"


## Developer cheat: a switchback staircase from the surface to a safe hellstone
## landing deep in the hell biome. Each step is one cell down and one across,
## reversing at the shaft walls, with headroom and a solid step floor, so it is
## walkable. Runs after caves/lava, overriding whatever it passes through. Opt-in
## via the dev_descent preset; never active in a normal world.
static func _carve_dev_staircase(cells: Dictionary, surface: Dictionary,
		width: int, height: int, hell_cfg: Dictionary) -> void:
	var bedrock_top := height - BEDROCK_THICKNESS
	var shaft_w := 14
	var x0 := clampi(width / 2 + 16, 3, width - shaft_w - 4)   # just east of the hall
	var surf_y := int(surface.get(x0, 0))
	var col_depth := maxi(1, bedrock_top - surf_y)
	# Descend well into hell (start_frac is where hell begins).
	var start_frac := float(hell_cfg.get("start_frac", 0.68))
	var target_y := surf_y + int((start_frac + 0.12) * float(col_depth))
	target_y = mini(target_y, bedrock_top - 3)
	var cx := x0
	var y := surf_y + 1
	var dir := 1
	while y < target_y:
		for hy in range(y - 2, y + 1):
			if hy >= 0 and hy < bedrock_top:
				cells.erase(Vector2i(cx, hy))
		cells[Vector2i(cx, y + 1)] = "stone"   # solid, walkable step
		cx += dir
		y += 1
		if cx <= x0:
			cx = x0
			dir = 1
		elif cx >= x0 + shaft_w:
			cx = x0 + shaft_w
			dir = -1
	# A safe hellstone landing at the bottom, with the lava cleared above it, so
	# the descent never ends in a lava bath.
	for lx in range(x0 - 2, x0 + shaft_w + 3):
		for ly in range(target_y - 3, target_y + 1):
			if ly >= 0 and ly < bedrock_top:
				cells.erase(Vector2i(lx, ly))
		cells[Vector2i(lx, target_y + 1)] = "hellstone"


## Stamps one tree: a tree_trunk column topped by a small tree_leaves canopy.
## Trees never overwrite existing cells, so they cannot swallow terrain.
static func _grow_tree(cells: Dictionary, rng: RandomNumberGenerator,
		x: int, surf_y: int) -> void:
	var trunk_h := rng.randi_range(TREE_MIN_H, TREE_MAX_H)
	for i in range(trunk_h):
		var pos := Vector2i(x, surf_y - 1 - i)
		if pos.y >= 0 and not cells.has(pos):
			cells[pos] = "tree_trunk"
	var top_y := surf_y - 1 - trunk_h
	for dx in range(-1, 2):
		for dy in range(-1, 1):
			var pos := Vector2i(x + dx, top_y + dy)
			if pos.y >= 0 and not cells.has(pos):
				cells[pos] = "tree_leaves"


## Flattens ground and clears air around the Town Hall site, then stamps
## protected town_hall_core cells. Returns the hall footprint info.
static func stamp_town_hall(cells: Dictionary, surface: Dictionary, hall_x: int) -> Dictionary:
	var ground_y: int = surface.get(hall_x, 30)
	for x in range(hall_x - 6, hall_x + 7):
		for y in range(ground_y - 12, ground_y):
			cells.erase(Vector2i(x, y))
		cells[Vector2i(x, ground_y)] = "grass"
		for y in range(ground_y + 1, ground_y + 5):
			if not cells.has(Vector2i(x, y)):
				cells[Vector2i(x, y)] = "dirt"
		surface[x] = ground_y
	var core_cells: Array[Vector2i] = []
	for x in range(hall_x - 1, hall_x + 2):
		for y in range(ground_y - 2, ground_y):
			var pos := Vector2i(x, y)
			cells[pos] = "town_hall_core"
			core_cells.append(pos)
	return {
		"center_cell": Vector2i(hall_x, ground_y - 1),
		"ground_y": ground_y,
		"core_cells": core_cells,
	}
