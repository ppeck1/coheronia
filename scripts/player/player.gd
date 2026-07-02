extends CharacterBody2D
## Player: movement, jump, hold-to-mine with hardness timing, block/torch
## placement from the hotbar, torch crafting, health.

signal inventory_changed
signal health_changed(health: float)
signal mined(block_id: String, drops: Dictionary)
signal crafted(recipe_id: String)
signal player_event(message: String)

const SPEED := 140.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 820.0
const REACH_TILES := 5.0

var world: Node2D
var health := 100.0
var max_health := 100.0
var tool_tier := 1
var base_mine_speed := 1.0
var inventory := InventoryData.new()
var hotbar: Array[String] = ["dirt", "wood", "stone", "torch"]
var selected_slot := 0

var mine_target := Vector2i(-99999, -99999)
var mine_progress := 0.0
var mine_required := 0.0

var _hurt_cooldown := 0.0


func selected_item() -> String:
	return hotbar[selected_slot]


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED
	move_and_slide()
	_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)

	if world == null:
		return
	_handle_hotbar()
	_handle_mining(delta)
	if Input.is_action_just_pressed("place"):
		try_place(world.cell_of(get_global_mouse_position()), selected_item())
	if Input.is_action_just_pressed("craft"):
		craft("craft_torch")
	queue_redraw()


func _handle_hotbar() -> void:
	for i in range(hotbar.size()):
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			selected_slot = i
			inventory_changed.emit()


func _handle_mining(delta: float) -> void:
	if not Input.is_action_pressed("mine"):
		_reset_mining()
		return
	var cell: Vector2i = world.cell_of(get_global_mouse_position())
	if Input.is_action_just_pressed("mine") and _try_hit_threat(get_global_mouse_position()):
		return
	process_mining(cell, delta)


## Shared mining path used by live input and the smoke test.
## Returns true when a block finished breaking this call.
func process_mining(cell: Vector2i, delta: float) -> bool:
	if not _in_reach(cell) or not world.can_mine(cell, tool_tier):
		_reset_mining()
		return false
	if cell != mine_target:
		mine_target = cell
		mine_progress = 0.0
		mine_required = world.mine_time(cell, base_mine_speed)
	mine_progress += delta
	if mine_progress < mine_required:
		return false
	var block_id: String = world.block_at(cell)
	var drops: Dictionary = world.break_block(cell)
	inventory.add_many(drops)
	_reset_mining()
	inventory_changed.emit()
	mined.emit(block_id, drops)
	return true


func try_place(cell: Vector2i, block_id: String) -> bool:
	if not _in_reach(cell):
		return false
	if inventory.count(block_id) <= 0:
		return false
	if _cell_overlaps_body(cell) and BlockRegistry.is_solid(block_id):
		return false
	if not world.place_block(cell, block_id):
		return false
	inventory.remove(block_id)
	inventory_changed.emit()
	return true


func craft(recipe_id: String) -> bool:
	var recipe: Dictionary = BlockRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	if not inventory.remove_all(recipe.get("inputs", {})):
		player_event.emit("Cannot craft %s: missing materials." % recipe.get("display_name", recipe_id))
		return false
	inventory.add_many(recipe.get("outputs", {}))
	inventory_changed.emit()
	crafted.emit(recipe_id)
	return true


func take_damage(amount: float) -> void:
	if _hurt_cooldown > 0.0:
		return
	_hurt_cooldown = 0.8
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	if health <= 0.0:
		respawn()


func respawn() -> void:
	health = max_health
	health_changed.emit(health)
	if world != null and not world.hall_info.is_empty():
		global_position = world.cell_center(world.hall_info["center_cell"]) + Vector2(-48, -24)
		velocity = Vector2.ZERO
	player_event.emit("You collapsed and awoke near the Town Hall.")


func mine_progress_ratio() -> float:
	if mine_required <= 0.0:
		return 0.0
	return clampf(mine_progress / mine_required, 0.0, 1.0)


func _reset_mining() -> void:
	mine_target = Vector2i(-99999, -99999)
	mine_progress = 0.0
	mine_required = 0.0


func _in_reach(cell: Vector2i) -> bool:
	var t: float = float(world.tile_size())
	return global_position.distance_to(world.cell_center(cell)) <= REACH_TILES * t


func _cell_overlaps_body(cell: Vector2i) -> bool:
	var t: float = float(world.tile_size())
	var cell_rect := Rect2(Vector2(cell) * t, Vector2(t, t))
	var body_rect := Rect2(global_position + Vector2(-6, -14), Vector2(12, 28))
	return cell_rect.intersects(body_rect)


func _try_hit_threat(at: Vector2) -> bool:
	if not _in_reach(world.cell_of(at)):
		return false
	for threat in get_tree().get_nodes_in_group("threats"):
		if threat.global_position.distance_to(at) < 14.0:
			threat.take_hit(1)
			return true
	return false


func _draw() -> void:
	# Placeholder body.
	draw_rect(Rect2(-6, -14, 12, 28), Color(0.92, 0.83, 0.55))
	draw_rect(Rect2(-4, -12, 8, 6), Color(0.35, 0.25, 0.18))
	# Mining target highlight.
	if world != null and Input.is_action_pressed("mine") and mine_required > 0.0:
		var t: float = float(world.tile_size())
		var local := to_local(Vector2(mine_target) * t)
		draw_rect(Rect2(local, Vector2(t, t)), Color(1, 1, 1, 0.6), false, 1.5)
