extends Node2D
## Game root: wires world/player/hall/HUD together, runs the day/night
## cycle and the night pressure event, and handles save/load/interact input.

const SimpleThreatScene := preload("res://scenes/entities/SimpleThreat.tscn")
const EnemyRegistryClass := preload("res://scripts/data/enemy_registry.gd")
const ProgressionRegistryClass := preload("res://scripts/data/progression_registry.gd")
const AncestryRegistryClass := preload("res://scripts/data/ancestry_registry.gd")

const DAY_LENGTH_SECONDS := 100.0
const NIGHT_START := 0.65          # time_of_day fraction where night begins
const NIGHT_BASE_SEVERITY := 10.0
const INTERACT_RANGE := 72.0

const DAY_TINT := Color(1, 1, 1)
const NIGHT_TINT := Color(0.22, 0.24, 0.38)
const STORM_TINT := Color(0.55, 0.58, 0.66)

const POPULATION_MAX := 8        # absolute ceiling; base_level gates effective cap
const BASE_LEVEL_MAX_MVP := 3   # progression capped at village for MVP

const STORM_CHANCE_PER_DAY := 0.5
const STORM_ROLL_TIME := 0.35      # midday roll point
const STORM_DURATION := 18.0
const STORM_SEVERITY := 8.0
const STORM_MAX_DPS := 3.0

## Cave crawler spawning: checks every N seconds when player is underground.
const CAVE_SPAWN_INTERVAL := 30.0
const CAVE_CRAWLER_CAP := 2

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var town_hall: Node2D = $TownHall
@onready var hud: CanvasLayer = $HUD
@onready var settlement: Node = $SettlementModel
@onready var save_manager: Node = $SaveManager
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var threats: Node2D = $Threats

var time_of_day := 0.25
var day_count := 1
var is_night := false
var storm_active := false
var storm_time_left := 0.0
var _storm_rolled_today := false

var _enemy_registry = null          # EnemyRegistryClass instance
var _cave_spawn_timer := 0.0

var _progression_registry = null    # ProgressionRegistryClass instance
var _ancestry_registry = null       # AncestryRegistryClass instance
## xp_type_id -> float; use int() at every read point to avoid fractional-XP loss
var xp_totals: Dictionary = {}
var player_level := 1
var _level_start_xp := 0           # cumulative XP at start of current level (set by _recalc_player_level)
var base_xp := 0                    # informational; base_level check is authoritative
var base_level := 1                 # ratchets up, never decreases; capped at BASE_LEVEL_MAX_MVP
var _depth_hwm := 0                 # highest depth band reached (10 tiles per band)
## FQ-06: purchased perk ids (Array[String]); world-owned like XP/levels.
## Points: one per player level above 1; spent points derive from perk costs.
var purchased_perks: Array = []
var _depth_check_timer := 0.0
var _warned_requires_keys: Dictionary = {}  # tracks keys already warned about in _meets_base_level_requires


func _ready() -> void:
	GameState.ensure_play_context()
	_enemy_registry = EnemyRegistryClass.new()
	_progression_registry = ProgressionRegistryClass.new()
	_ancestry_registry = AncestryRegistryClass.new()
	# Initialise XP totals to 0.0 (float) for every known type.
	for t: Dictionary in _progression_registry.xp_types():
		xp_totals[str(t.get("id", ""))] = 0.0
	_wire_references()
	_wire_signals()
	player.apply_character(GameState.current_character)
	apply_ancestry_for_species(str(GameState.current_character.get("species", "")))
	var saved_state: Dictionary = GameState.get_current_state()
	if saved_state.is_empty():
		world.setup(config().seed_value())
	else:
		save_manager.apply_state(saved_state)
	# Wave B: load character-owned carried state (with legacy migration when needed).
	_load_character_carried_state(saved_state)
	# Grant role starter items once per character (flag prevents duplication).
	_grant_role_items()
	_position_actors()
	if not saved_state.is_empty():
		# Saved player position overrides the default spawn.
		save_manager.apply_player_position(saved_state)
	hud.update_inventory()
	hud.update_health(player.health, player.max_health)
	hud.update_attunement(player.attunement, player.max_attunement())
	_refresh_hud_progression()
	log_event("Welcome to Coheronia. Shelter and light the Town Hall.")
	hud.set_save_hint(save_manager.has_save())
	settlement.compute()
	if OS.get_environment("COHERONIA_SMOKE") == "1":
		var smoke := preload("res://scripts/main/smoke_test.gd").new()
		smoke.name = "SmokeTest"
		add_child(smoke)


func config() -> WorldConfig:
	return GameState.current_config


func _grant_role_items() -> void:
	# Wave B: grant once per character using the items_granted flag.
	if bool(GameState.current_character.get("items_granted", false)):
		return
	var char_id: String = str(GameState.current_character.get("id", ""))
	var role: Dictionary = BlockRegistry.role_def(str(GameState.current_character.get("role", "")))
	var items: Dictionary = role.get("starting_items", {})
	if not items.is_empty():
		player.inventory.add_many(items)
		player.inventory_changed.emit()
	GameState.mark_items_granted(char_id)


## Wave B/F: loads this character's carried state into the player.
## If the character lacks a carried_inventory field (legacy character), attempts a
## one-time migration from the world save's player dict; otherwise uses sane defaults.
## Wave F: reads carried_tool_tiers dict {pick, axe}; old chars with only
## carried_tool_tier migrate to {pick: N, axe: 0} (the axe must be crafted).
## Always calls inventory_changed so the HUD refreshes.
func _load_character_carried_state(saved_state: Dictionary) -> void:
	if GameState.current_character.is_empty():
		player.inventory.from_dict({})
		player.selected_slot = 0
		player.tool_tier = 1
		player.axe_tier = 0
		player.apply_equipment({})
		player.inventory_changed.emit()
		return
	# FQ-03: gear slots ride on the character record; a pre-FQ-03 character
	# without the key gets empty inert slots here and the full dict (tool
	# slots derived from tiers) persisted on the next save.
	player.apply_equipment(Dictionary(GameState.current_character.get("equipment", {})))
	if GameState.current_character.has("carried_inventory"):
		# Character record is authoritative.
		player.inventory.from_dict(
			Dictionary(GameState.current_character.get("carried_inventory", {})))
		player.selected_slot = clampi(
			int(GameState.current_character.get("carried_slot", 0)),
			0, player.hotbar.size() - 1)
		# Wave F: prefer the new tool_tiers dict; fall back to legacy field.
		if GameState.current_character.has("carried_tool_tiers"):
			var tiers := Dictionary(GameState.current_character.get("carried_tool_tiers", {}))
			player.tool_tier = int(tiers.get("pick", 1))
			player.axe_tier = int(tiers.get("axe", 0))
		else:
			player.tool_tier = int(GameState.current_character.get("carried_tool_tier", 1))
			player.axe_tier = 0  # legacy migration: the axe must still be crafted
		# FQ-03 review fix: a pre-FQ-03 record (no equipment key) gets its
		# derived gear persisted immediately, mirroring the legacy branch,
		# instead of depending on the player reaching an explicit save.
		if not GameState.current_character.has("equipment"):
			GameState.save_character_carried(
				str(GameState.current_character.get("id", "")),
				player.inventory.to_dict(), player.selected_slot,
				{"pick": player.tool_tier, "axe": player.axe_tier},
				player.equipped_dict())
	else:
		# Legacy character (no carried_inventory key): migrate from world save once.
		var legacy: Dictionary = save_manager.legacy_player_carried(saved_state)
		var migrated_from_world := not legacy.is_empty()
		if migrated_from_world:
			player.inventory.from_dict(legacy.get("inventory", {}))
			player.selected_slot = clampi(int(legacy.get("selected_slot", 0)),
				0, player.hotbar.size() - 1)
			player.tool_tier = int(legacy.get("tool_tier", 1))
			player.axe_tier = 0  # legacy migration: the axe must still be crafted
		else:
			player.inventory.from_dict({})
			player.selected_slot = 0
			player.tool_tier = 1
			player.axe_tier = 0
		# Persist the migrated or default state into the character record.
		# FQ-03: include the derived gear dict so the legacy character gains
		# its equipment shape (starter/forged pick, crafted axe) immediately.
		var char_id: String = str(GameState.current_character.get("id", ""))
		GameState.save_character_carried(char_id,
			player.inventory.to_dict(), player.selected_slot,
			{"pick": player.tool_tier, "axe": player.axe_tier},
			player.equipped_dict())
		# FQ-00: a legacy world already granted this character's starter items
		# under the pre-v0.6 format, and that inventory just became authoritative
		# above. Mark items_granted so _grant_role_items() does not add a second
		# copy of the role's starting_items on top of the migrated inventory.
		# A character with no legacy world data yet (migrated_from_world == false)
		# is treated as brand new and still receives its starter grant normally.
		if migrated_from_world:
			GameState.mark_items_granted(char_id)
	player.inventory_changed.emit()


## Wave B/F: applies the current character's carried state to the player.
## Used by load_game() — no migration needed because the character was already
## written during the preceding save_game() call. Handles both new (tool_tiers
## dict) and legacy (carried_tool_tier only) formats defensively.
func _apply_character_carried_state() -> void:
	var char: Dictionary = GameState.current_character
	player.inventory.from_dict(Dictionary(char.get("carried_inventory", {})))
	player.selected_slot = clampi(
		int(char.get("carried_slot", 0)), 0, player.hotbar.size() - 1)
	# FQ-03: restore gear slots (tool slots re-derive from the tiers below).
	player.apply_equipment(Dictionary(char.get("equipment", {})))
	if char.has("carried_tool_tiers"):
		var tiers := Dictionary(char.get("carried_tool_tiers", {}))
		player.tool_tier = int(tiers.get("pick", 1))
		player.axe_tier = int(tiers.get("axe", 0))
	else:
		player.tool_tier = int(char.get("carried_tool_tier", 1))
		player.axe_tier = 0  # legacy migration: the axe must still be crafted
	player.inventory_changed.emit()


func summary() -> Dictionary:
	return {
		"day": day_count,
		"population": town_hall.population,
		"coherence": int(round(settlement.coherence)),
		"damage": int(round(town_hall.damage)),
	}


func _wire_references() -> void:
	player.world = world
	settlement.world = world
	settlement.town_hall = town_hall
	settlement.game_root = self
	save_manager.world = world
	save_manager.player = player
	save_manager.town_hall = town_hall
	save_manager.game_root = self
	hud.player = player
	hud.town_hall = town_hall
	# FQ-06: the skill tree panel reads perk state through this game_root.
	hud.setup_skill_panel(self)


func _wire_signals() -> void:
	player.inventory_changed.connect(hud.update_inventory)
	player.health_changed.connect(hud.update_health)
	player.attunement_changed.connect(hud.update_attunement)
	player.mined.connect(_on_player_mined)
	player.crafted.connect(_on_player_crafted)
	player.placed.connect(_on_player_placed)
	player.player_event.connect(log_event)
	town_hall.stockpile_changed.connect(func() -> void:
		hud.update_inventory()
		settlement.compute())
	settlement.updated.connect(hud.update_settlement)
	settlement.updated.connect(
		func(_c: float, _l: float, _r: float, _i: Dictionary, _lb: Array) -> void:
			_check_base_level())
	hud.deposit_requested.connect(_on_deposit_requested)
	hud.repair_requested.connect(_on_repair_requested)
	hud.forge_requested.connect(_on_forge_requested)
	hud.forge_axe_requested.connect(_on_forge_axe_requested)
	hud.forge_sword_requested.connect(_on_forge_sword_requested)
	hud.forge_armor_requested.connect(_on_forge_armor_requested)
	hud.lantern_requested.connect(_on_lantern_requested)


func _position_actors() -> void:
	var hall_center: Vector2 = world.cell_center(world.hall_info["center_cell"])
	town_hall.position = Vector2(hall_center.x, (world.hall_info["ground_y"]) * world.tile_size())
	player.global_position = hall_center + Vector2(-64, -40)
	var camera: Camera2D = player.get_node("Camera2D")
	var bounds: Rect2 = world.world_bounds()
	camera.limit_left = int(bounds.position.x)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.limit_top = -200


const _DEPTH_CHECK_INTERVAL := 3.0

func _process(delta: float) -> void:
	_advance_time(delta)
	_advance_cave_spawns(delta)
	_depth_check_timer += delta
	if _depth_check_timer >= _DEPTH_CHECK_INTERVAL:
		_depth_check_timer = 0.0
		_check_depth_xp()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		if save_manager.save_game():
			log_event("Game saved (F5).")
			hud.set_save_hint(true)
		else:
			log_event("Save failed.")
	elif event.is_action_pressed("load_game"):
		if load_game():
			log_event("Game loaded (F9).")
		else:
			log_event("No save to load.")
	elif event.is_action_pressed("toggle_inventory"):
		# Wave C: opening inventory closes the other panels; they do not overlap.
		if hud.town_panel_open():
			hud.toggle_town_panel()
		if hud.skill_panel_open():
			hud.toggle_skill_panel()
		hud.toggle_inventory_panel()
	elif event.is_action_pressed("toggle_skills"):
		# FQ-06: the skill tree is mutually exclusive with the other panels.
		if hud.town_panel_open():
			hud.toggle_town_panel()
		if hud.inventory_panel_open():
			hud.toggle_inventory_panel()
		hud.toggle_skill_panel()
	elif event.is_action_pressed("interact") or event.is_action_pressed("toggle_town"):
		_try_interact()
	elif event.is_action_pressed("ui_cancel"):
		# Esc closes skills, then inventory, then town panel, then saves and exits.
		if hud.skill_panel_open():
			hud.toggle_skill_panel()
		elif hud.inventory_panel_open():
			hud.toggle_inventory_panel()
		elif hud.town_panel_open():
			hud.toggle_town_panel()
		else:
			save_manager.save_game()
			log_event("Saved. Returning to the shell...")
			GameState.exit_to_shell()


func _advance_time(delta: float) -> void:
	time_of_day += delta / DAY_LENGTH_SECONDS
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day_count += 1
		_storm_rolled_today = false
	var night_now := time_of_day >= NIGHT_START
	if night_now and not is_night:
		_on_nightfall()
	elif not night_now and is_night:
		_on_dawn()
	is_night = night_now
	_advance_storm(delta)
	# Smooth tint transition near the day/night/storm boundaries.
	var target := NIGHT_TINT if is_night else (STORM_TINT if storm_active else DAY_TINT)
	canvas_modulate.color = canvas_modulate.color.lerp(target, delta * 1.5)


func _advance_storm(delta: float) -> void:
	if not _storm_rolled_today and not is_night and time_of_day >= STORM_ROLL_TIME:
		_storm_rolled_today = true
		if config().rule("weather_affects_survival") \
				and randf() < STORM_CHANCE_PER_DAY * config().environment_danger():
			start_storm()
	if not storm_active:
		return
	storm_time_left -= delta
	# Exposure: a roofed hall shrugs storms off; ground fill does not help.
	var exposure: float = clampf(1.0 - settlement.roof_coverage(), 0.0, 1.0)
	if exposure > 0.05:
		town_hall.take_damage(STORM_MAX_DPS * config().environment_danger() * exposure * delta)
		town_hall.queue_redraw()
	if storm_time_left <= 0.0:
		storm_active = false
		log_event("The storm passes.")
		if player.health > 0.0:
			award_xp("storm_survived")
		settlement.compute()


func start_storm() -> void:
	storm_active = true
	storm_time_left = STORM_DURATION
	log_event("A storm batters the settlement! Exposed structures take damage.")
	settlement.compute()


## Deterministic entry point for the smoke test. Respects the weather
## rule; returns whether a storm actually started.
func force_storm() -> bool:
	_storm_rolled_today = true
	if not config().rule("weather_affects_survival"):
		return false
	start_storm()
	return true


func _on_nightfall() -> void:
	is_night = true
	var base_count := night_spawn_count()
	# Fix 7: apply density_mult from the difficulty profile to the surface spawn count.
	var scaling := {"density_mult": 1.0, "loot_mult": 1.0}
	if _enemy_registry != null:
		scaling = _enemy_registry.scaling_for_difficulty(config().difficulty("enemy"))
	var spawn_count := 0
	if base_count > 0:
		spawn_count = clampi(int(round(float(base_count) * float(scaling.get("density_mult", 1.0)))), 1, 5)
	if spawn_count > 0:
		log_event("Night falls. Pressure rises (%d threat%s approaching)." % [
			spawn_count, "" if spawn_count == 1 else "s"])
	else:
		log_event("Night falls.")
	for i in range(spawn_count):
		_spawn_surface_slime(i)
	_maybe_spawn_raider()
	hud.update_time(day_count, true, spawn_count)
	settlement.compute()


## Threats per night from the world config: darkness rule gates spawns,
## the lighting rule lets torches near the hall reduce them, and the
## enemy difficulty axis scales the count.
func night_spawn_count() -> int:
	if not config().rule("darkness_increases_enemies"):
		return 0
	var enemy: float = config().difficulty("enemy")
	if enemy <= 0.0:
		return 0
	var base := 2
	if config().rule("lighting_affects_safety"):
		var light_score: float = settlement.gather_inputs().get("light_score", 0.0)
		if light_score >= 16.0:
			base = 1
	return clampi(int(ceil(base * enemy)), 1, 5)


## Threat hp from enemy difficulty, plus time scaling when enabled.
func threat_hp() -> int:
	var hp := maxi(1, int(round(3.0 * config().difficulty("enemy"))))
	if config().rule("enemies_scale_over_time"):
		hp += (day_count - 1) / 3
	return hp


func _on_dawn() -> void:
	is_night = false
	hud.update_time(day_count, false)
	var all_threats := get_tree().get_nodes_in_group("threats")
	var survived := all_threats.size()
	for threat in all_threats:
		# Fix 5: spare underground enemies — cave crawlers persist through dawn.
		if threat.family != "underground":
			threat.queue_free()
	log_event("Dawn breaks. The pressure recedes." if survived > 0 else "Dawn breaks.")
	award_xp("night_survived")
	consume_daily_food()
	settlement.compute()


func daily_food_need() -> int:
	return maxi(1, ceili(town_hall.population / 2.0 * config().difficulty("survival")))


## Coherence needed for a settler to arrive: lower when subjects are
## impressionable, adjusted by the character's charisma.
func growth_threshold() -> float:
	return 70.0 - 15.0 * config().difficulty("impressionability") + player.growth_threshold_delta


## Population eats at dawn. Shortage feeds scarcity_penalty via the
## settlement model and drives settlers away; abundance plus a coherent
## settlement attracts newcomers.
func consume_daily_food() -> void:
	var coherence_at_dawn: float = settlement.coherence
	if not config().rule("subjects_require_food"):
		_update_population({"eaten": 0, "needed": 0}, coherence_at_dawn)
		return
	var result: Dictionary = town_hall.consume_food(daily_food_need())
	if result["eaten"] >= result["needed"]:
		log_event("Settlers ate %d food from the stockpile." % result["eaten"])
		award_xp("subject_fed")
	else:
		log_event("Food shortage! Settlers needed %d food, found %d. Gather berries." % [
			result["needed"], result["eaten"]])
	_update_population(result, coherence_at_dawn)


func _update_population(meal: Dictionary, coherence_at_dawn: float) -> void:
	var requires_food: bool = config().rule("subjects_require_food")
	var food_ok: bool = not requires_food \
		or int(town_hall.stockpile.get("food", 0)) >= town_hall.population
	if meal["eaten"] < meal["needed"]:
		if town_hall.population > 1:
			town_hall.population -= 1
			log_event("A settler left after going hungry. Population is now %d." % town_hall.population)
	elif coherence_at_dawn >= growth_threshold() and food_ok \
			and town_hall.population < effective_population_cap():
		town_hall.population += 1
		log_event("Drawn by a thriving settlement, a settler arrived. Population is now %d." % town_hall.population)
	town_hall.stockpile_changed.emit()


## Spawn a surface_slime at night (replaces hardcoded night threat).
func _spawn_surface_slime(index: int) -> void:
	var def: Dictionary = {}
	if _enemy_registry != null:
		def = _enemy_registry.get_def("surface_slime")
	# Fix 9: guard against empty def (mirrors _maybe_spawn_raider and _advance_cave_spawns).
	if def.is_empty():
		return
	var side := -1 if index % 2 == 0 else 1
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	var spawn_x: int = hall_cell.x + side * 22
	var surf_y: int = world.surface.get(spawn_x, hall_cell.y)
	_spawn_enemy_at(def, world.cell_center(Vector2i(spawn_x, surf_y - 2)))


## Spawn a raider_basic when conditions from the def's spawn_rule are met.
## Fix 6: read thresholds and base_chance from the def's spawn_rule dict.
## Fix 7: multiply base_chance by density_mult.
func _maybe_spawn_raider() -> void:
	if _enemy_registry == null:
		return
	if not config().rule("darkness_increases_enemies"):
		return
	var def: Dictionary = _enemy_registry.get_def("raider_basic")
	if def.is_empty():
		return
	var spawn_rule: Dictionary = def.get("spawn_rule", {})
	var day_thresh: int = int(spawn_rule.get("day_threshold", 5))
	var stock_thresh: int = int(spawn_rule.get("stockpile_threshold", 25))
	var base_chance: float = float(spawn_rule.get("base_chance", 0.3))
	var stockpile_big: bool = town_hall.total_stock() >= stock_thresh
	if day_count < day_thresh and not stockpile_big:
		return
	var scaling: Dictionary = _enemy_registry.scaling_for_difficulty(config().difficulty("enemy"))
	var effective_chance: float = base_chance * float(scaling.get("density_mult", 1.0))
	if randf() > effective_chance * config().difficulty("enemy"):
		return
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	var side := 1 if randi() % 2 == 0 else -1
	var spawn_x: int = hall_cell.x + side * 35
	var surf_y: int = world.surface.get(spawn_x, hall_cell.y)
	_spawn_enemy_at(def, world.cell_center(Vector2i(spawn_x, surf_y - 2)))
	log_event("WARNING: A raider approaches the settlement!")


## Advance the cave crawler periodic spawn timer; spawn underground when ready.
func _advance_cave_spawns(delta: float) -> void:
	if _enemy_registry == null:
		return
	# Fix 8a: peaceful worlds must have no cave crawlers.
	if not config().rule("darkness_increases_enemies"):
		return
	_cave_spawn_timer += delta
	if _cave_spawn_timer < CAVE_SPAWN_INTERVAL:
		return
	_cave_spawn_timer = 0.0
	# Fix 8c: count live underground-family enemies (not just cave_crawler id).
	var crawler_count := 0
	for t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			if t.family == "underground":
				crawler_count += 1
	if crawler_count >= CAVE_CRAWLER_CAP:
		return
	# Only spawn if the player is underground (below the surface y).
	var pcell: Vector2i = world.cell_of(player.global_position)
	# Fix 8b: guard against missing map-edge columns (fallback 0 wrongly passes).
	if not world.surface.has(pcell.x):
		return
	var surf_y: int = world.surface.get(pcell.x, 0)
	if pcell.y <= surf_y:
		return
	# Find a nearby air cell underground for the spawn.
	var spawn_cell := Vector2i(pcell.x + (randi() % 7 - 3), pcell.y + 1)
	var tries := 0
	while world.block_at(spawn_cell) != "air" and tries < 8:
		spawn_cell.y += 1
		tries += 1
	if world.block_at(spawn_cell) != "air":
		return
	var def: Dictionary = _enemy_registry.get_def("cave_crawler")
	if def.is_empty():
		return
	_spawn_enemy_at(def, world.cell_center(spawn_cell))
	log_event("A Cave Crawler lurks in the dark below.")


## Generic enemy spawner configured from a def dict.
func _spawn_enemy_at(def: Dictionary, pos: Vector2) -> Node:
	var scaling := {"density_mult": 1.0, "loot_mult": 1.0}
	if _enemy_registry != null:
		scaling = _enemy_registry.scaling_for_difficulty(config().difficulty("enemy"))
	var threat := SimpleThreatScene.instantiate()
	threat.world = world
	threat.town_hall = town_hall
	threat.player = player
	threat.position = pos
	threat.enemy_id = str(def.get("id", "surface_slime"))
	threat.family = str(def.get("family", "surface"))
	threat.drops = def.get("drops", [])
	threat.loot_mult = float(scaling.get("loot_mult", 1.0))
	threat.hp = threat_hp()
	threat.hall_dps = 4.0 * config().difficulty("enemy")
	# FQ-01: data-driven contact damage/speed from the def, falling back to
	# the simple_threat.gd consts when the def omits them. contact_damage
	# scales with enemy difficulty like hall_dps.
	threat.contact_damage = float(def.get("contact_damage", threat.PLAYER_DAMAGE)) \
		* config().difficulty("enemy")
	threat.move_speed = float(def.get("speed", threat.SPEED))
	threat.died.connect(_on_threat_died)
	threats.add_child(threat)
	return threat


## Smoke-test hook: spawn one enemy by id at a deterministic test position.
func spawn_enemy_for_test(enemy_id: String) -> Node:
	var def: Dictionary = {}
	if _enemy_registry != null:
		def = _enemy_registry.get_def(enemy_id)
	var hall_cell: Vector2i = world.hall_info.get("center_cell", Vector2i(world.width / 2, 0))
	var spawn_x: int = hall_cell.x + 30
	var surf_y: int = world.surface.get(spawn_x, hall_cell.y)
	return _spawn_enemy_at(def, world.cell_center(Vector2i(spawn_x, surf_y - 2)))


func _on_threat_died() -> void:
	log_event("A threat was destroyed.")
	award_xp("enemy_defeated")
	settlement.compute()
	call_deferred("_refresh_threat_display")


func _live_threat_count() -> int:
	var count := 0
	for threat in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(threat) and not threat.is_queued_for_deletion():
			count += 1
	return count


## Deferred so a dying threat's queue_free() is visible to the count.
func _refresh_threat_display() -> void:
	hud.update_time(day_count, is_night, _live_threat_count())


## Total severity of active pressure, consumed by the settlement model.
func current_threat_severity() -> float:
	var severity := 0.0
	if is_night and config().rule("darkness_increases_enemies"):
		severity += NIGHT_BASE_SEVERITY
	if storm_active:
		severity += STORM_SEVERITY
	for threat in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(threat) and not threat.is_queued_for_deletion():
			severity += threat.SEVERITY
	return severity


func _try_interact() -> void:
	if hud.town_panel_open():
		hud.toggle_town_panel()
		return
	if player.global_position.distance_to(town_hall.global_position) <= INTERACT_RANGE:
		hud.toggle_town_panel()
	else:
		log_event("Nothing to interact with here.")


func _on_deposit_requested() -> void:
	var moved: Dictionary = town_hall.deposit_all(player.inventory)
	if moved.is_empty():
		log_event("Nothing to deposit.")
	else:
		var parts: Array[String] = []
		for item_id in moved:
			parts.append("%s ×%d" % [BlockRegistry.display_name(item_id), moved[item_id]])
		log_event("Deposited %s." % ", ".join(parts))
		award_xp("resource_deposited")
	player.inventory_changed.emit()
	hud.refresh_town_panel()


func _on_repair_requested() -> void:
	if town_hall.repair():
		log_event("Town Hall repaired.")
		town_hall.queue_redraw()
	else:
		log_event("Cannot repair (no damage or not enough stone).")
	hud.refresh_town_panel()


func _on_forge_requested() -> void:
	if town_hall.forge_pick(player):
		log_event("Forged a sturdier pick (tier 2). Ore is now mineable, and mining is faster.")
		award_xp("tool_crafted")
	else:
		log_event("Cannot forge pick (already forged, or stockpile lacks 3 wood + 5 stone).")
	hud.refresh_town_panel()


func _on_forge_axe_requested() -> void:
	if town_hall.forge_axe(player):
		log_event("Crafted an axe (tier 1). Wood and plants harvest faster.")
		award_xp("tool_crafted")
	else:
		log_event("Cannot craft axe (already crafted, or stockpile lacks 4 wood + 2 stone).")
	hud.refresh_town_panel()


func _on_forge_sword_requested() -> void:
	if town_hall.forge_sword(player):
		log_event("Forged a crude sword. Your strikes hit much harder.")
		award_xp("tool_crafted")
	else:
		log_event("Cannot forge sword (already armed, or stockpile lacks 2 wood + 3 stone).")
	hud.refresh_town_panel()


func _on_forge_armor_requested() -> void:
	if town_hall.forge_armor(player):
		log_event("Forged a crude armor set. Incoming blows are softened.")
		award_xp("tool_crafted")
	else:
		log_event("Cannot forge armor (already armored, or stockpile lacks 6 wood + 4 stone).")
	hud.refresh_town_panel()


func _on_lantern_requested() -> void:
	if town_hall.craft_from_stockpile("craft_lantern", player):
		log_event("Crafted a lantern. It shines farther than a torch (slot 5).")
	else:
		log_event("Cannot craft lantern (stockpile lacks 2 ore + 1 wood).")
	hud.refresh_town_panel()


func _on_player_mined(block_id: String, drops: Dictionary) -> void:
	var parts: Array[String] = []
	for item_id in drops:
		parts.append("%s ×%d" % [BlockRegistry.display_name(item_id), drops[item_id]])
	log_event("Mined %s (+%s)." % [BlockRegistry.display_name(block_id), ", ".join(parts)])
	award_xp("block_mined")


func _on_player_placed(_block_id: String) -> void:
	award_xp("block_placed")


func _on_player_crafted(recipe_id: String) -> void:
	log_event("Crafted %s." % BlockRegistry.get_recipe(recipe_id).get("display_name", recipe_id))
	award_xp("tool_crafted")


func log_event(message: String) -> void:
	hud.log_event(message)


func load_game() -> bool:
	if not save_manager.load_game():
		return false
	# Wave B: restore character-owned carried state after world state is applied.
	_apply_character_carried_state()
	hud.update_time(day_count, is_night, _live_threat_count())
	hud.update_inventory()
	_refresh_hud_progression()
	settlement.compute()
	return true


## Serialize live threats to a save-friendly array.
## Fix 2: also saves max_hp so restores can preserve the damage bar correctly.
func serialize_threats() -> Array:
	var out: Array = []
	for threat in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(threat) and not threat.is_queued_for_deletion():
			out.append({
				"x": threat.global_position.x,
				"y": threat.global_position.y,
				"hp": threat.hp,
				"max_hp": threat.max_hp,
				"enemy_id": threat.enemy_id,
			})
	return out


## Restore threats from a saved array.
## Fix 1: calls _spawn_enemy_at so hall_dps and all other fields are wired correctly,
## then overrides hp/max_hp from the save entry (set after add_child/_ready).
## Fix 2: restores max_hp; falls back to maxi(3, hp) for old saves without the key.
func apply_threats(data: Array) -> void:
	for threat in get_tree().get_nodes_in_group("threats"):
		threat.queue_free()
	for entry in data:
		var eid: String = str(entry.get("enemy_id", "surface_slime"))
		var def: Dictionary = {}
		if _enemy_registry != null:
			def = _enemy_registry.get_def(eid)
		var pos := Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		var threat := _spawn_enemy_at(def, pos)
		# Override hp/max_hp from save (after add_child/_ready ran max_hp = maxi(max_hp, hp)).
		threat.hp = int(entry.get("hp", 3))
		threat.max_hp = int(entry.get("max_hp", maxi(3, threat.hp)))


func time_state() -> Dictionary:
	return {
		"time_of_day": time_of_day,
		"day_count": day_count,
		"storm_active": storm_active,
		"storm_time_left": storm_time_left,
		"storm_rolled_today": _storm_rolled_today,
	}


func apply_time_state(data: Dictionary) -> void:
	time_of_day = float(data.get("time_of_day", 0.25))
	day_count = int(data.get("day_count", 1))
	storm_active = bool(data.get("storm_active", false))
	storm_time_left = float(data.get("storm_time_left", 0.0))
	# Pre-v0.3 saves lack this key; default so loading mid-day does not
	# instantly roll a surprise storm.
	_storm_rolled_today = bool(data.get("storm_rolled_today", time_of_day >= STORM_ROLL_TIME))
	is_night = time_of_day >= NIGHT_START
	canvas_modulate.color = NIGHT_TINT if is_night else (STORM_TINT if storm_active else DAY_TINT)


## Used by the smoke test to exercise the threat loop deterministically.
func force_night() -> void:
	time_of_day = NIGHT_START + 0.01
	_on_nightfall()


# ---------------------------------------------------------------------------
# Progression: player XP, levels, base level
# ---------------------------------------------------------------------------

## Applies the wired Phase B player_effects for species_id to the player.
## Non-Phase-B or unknown species receive all-default values (mult 1.0, bonus 0).
## Always call this after player.apply_character() so ancestry_health_bonus
## stacks correctly on top of the trait/role max_health base.
func apply_ancestry_for_species(species_id: String) -> void:
	if _ancestry_registry == null:
		player.apply_ancestry_effects({})
		return
	if species_id in _ancestry_registry.phase_b_ids():
		var ancestry: Dictionary = _ancestry_registry.get_ancestry(species_id)
		player.apply_ancestry_effects(ancestry.get("player_effects", {}))
	else:
		player.apply_ancestry_effects({})


## Award XP for event_id (defined in player_xp.json).
## Fix 11: accrues float XP (raw_amount * learning_speed_mult) without rounding
## to avoid losing fractional gains on small base_amounts (e.g. human 1.05x).
## Use int() at every read point.
func award_xp(event_id: String) -> void:
	if _progression_registry == null:
		return
	var ev: Dictionary = _progression_registry.xp_event(event_id)
	if ev.is_empty():
		return
	var xp_type: String = str(ev.get("xp_type", ""))
	var raw_amount: int = int(ev.get("base_amount", 0))
	var base_gain: int = int(ev.get("also_awards", {}).get("base_xp", 0))
	if xp_type != "":
		xp_totals[xp_type] = float(xp_totals.get(xp_type, 0.0)) + float(raw_amount) * player.learning_speed_mult
	base_xp += base_gain
	_recalc_player_level()
	_refresh_hud_progression()


## Fix 15: shared helper — sum of all XP type totals (integer read point).
func _total_xp() -> int:
	var total := 0
	for t in xp_totals:
		total += int(xp_totals[t])
	return total


## Recomputes player_level from cumulative XP across all types.
## Fix 15: records _level_start_xp for O(1) _xp_toward_next.
func _recalc_player_level() -> void:
	var total := _total_xp()
	var lv := 1
	var cumulative := 0
	while true:
		var needed: int = _progression_registry.xp_to_next(lv)
		if cumulative + needed > total:
			break
		cumulative += needed
		lv += 1
		if lv > 999:
			break
	player_level = lv
	_level_start_xp = cumulative


## XP accumulated in the current level (toward xp_to_next). O(1) after recalc.
func _xp_toward_next() -> int:
	if _progression_registry == null:
		return 0
	return _total_xp() - _level_start_xp


## Fix 15: push updated progression to the HUD — replaces four identical call sites.
func _refresh_hud_progression() -> void:
	hud.update_progression(player_level, _xp_toward_next(),
		_progression_registry.xp_to_next(player_level), _base_level_display_name())


## Evaluate base level requirements from settlement state (ratchet, never decreases).
## Fix 3: only considers base_level + 1 per call (one tier per tick).
##         Returns immediately when already at MVP cap.
func _check_base_level() -> void:
	if _progression_registry == null:
		return
	# Fix 3: early-out at cap.
	if base_level >= BASE_LEVEL_MAX_MVP:
		return
	var next_lv: int = base_level + 1
	for bl: Dictionary in _progression_registry.base_levels_ordered():
		var lv: int = int(bl.get("level", 0))
		if lv != next_lv:
			continue
		if _meets_base_level_requires(bl.get("requires", {})):
			base_level = next_lv
			var name_str: String = _base_level_display_name()
			log_event("Settlement advanced to %s!" % name_str)
			_refresh_hud_progression()
		break


## Check whether physical world conditions in req are met.
## Fix 4: iterates the requires dict; any unrecognized key fails-closed and
##         emits push_warning once per key (avoids silent bypass of future keys).
func _meets_base_level_requires(req: Dictionary) -> bool:
	var si: Dictionary = settlement.inputs
	for key in req:
		match key:
			"shelter_score":
				if si.get("shelter_score", 0.0) < float(req[key]):
					return false
			"light_score":
				if si.get("light_score", 0.0) < float(req[key]):
					return false
			"food_reserve":
				if int(town_hall.stockpile.get("food", 0)) < int(req[key]):
					return false
			"stockpile_value":
				if town_hall.total_stock() < int(req[key]):
					return false
			"population":
				if town_hall.population < int(req[key]):
					return false
			_:
				if not _warned_requires_keys.has(key):
					_warned_requires_keys[key] = true
					push_warning("_meets_base_level_requires: unrecognized key '%s' — fail-closed" % key)
				return false
	return true


## Display name of the current base level.
func _base_level_display_name() -> String:
	if _progression_registry == null:
		return "Camp"
	for bl: Dictionary in _progression_registry.base_levels_ordered():
		if int(bl.get("level", 0)) == base_level:
			return str(bl.get("display_name", "Camp"))
	return "Camp"


## Population cap gated by base level; never exceeds POPULATION_MAX.
func effective_population_cap() -> int:
	if _progression_registry == null:
		return POPULATION_MAX
	for bl: Dictionary in _progression_registry.base_levels_ordered():
		if int(bl.get("level", 0)) == base_level:
			var cap: int = int(bl.get("unlocks", {}).get("population_cap", POPULATION_MAX))
			return mini(POPULATION_MAX, cap)
	return POPULATION_MAX


## Award new_depth_reached XP when the player enters a new 10-tile depth band.
func _check_depth_xp() -> void:
	if world == null:
		return
	var pcell: Vector2i = world.cell_of(player.global_position)
	var surf_y: int = world.surface.get(pcell.x, 0)
	if pcell.y <= surf_y:
		return
	var band: int = (pcell.y - surf_y) / 10
	if band > _depth_hwm:
		_depth_hwm = band
		award_xp("new_depth_reached")


# ---------------------------------------------------------------------------
# FQ-06: perk points, states, and purchases
# ---------------------------------------------------------------------------

func perk_points_total() -> int:
	return maxi(0, player_level - 1)


func perk_points_spent() -> int:
	if _progression_registry == null:
		return 0
	var spent := 0
	for pid in purchased_perks:
		spent += int(_progression_registry.get_perk(str(pid)).get("cost", 1))
	return spent


func perk_points_available() -> int:
	# Floored so a hand-edited save with overspent perks displays 0, not a
	# negative count (purchases stay blocked either way).
	return maxi(0, perk_points_total() - perk_points_spent())


## "purchased" | "available" (all prerequisites purchased) | "locked".
## Affordability is a separate purchase-time gate, not a display state.
func perk_state(perk_id: String) -> String:
	if perk_id in purchased_perks:
		return "purchased"
	var perk: Dictionary = _progression_registry.get_perk(perk_id) \
		if _progression_registry != null else {}
	if perk.is_empty():
		return "locked"
	for prereq in perk.get("prerequisites", []):
		if not (str(prereq) in purchased_perks):
			return "locked"
	return "available"


## Buys a perk with real level-derived points. Returns false when unknown,
## already purchased, prerequisite-locked, or unaffordable.
func try_purchase_perk(perk_id: String) -> bool:
	if _progression_registry == null:
		return false
	var perk: Dictionary = _progression_registry.get_perk(perk_id)
	if perk.is_empty():
		return false
	if perk_state(perk_id) != "available":
		return false
	if int(perk.get("cost", 1)) > perk_points_available():
		return false
	purchased_perks.append(perk_id)
	_apply_purchased_perk_effects()
	log_event("Perk learned: %s." % str(perk.get("display_name", perk_id)))
	return true


## Recomputes the combined live perk effects and pushes them to the player.
## mining_speed multiplies; attunement_bonus adds (the FQ-05 join point).
## Planning-stage effect keys stay inert until their systems ship.
func _apply_purchased_perk_effects() -> void:
	var combined := {"mining_speed": 1.0, "attunement_bonus": 0.0}
	if _progression_registry != null:
		for pid in purchased_perks:
			var perk: Dictionary = _progression_registry.get_perk(str(pid))
			var value := float(perk.get("effect_value", 0.0))
			match str(perk.get("effect_key", "")):
				"mining_speed":
					combined["mining_speed"] = float(combined["mining_speed"]) * value
				"attunement_bonus":
					combined["attunement_bonus"] = float(combined["attunement_bonus"]) + value
				_:
					pass
	player.apply_perk_effects(combined)


## Skill tree panel accessors (the panel holds a game_root reference).
func perk_lanes() -> Array:
	return _progression_registry.perk_lanes() if _progression_registry != null else []


func get_perk(perk_id: String) -> Dictionary:
	return _progression_registry.get_perk(perk_id) if _progression_registry != null else {}


func _on_perk_purchase_requested(perk_id: String) -> void:
	if not try_purchase_perk(perk_id):
		log_event("Cannot learn that perk (locked, owned, or not enough points).")
	hud.refresh_skill_panel()


# ---------------------------------------------------------------------------
# Progression save / load
# ---------------------------------------------------------------------------

func progression_state() -> Dictionary:
	return {
		"xp_totals": xp_totals.duplicate(),
		"player_level": player_level,
		"base_xp": base_xp,
		"base_level": base_level,
		"depth_hwm": _depth_hwm,
		"purchased_perks": purchased_perks.duplicate(),
	}


## Restore progression from a saved state dict.
## Fix 11: loads xp_totals as float to preserve fractional accumulation.
## Missing keys default cleanly (level 1 Camp, zero XP).
func apply_progression_state(data: Dictionary) -> void:
	# Re-seed to 0.0 (float) for all known types first.
	xp_totals = {}
	if _progression_registry != null:
		for t: Dictionary in _progression_registry.xp_types():
			xp_totals[str(t.get("id", ""))] = 0.0
	var raw: Dictionary = data.get("xp_totals", {})
	for k in raw:
		xp_totals[str(k)] = float(raw[k])
	player_level = int(data.get("player_level", 1))
	base_xp = int(data.get("base_xp", 0))
	base_level = int(data.get("base_level", 1))
	_depth_hwm = int(data.get("depth_hwm", 0))
	# FQ-06: restore purchased perks, dropping ids that no longer exist in
	# data (a renamed/removed perk quietly refunds its points). A null
	# registry (impossible in the normal boot order) leaves the previous
	# list untouched rather than silently wiping purchases.
	if _progression_registry != null:
		purchased_perks = []
		for pid in data.get("purchased_perks", []):
			if not _progression_registry.get_perk(str(pid)).is_empty():
				purchased_perks.append(str(pid))
		_apply_purchased_perk_effects()
