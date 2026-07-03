class_name AncestryDetail
extends RefCounted
## Loads ancestries.json and builds ancestry detail panel text.
## Instance: look up entries by id (shell use).
## Static build_panel_text(): pure function, callable from smoke_test without UI.

const JsonData := preload("res://scripts/data/json_data.gd")

var _ancestries: Array = []


func _init() -> void:
	var data: Dictionary = JsonData.load_dict("res://data/ancestries.json")
	_ancestries = data.get("ancestries", [])


## Returns the full ancestry dict for the given id, or {} if not found.
func get_ancestry(id: String) -> Dictionary:
	for entry: Dictionary in _ancestries:
		if entry.get("id", "") == id:
			return entry
	return {}


## Returns ids of phase-B (currently live) ancestries.
func phase_b_ids() -> Array:
	var ids: Array = []
	for entry: Dictionary in _ancestries:
		if entry.get("implementation_phase", "") == "B":
			ids.append(str(entry.get("id", "")))
	return ids


# ---------------------------------------------------------------------------
# Static text-building (pure function — no I/O, safe to call from smoke_test)
# ---------------------------------------------------------------------------

## Build the compact detail panel text for an ancestry dict.
## is_live = true if the ancestry is currently playable (phase B).
static func build_panel_text(ancestry: Dictionary, is_live: bool) -> String:
	var parts: PackedStringArray = []
	var display_name: String = str(ancestry.get("display_name", "Unknown"))
	var description: String = str(ancestry.get("description", ""))
	parts.append(display_name)
	if description != "":
		parts.append(description)
	if not is_live:
		parts.append("[Planned — not playable yet]")
		return "\n".join(parts)

	# --- Player effects (numeric keys formatted, then notes) ---
	var effects: Dictionary = ancestry.get("player_effects", {})
	var effect_parts: PackedStringArray = []
	for key in effects:
		if key == "notes":
			continue
		var fmt_str: String = _format_effect(str(key), effects[key])
		if fmt_str != "":
			effect_parts.append(fmt_str)
	var notes: Array = effects.get("notes", [])
	for note in notes:
		var s: String = str(note)
		if s != "":
			effect_parts.append(s)
	if effect_parts.size() > 0:
		parts.append("Effects: " + "; ".join(effect_parts))

	# --- Tradeoffs / constraints ---
	var bones: Dictionary = ancestry.get("bones", {})
	var constraint: String = str(bones.get("constraint", ""))
	if constraint != "":
		parts.append("Tradeoff: " + constraint)

	# --- Spawn band ---
	var spawn_band: String = str(ancestry.get("spawn_band", ""))
	if spawn_band != "":
		parts.append("Spawn: " + spawn_band.replace("_", " "))

	# --- Biome affinity summary (best >= 2, worst <= -1) ---
	var biome_text: String = _biome_summary(ancestry.get("biome_affinity", {}))
	if biome_text != "":
		parts.append(biome_text)

	return "\n".join(parts)


## Maps a player_effect key + value to a human-readable string, or "".
## Format codes: pct_from_1 = (val-1)*100%, pct_raw_add = val*100% with +,
##               pct_raw = val*100%, pct_neg = -val*100%, int_plus = +int,
##               mult_x = x<val>, bool_yes = label if true.
static func _format_effect(key: String, value: Variant) -> String:
	# [label, format_code]
	var MAP: Dictionary = {
		"learning_speed_mult":          ["All XP", "pct_from_1"],
		"diplomacy_mult":               ["Diplomacy", "pct_from_1"],
		"stone_ore_mining_mult":        ["Mining (stone/ore)", "pct_from_1"],
		"move_speed_mult":              ["Move", "pct_from_1"],
		"jump_mult":                    ["Jump", "pct_from_1"],
		"jump_bonus":                   ["Jump", "pct_raw_add"],
		"carry_efficiency_mult":        ["Carry capacity", "pct_from_1"],
		"health_bonus":                 ["Max health", "int_plus"],
		"health_reduction":             ["Max health", "mult_x"],
		"stamina_endurance_mult":       ["Stamina endurance", "pct_from_1"],
		"fall_damage_reduction":        ["Fall damage", "pct_neg"],
		"fall_damage_reduction_stone":  ["Fall dmg on stone", "pct_neg"],
		"forest_movement_mult":         ["Forest move", "pct_from_1"],
		"hotbar_slots_bonus":           ["Hotbar slots", "int_plus"],
		"tree_clearing_speed_mult":     ["Tree clearing", "pct_from_1"],
		"stealth_mult":                 ["Stealth", "pct_from_1"],
		"dark_vision":                  ["Dark vision", "bool_yes"],
		"mushroom_harvest_mult":        ["Mushroom harvest", "pct_from_1"],
		"crystal_harvest_mult":         ["Crystal harvest", "pct_from_1"],
		"underground_movement_mult":    ["Underground move", "pct_from_1"],
		"sunlight_stamina_penalty":     ["Sunlight stamina", "pct_from_1"],
		"ore_mining_mult":              ["Ore mining", "pct_from_1"],
		"hitbox_reduction":             ["Hitbox", "pct_from_1"],
		"trap_cost_reduction":          ["Trap cost", "pct_from_1"],
		"material_recovery_chance":     ["Material recovery", "pct_raw"],
		"cave_crawl_speed_mult":        ["Cave crawl", "pct_from_1"],
		"scrap_recovery_mult":          ["Scrap recovery", "pct_from_1"],
		"trap_bonus_underground":       ["Underground traps", "pct_from_1"],
		"trap_cost_reduction_gnome":    ["Trap cost", "pct_from_1"],
		"crafting_speed_mult":          ["Crafting speed", "pct_from_1"],
		"machine_cost_reduction":       ["Machine cost", "pct_from_1"],
		"melee_penalty":                ["Melee", "pct_from_1"],
		"swim_speed_mult":              ["Swim speed", "pct_from_1"],
		"water_breathing":              ["Water breathing", "bool_yes"],
		"poison_resistance_mult":       ["Poison resistance", "pct_from_1"],
		"swamp_movement_mult":          ["Swamp move", "pct_from_1"],
		"cold_food_stamina_mult":       ["Cold food/stamina cost", "pct_from_1"],
		"crystal_machine_bonus":        ["Crystal/machine", "pct_from_1"],
		"precision_crafting_mult":      ["Precision crafting", "pct_from_1"],
		"automation_bonus_deep":        ["Deep automation", "pct_from_1"],
		"surface_survival_penalty":     ["Surface survival", "mult_x"],
		"breath_ability":               ["Elemental breath", "bool_yes"],
		"elemental_resistance":         ["Elemental resistance", "bool_yes"],
		"intimidation_mult":            ["Intimidation", "pct_from_1"],
		"food_need_mult":               ["Food need", "pct_from_1"],
	}
	if not MAP.has(key):
		return ""
	var info: Array = MAP[key]
	var lbl: String = str(info[0])
	var fmt: String = str(info[1])
	if fmt == "pct_from_1":
		var pct: int = int(round((float(value) - 1.0) * 100.0))
		if pct == 0:
			return ""
		if pct > 0:
			return "%s: +%d%%" % [lbl, pct]
		return "%s: %d%%" % [lbl, pct]
	if fmt == "pct_raw_add":
		return "%s: +%d%%" % [lbl, int(round(float(value) * 100.0))]
	if fmt == "pct_raw":
		return "%s: %d%%" % [lbl, int(round(float(value) * 100.0))]
	if fmt == "pct_neg":
		return "%s: -%d%%" % [lbl, int(round(float(value) * 100.0))]
	if fmt == "int_plus":
		return "%s: +%d" % [lbl, int(value)]
	if fmt == "mult_x":
		return "%s: x%.1f" % [lbl, float(value)]
	if fmt == "bool_yes":
		if bool(value):
			return lbl
		return ""
	return ""


## Returns a compact biome affinity summary string.
## Lists up to 3 best biomes (affinity >= 2) and up to 2 worst (affinity <= -1).
static func _biome_summary(biome_affinity: Dictionary) -> String:
	if biome_affinity.is_empty():
		return ""
	# Collect best biomes in descending value order (3 first, then 2), cap at 3.
	var best: PackedStringArray = []
	for target in [3, 2]:
		if best.size() >= 3:
			break
		for biome in biome_affinity:
			if best.size() >= 3:
				break
			if int(biome_affinity[biome]) == target:
				best.append(str(biome).replace("_", " "))
	# Collect worst biomes in ascending value order (-2 first, then -1), cap at 2.
	var worst: PackedStringArray = []
	for target in [-2, -1]:
		if worst.size() >= 2:
			break
		for biome in biome_affinity:
			if worst.size() >= 2:
				break
			if int(biome_affinity[biome]) == target:
				worst.append(str(biome).replace("_", " "))
	var result_parts: PackedStringArray = []
	if best.size() > 0:
		result_parts.append("Best: " + ", ".join(best))
	if worst.size() > 0:
		result_parts.append("Avoid: " + ", ".join(worst))
	if result_parts.size() == 0:
		return ""
	return "Biomes — " + "; ".join(result_parts)
