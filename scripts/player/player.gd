extends CharacterBody2D
## Player: movement, jump, hold-to-mine with hardness timing, block/torch
## placement from the hotbar, torch crafting, health.

signal inventory_changed
signal health_changed(health: float)
signal mined(block_id: String, drops: Dictionary)
signal crafted(recipe_id: String)
signal placed(block_id: String)
signal player_event(message: String)

const SPEED := 140.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 820.0
const REACH_TILES := 5.0

var world: Node2D
var health := 100.0
var max_health := 100.0
var tool_tier := 1    # pick tier; kept as primary alias for the pick.
var axe_tier := 0     # 0 = no axe; 1+ = axe tier. Wave F.
var base_mine_speed := 1.0
var inventory := InventoryData.new()

# Character-driven modifiers (see data/character_data.json).
var body_color := Color(0.92, 0.83, 0.55)
var trim_color := Color(0.35, 0.25, 0.18)
var trait_mine_mult := 1.0
var reach_bonus := 0.0
var bush_bonus_food := 0
var growth_threshold_delta := 0.0
var hotbar: Array[String] = ["dirt", "wood", "stone", "torch", "lantern"]
var selected_slot := 0

# Ancestry effects (Phase B; reset in apply_character, set by apply_ancestry_effects).
var ancestry_move_mult := 1.0
var ancestry_jump_mult := 1.0
var stone_ore_mine_mult := 1.0
var ancestry_health_bonus := 0.0
var learning_speed_mult := 1.0

var mine_target := Vector2i(-99999, -99999)
var mine_progress := 0.0
var mine_required := 0.0

var _hurt_cooldown := 0.0


func selected_item() -> String:
	return hotbar[selected_slot]


## Applies a shell character (appearance, traits, role effects) to this
## player. Resets ancestry effects to defaults; call apply_ancestry_effects
## afterwards when an ancestry should be active.
func apply_character(character: Dictionary) -> void:
	# Reset ancestry vars first so stale values never persist across calls.
	ancestry_move_mult = 1.0
	ancestry_jump_mult = 1.0
	stone_ore_mine_mult = 1.0
	ancestry_health_bonus = 0.0
	learning_speed_mult = 1.0
	var appearance: Dictionary = BlockRegistry.appearance_def(str(character.get("appearance", "tan")))
	body_color = Color.from_string("#" + str(appearance.get("body", "ebd48c")), body_color)
	trim_color = Color.from_string("#" + str(appearance.get("trim", "59402e")), trim_color)
	var effects: Dictionary = BlockRegistry.trait_effects(character.get("traits", []))
	var role: Dictionary = BlockRegistry.role_def(str(character.get("role", "")))
	for key in role.get("effects", {}):
		if key.ends_with("_bonus"):
			effects[key] = float(effects.get(key, 0.0)) + float(role["effects"][key])
		else:
			effects[key] = role["effects"][key]
	max_health = 100.0 + float(effects.get("max_health_bonus", 0.0))
	health = minf(health, max_health)
	trait_mine_mult = float(effects.get("mine_speed_mult", 1.0))
	reach_bonus = float(effects.get("reach_bonus", 0.0))
	bush_bonus_food = int(effects.get("bush_bonus_food", 0))
	growth_threshold_delta = float(effects.get("growth_threshold_delta", 0.0))
	queue_redraw()


## Applies ancestry player_effects dict to this player. Call after
## apply_character. Pass {} (or let game_root call apply_ancestry_for_species)
## to keep defaults for unknown/non-Phase-B species.
## Wired keys: move_speed_mult, jump_mult, stone_ore_mining_mult,
##             learning_speed_mult, health_bonus.
func apply_ancestry_effects(effects: Dictionary) -> void:
	ancestry_move_mult = float(effects.get("move_speed_mult", 1.0))
	# Fix 12: elf uses jump_bonus (additive fraction) instead of jump_mult.
	if effects.has("jump_mult"):
		ancestry_jump_mult = float(effects["jump_mult"])
	else:
		ancestry_jump_mult = 1.0 + float(effects.get("jump_bonus", 0.0))
	stone_ore_mine_mult = float(effects.get("stone_ore_mining_mult", 1.0))
	learning_speed_mult = float(effects.get("learning_speed_mult", 1.0))
	ancestry_health_bonus = float(effects.get("health_bonus", 0.0))
	max_health += ancestry_health_bonus
	# Fix 12: goblin uses health_reduction (multiplier, default 1.0 = no change).
	max_health = int(round(max_health * float(effects.get("health_reduction", 1.0))))
	health = minf(health, max_health)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY * ancestry_jump_mult
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED * ancestry_move_mult
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
		var _bid: String = world.block_at(cell)
		var _mine_speed := _effective_mine_speed_for(_bid)
		if stone_ore_mine_mult != 1.0:
			if _bid == "stone" or _bid == "ore":
				_mine_speed *= stone_ore_mine_mult
		mine_required = world.mine_time(cell, _mine_speed)
	mine_progress += delta
	if mine_progress < mine_required:
		return false
	var block_id: String = world.block_at(cell)
	var drops: Dictionary = world.break_block(cell)
	inventory.add_many(drops)
	if block_id == "berry_bush" and bush_bonus_food > 0:
		inventory.add("food", bush_bonus_food)
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
	placed.emit(block_id)
	return true


## Better picks mine faster: +50% speed per tier above 1; traits multiply.
func effective_mine_speed() -> float:
	return base_mine_speed * trait_mine_mult * (1.0 + 0.5 * float(tool_tier - 1))


## Wave F: returns effective mine speed for a specific block, applying the axe
## bonus (+40%) for axe-preferred blocks when an axe is carried.
## Stone/ore and other pick-preferred blocks are unaffected by axe_tier.
func _effective_mine_speed_for(block_id: String) -> float:
	var speed := effective_mine_speed()
	if axe_tier > 0 and BlockRegistry.preferred_tool(block_id) == "axe":
		speed *= 1.4
	return speed


func craft(recipe_id: String) -> bool:
	var recipe: Dictionary = BlockRegistry.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	if str(recipe.get("station", "hand")) != "hand":
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
	return global_position.distance_to(world.cell_center(cell)) <= (REACH_TILES + reach_bonus) * t


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
	# Placeholder body in the character's appearance colors.
	draw_rect(Rect2(-6, -14, 12, 28), body_color)
	draw_rect(Rect2(-4, -12, 8, 6), trim_color)
	# Mining target highlight with progress fill at the cursor.
	if world != null and Input.is_action_pressed("mine") and mine_required > 0.0:
		var t: float = float(world.tile_size())
		var local := to_local(Vector2(mine_target) * t)
		draw_rect(Rect2(local, Vector2(t, t)), Color(1, 1, 1, 0.6), false, 1.5)
		var ratio := mine_progress_ratio()
		if ratio > 0.0:
			draw_rect(Rect2(local + Vector2(0, t + 2), Vector2(t, 3)), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(local + Vector2(0, t + 2), Vector2(t * ratio, 3)), Color(1.0, 0.85, 0.3))
