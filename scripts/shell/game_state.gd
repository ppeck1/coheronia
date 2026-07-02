extends Node
## Autoload "GameState": the persistent outer shell. Owns the player
## profile, characters, and worlds (each world = config + terrain
## history + simulation state, stored as user://worlds/<id>.json).
## The shell file user://shell.json holds profile + characters.

const SHELL_PATH := "user://shell.json"
const WORLDS_DIR := "user://worlds"
const SHELL_VERSION := "0.4"

var profile: Dictionary = {}
var characters: Array = []
var current_character: Dictionary = {}
var current_world_id: String = ""
var current_config: WorldConfig = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(WORLDS_DIR)
	load_shell()


# ---------- shell persistence ----------

func load_shell() -> void:
	profile = {"player_name": "Player", "last_world": "", "last_character": "", "created_at": _now()}
	characters = []
	if not FileAccess.file_exists(SHELL_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SHELL_PATH))
	if parsed is Dictionary:
		profile = parsed.get("profile", profile)
		characters = parsed.get("characters", [])


func save_shell() -> bool:
	var file := FileAccess.open(SHELL_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"shell_version": SHELL_VERSION,
		"profile": profile,
		"characters": characters,
	}, "  "))
	return true


# ---------- characters ----------

func create_character(char_data: Dictionary) -> Dictionary:
	var character := {
		"id": _make_id("char"),
		"name": str(char_data.get("name", "Nameless")),
		"species": str(char_data.get("species", "human")),
		"appearance": str(char_data.get("appearance", "tan")),
		"traits": char_data.get("traits", []),
		"role": str(char_data.get("role", "homesteader")),
		"created_at": _now(),
	}
	characters.append(character)
	save_shell()
	return character


func delete_character(char_id: String) -> void:
	for i in range(characters.size()):
		if str(characters[i].get("id", "")) == char_id:
			characters.remove_at(i)
			break
	save_shell()


func get_character(char_id: String) -> Dictionary:
	for character in characters:
		if str(character.get("id", "")) == char_id:
			return character
	return {}


# ---------- worlds ----------

func world_path(world_id: String) -> String:
	return "%s/%s.json" % [WORLDS_DIR, world_id]


## Returns Array of {id, config, meta} for every stored world.
func list_worlds() -> Array:
	var out: Array = []
	for file_name in DirAccess.get_files_at(WORLDS_DIR):
		if not file_name.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [WORLDS_DIR, file_name]))
		if parsed is Dictionary:
			out.append({
				"id": str(parsed.get("meta", {}).get("id", file_name.get_basename())),
				"config": parsed.get("config", {}),
				"meta": parsed.get("meta", {}),
			})
	out.sort_custom(func(a, b) -> bool:
		return str(a["meta"].get("last_played", "")) > str(b["meta"].get("last_played", "")))
	return out


## Creates and persists a world from a config dict. seed 0 -> random.
## Returns the world id.
func create_world(config_dict: Dictionary) -> String:
	var config := WorldConfig.new(config_dict)
	if config.seed_value() == 0:
		config.data["seed"] = (randi() % 999983) + 1
	var world_id := _make_id("world")
	var payload := {
		"world_version": SHELL_VERSION,
		"meta": {
			"id": world_id,
			"created_at": _now(),
			"last_played": "",
			"last_character": "",
			"summary": {},
		},
		"config": config.to_dict(),
		"state": {},
	}
	_write_world(world_id, payload)
	return world_id


func delete_world(world_id: String) -> void:
	DirAccess.remove_absolute(world_path(world_id))


func load_world_file(world_id: String) -> Dictionary:
	if not FileAccess.file_exists(world_path(world_id)):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(world_path(world_id)))
	return parsed if parsed is Dictionary else {}


func _write_world(world_id: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(world_path(world_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	return true


# ---------- play flow ----------

## Enters a world with a character and switches to the game scene.
func start_world(world_id: String, char_id: String) -> void:
	var character := get_character(char_id)
	if character.is_empty() and not characters.is_empty():
		character = characters[0]
	set_context(world_id, character)
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


## Sets the current world/character context without a scene change
## (used by start_world, tests, and the direct-run fallback).
func set_context(world_id: String, character: Dictionary) -> void:
	var payload := load_world_file(world_id)
	current_world_id = world_id
	current_character = character
	current_config = WorldConfig.new(payload.get("config", {}))
	profile["last_world"] = world_id
	profile["last_character"] = str(character.get("id", ""))
	save_shell()


## Persists the running simulation state + summary into the world file.
func save_current_world_state(state: Dictionary, summary: Dictionary) -> bool:
	if current_world_id == "":
		return false
	var payload := load_world_file(current_world_id)
	if payload.is_empty():
		return false
	payload["state"] = state
	payload["meta"]["last_played"] = _now()
	payload["meta"]["last_character"] = str(current_character.get("id", ""))
	payload["meta"]["summary"] = summary
	return _write_world(current_world_id, payload)


func get_current_state() -> Dictionary:
	if current_world_id == "":
		return {}
	return load_world_file(current_world_id).get("state", {})


## Fallback so Main can run directly (F6/smoke) without the shell flow:
## builds a default character and a standard world.
func ensure_play_context() -> void:
	if current_config != null:
		return
	var character := create_character({"name": "Wanderer", "role": "homesteader"})
	var config: Dictionary = WorldConfig.from_preset("folk_kingdom")
	config["name"] = "Quick World"
	var world_id := create_world(config)
	set_context(world_id, character)


func exit_to_shell() -> void:
	current_world_id = ""
	current_config = null
	current_character = {}
	get_tree().change_scene_to_file("res://scenes/shell/Shell.tscn")


# ---------- helpers ----------

func _make_id(prefix: String) -> String:
	return "%s-%d-%04d" % [prefix, int(Time.get_unix_time_from_system()), randi() % 10000]


func _now() -> String:
	return Time.get_datetime_string_from_system()
