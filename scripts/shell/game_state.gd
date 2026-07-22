extends Node
## Autoload "GameState": the persistent outer shell. Owns the player
## profile, characters, and worlds (each world = config + terrain
## history + simulation state, stored as user://worlds/<id>.json).
## The shell file user://shell.json holds profile + characters.

## R-03: the persistence root is injectable so tests/CI can run against a fresh,
## isolated location and never read or write the player's real profile. Set the
## `COHERONIA_PERSIST_ROOT` environment variable (e.g. "user://smoke_root/") to
## redirect all shell/world files; unset means the normal "user://" profile.
const DEFAULT_PERSISTENCE_ROOT := "user://"
## R-03: isolated root used by automated test/capture runs (COHERONIA_SMOKE etc.).
const SMOKE_PERSISTENCE_ROOT := "user://smoke_root/"
const SHELL_VERSION := "0.4"
## R-02: schema versions this build can read. A save stamped with anything else
## is surfaced (schema mismatch) but never destroyed.
const SUPPORTED_VERSIONS: Array[String] = ["0.1", "0.2", "0.3", "0.4"]
const DEFAULT_DOCK_ASSIGNMENTS: Array[String] = ["dirt", "wood", "stone", "torch", "lantern"]

var profile: Dictionary = {}
var characters: Array = []
var current_character: Dictionary = {}
var current_world_id: String = ""
var current_config: WorldConfig = null
var hud_edit_mode := false
# R-03: injectable persistence root (see COHERONIA_PERSIST_ROOT). Derives the
# shell + worlds paths so a test root fully isolates from the real profile.
var persistence_root := DEFAULT_PERSISTENCE_ROOT

# R-02: save-integrity observability. Load paths set these so a corrupt or
# unexpected save is surfaced instead of silently becoming a new empty profile.
# "ok" | "missing" | "recovered" (restored from .bak) | "quarantined" (corrupt,
# moved to .corrupt, no valid backup) | "unsupported_schema".
var shell_load_status := "ok"
var world_load_status := "ok"


func _ready() -> void:
	# R-03: pick the persistence root before the first load so an isolated test/
	# capture run never reads or writes the player's real profile. An explicit
	# COHERONIA_PERSIST_ROOT wins; otherwise any automated/capture flag routes to
	# a dedicated smoke root; a normal launch uses the real "user://" profile.
	var injected := OS.get_environment("COHERONIA_PERSIST_ROOT")
	if injected != "":
		persistence_root = injected
	elif _is_isolated_run():
		persistence_root = SMOKE_PERSISTENCE_ROOT
	DirAccess.make_dir_recursive_absolute(worlds_dir())
	load_shell()


## R-03: true when an automated test or capture flag is set — these runs isolate
## their persistence so they never touch the real profile.
static func _is_isolated_run() -> bool:
	return OS.get_environment("COHERONIA_SMOKE") == "1" \
		or OS.get_environment("COHERONIA_SMOKE_FOCUS") != "" \
		or OS.get_environment("COHERONIA_HUD_QA") == "1" \
		or OS.get_environment("COHERONIA_SHOTS") == "1"


## R-03: the shell profile file under the current persistence root.
func shell_path() -> String:
	return persistence_root.path_join("shell.json")


## R-03: the worlds directory under the current persistence root.
func worlds_dir() -> String:
	return persistence_root.path_join("worlds")


## R-03: redirect persistence to `root` (ensuring its worlds dir) and reload the
## shell from there. Empty falls back to the default. Used to isolate tests.
func set_persistence_root(root: String) -> void:
	persistence_root = root if root != "" else DEFAULT_PERSISTENCE_ROOT
	DirAccess.make_dir_recursive_absolute(worlds_dir())
	load_shell()


# ---------- shell persistence ----------

func load_shell() -> void:
	profile = {"player_name": "Player", "last_world": "", "last_character": "", "created_at": _now()}
	characters = []
	shell_load_status = "ok"
	# R-02: recover instead of silently defaulting. A corrupt shell is quarantined
	# and a .bak is tried; a genuinely unrecoverable/absent file keeps defaults but
	# is surfaced via shell_load_status, never mistaken for a fresh empty profile.
	var result := _load_json_recover(shell_path())
	var status := str(result.get("status", "ok"))
	if status == "missing":
		return
	if status == "quarantined":
		shell_load_status = "quarantined"
		return
	var parsed: Dictionary = result.get("data", {})
	var version := str(parsed.get("shell_version", ""))
	if not _schema_supported(version):
		shell_load_status = "unsupported_schema"
	elif status == "recovered":
		shell_load_status = "recovered"
	# Best-effort load / migrate, even on a schema mismatch (never destroy data).
	profile = parsed.get("profile", profile)
	var loaded_characters: Variant = parsed.get("characters", [])
	if loaded_characters is Array:
		for raw_character in loaded_characters:
			if raw_character is Dictionary:
				var character: Dictionary = raw_character.duplicate(true)
				character["body_variant"] = normalize_body_variant(
					str(character.get("body_variant", "masculine")))
				# FQ-13P3: legacy characters (saved before cosmetic variants)
				# get a deterministic default from their id, so they never
				# change appearance across loads.
				if not character.has("visual_variant"):
					character["visual_variant"] = default_visual_variant(
						str(character.get("id", "")))
				characters.append(character)
	# Heal: a successful recovery from a supported-schema backup re-persists the
	# primary so the next run starts from a healthy file (with a fresh .bak).
	if shell_load_status == "recovered":
		save_shell()


## FQ-09C: profile-level flag — the opening prologue has been completed or
## skipped at least once. Idempotent: replay never rewrites or clears it, and
## no character/world/inventory state is touched.
func mark_prologue_seen() -> void:
	if bool(profile.get("prologue_seen", false)):
		return
	profile["prologue_seen"] = true
	save_shell()


func save_shell() -> bool:
	return _atomic_write_json(shell_path(), {
		"shell_version": SHELL_VERSION,
		"profile": profile,
		"characters": characters,
	})


# ---------- atomic persistence (R-02) ----------

## Serialize `payload` and atomically replace `path`: write a temp file,
## validate that it re-parses to a non-empty object, back up the current file to
## `path`.bak, then rename the temp into place. Guarantees:
## - a crash or failure mid-write never damages the live file (the temp is only
##   renamed in after it validates; on a late failure the .bak is restored);
## - a serialization that cannot round-trip never overwrites a good save;
## - the previous good save is always preserved as `path`.bak for recovery.
## Returns false without leaving `path` missing on any failure.
func _atomic_write_json(path: String, payload: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	# Validate the temp before it is allowed to replace anything.
	if not _json_object_or_null(tmp) is Dictionary:
		DirAccess.remove_absolute(tmp)
		return false
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(path, bak) != OK:
			DirAccess.remove_absolute(tmp)
			return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		# Never leave the live file missing: restore the backup we just moved.
		if FileAccess.file_exists(bak):
			DirAccess.rename_absolute(bak, path)
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Parse a file to a Dictionary, else null (missing file, empty, or bad JSON).
func _json_object_or_null(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return null
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else null


## Load a JSON-object save with recovery. Returns {data, status}:
## - "missing": no file yet (normal first run) -> {}.
## - "ok": parsed cleanly.
## - "recovered": the primary was corrupt (quarantined to `path`.corrupt) and a
##   valid `path`.bak was used instead.
## - "quarantined": the primary was corrupt with no valid backup; it was moved to
##   `path`.corrupt so it is never silently overwritten, and {} is returned.
## A corrupt save is thus surfaced and preserved, never mistaken for "new".
func _load_json_recover(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": {}, "status": "missing"}
	var parsed: Variant = _json_object_or_null(path)
	if parsed is Dictionary:
		return {"data": parsed, "status": "ok"}
	# Primary is corrupt: quarantine it (never delete a user's save blindly).
	var quarantine := path + ".corrupt"
	if FileAccess.file_exists(quarantine):
		DirAccess.remove_absolute(quarantine)
	DirAccess.rename_absolute(path, quarantine)
	var bak := path + ".bak"
	var backup: Variant = _json_object_or_null(bak)
	if backup is Dictionary:
		return {"data": backup, "status": "recovered"}
	return {"data": {}, "status": "quarantined"}


## The version stamp is supported when absent (pre-versioned) or in the known
## set. Anything else is a forward/unknown schema: surface it, do not destroy.
func _schema_supported(version: String) -> bool:
	return version == "" or SUPPORTED_VERSIONS.has(version)


# ---------- characters ----------

func create_character(char_data: Dictionary) -> Dictionary:
	var character := {
		"id": _make_id("char"),
		"name": str(char_data.get("name", "Nameless")),
		"species": str(char_data.get("species", "human")),
		"body_variant": normalize_body_variant(str(char_data.get("body_variant", "masculine"))),
		# FQ-13P3: character-owned cosmetic body variant (presentation-only).
		"visual_variant": maxi(0, int(char_data.get("visual_variant", 0))),
		"appearance": str(char_data.get("appearance", "tan")),
		"traits": char_data.get("traits", []),
		"role": str(char_data.get("role", "homesteader")),
		"created_at": _now(),
		# Wave B: carried state lives on the character, not the world save.
		"items_granted": false,
		"carried_inventory": {},
		"carried_inventory_layout": [],
		"carried_dock_assignments": default_dock_assignments(),
		"carried_slot": 0,
		# Wave F: tool_tiers dict {pick, axe}; carried_tool_tier kept for legacy readers.
		"carried_tool_tiers": {"pick": 1, "axe": 0},
		"carried_tool_tier": 1,
		# FQ-03: gear slots (slot_id -> item_id, "" = empty). Every character
		# starts with the basic pick equipped; everything else is empty.
		"equipment": default_equipment(),
	}
	characters.append(character)
	save_shell()
	return character


func normalize_body_variant(body_variant: String) -> String:
	return BlockRegistry.normalize_body_variant(body_variant)


## FQ-13P3: a stable cosmetic-variant default for a character id (0..2). Legacy
## characters get the same value every load; presentation-only, never random.
func default_visual_variant(char_id: String) -> int:
	if char_id == "":
		return 0
	return posmod(hash(char_id), 3)


## FQ-03: a fresh equipment dict — all slots empty except the starter pickaxe.
func default_equipment() -> Dictionary:
	var out := {}
	for slot in BlockRegistry.equipment_slots():
		out[str(slot.get("id", ""))] = ""
	out["pickaxe"] = "pick_basic"
	return out


func default_dock_assignments() -> Array:
	return DEFAULT_DOCK_ASSIGNMENTS.duplicate()


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


## Persists the character's carried state (inventory, hotbar slot, tool tiers)
## into the characters array and shell.json. Also keeps current_character in sync.
## Wave F: tool_tiers is a dict {"pick": int, "axe": int}; carried_tool_tier is
## kept as a legacy-compat alias for pick tier.
## FQ-03: equipment is the full gear dict (slot_id -> item_id); pass {} to
## leave the character's stored equipment untouched (legacy 4-arg callers).
func save_character_carried(char_id: String, inv_dict: Dictionary,
		slot: int, tool_tiers: Dictionary, equipment: Dictionary = {},
		backpack_layout: Array = [], dock_assignments: Array = []) -> void:
	for i in range(characters.size()):
		if str(characters[i].get("id", "")) == char_id:
			characters[i]["carried_inventory"] = inv_dict
			characters[i]["carried_inventory_layout"] = backpack_layout.duplicate()
			characters[i]["carried_dock_assignments"] = dock_assignments.duplicate() \
				if not dock_assignments.is_empty() else default_dock_assignments()
			characters[i]["carried_slot"] = slot
			characters[i]["carried_tool_tiers"] = tool_tiers
			characters[i]["carried_tool_tier"] = int(tool_tiers.get("pick", 1))
			if not equipment.is_empty():
				characters[i]["equipment"] = equipment
			if str(current_character.get("id", "")) == char_id:
				current_character["carried_inventory"] = inv_dict
				current_character["carried_inventory_layout"] = backpack_layout.duplicate()
				current_character["carried_dock_assignments"] = dock_assignments.duplicate() \
					if not dock_assignments.is_empty() else default_dock_assignments()
				current_character["carried_slot"] = slot
				current_character["carried_tool_tiers"] = tool_tiers
				current_character["carried_tool_tier"] = int(tool_tiers.get("pick", 1))
				if not equipment.is_empty():
					current_character["equipment"] = equipment
			break
	save_shell()


## Marks that this character has received their role starter items.
## Also keeps current_character in sync so re-entry guards work in the same session.
func mark_items_granted(char_id: String) -> void:
	for i in range(characters.size()):
		if str(characters[i].get("id", "")) == char_id:
			characters[i]["items_granted"] = true
			if str(current_character.get("id", "")) == char_id:
				current_character["items_granted"] = true
			break
	save_shell()


# ---------- worlds ----------

func world_path(world_id: String) -> String:
	return "%s/%s.json" % [worlds_dir(), world_id]


## Returns Array of {id, config, meta} for every stored world.
func list_worlds() -> Array:
	var out: Array = []
	for file_name in DirAccess.get_files_at(worlds_dir()):
		if not file_name.ends_with(".json"):
			continue
		# Tolerate a corrupt world file in the listing (it is quarantined on an
		# explicit load, not while enumerating); a valid one is shown normally.
		var parsed: Variant = _json_object_or_null("%s/%s" % [worlds_dir(), file_name])
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
	# R-02: a failed write is observable — return "" instead of an id for a world
	# that was never persisted. The atomic write leaves no partial file behind.
	if not _write_world(world_id, payload):
		return ""
	return world_id


func delete_world(world_id: String) -> void:
	DirAccess.remove_absolute(world_path(world_id))


func load_world_file(world_id: String) -> Dictionary:
	# R-02: recover a corrupt world file from its .bak and surface the status,
	# instead of silently returning {} (which reads as "brand new empty world").
	var result := _load_json_recover(world_path(world_id))
	world_load_status = str(result.get("status", "ok"))
	var data: Dictionary = result.get("data", {})
	# Heal a recovered world so the quarantined primary is restored on disk.
	if world_load_status == "recovered" and not data.is_empty():
		_write_world(world_id, data)
	return data


func _write_world(world_id: String, payload: Dictionary) -> bool:
	return _atomic_write_json(world_path(world_id), payload)


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
	if world_id == "":
		return   # R-02: world write failed; leave no broken play context.
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
