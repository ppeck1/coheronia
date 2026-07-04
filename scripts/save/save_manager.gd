extends Node
## F5/F9 save/load. Builds/applies the simulation state dict; persistence
## goes through GameState into the current world's file (the world is a
## configured simulation container: config + terrain history + state).

const SAVE_VERSION := "0.5"
const ACCEPTED_VERSIONS := ["0.5", "0.4"]

var world: Node2D
var player: CharacterBody2D
var town_hall: Node2D
var game_root: Node


func collect_state() -> Dictionary:
	# Wave B: player inventory/slot/tool_tier are now character-owned (in shell.json).
	# World state owns position, health, terrain, hall, time, threats, progression.
	return {
		"save_version": SAVE_VERSION,
		"character_id": str(GameState.current_character.get("id", "")),
		"world_seed": world.world_seed,
		"terrain_deltas": world.serialize_deltas(),
		"player": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"health": player.health,
		},
		"town_hall": town_hall.to_dict(),
		"time": game_root.time_state(),
		"threats": game_root.serialize_threats(),
		"bush_regrow": world.serialize_bush_regrow(),
		"progression": game_root.progression_state(),
	}


func save_game() -> bool:
	# Save character carried state (inventory/slot/tier) to shell.json alongside world.
	var char_id: String = str(GameState.current_character.get("id", ""))
	if char_id != "":
		GameState.save_character_carried(char_id,
			player.inventory.to_dict(), player.selected_slot, player.tool_tier)
	return GameState.save_current_world_state(collect_state(), game_root.summary())


## Returns legacy player inventory/slot/tier from an old-format world state dict.
## Old saves stored these under state["player"]; new saves do not. Used for
## one-time migration of characters that lack a carried_inventory field.
func legacy_player_carried(state: Dictionary) -> Dictionary:
	var p: Dictionary = state.get("player", {})
	if not (p.has("inventory") or p.has("tool_tier") or p.has("selected_slot")):
		return {}
	return {
		"inventory": p.get("inventory", {}),
		"selected_slot": int(p.get("selected_slot", 0)),
		"tool_tier": int(p.get("tool_tier", 1)),
	}


func has_save() -> bool:
	return not GameState.get_current_state().is_empty()


func load_game() -> bool:
	var state: Dictionary = GameState.get_current_state()
	if state.is_empty():
		return false
	if not apply_state(state):
		return false
	apply_player_position(state)
	return true


## Rebuilds the world/simulation from a state dict. Player position is
## applied separately so the fresh-boot path can keep the default spawn.
func apply_state(state: Dictionary) -> bool:
	if str(state.get("save_version", "")) not in ACCEPTED_VERSIONS:
		push_error("SaveManager: unsupported save version")
		return false

	world.setup(int(state.get("world_seed", 0)),
		world.parse_deltas(state.get("terrain_deltas", {})),
		world.parse_bush_regrow(state.get("bush_regrow", {})))

	var p: Dictionary = state.get("player", {})
	player.health = float(p.get("health", 100.0))
	player.health_changed.emit(player.health)
	# Wave B: inventory/slot/tool_tier are character-owned; caller loads them
	# via game_root._load_character_carried_state / _apply_character_carried_state.

	# Fix 10: restore progression BEFORE town_hall.from_dict so _check_base_level
	# sees the correct saved base_level when stockpile_changed fires during from_dict.
	game_root.apply_progression_state(state.get("progression", {}))
	town_hall.from_dict(state.get("town_hall", {}))
	game_root.apply_time_state(state.get("time", {}))
	game_root.apply_threats(state.get("threats", []))
	return true


func apply_player_position(state: Dictionary) -> void:
	var p: Dictionary = state.get("player", {})
	if p.has("x") and p.has("y"):
		player.global_position = Vector2(float(p["x"]), float(p["y"]))
		player.velocity = Vector2.ZERO
