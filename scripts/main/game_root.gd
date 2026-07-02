extends Node2D
## Game root: wires world/player/hall/HUD together, runs the day/night
## cycle and the night pressure event, and handles save/load/interact input.

const SimpleThreatScene := preload("res://scenes/entities/SimpleThreat.tscn")
const EnemyRegistryClass := preload("res://scripts/data/enemy_registry.gd")

const DAY_LENGTH_SECONDS := 100.0
const NIGHT_START := 0.65          # time_of_day fraction where night begins
const NIGHT_BASE_SEVERITY := 10.0
const INTERACT_RANGE := 72.0

const DAY_TINT := Color(1, 1, 1)
const NIGHT_TINT := Color(0.22, 0.24, 0.38)
const STORM_TINT := Color(0.55, 0.58, 0.66)

const POPULATION_MAX := 8

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

var _enemy_registry = null  # EnemyRegistryClass instance
var _cave_spawn_timer := 0.0


func _ready() -> void:
	GameState.ensure_play_context()
	_enemy_registry = EnemyRegistryClass.new()
	_wire_references()
	_wire_signals()
	player.apply_character(GameState.current_character)
	var saved_state: Dictionary = GameState.get_current_state()
	if saved_state.is_empty():
		world.setup(config().seed_value())
		_grant_role_items()
	else:
		save_manager.apply_state(saved_state)
	_position_actors()
	if not saved_state.is_empty():
		# Saved player position overrides the default spawn.
		save_manager.apply_player_position(saved_state)
	hud.update_inventory()
	hud.update_health(player.health)
	hud.update_time(day_count, is_night)
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
	var role: Dictionary = BlockRegistry.role_def(str(GameState.current_character.get("role", "")))
	var items: Dictionary = role.get("starting_items", {})
	if not items.is_empty():
		player.inventory.add_many(items)
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


func _wire_signals() -> void:
	player.inventory_changed.connect(hud.update_inventory)
	player.health_changed.connect(hud.update_health)
	player.mined.connect(_on_player_mined)
	player.crafted.connect(_on_player_crafted)
	player.player_event.connect(log_event)
	town_hall.stockpile_changed.connect(func() -> void:
		hud.update_inventory()
		settlement.compute())
	settlement.updated.connect(hud.update_settlement)
	hud.deposit_requested.connect(_on_deposit_requested)
	hud.repair_requested.connect(_on_repair_requested)
	hud.forge_requested.connect(_on_forge_requested)
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


func _process(delta: float) -> void:
	_advance_time(delta)
	_advance_cave_spawns(delta)


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
	elif event.is_action_pressed("interact") or event.is_action_pressed("toggle_town"):
		_try_interact()
	elif event.is_action_pressed("ui_cancel"):
		if hud.town_panel_open():
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
	var spawn_count := night_spawn_count()
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
	var survived := get_tree().get_nodes_in_group("threats").size()
	for threat in get_tree().get_nodes_in_group("threats"):
		threat.queue_free()
	log_event("Dawn breaks. The pressure recedes." if survived > 0 else "Dawn breaks.")
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
			and town_hall.population < POPULATION_MAX:
		town_hall.population += 1
		log_event("Drawn by a thriving settlement, a settler arrived. Population is now %d." % town_hall.population)
	town_hall.stockpile_changed.emit()


## Spawn a surface_slime at night (replaces hardcoded night threat).
func _spawn_surface_slime(index: int) -> void:
	var def: Dictionary = {}
	if _enemy_registry != null:
		def = _enemy_registry.get_def("surface_slime")
	var side := -1 if index % 2 == 0 else 1
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	var spawn_x: int = hall_cell.x + side * 22
	var surf_y: int = world.surface.get(spawn_x, hall_cell.y)
	_spawn_enemy_at(def, world.cell_center(Vector2i(spawn_x, surf_y - 2)))


## Spawn a raider_basic at nightfall after day 5 or when stockpile is large.
func _maybe_spawn_raider() -> void:
	if _enemy_registry == null:
		return
	if not config().rule("darkness_increases_enemies"):
		return
	var stockpile_big: bool = town_hall.total_stock() >= 10
	if day_count < 5 and not stockpile_big:
		return
	if randf() > 0.30 * config().difficulty("enemy"):
		return
	var def: Dictionary = _enemy_registry.get_def("raider_basic")
	if def.is_empty():
		return
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	var side := 1 if randi() % 2 == 0 else -1
	var spawn_x: int = hall_cell.x + side * 35
	var surf_y: int = world.surface.get(spawn_x, hall_cell.y)
	_spawn_enemy_at(def, world.cell_center(Vector2i(spawn_x, surf_y - 2)))
	log_event("A raider approaches the settlement!")


## Advance the cave crawler periodic spawn timer; spawn underground when ready.
func _advance_cave_spawns(delta: float) -> void:
	if _enemy_registry == null:
		return
	_cave_spawn_timer += delta
	if _cave_spawn_timer < CAVE_SPAWN_INTERVAL:
		return
	_cave_spawn_timer = 0.0
	# Count live cave crawlers.
	var crawler_count := 0
	for t in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			if t.enemy_id == "cave_crawler":
				crawler_count += 1
	if crawler_count >= CAVE_CRAWLER_CAP:
		return
	# Only spawn if the player is underground (below the surface y).
	var pcell: Vector2i = world.cell_of(player.global_position)
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
	else:
		log_event("Cannot forge pick (already forged, or stockpile lacks 3 wood + 5 stone).")
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


func _on_player_crafted(recipe_id: String) -> void:
	log_event("Crafted %s." % BlockRegistry.get_recipe(recipe_id).get("display_name", recipe_id))


func log_event(message: String) -> void:
	hud.log_event(message)


func load_game() -> bool:
	if not save_manager.load_game():
		return false
	hud.update_time(day_count, is_night, _live_threat_count())
	hud.update_inventory()
	settlement.compute()
	return true


func serialize_threats() -> Array:
	var out: Array = []
	for threat in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(threat) and not threat.is_queued_for_deletion():
			out.append({
				"x": threat.global_position.x,
				"y": threat.global_position.y,
				"hp": threat.hp,
				"enemy_id": threat.enemy_id,
			})
	return out


func apply_threats(data: Array) -> void:
	for threat in get_tree().get_nodes_in_group("threats"):
		threat.queue_free()
	for entry in data:
		var eid: String = str(entry.get("enemy_id", "surface_slime"))
		var def: Dictionary = {}
		if _enemy_registry != null:
			def = _enemy_registry.get_def(eid)
		var scaling := {"density_mult": 1.0, "loot_mult": 1.0}
		if _enemy_registry != null:
			scaling = _enemy_registry.scaling_for_difficulty(config().difficulty("enemy"))
		var threat := SimpleThreatScene.instantiate()
		threat.world = world
		threat.town_hall = town_hall
		threat.player = player
		threat.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		threat.hp = int(entry.get("hp", 3))
		threat.enemy_id = eid
		threat.family = str(def.get("family", "surface"))
		threat.drops = def.get("drops", [])
		threat.loot_mult = float(scaling.get("loot_mult", 1.0))
		threat.died.connect(_on_threat_died)
		threats.add_child(threat)


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
