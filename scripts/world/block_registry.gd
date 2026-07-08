extends Node
## Autoload singleton. Single authority for data-driven JSON definitions.

var tile_size: int = 16
var blocks: Dictionary = {}
var recipes: Array = []
var settlement_rules: Dictionary = {}
var world_settings: Dictionary = {}
var character_data: Dictionary = {}
var equipment: Dictionary = {}      # FQ-03: data/equipment.json (slots + items)
var visual_assets: Dictionary = {}  # FQ-07: data/visual_assets.json (image refs)
var _visual_cache: Dictionary = {}  # resolved path -> Texture2D (or null = missing)
var items_data: Dictionary = {}     # FQ-09: data/items.json (non-block item metadata)
var _item_icon_cache: Dictionary = {}  # item_id -> Texture2D (art or fallback swatch)


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
	equipment = _load_json("res://data/equipment.json")
	visual_assets = _load_json("res://data/visual_assets.json")
	items_data = _load_json("res://data/items.json").get("items", {})
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
	# FQ-09: non-block item ids (drops etc.) resolve through items.json.
	var block: Dictionary = get_block(block_id)
	if not block.is_empty():
		return str(block.get("display_name", block_id))
	return str(items_data.get(block_id, {}).get("display_name", block_id))


## FQ-09: one-line descriptor for tooltips ("" when none exists).
func item_description(item_id: String) -> String:
	return str(items_data.get(item_id, {}).get("description", ""))


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


# ---------------------------------------------------------------------------
# FQ-07: visual assets (data/visual_assets.json) — image-first, color fallback
# ---------------------------------------------------------------------------

## Resolved res:// path for a category/id: an explicit entry in
## visual_assets.json overrides the art/generated/<category>/<id>.png
## convention. The file may or may not exist — see visual_texture.
func visual_asset_path(category: String, id: String) -> String:
	var explicit := str(visual_assets.get("categories", {}).get(category, {}).get(id, ""))
	if explicit != "":
		return explicit if explicit.begins_with("res://") else "res://" + explicit
	return "res://%s/%s/%s.png" % [
		str(visual_assets.get("asset_root", "art/generated")), category, id]


## The image texture for category/id, or null when no image exists — callers
## fall back to their generated colors/shapes. Loaded via Image.load_from_file
## (never the import system), so plain runs need no editor import pass.
## Results (including misses) are cached; clear_visual_cache resets.
func visual_texture(category: String, id: String) -> Texture2D:
	var path := visual_asset_path(category, id)
	if _visual_cache.has(path):
		return _visual_cache[path]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_visual_cache[path] = tex
	return tex


## Drops all cached lookups so newly added/removed art is picked up
## (used by smoke and available for a future hot-reload).
func clear_visual_cache() -> void:
	_visual_cache.clear()
	_item_icon_cache.clear()


## FQ-09: a UI icon for any item id — real art when present (FQ-07 lookup),
## otherwise a generated 16x16 color swatch: items.json color, or a
## deterministic hash-derived hue for ids with no data anywhere. Cached;
## cleared together with the visual cache.
func item_icon(item_id: String) -> Texture2D:
	if _item_icon_cache.has(item_id):
		return _item_icon_cache[item_id]
	var tex: Texture2D = visual_texture("items", item_id)
	if tex == null:
		var color := item_fallback_color(item_id)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(color)
		var edge := color.darkened(0.3)
		for i in range(16):
			img.set_pixel(i, 15, edge)
			img.set_pixel(15, i, edge)
		tex = ImageTexture.create_from_image(img)
	_item_icon_cache[item_id] = tex
	return tex


## FQ-09: swatch color for an item id (items.json "color" hex, else a stable
## hue derived from the id so unknown items still get a distinct icon).
func item_fallback_color(item_id: String) -> Color:
	var hex := str(items_data.get(item_id, {}).get("color", ""))
	if hex != "":
		return Color.from_string("#" + hex, Color.MAGENTA)
	return Color.from_hsv(float(hash(item_id) % 360) / 360.0, 0.55, 0.72)


# ---------------------------------------------------------------------------
# FQ-03: equipment (data/equipment.json) — gear slots and equipment items
# ---------------------------------------------------------------------------

## Ordered gear slot definitions [{id, display_name, accepts}, ...].
func equipment_slots() -> Array:
	return equipment.get("slots", [])


func equipment_slot(slot_id: String) -> Dictionary:
	for slot in equipment_slots():
		if str(slot.get("id", "")) == slot_id:
			return slot
	return {}


func equipment_item(item_id: String) -> Dictionary:
	return equipment.get("items", {}).get(item_id, {})


func equipment_item_display_name(item_id: String) -> String:
	return str(equipment_item(item_id).get("display_name", item_id))


## True when item_id can sit in slot_id ("" always fits: an empty slot is valid).
func item_fits_slot(item_id: String, slot_id: String) -> bool:
	if item_id == "":
		return true
	var slot := equipment_slot(slot_id)
	if slot.is_empty():
		return false
	var item := equipment_item(item_id)
	if item.is_empty():
		return false
	return str(item.get("slot_type", "")) == str(slot.get("accepts", ""))


## Returns a full 12-slot equipment dict from a possibly partial/invalid raw
## dict: every known slot id is present; unknown slots are dropped; items that
## do not exist or do not fit their slot become "" (empty is always valid).
func normalize_equipment(raw: Dictionary) -> Dictionary:
	var out := {}
	for slot in equipment_slots():
		var sid := str(slot.get("id", ""))
		var iid := str(raw.get(sid, ""))
		out[sid] = iid if item_fits_slot(iid, sid) else ""
	return out


## Best pickaxe item for a numeric pick tier (highest pick_tier <= tier).
## Tier data lives on the items, so new picks slot in without code changes.
func pick_item_for_tier(tier: int) -> String:
	return _tool_item_for_tier("pickaxe", "pick_tier", tier)


## Axe item for a numeric axe tier ("" when tier 0 — no axe crafted yet).
func axe_item_for_tier(tier: int) -> String:
	return _tool_item_for_tier("axe", "axe_tier", tier)


func _tool_item_for_tier(slot_type: String, effect_key: String, tier: int) -> String:
	var best_id := ""
	var best_tier := 0
	for item_id in equipment.get("items", {}):
		var item: Dictionary = equipment["items"][item_id]
		if str(item.get("slot_type", "")) != slot_type:
			continue
		var item_tier := int(item.get("effects", {}).get(effect_key, 0))
		if item_tier <= tier and item_tier > best_tier:
			best_tier = item_tier
			best_id = item_id
	return best_id
