extends CharacterBody2D
## Enemy entity configured from a def (enemy_id, family, drops, loot_mult).
## All three live enemy types (surface_slime, cave_crawler, raider_basic)
## reuse this scene; family drives the visual tint.
## Shambles toward the Town Hall and gnaws at it on contact; player can
## hit it with the mine action.

signal died

const SPEED := 38.0
const GRAVITY := 820.0
const JUMP_VELOCITY := -240.0
# FQ-09M: self-freeing action effects (presentation only, never saved).
const SimpleThreatFx := preload("res://scripts/fx/action_fx.gd")
const PLAYER_DAMAGE := 8.0
const SEVERITY := 10.0

## Per-family body color for quick visual identification.
const FAMILY_COLORS := {
	"surface": Color(0.55, 0.25, 0.65, 0.9),
	"underground": Color(0.25, 0.55, 0.25, 0.9),
	"raider": Color(0.72, 0.32, 0.18, 0.9),
}

var world: Node2D
var town_hall: Node2D
var player: CharacterBody2D
var hp := 3
var max_hp := 3
var hall_dps := 4.0  # set by the spawner from enemy difficulty

## Def-driven fields, set by the spawner.
var enemy_id: String = "surface_slime"
var family: String = "surface"
var drops: Array = []      # Array of {item_id, chance}
var loot_mult: float = 1.0
## Test hook: if >= 0.0 this value overrides every drop's rolled chance.
var drop_chance_override: float = -1.0

## FQ-01: data-driven contact damage/speed, set by the spawner from the enemy
## def's "contact_damage"/"speed" fields (fallback to the PLAYER_DAMAGE/SPEED
## consts above when the def omits them). contact_damage is pre-scaled by
## config().difficulty("enemy") at spawn time, mirroring hall_dps.
var contact_damage := PLAYER_DAMAGE
var move_speed := SPEED

## FQ-07: optional sprite from art/generated/enemies/<enemy_id>.png; null
## keeps the drawn-rect fallback below.
var _art: Texture2D = null


func _ready() -> void:
	add_to_group("threats")
	max_hp = maxi(max_hp, hp)
	_art = BlockRegistry.visual_texture("enemies", enemy_id)


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
			velocity.x = signf(dx) * move_speed
	if is_on_wall() and is_on_floor() and not at_hall:
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	if player != null and global_position.distance_to(player.global_position) < 18.0:
		player.take_damage(contact_damage)
	queue_redraw()


func take_hit(amount: int) -> void:
	hp -= amount
	# FQ-09M: a spark on every landed hit; dust when the threat goes down.
	# Presentation only — drops, hp, and death flow are untouched.
	if is_inside_tree():
		SimpleThreatFx.spawn(get_parent(), "hit_spark", global_position)
	if hp <= 0:
		if is_inside_tree():
			SimpleThreatFx.spawn(get_parent(), "dust_puff", global_position)
		_roll_drops()
		died.emit()
		queue_free()
	else:
		queue_redraw()


## Roll each drop entry and add won items to the player inventory.
func _roll_drops() -> void:
	if player == null or drops.is_empty():
		return
	var added := false
	for drop in drops:
		var chance: float = float(drop.get("chance", 0.0))
		if drop_chance_override >= 0.0:
			chance = drop_chance_override
		if randf() < chance * loot_mult:
			player.inventory.add(str(drop.get("item_id", "")), 1)
			added = true
	if added:
		player.inventory_changed.emit()


## FQ-08: health-bar fill fraction (1.0 = unhurt) for the hurt bar.
func health_bar_ratio() -> float:
	return clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)


func _draw() -> void:
	# FQ-07: image-first with the drawn-rect fallback. Damage reddens the
	# sprite via a subtractive tint (overbright modulate clamps to white in
	# the compatibility renderer, so lightening would be invisible on art).
	var hurt := minf(0.45, 0.15 * float(max_hp - hp)) if hp < max_hp else 0.0
	if _art != null:
		var tint := Color(1.0, 1.0 - hurt, 1.0 - hurt)
		draw_texture(_art, -_art.get_size() / 2.0, tint)
	else:
		var body: Color = FAMILY_COLORS.get(family, FAMILY_COLORS["surface"])
		if hurt > 0.0:
			body = body.lightened(hurt)
		draw_rect(Rect2(-7, -6, 14, 12), body)
		draw_rect(Rect2(-4, -3, 3, 3), Color.WHITE)
		draw_rect(Rect2(1, -3, 3, 3), Color.WHITE)
	# FQ-08: mini health bar above the body once damaged — damage is visible
	# well before death on both the art and fallback paths.
	if hp < max_hp:
		draw_rect(Rect2(-8, -12, 16, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-8, -12, 16.0 * health_bar_ratio(), 3), Color(0.85, 0.2, 0.2))
