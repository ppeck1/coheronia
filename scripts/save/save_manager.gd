extends Node
## F5/F9 save/load. Persists seed + terrain deltas, player state, inventory,
## Town Hall stockpile/damage, and time/pressure state as JSON in user://.

const SAVE_PATH := "user://coheronia_save.json"
const SAVE_VERSION := "0.1"

var world: Node2D
var player: CharacterBody2D
var town_hall: Node2D
var game_root: Node


func save_game() -> bool:
	var state := {
		"save_version": SAVE_VERSION,
		"world_seed": world.world_seed,
		"terrain_deltas": world.serialize_deltas(),
		"player": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"health": player.health,
			"tool_tier": player.tool_tier,
			"selected_slot": player.selected_slot,
			"inventory": player.inventory.to_dict(),
		},
		"town_hall": town_hall.to_dict(),
		"time": game_root.time_state(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open %s for writing" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(state, "  "))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var state = JSON.parse_string(file.get_as_text())
	if not state is Dictionary:
		push_error("SaveManager: save file did not parse")
		return false
	if str(state.get("save_version", "")) != SAVE_VERSION:
		push_error("SaveManager: unsupported save version")
		return false

	world.setup(int(state.get("world_seed", 0)),
		world.parse_deltas(state.get("terrain_deltas", {})))

	var p: Dictionary = state.get("player", {})
	player.global_position = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
	player.velocity = Vector2.ZERO
	player.health = float(p.get("health", 100.0))
	player.tool_tier = int(p.get("tool_tier", 1))
	player.selected_slot = clampi(int(p.get("selected_slot", 0)), 0, player.hotbar.size() - 1)
	player.inventory.from_dict(p.get("inventory", {}))
	player.inventory_changed.emit()
	player.health_changed.emit(player.health)

	town_hall.from_dict(state.get("town_hall", {}))
	game_root.apply_time_state(state.get("time", {}))
	return true
