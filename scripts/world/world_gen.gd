class_name WorldGen
extends RefCounted
## Deterministic terrain generation, driven by a WorldConfig. Same seed +
## same generation settings -> same terrain. Each block type generates on
## its own seed channel (seed + per-type offset from the config), so the
## variation of ore/trees/bushes within one seed is independently tunable.

const TREE_MIN_H := 3
const TREE_MAX_H := 5
const BG_TREE_MIN_H := 4
const BG_TREE_MAX_H := 7
## FQ-02: force a solid foreground tree after this many consecutive background
## trees so harvestable wood stays available at any tree_foreground_ratio > 0.
const MAX_CONSECUTIVE_BG_TREES := 2


## Returns { "cells": {Vector2i: block_id}, "surface": {int x: int y},
##           "background": {Vector2i: flora_id}, "width": int, "height": int }.
## background holds decorative pass-through flora (bg_trunk/bg_canopy) that is
## rendered behind actors and never collides, mines, or persists in deltas.
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
				if ore_abundance > 0.0 and y > surf_y + 8 \
						and ore_noise.get_noise_2d(float(x), float(y)) > ore_threshold:
					cells[pos] = "ore"
				else:
					cells[pos] = "stone"

	# Trees, on their own seed channel. FQ-02 splits each tree site into one
	# of two concepts: a solid, mineable foreground wood column, or a taller
	# pass-through background tree (trunk + canopy) in the background dict.
	var background: Dictionary = {}
	var tree_density := config.gen("tree_density")
	if tree_density > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = world_seed + int(config.gen("tree_seed_offset"))
		var fg_ratio := clampf(config.gen("tree_foreground_ratio"), 0.0, 1.0)
		var bg_streak := 0
		var x_cursor := 4
		while x_cursor < width - 4:
			if rng.randf() < 0.55 * tree_density:
				var surf_y2: int = surface[x_cursor]
				var foreground := rng.randf() < fg_ratio
				if fg_ratio > 0.0 and bg_streak >= MAX_CONSECUTIVE_BG_TREES:
					foreground = true
				if foreground:
					bg_streak = 0
					var tree_h := rng.randi_range(TREE_MIN_H, TREE_MAX_H)
					for i in range(tree_h):
						cells[Vector2i(x_cursor, surf_y2 - 1 - i)] = "wood"
				else:
					bg_streak += 1
					_grow_background_tree(cells, background, rng, x_cursor, surf_y2)
			x_cursor += rng.randi_range(7, 14)

	# Berry bushes: surface food source, own seed channel. Skip cells that
	# background flora occupies so bushes never grow inside a background trunk.
	var bush_density := config.gen("bush_density")
	if bush_density > 0.0:
		var bush_rng := RandomNumberGenerator.new()
		bush_rng.seed = world_seed + int(config.gen("bush_seed_offset"))
		for x in range(2, width - 2):
			var above := Vector2i(x, surface[x] - 1)
			if bush_rng.randf() < 0.07 * bush_density and not cells.has(above) \
					and not background.has(above):
				cells[above] = "berry_bush"

	return {"cells": cells, "surface": surface, "background": background,
		"width": width, "height": height}


## Stamps one pass-through background tree: a trunk column topped by a small
## canopy. Background flora never overwrites real cells, so it cannot swallow
## terrain, foreground wood, or bushes.
static func _grow_background_tree(cells: Dictionary, background: Dictionary,
		rng: RandomNumberGenerator, x: int, surf_y: int) -> void:
	var trunk_h := rng.randi_range(BG_TREE_MIN_H, BG_TREE_MAX_H)
	for i in range(trunk_h):
		var pos := Vector2i(x, surf_y - 1 - i)
		if pos.y >= 0 and not cells.has(pos):
			background[pos] = "bg_trunk"
	var top_y := surf_y - trunk_h
	for dx in range(-1, 2):
		for dy in range(-1, 1):
			var pos := Vector2i(x + dx, top_y + dy)
			if pos.y >= 0 and not cells.has(pos) and not background.has(pos):
				background[pos] = "bg_canopy"


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
