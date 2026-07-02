class_name WorldGen
extends RefCounted
## Deterministic terrain generation. Same seed -> same base terrain, so
## saves only need to persist the seed plus edit deltas.

const DIRT_DEPTH := 4
const TREE_MIN_H := 3
const TREE_MAX_H := 5


## Returns { "cells": {Vector2i: block_id}, "surface": {int x: int y} }.
## y grows downward; surface[x] is the y of the topmost solid cell.
static func generate(world_seed: int, width: int, height: int, surface_base: int) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.02
	var ore_noise := FastNoiseLite.new()
	ore_noise.seed = world_seed + 1337
	ore_noise.frequency = 0.09
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	var cells: Dictionary = {}
	var surface: Dictionary = {}

	for x in range(width):
		var surf_y := surface_base + int(round(noise.get_noise_1d(float(x)) * 9.0))
		surf_y = clampi(surf_y, 6, height - 10)
		surface[x] = surf_y
		for y in range(surf_y, height):
			var pos := Vector2i(x, y)
			if y == surf_y:
				cells[pos] = "grass"
			elif y <= surf_y + DIRT_DEPTH:
				cells[pos] = "dirt"
			else:
				if ore_noise.get_noise_2d(float(x), float(y)) > 0.62 and y > surf_y + 8:
					cells[pos] = "ore"
				else:
					cells[pos] = "stone"

	# Simple "trees": short wood columns on the surface as the early wood source.
	var x_cursor := 4
	while x_cursor < width - 4:
		if rng.randf() < 0.55:
			var surf_y2: int = surface[x_cursor]
			var tree_h := rng.randi_range(TREE_MIN_H, TREE_MAX_H)
			for i in range(tree_h):
				cells[Vector2i(x_cursor, surf_y2 - 1 - i)] = "wood"
		x_cursor += rng.randi_range(7, 14)

	return {"cells": cells, "surface": surface}


## Flattens ground and clears air around the Town Hall site, then stamps
## protected town_hall_core cells. Returns the hall footprint info.
static func stamp_town_hall(cells: Dictionary, surface: Dictionary, hall_x: int) -> Dictionary:
	var ground_y: int = surface.get(hall_x, 30)
	for x in range(hall_x - 6, hall_x + 7):
		# Flatten: fill below ground line, clear above it.
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
