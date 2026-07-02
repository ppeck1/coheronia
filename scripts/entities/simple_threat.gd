extends CharacterBody2D
## Simple night threat: a slime that shambles toward the Town Hall and
## gnaws at it on contact. Blocked by solid walls; the player can whack it
## with the mine action. Despawns at dawn.

signal died

const SPEED := 38.0
const GRAVITY := 820.0
const JUMP_VELOCITY := -240.0
const PLAYER_DAMAGE := 8.0
const SEVERITY := 10.0

var world: Node2D
var town_hall: Node2D
var player: CharacterBody2D
var hp := 3
var max_hp := 3
var hall_dps := 4.0  # set by the spawner from enemy difficulty


func _ready() -> void:
	add_to_group("threats")
	max_hp = maxi(max_hp, hp)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var at_hall := false
	if town_hall != null:
		var dx := town_hall.global_position.x - global_position.x
		var near := absf(dx) < 26.0 and absf(town_hall.global_position.y - global_position.y) < 40.0
		if near:
			at_hall = true
			velocity.x = 0.0
			town_hall.take_damage(hall_dps * delta)
		else:
			velocity.x = signf(dx) * SPEED
	if is_on_wall() and is_on_floor() and not at_hall:
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	if player != null and global_position.distance_to(player.global_position) < 18.0:
		player.take_damage(PLAYER_DAMAGE)
	queue_redraw()


func take_hit(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		died.emit()
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var body := Color(0.55, 0.25, 0.65, 0.9)
	if hp < max_hp:
		body = body.lightened(minf(0.45, 0.15 * float(max_hp - hp)))
	draw_rect(Rect2(-7, -6, 14, 12), body)
	draw_rect(Rect2(-4, -3, 3, 3), Color.WHITE)
	draw_rect(Rect2(1, -3, 3, 3), Color.WHITE)
