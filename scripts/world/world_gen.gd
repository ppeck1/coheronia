class_name WorldGen
extends RefCounted
## Deterministic terrain generation, driven by a WorldConfig. Same seed +
## same generation settings -> same terrain. Each block type generates on
## its own seed channel (seed + per-type offset from the config), so the
## variation of ore/trees/bushes within one seed is independently tunable.

const TREE_MIN_H := 3
const TREE_MAX_H := 5

## LQ-3: the liquid block ids the encapsulation pass seals inside rock.
const LIQUID_BLOCK_IDS := ["lava", "water"]

## World Depths: bump this when the generator changes in a way that alters the
## terrain a given seed produces. New worlds are stamped with it at creation
## (game_state.create_world); worlds created earlier keep their stored version
## (absent -> 1) so their seed+delta terrain regenerates unchanged.
##   v1 = legacy (dirt over stone, ore families, solid fill, no caves/hell)
##   v2 = World Depths (data-driven strata, deepstone, unmineable bedrock floor;
##        caves + hell land under this same version as WD-2/WD-3 add them)
##   v3 = Liquid Physics (LQ-3): surface + underground water lakes
##   v4 = Liquid pool pruning: generated lava/water pockets below a minimum
##        connected volume are dropped, so the underground no longer speckles
##        with lone single-cell lava/water blocks.
##   v5 = Liquid encapsulation bugfix: the seal pass walls in EVERY flowable face
##        of a generated pool, not just absent (air) cells. v3/v4 sealed only air,
##        so a pool touching a non-solid decoration (tree/bush) kept a real open
##        face the fluid sim would pour through on the first nearby disturbance.
##        v5 seals those faces (see _encapsulate_liquids); v3/v4 stay byte-identical.
const CURRENT_GEN_VERSION := 5

## v4: a generated liquid pocket (lava or water) smaller than this many connected
## same-liquid cells is removed at gen time, so the caves keep only real pools
## instead of scattered single blocks. Overridable via world_settings `liquids`.
const DEFAULT_MIN_LIQUID_POOL := 5

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
			_place_hell_lava(cells, surface, width, height, world_seed, hell_cfg, gen_version)
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

	# Liquid Physics (v3, LQ-3): water lakes + liquid encapsulation. Runs last so
	# surface ponds clear any trees/bushes in their footprint.
	if gen_version >= 3:
		var water_cfg: Dictionary = WorldConfig.settings().get("water", {})
		if not water_cfg.is_empty():
			_place_underground_water(cells, surface, width, height, world_seed, water_cfg)
		# v4: drop tiny generated liquid pockets (lone single-cell lava/water) so only
		# real pools survive. Runs before encapsulation so pruned cells aren't sealed.
		if gen_version >= 4:
			var min_pool: int = int(WorldConfig.settings().get("liquids", {})
				.get("min_pool_volume", DEFAULT_MIN_LIQUID_POOL))
			_prune_small_liquid_pools(cells, min_pool)
		# Seal every generated liquid (lava + underground water) inside solid rock,
		# so it sits inert until the player MINES into it — a nearby edit no longer
		# merely wakes an already-exposed pool. Runs before surface ponds so ponds
		# keep their open tops.
		_encapsulate_liquids(cells, surface, width, height, strata, gen_version)
		if not water_cfg.is_empty():
			_place_surface_lakes(cells, surface, width, height, world_seed, water_cfg)

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


## World Depths (v2, WD-3): pool lava in hell cavities. Deterministic from seed.
##
## Legacy (gen_version < 4): a carved (air) cell in the hell band sitting directly
## on solid rock becomes lava where a lava-noise channel clears its threshold. This
## per-cell sampling scatters thin, mostly single-cell lava across the floor.
##
## v4: instead, one noise decision PER COLUMN (a constant y sample) picks lava
## columns — so lava forms coherent horizontal lakes — and each qualifying column
## fills its cavity floor bottom-up to `lava_pool_depth`, giving pools real volume.
## This is what stops the "lone single lava block everywhere" look; the later prune
## then only sweeps up genuine stragglers. Lava is stored (non-solid, light-emitting,
## contact-damage).
static func _place_hell_lava(cells: Dictionary, surface: Dictionary, width: int,
		height: int, world_seed: int, hell_cfg: Dictionary, gen_version: int) -> void:
	var start_frac := float(hell_cfg.get("start_frac", 0.68))
	var lava := FastNoiseLite.new()
	lava.seed = world_seed + int(hell_cfg.get("lava_seed_offset", 0))
	lava.frequency = float(hell_cfg.get("lava_frequency", 0.07))
	var lava_thr := float(hell_cfg.get("lava_threshold", 0.0))
	var pool_depth := int(hell_cfg.get("lava_pool_depth", 5))
	var bedrock_top := height - BEDROCK_THICKNESS
	for x in range(width):
		var surf_y: int = int(surface.get(x, 0))
		# WD-4: hell begins at start_frac of this column's usable depth.
		var col_depth := maxi(1, bedrock_top - surf_y)
		var hell_start_y := surf_y + int(start_frac * float(col_depth))
		if gen_version >= 4:
			# One lake decision per column (constant y sample) → coherent lava lakes.
			if lava.get_noise_2d(float(x), float(hell_start_y)) <= lava_thr:
				continue
			var filled := 0
			for y in range(bedrock_top - 1, hell_start_y - 1, -1):   # bottom-up
				var pos := Vector2i(x, y)
				if cells.has(pos):
					filled = 0
					continue
				# Fill air resting on a solid/lava cell, capped at pool_depth.
				if filled < pool_depth and cells.has(Vector2i(x, y + 1)):
					cells[pos] = "lava"
					filled += 1
			continue
		# Legacy per-cell scatter (v2/v3): unchanged for save-compat.
		for y in range(hell_start_y, bedrock_top):
			var pos := Vector2i(x, y)
			if cells.has(pos):
				continue   # solid rock, not a cavity
			# A cavity floor: air resting directly on a solid cell below.
			if not cells.has(Vector2i(x, y + 1)):
				continue
			if lava.get_noise_2d(float(x), float(y)) > lava_thr:
				cells[pos] = "lava"


## Liquid Physics (v3, LQ-3): pools water on cavity floors in a mid depth band
## (above the hell/lava band, so water and lava stay separate at generation). The
## caller seals these pockets with _encapsulate_liquids afterward. Deterministic.
static func _place_underground_water(cells: Dictionary, surface: Dictionary, width: int,
		height: int, world_seed: int, water_cfg: Dictionary) -> void:
	# --- Underground lakes: pool water on cavity floors in a mid band. ---
	var band_top := float(water_cfg.get("underground_band_top_frac", 0.30))
	var band_bot := float(water_cfg.get("underground_band_bot_frac", 0.60))
	var pool_depth := int(water_cfg.get("underground_pool_depth", 5))
	var wnoise := FastNoiseLite.new()
	wnoise.seed = world_seed + int(water_cfg.get("underground_seed_offset", 2551))
	wnoise.frequency = float(water_cfg.get("underground_frequency", 0.05))
	var wthr := float(water_cfg.get("underground_threshold", 0.35))
	var bedrock_top := height - BEDROCK_THICKNESS
	for x in range(width):
		var surf_y: int = int(surface.get(x, 0))
		var col_depth: int = maxi(1, bedrock_top - surf_y)
		var y0: int = surf_y + int(band_top * float(col_depth))
		var y1: int = surf_y + int(band_bot * float(col_depth))
		# One lake decision per column (constant y sample) so lakes form coherent
		# horizontal regions rather than speckle.
		if wnoise.get_noise_2d(float(x), float(y0)) <= wthr:
			continue
		var filled := 0
		for y in range(y1, y0 - 1, -1):   # bottom-up so water rests on floors
			var pos := Vector2i(x, y)
			if cells.has(pos):
				filled = 0
				continue
			# Fill air that rests on a solid/water cell, capped at pool_depth.
			if filled < pool_depth and cells.has(Vector2i(x, y + 1)):
				cells[pos] = "water"
				filled += 1


## v4: removes generated liquid pockets smaller than `min_volume` connected
## same-liquid cells, so the underground keeps only real pools instead of the
## lone single blocks the per-cell noise placement scattered. Connectivity is
## orthogonal (matching the fluid sim's flow) and per-liquid (lava and water are
## never merged into one pocket). Pruned cells become air (the carved cavity they
## pooled in), so this only ever REMOVES liquid — it never adds or moves rock.
## Runs before _encapsulate_liquids so a pruned pocket is not sealed in.
static func _prune_small_liquid_pools(cells: Dictionary, min_volume: int) -> void:
	if min_volume <= 1:
		return
	var visited: Dictionary = {}
	var to_clear: Array[Vector2i] = []
	for start: Vector2i in cells:
		if visited.has(start) or not (str(cells[start]) in LIQUID_BLOCK_IDS):
			continue
		var kind: String = str(cells[start])
		# Flood-fill this pocket (same liquid, orthogonally connected).
		var component: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		visited[start] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			component.append(c)
			for nb: Vector2i in [c + Vector2i(0, 1), c + Vector2i(0, -1),
					c + Vector2i(1, 0), c + Vector2i(-1, 0)]:
				if visited.has(nb):
					continue
				if str(cells.get(nb, "air")) == kind:
					visited[nb] = true
					stack.append(nb)
		if component.size() < min_volume:
			to_clear.append_array(component)
	for c: Vector2i in to_clear:
		cells.erase(c)   # back to air — the cavity these cells pooled in


## Liquid Physics (v3, LQ-3): seals every generated liquid pocket (lava +
## underground water) inside solid rock by filling any open-face cell orthogonally
## adjacent to a liquid with the depth-appropriate stratum block. The result:
## generated liquid never borders a flowable cell, so it sits inert until the
## player MINES into it — mining is what releases it, not merely a nearby edit.
## Runs before surface ponds, which keep their intended open tops.
##
## v5 (bugfix): an "open face" is any cell the fluid sim (`fluid_sim._can_receive`)
## would flow INTO, not merely an absent (air) cell. The v3/v4 pass sealed only
## air, so a generated liquid cell orthogonally touching a NON-SOLID decoration
## (tree_trunk/leaves/berry_bush and, generally, any non-solid non-liquid block)
## was left with a real open face: the sim floods those decorations, so the pool
## would pour into one the moment an adjacent block was disturbed. v5 seals those
## faces too. Existing v3/v4 worlds keep the air-only pass byte-for-byte, so they
## regenerate unchanged; only worlds stamped v5+ get the tightened seal. A cell
## that is already solid, a same-or-other liquid, or a protected structure is a
## barrier and never sealed over.
static func _encapsulate_liquids(cells: Dictionary, surface: Dictionary,
		width: int, height: int, strata: Array, gen_version: int) -> void:
	var bedrock_top := height - BEDROCK_THICKNESS
	var seal: Dictionary = {}   # Vector2i -> solid block id
	for pos: Vector2i in cells:
		if not (str(cells[pos]) in LIQUID_BLOCK_IDS):
			continue
		for nb: Vector2i in [pos + Vector2i(0, 1), pos + Vector2i(0, -1),
				pos + Vector2i(1, 0), pos + Vector2i(-1, 0)]:
			if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= height:
				continue
			if seal.has(nb):
				continue   # already scheduled to be sealed this pass
			if not _is_open_liquid_face(cells, nb, gen_version):
				continue   # rock / liquid / protected (v3-v4: only air is "open")
			var surf_y: int = int(surface.get(nb.x, 0))
			var col_depth: int = maxi(1, bedrock_top - surf_y)
			var f: float = float(maxi(0, nb.y - surf_y)) / float(col_depth)
			seal[nb] = _stratum_base_frac(strata, f)
	for nb: Vector2i in seal:
		cells[nb] = seal[nb]


## True when `nb` is a face a generated liquid could flow through, so the
## encapsulation pass must wall it in.
##   * v3/v4 (save-compat): only an absent (air) cell counts — the original
##     `cells.has(nb)` test, inverted, byte-for-byte.
##   * v5+: mirrors `fluid_sim._can_receive` — air OR any non-solid, non-liquid,
##     non-protected block (a decoration the sim floods) is an open face; solids,
##     liquids (same or other), and protected structures are barriers.
static func _is_open_liquid_face(cells: Dictionary, nb: Vector2i, gen_version: int) -> bool:
	if not cells.has(nb):
		return true   # air — flowable in every version
	if gen_version < 5:
		return false  # v3/v4: an occupied cell is treated as sealed (legacy)
	var bid: String = str(cells[nb])
	if BlockRegistry.is_liquid(bid):
		return false  # a same/other liquid dams (or reacts) — not an open face
	if BlockRegistry.is_solid(bid) or BlockRegistry.has_tag(bid, "protected"):
		return false  # solid rock / protected structure — a barrier
	return true       # a non-solid decoration the sim would flood through


## LQ-3: scatters surface ponds. Each is a tapered bowl carved into the surface
## and filled with water to a flat top; rim columns keep their ground as banks.
## Kept clear of the Town Hall column (stamped later at width / 2).
static func _place_surface_lakes(cells: Dictionary, surface: Dictionary,
		width: int, height: int, world_seed: int, water_cfg: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + int(water_cfg.get("surface_lake_seed_offset", 3313))
	var chance := float(water_cfg.get("surface_lake_chance", 0.10))
	var min_w := int(water_cfg.get("surface_lake_min_w", 5))
	var max_w := int(water_cfg.get("surface_lake_max_w", 10))
	var min_d := int(water_cfg.get("surface_lake_min_depth", 3))
	var max_d := int(water_cfg.get("surface_lake_max_depth", 6))
	var hall_x := width / 2
	var x := max_w + 2
	while x < width - max_w - 2:
		if absi(x - hall_x) > 12 and rng.randf() < chance:
			var w := rng.randi_range(min_w, max_w)
			var d := rng.randi_range(min_d, max_d)
			_carve_surface_lake(cells, surface, x, w, d)
			x += w * 2 + rng.randi_range(6, 14)
		else:
			x += rng.randi_range(6, 16)


## LQ-3: carves one pond at column `cx`, half-width `w`, max depth `d`. The water
## surface is flat at the centre's ground level; the bowl tapers to 0 at the rim
## (so the outer columns stay dry banks). Terrain above the water line in the
## footprint is cleared, and a dirt floor is guaranteed under the deepest cells.
static func _carve_surface_lake(cells: Dictionary, surface: Dictionary,
		cx: int, w: int, d: int) -> void:
	var water_top: int = int(surface.get(cx, 0))
	for lx in range(cx - w + 1, cx + w):
		var dist: int = absi(lx - cx)
		var depth_here: int = int(round(float(d) * (1.0 - float(dist) / float(w))))
		if depth_here <= 0:
			continue   # rim column: leave the ground as a bank
		var bottom: int = water_top + depth_here
		for y in range(0, bottom):
			var pos := Vector2i(lx, y)
			if y >= water_top:
				cells[pos] = "water"
			else:
				cells.erase(pos)   # clear hills/trees above the water line
		if not cells.has(Vector2i(lx, bottom)):
			cells[Vector2i(lx, bottom)] = "dirt"   # a floor to hold the pond
		surface[lx] = water_top


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


## The one canonical tree rule, shared by world-gen and the live renewable-tree
## maturation (world._mature_sapling) so both grow the SAME shape. Given a trunk
## height and the ground cell y (the cell the trunk sits on), returns the ordered
## [[Vector2i, block_id], ...] a tree occupies: a tree_trunk column topped by a
## small 3-wide tree_leaves canopy. Pure geometry — the caller decides how to
## place it (skip occupied cells at gen time; validate clearance when maturing).
static func tree_layout(trunk_h: int, x: int, ground_y: int) -> Array:
	var out: Array = []
	for i in range(trunk_h):
		var pos := Vector2i(x, ground_y - 1 - i)
		if pos.y >= 0:
			out.append([pos, "tree_trunk"])
	var top_y := ground_y - 1 - trunk_h
	for dx in range(-1, 2):
		for dy in range(-1, 1):
			var pos := Vector2i(x + dx, top_y + dy)
			if pos.y >= 0:
				out.append([pos, "tree_leaves"])
	return out


## Stamps one tree: a tree_trunk column topped by a small tree_leaves canopy.
## Trees never overwrite existing cells, so they cannot swallow terrain.
static func _grow_tree(cells: Dictionary, rng: RandomNumberGenerator,
		x: int, surf_y: int) -> void:
	var trunk_h := rng.randi_range(TREE_MIN_H, TREE_MAX_H)
	for entry in tree_layout(trunk_h, x, surf_y):
		var pos: Vector2i = entry[0]
		if not cells.has(pos):
			cells[pos] = str(entry[1])


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
