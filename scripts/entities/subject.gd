extends CharacterBody2D
## R-08 slice 1: a visible farmhand settler. It walks the surface within a bounded
## radius of the Town Hall, harvests ripe crops (depositing the yield into the
## hall stockpile), and idles "hungry" when the settlement has run out of food.
## Its identity/position/job/hunger persist in the world save. Procedural draw
## only -- no art assets (R-10 owns art). It is a concrete actor layered ON TOP
## of the existing abstract town_hall.population / food model, which is unchanged.
##
## POPULATION / ECONOMY CONTRACT (R-08 canonical accounting model):
## the abstract population food model -- game_root.consume_daily_food() ->
## town_hall.consume_food(daily_food_need()) once per dawn -- is the SINGLE
## authority that CHARGES food from the stockpile. A visible subject is one of
## those town_hall.population members made concrete; it NEVER deducts food
## itself. This is what prevents charging the same settler twice (once through
## the abstract population upkeep and again through an individual subject
## upkeep). A subject's `hungry`/idle state is therefore a READ of settlement
## food availability (an empty food stockpile), not a charge -- harvesting ADDS
## food (production), and nothing in this actor SUBTRACTS food (consumption).

const GRAVITY := 900.0
const MOVE_SPEED := 42.0
const JUMP_VELOCITY := -260.0
const WORK_RADIUS_CELLS := 22     # bounded roam around home
const HARVEST_DIST := 14.0
const REPAIR_DIST := 20.0         # the hall is wider than a crop cell
const HOME_IDLE_DIST := 10.0
const BODY_COL := Color(0.52, 0.78, 0.5)
const REPAIRER_COL := Color(0.5, 0.62, 0.82)
const HUNGRY_COL := Color(0.82, 0.62, 0.38)
const TRIM_COL := Color(0.30, 0.24, 0.18)

var world = null
var town_hall = null
var subject_id := "farmhand_1"
var job := "farmhand"
var hungry := false
var _home := Vector2.ZERO
var _target := Vector2i(-1, -1)


func _ready() -> void:
	add_to_group("subjects")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 24)
	shape.shape = rect
	add_child(shape)


func setup(w: Node, hall: Node, id: String = "farmhand_1") -> void:
	world = w
	town_hall = hall
	subject_id = id
	_home = hall.global_position


func _physics_process(delta: float) -> void:
	if world == null or town_hall == null:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	refresh_hunger()
	var acted := false
	if not hungry:
		acted = run_job(delta)
	if not acted:
		# nothing to do (or hungry): drift back toward home and idle there.
		var dx := _home.x - global_position.x
		velocity.x = signf(dx) * MOVE_SPEED if absf(dx) > HOME_IDLE_DIST else 0.0
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	queue_redraw()


## R-08: run one tick of this settler's assigned job. Returns true while the
## settler is actively working (so the caller does not also drift home). Public
## so the smoke can drive a deterministic tick without waiting on physics.
func run_job(delta: float) -> bool:
	if world == null or town_hall == null:
		return false
	match job:
		"farmhand":
			return _run_farmhand(delta)
		"repairer":
			return _run_repairer(delta)
	return false


## Farmhand: target the nearest ripe crop within the work radius of home; steer
## to it and, once in range, harvest it into the hall stockpile.
func _run_farmhand(_delta: float) -> bool:
	var home_cell: Vector2i = world.cell_of(_home)
	if _target.x < 0 or world.block_at(_target) != "crop_ripe":
		_target = world.nearest_ripe_crop(home_cell, WORK_RADIUS_CELLS)
	if _target.x < 0:
		return false
	var tpos: Vector2 = world.cell_center(_target)
	if global_position.distance_to(tpos) <= HARVEST_DIST:
		_harvest(_target)
		_target = Vector2i(-1, -1)
		velocity.x = 0.0
		return true
	velocity.x = signf(tpos.x - global_position.x) * MOVE_SPEED
	return true


## Repairer: when the hall can be repaired (damaged AND the stockpile holds the
## cost), walk to it and repair -- spending stockpile stone through the same
## town_hall.repair() authority as the player's Repair button. Idle otherwise.
func _run_repairer(_delta: float) -> bool:
	if not town_hall.can_repair():
		return false
	var hpos: Vector2 = town_hall.global_position
	if global_position.distance_to(hpos) <= REPAIR_DIST:
		town_hall.repair()
		town_hall.queue_redraw()
		velocity.x = 0.0
		return true
	velocity.x = signf(hpos.x - global_position.x) * MOVE_SPEED
	return true


## Harvest a ripe crop cell and deposit its yield (food + seed) into the stockpile.
## This is PRODUCTION -- it only ADDS to the stockpile. Food consumption is owned
## solely by the abstract population model (see the contract note at the top).
func _harvest(cell: Vector2i) -> void:
	var drops: Dictionary = world.harvest_crop(cell)
	for item_id in drops:
		town_hall.stockpile[item_id] = int(town_hall.stockpile.get(item_id, 0)) + int(drops[item_id])
	if not drops.is_empty():
		town_hall.stockpile_changed.emit()


## R-08: recompute this subject's hunger from settlement food availability. This
## is a READ, never a charge: the subject is a member of town_hall.population and
## its food is already accounted for by the once-per-dawn population upkeep, so
## deducting here would double-charge the same settler. `hungry` (and idle) is
## simply "the settlement stockpile has no food to draw on". Public + pure so the
## smoke can assert the no-double-charge contract deterministically.
func refresh_hunger() -> void:
	if town_hall == null:
		return
	hungry = int(town_hall.stockpile.get("food", 0)) <= 0


func _draw() -> void:
	var base_col: Color = REPAIRER_COL if job == "repairer" else BODY_COL
	var col: Color = HUNGRY_COL if hungry else base_col
	draw_rect(Rect2(-5, -22, 10, 22), col)          # torso/legs
	draw_circle(Vector2(0, -26), 5, col)            # head
	draw_rect(Rect2(-5, -22, 10, 4), TRIM_COL)      # belt/hem
	if job == "repairer":
		draw_line(Vector2(6, -16), Vector2(11, -25), TRIM_COL, 2.0)   # hammer handle
		draw_rect(Rect2(9, -28, 5, 4), TRIM_COL)                      # hammer head
	else:
		draw_line(Vector2(5, -18), Vector2(11, -26), TRIM_COL, 2.0)   # a hoe


func to_dict() -> Dictionary:
	return {
		"id": subject_id, "job": job, "hungry": hungry,
		"x": global_position.x, "y": global_position.y,
	}


func from_dict(d: Dictionary) -> void:
	subject_id = str(d.get("id", subject_id))
	job = str(d.get("job", "farmhand"))
	hungry = bool(d.get("hungry", false))
	global_position = Vector2(
		float(d.get("x", global_position.x)), float(d.get("y", global_position.y)))
