extends RefCounted
## S-07.4 (ownership decomposition): the stateless inventory / loadout *policy*
## lifted out of hud.gd behind a preserved facade. Nothing here owns scene state
## -- every function is a pure transform over its arguments and the BlockRegistry
## autoload (block/equipment definitions). hud.gd keeps thin delegating wrappers,
## so its surface and the smoke that drives sorting, tooltips, and equipment-slot
## order are unchanged. Selection state, node access, drag/drop, and player
## inventory mutation stay in hud.gd -- they are NOT policy and must not move.
##
## No `class_name` (repo cache-safety rule): consumers `preload` this script.


## A copy of `layout` with every occurrence of `item_id` cleared to "".
static func layout_without_item(layout: Array, item_id: String) -> Array:
	var out: Array = layout.duplicate()
	for i in range(out.size()):
		if str(out[i]) == item_id:
			out[i] = ""
	return out


## Index of the first empty ("") slot, or layout.size() if the layout is full.
static func first_empty_layout_index(layout: Array) -> int:
	for i in range(layout.size()):
		if str(layout[i]) == "":
			return i
	return layout.size()


static func valid_layout_index(index: int, layout: Array) -> bool:
	return index >= 0 and index < layout.size()


static func is_tool_slot(slot_id: String) -> bool:
	return slot_id == "pickaxe" or slot_id == "axe"


## Deterministic backpack sort key: category bucket, then display name, then id.
static func inventory_sort_key(item_id: String) -> String:
	var category := "9"
	if BlockRegistry.is_placeable(item_id):
		category = "0"
	elif item_id == "ore" or item_id.ends_with("_ore") or item_id.ends_with("_ingot"):
		category = "1"
	elif item_id == "food" or item_id == "crop_seeds":
		category = "2"
	elif item_id == "slime_gel" or item_id == "meat" or item_id == "hide_scrap" \
			or item_id == "thorn_quill" or item_id == "chitin" or item_id == "silk" \
			or item_id == "eyes":
		category = "3"
	elif not BlockRegistry.equipment_item(item_id).is_empty():
		category = "4"
	return "%s|%s|%s" % [category, BlockRegistry.display_name(item_id).to_lower(), item_id]


static func item_tooltip(item_id: String) -> String:
	var tip: String = BlockRegistry.display_name(item_id)
	var desc: String = BlockRegistry.item_description(item_id)
	if desc != "":
		tip += "\n" + desc
	return tip


static func equipment_short_label(slot_id: String, item_id: String) -> String:
	if item_id != "":
		return BlockRegistry.equipment_item_display_name(item_id)
	return str(BlockRegistry.equipment_slot(slot_id).get("display_name", slot_id))


static func equipment_tooltip(slot: Dictionary, item_id: String) -> String:
	var slot_name: String = str(slot.get("display_name", slot.get("id", "")))
	if item_id == "":
		return "%s\nEmpty" % slot_name
	var item: Dictionary = BlockRegistry.equipment_item(item_id)
	var tip: String = "%s\n%s" % [slot_name, BlockRegistry.equipment_item_display_name(item_id)]
	var desc: String = str(item.get("description", ""))
	if desc != "":
		tip += "\n" + desc
	var effects: Dictionary = item.get("effects", {})
	if not effects.is_empty():
		var parts: Array[String] = []
		for key in effects:
			parts.append("%s %+d" % [str(key).capitalize().replace("_", " "), int(effects[key])])
		tip += "\n" + ", ".join(parts)
	return tip


## Equipment board slots in fixed display order (weapon..accessory), filtered to
## the ids that actually exist in BlockRegistry.equipment_slots().
static func equipment_board_slots() -> Array:
	var by_id := {}
	for slot in BlockRegistry.equipment_slots():
		by_id[str(slot.get("id", ""))] = slot
	var order := [
		"weapon", "offhand_weapon", "pickaxe",
		"axe", "helmet", "torso",
		"feet", "ring_1", "ring_2",
		"ring_3", "ring_4", "amulet",
		"accessory",
	]
	var out: Array = []
	for slot_id in order:
		if by_id.has(slot_id):
			out.append(by_id[slot_id])
	return out
