class_name WorldGen
extends RefCounted
## Deterministic terrain generation, driven by a WorldConfig. Same seed +
## same generation settings -> same terrain. Each block type generates on
## its own seed channel (seed + per-type offset from the config), so the
## variation of ore/trees/bushes within one seed is independently tunable.

const TREE_MIN_H := 3
const TREE_MAX_H := 5


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

	for x in range(width):
		var surf_y := surface_base + int(round(noise.get_noise_1d(float(x)) * amplitude))
		surf_y = clampi(surf_y, 6, height - 10)
		surface[x] = surf_y
		for y in range(surf_y, height):
			var pos := Vector2i(x, y)
			if y == surf_y:
				cells[pos] = "grass"
			elif y <= surf_y + dirt_depth:
				cells[pos] = "dirt"
			else:
				var depth := y - surf_y
				if ore_abundance > 0.0 and depth > 8 \
						and ore_noise.get_noise_2d(float(x), float(y)) > ore_threshold:
					cells[pos] = "ore"
				else:
					cells[pos] = _ore_family_at(ore_families, x, y, depth)

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
## and whose channel clears its threshold; "stone" when none match. Deterministic
## from seed+cell, so the same world always yields the same ore layout.
static func _ore_family_at(families: Array, x: int, y: int, depth: int) -> String:
	for fam in families:
		if depth >= int(fam["min_depth"]) and depth <= int(fam["max_depth"]) \
				and (fam["noise"] as FastNoiseLite).get_noise_2d(float(x), float(y)) \
					> float(fam["threshold"]):
			return str(fam["id"])
	return "stone"


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
