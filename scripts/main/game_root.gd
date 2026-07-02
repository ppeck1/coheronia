extends Node2D
## Game root: wires world/player/hall/HUD together, runs the day/night
## cycle and the night pressure event, and handles save/load/interact input.

const SimpleThreatScene := preload("res://scenes/entities/SimpleThreat.tscn")

const DAY_LENGTH_SECONDS := 100.0
const NIGHT_START := 0.65          # time_of_day fraction where night begins
const NIGHT_BASE_SEVERITY := 10.0
const INTERACT_RANGE := 72.0

const DAY_TINT := Color(1, 1, 1)
const NIGHT_TINT := Color(0.22, 0.24, 0.38)
const STORM_TINT := Color(0.55, 0.58, 0.66)

const POPULATION_MAX := 8
const GROWTH_COHERENCE := 55.0

const STORM_CHANCE_PER_DAY := 0.5
const STORM_ROLL_TIME := 0.35      # midday roll point
const STORM_DURATION := 18.0
const STORM_SEVERITY := 8.0
const STORM_MAX_DPS := 3.0

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


func _ready() -> void:
	world.setup(randi() % 1000000)
	_wire_references()
	_wire_signals()
	_position_actors()
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
		if randf() < STORM_CHANCE_PER_DAY:
			start_storm()
	if not storm_active:
		return
	storm_time_left -= delta
	# Exposure: a roofed hall shrugs storms off; ground fill does not help.
	var exposure: float = clampf(1.0 - settlement.roof_coverage(), 0.0, 1.0)
	if exposure > 0.05:
		town_hall.take_damage(STORM_MAX_DPS * exposure * delta)
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


## Deterministic entry point for the smoke test.
func force_storm() -> void:
	_storm_rolled_today = true
	start_storm()


func _on_nightfall() -> void:
	is_night = true
	var light_score: float = settlement.gather_inputs().get("light_score", 0.0)
	var spawn_count := 1 if light_score >= 16.0 else 2
	log_event("Night falls. Pressure rises (%d threat%s approaching)." % [
		spawn_count, "" if spawn_count == 1 else "s"])
	for i in range(spawn_count):
		_spawn_threat(i)
	hud.update_time(day_count, true, spawn_count)
	settlement.compute()


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
	return maxi(1, ceili(town_hall.population / 2.0))


## Population eats at dawn. Shortage feeds scarcity_penalty via the
## settlement model and drives settlers away; abundance plus a coherent
## settlement attracts newcomers.
func consume_daily_food() -> void:
	var coherence_at_dawn: float = settlement.coherence
	var result: Dictionary = town_hall.consume_food(daily_food_need())
	if result["eaten"] >= result["needed"]:
		log_event("Settlers ate %d food from the stockpile." % result["eaten"])
	else:
		log_event("Food shortage! Settlers needed %d food, found %d. Gather berries." % [
			result["needed"], result["eaten"]])
	_update_population(result, coherence_at_dawn)


func _update_population(meal: Dictionary, coherence_at_dawn: float) -> void:
	if meal["eaten"] < meal["needed"]:
		if town_hall.population > 1:
			town_hall.population -= 1
			log_event("A settler left after going hungry. Population is now %d." % town_hall.population)
	elif coherence_at_dawn >= GROWTH_COHERENCE \
			and int(town_hall.stockpile.get("food", 0)) >= town_hall.population \
			and town_hall.population < POPULATION_MAX:
		town_hall.population += 1
		log_event("Drawn by a thriving settlement, a settler arrived. Population is now %d." % town_hall.population)
	town_hall.stockpile_changed.emit()


func _spawn_threat(index: int) -> void:
	var threat := SimpleThreatScene.instantiate()
	threat.world = world
	threat.town_hall = town_hall
	threat.player = player
	var side := -1 if index % 2 == 0 else 1
	var hall_cell: Vector2i = world.hall_info["center_cell"]
	var spawn_x: int = hall_cell.x + side * 22
	var surf_y: int = world.surface.get(spawn_x, hall_cell.y)
	threat.position = world.cell_center(Vector2i(spawn_x, surf_y - 2))
	threat.died.connect(_on_threat_died)
	threats.add_child(threat)


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
	if is_night:
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
			})
	return out


func apply_threats(data: Array) -> void:
	for threat in get_tree().get_nodes_in_group("threats"):
		threat.queue_free()
	for entry in data:
		var threat := SimpleThreatScene.instantiate()
		threat.world = world
		threat.town_hall = town_hall
		threat.player = player
		threat.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		threat.hp = int(entry.get("hp", 3))
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
