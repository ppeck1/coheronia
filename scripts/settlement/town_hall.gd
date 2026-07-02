extends Node2D
## Town Hall: settlement anchor. Holds the stockpile, structural damage,
## and abstract population. The protected town_hall_core blocks in the
## world grid give it physical presence; this node is the logic + visual.

signal stockpile_changed
signal damaged(amount: float)

const DEPOSITABLE := ["dirt", "stone", "wood", "ore"]
const REPAIR_COST := {"stone": 2}
const REPAIR_AMOUNT := 25.0

var stockpile: Dictionary = {}
var damage := 0.0            # 0 (intact) .. 100 (ruined)
var population := 4


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
	stockpile_changed.emit()
	return true


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
	stockpile_changed.emit()


func _draw() -> void:
	# Placeholder hall drawn over the core blocks: walls + roof + door + banner.
	var wall := Color(0.42, 0.30, 0.55)
	var roof := Color(0.30, 0.20, 0.40)
	draw_rect(Rect2(-24, -32, 48, 32), wall)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-28, -32), Vector2(28, -32), Vector2(0, -48)]), roof)
	draw_rect(Rect2(-5, -14, 10, 14), Color(0.25, 0.17, 0.10))
	draw_rect(Rect2(-2, -46, 2, 10), Color(0.85, 0.75, 0.30))
	if damage > 0.0:
		# Cracks darken with damage.
		var crack := Color(0, 0, 0, clampf(damage / 130.0, 0.0, 0.7))
		draw_rect(Rect2(-24, -32, 48, 32), crack)
