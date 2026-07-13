extends Node2D
## Town Hall: settlement anchor. Holds the stockpile, structural damage,
## and abstract population. The protected town_hall_core blocks in the
## world grid give it physical presence; this node is the logic + visual.

signal stockpile_changed
signal damaged(amount: float)

const DEPOSITABLE := ["dirt", "stone", "wood", "ore", "food"]
const REPAIR_COST := {"stone": 2}
const REPAIR_AMOUNT := 25.0
const FORGE_RECIPE_ID := "basic_pick_upgrade"
const AXE_RECIPE_ID := "craft_axe"
const SWORD_RECIPE_ID := "craft_sword"
const ARMOR_RECIPE_ID := "craft_armor_set"
const ART_RECT := Rect2(-28, -48, 56, 48)
const WALL_RECT := Rect2(-24, -32, 48, 32)

var stockpile: Dictionary = {}
var damage := 0.0            # 0 (intact) .. 100 (ruined)
var population := 4
var _art: Texture2D = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art = BlockRegistry.visual_texture("structures", "town_hall")


func using_structure_art() -> bool:
	return _art != null


func damage_overlay_alpha() -> float:
	return clampf(damage / 130.0, 0.0, 0.7)


func total_stock() -> int:
	var sum := 0
	for item_id in stockpile:
		sum += int(stockpile[item_id])
	return sum


## Moves all depositable resources from an inventory into the stockpile.
## Returns what was moved.
func deposit_all(inventory: InventoryData) -> Dictionary:
	var moved := {}
	for item_id in DEPOSITABLE:
		var n := inventory.count(item_id)
		if n > 0:
			inventory.remove(item_id, n)
			stockpile[item_id] = int(stockpile.get(item_id, 0)) + n
			moved[item_id] = n
	if not moved.is_empty():
		stockpile_changed.emit()
	return moved


func take_damage(amount: float) -> void:
	damage = clampf(damage + amount, 0.0, 100.0)
	queue_redraw()
	damaged.emit(amount)


## Spends stockpile stone to reduce damage. Returns true if repair happened.
func repair() -> bool:
	if damage <= 0.0:
		return false
	for item_id in REPAIR_COST:
		if int(stockpile.get(item_id, 0)) < int(REPAIR_COST[item_id]):
			return false
	for item_id in REPAIR_COST:
		stockpile[item_id] = int(stockpile[item_id]) - int(REPAIR_COST[item_id])
	damage = maxf(0.0, damage - REPAIR_AMOUNT)
	queue_redraw()
	stockpile_changed.emit()
	return true


## Crafts a town_hall-station recipe: inputs come from the stockpile,
## outputs go to the player's inventory. Returns true on success.
func craft_from_stockpile(recipe_id: String, player: CharacterBody2D) -> bool:
	var recipe: Dictionary = BlockRegistry.get_recipe(recipe_id)
	if str(recipe.get("station", "")) != "town_hall":
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		if int(stockpile.get(item_id, 0)) < int(inputs[item_id]):
			return false
	for item_id in inputs:
		stockpile[item_id] = int(stockpile[item_id]) - int(inputs[item_id])
		if int(stockpile[item_id]) <= 0:
			stockpile.erase(item_id)
	player.inventory.add_many(recipe.get("outputs", {}))
	player.inventory_changed.emit()
	stockpile_changed.emit()
	return true


## Spends stockpile per the town_hall-station recipe to upgrade the
## player's pick to tier 2. Returns true if the forge happened.
func forge_pick(player: CharacterBody2D) -> bool:
	if player.tool_tier >= 2:
		return false
	if not craft_from_stockpile(FORGE_RECIPE_ID, player):
		return false
	player.tool_tier = 2
	return true


## Wave F: crafts an axe (tier 1) from stockpile. Spends wood:4 + stone:2.
## Returns true if the axe was crafted. Player must not already have an axe.
func forge_axe(player: CharacterBody2D) -> bool:
	if player.axe_tier >= 1:
		return false
	var recipe: Dictionary = BlockRegistry.get_recipe(AXE_RECIPE_ID)
	if recipe.is_empty():
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		if int(stockpile.get(item_id, 0)) < int(inputs[item_id]):
			return false
	for item_id in inputs:
		stockpile[item_id] = int(stockpile[item_id]) - int(inputs[item_id])
		if int(stockpile[item_id]) <= 0:
			stockpile.erase(item_id)
	player.axe_tier = 1
	player.inventory_changed.emit()
	stockpile_changed.emit()
	return true


## FQ-04: checks and consumes a recipe's inputs from the stockpile.
## Returns true when everything was available and has been deducted.
func _consume_recipe_inputs(recipe_id: String) -> bool:
	var recipe: Dictionary = BlockRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		if int(stockpile.get(item_id, 0)) < int(inputs[item_id]):
			return false
	for item_id in inputs:
		stockpile[item_id] = int(stockpile[item_id]) - int(inputs[item_id])
		if int(stockpile[item_id]) <= 0:
			stockpile.erase(item_id)
	return true


## FQ-04: forges a crude sword into the weapon gear slot. Spends the
## craft_sword recipe inputs. Player must not already carry a weapon.
## The item/slot fit is verified before inputs are consumed so a data
## regression (renamed item, failed equipment.json load) cannot eat the
## stockpile without equipping anything.
func forge_sword(player: CharacterBody2D) -> bool:
	if str(player.equipped_dict().get("weapon", "")) != "":
		return false
	if not BlockRegistry.item_fits_slot("sword_crude", "weapon"):
		return false
	if not _consume_recipe_inputs(SWORD_RECIPE_ID):
		return false
	player.equip_item("weapon", "sword_crude")
	stockpile_changed.emit()
	return true


## FQ-04: forges the crude armor set (helmet + torso + feet) into the gear
## slots in one craft. Spends the craft_armor_set recipe inputs. Player must
## not already wear a torso piece (the set anchor). All three pieces are
## fit-checked before inputs are consumed, so a partial equip with a spent
## stockpile is impossible.
func forge_armor(player: CharacterBody2D) -> bool:
	if str(player.equipped_dict().get("torso", "")) != "":
		return false
	for piece in [["helmet", "helmet_crude"], ["torso", "torso_crude"], ["feet", "feet_crude"]]:
		if not BlockRegistry.item_fits_slot(piece[1], piece[0]):
			return false
	if not _consume_recipe_inputs(ARMOR_RECIPE_ID):
		return false
	player.equip_item("helmet", "helmet_crude")
	player.equip_item("torso", "torso_crude")
	player.equip_item("feet", "feet_crude")
	stockpile_changed.emit()
	return true


## Population eats from the stockpile once per dawn.
## Returns { "eaten": int, "needed": int }.
func consume_food(needed: int) -> Dictionary:
	var available := int(stockpile.get("food", 0))
	var eaten := mini(needed, available)
	if eaten > 0:
		stockpile["food"] = available - eaten
		if int(stockpile["food"]) <= 0:
			stockpile.erase("food")
		stockpile_changed.emit()
	return {"eaten": eaten, "needed": needed}


func to_dict() -> Dictionary:
	return {
		"stockpile": stockpile.duplicate(),
		"damage": damage,
		"population": population,
	}


func from_dict(data: Dictionary) -> void:
	stockpile = {}
	var raw: Dictionary = data.get("stockpile", {})
	for item_id in raw:
		stockpile[str(item_id)] = int(raw[item_id])
	damage = float(data.get("damage", 0.0))
	population = int(data.get("population", 4))
	queue_redraw()
	stockpile_changed.emit()


func _draw() -> void:
	if _art != null:
		draw_texture_rect(_art, ART_RECT, false)
	else:
		_draw_procedural_fallback()
	if damage > 0.0:
		draw_rect(WALL_RECT, Color(0, 0, 0, damage_overlay_alpha()))


func _draw_procedural_fallback() -> void:
	var wall := Color(0.42, 0.30, 0.55)
	var roof := Color(0.30, 0.20, 0.40)
	draw_rect(WALL_RECT, wall)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-28, -32), Vector2(28, -32), Vector2(0, -48)]), roof)
	draw_rect(Rect2(-5, -14, 10, 14), Color(0.25, 0.17, 0.10))
	draw_rect(Rect2(-2, -46, 2, 10), Color(0.85, 0.75, 0.30))
