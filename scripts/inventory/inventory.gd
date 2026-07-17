class_name InventoryData
extends RefCounted
## Player inventory: stackable resource counts keyed by item/block id.

const DEFAULT_LAYOUT_SLOTS := 35

var counts: Dictionary = {}
## Visual presentation order for the open inventory board. Counts remain the
## quantity authority; this only records which stack appears in which cell.
var layout: Array[String] = []


func add(item_id: String, amount: int = 1) -> void:
	counts[item_id] = int(counts.get(item_id, 0)) + amount
	ensure_layout()


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
	ensure_layout()
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
	ensure_layout()


func set_layout(raw_layout: Array, capacity: int = DEFAULT_LAYOUT_SLOTS) -> void:
	layout = _normalized_layout(raw_layout, capacity)


func layout_to_array(capacity: int = DEFAULT_LAYOUT_SLOTS) -> Array:
	ensure_layout(capacity)
	return layout.duplicate()


func ensure_layout(capacity: int = DEFAULT_LAYOUT_SLOTS) -> void:
	layout = _normalized_layout(layout, capacity)


func _normalized_layout(raw_layout: Array, capacity: int) -> Array[String]:
	var out: Array[String] = []
	for _i in range(maxi(capacity, 0)):
		out.append("")
	var seen := {}
	var limit: int = mini(raw_layout.size(), out.size())
	for i in range(limit):
		var item_id := str(raw_layout[i])
		if item_id == "" or not counts.has(item_id) or seen.has(item_id):
			continue
		out[i] = item_id
		seen[item_id] = true
	var sorted_ids: Array = counts.keys()
	sorted_ids.sort()
	for raw_id in sorted_ids:
		var item_id := str(raw_id)
		if seen.has(item_id):
			continue
		var placed := false
		for i in range(out.size()):
			if out[i] == "":
				out[i] = item_id
				placed = true
				break
		if not placed:
			out.append(item_id)
		seen[item_id] = true
	return out
