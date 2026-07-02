class_name InventoryData
extends RefCounted
## Player inventory: stackable resource counts keyed by item/block id.

var counts: Dictionary = {}


func add(item_id: String, amount: int = 1) -> void:
	counts[item_id] = int(counts.get(item_id, 0)) + amount


func add_many(items: Dictionary) -> void:
	for item_id in items:
		add(str(item_id), int(items[item_id]))


func count(item_id: String) -> int:
	return int(counts.get(item_id, 0))


func remove(item_id: String, amount: int = 1) -> bool:
	if count(item_id) < amount:
		return false
	counts[item_id] = count(item_id) - amount
	if counts[item_id] <= 0:
		counts.erase(item_id)
	return true


func has_all(items: Dictionary) -> bool:
	for item_id in items:
		if count(str(item_id)) < int(items[item_id]):
			return false
	return true


func remove_all(items: Dictionary) -> bool:
	if not has_all(items):
		return false
	for item_id in items:
		remove(str(item_id), int(items[item_id]))
	return true


func total() -> int:
	var sum := 0
	for item_id in counts:
		sum += int(counts[item_id])
	return sum


func to_dict() -> Dictionary:
	return counts.duplicate()


func from_dict(data: Dictionary) -> void:
	counts.clear()
	for item_id in data:
		var n := int(data[item_id])
		if n > 0:
			counts[str(item_id)] = n
