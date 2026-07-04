extends Node
## Autoload singleton. Single authority for data-driven JSON definitions.

var tile_size: int = 16
var blocks: Dictionary = {}
var recipes: Array = []
var settlement_rules: Dictionary = {}
var world_settings: Dictionary = {}
var character_data: Dictionary = {}


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var block_data: Dictionary = _load_json("res://data/blocks.json")
	tile_size = int(block_data.get("tile_size", 16))
	blocks = block_data.get("blocks", {})
	recipes = _load_json("res://data/recipes.json").get("recipes", [])
	settlement_rules = _load_json("res://data/settlement_rules.json")
	world_settings = _load_json("res://data/world_settings.json")
	character_data = _load_json("res://data/character_data.json")
	if blocks.is_empty():
		push_error("BlockRegistry: no blocks loaded from data/blocks.json")


func trait_effects(trait_ids: Array) -> Dictionary:
	var combined := {}
	for trait_def in character_data.get("traits", []):
		if trait_def.get("id", "") in trait_ids:
			for key in trait_def.get("effects", {}):
				combined[key] = trait_def["effects"][key]
	return combined


func role_def(role_id: String) -> Dictionary:
	for role in character_data.get("roles", []):
		if role.get("id", "") == role_id:
			return role
	return {}


func appearance_def(appearance_id: String) -> Dictionary:
	for appearance in character_data.get("appearances", []):
		if appearance.get("id", "") == appearance_id:
			return appearance
	return {"body": "ebd48c", "trim": "59402e"}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BlockRegistry: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("BlockRegistry: %s did not parse to a dictionary" % path)
	return {}


func get_block(block_id: String) -> Dictionary:
	return blocks.get(block_id, {})


func display_name(block_id: String) -> String:
	return str(get_block(block_id).get("display_name", block_id))


func hardness(block_id: String) -> float:
	return float(get_block(block_id).get("hardness", 1.0))


func required_tool_tier(block_id: String) -> int:
	return int(get_block(block_id).get("required_tool_tier", 0))


func drops(block_id: String) -> Dictionary:
	return get_block(block_id).get("drops", {})


func is_placeable(block_id: String) -> bool:
	return bool(get_block(block_id).get("is_placeable", false))


func is_solid(block_id: String) -> bool:
	return bool(get_block(block_id).get("is_solid", false))


func blocks_light(block_id: String) -> bool:
	return bool(get_block(block_id).get("blocks_light", false))


func emits_light(block_id: String) -> bool:
	return bool(get_block(block_id).get("emits_light", false))


func light_radius(block_id: String) -> int:
	return int(get_block(block_id).get("light_radius", 0))


func has_tag(block_id: String, tag: String) -> bool:
	return tag in get_block(block_id).get("settlement_tags", [])


func get_recipe(recipe_id: String) -> Dictionary:
	for recipe in recipes:
		if recipe.get("recipe_id", "") == recipe_id:
			return recipe
	return {}


## Wave F: returns the preferred tool kind for this block ("pick", "axe", or "").
func preferred_tool(block_id: String) -> String:
	return str(get_block(block_id).get("preferred_tool", ""))


## Wave E: returns true if the block requires a solid block directly below to stay.
func requires_support(block_id: String) -> bool:
	return bool(get_block(block_id).get("requires_support", false))
