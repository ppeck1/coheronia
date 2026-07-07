extends CharacterBody2D
## Player: movement, jump, hold-to-mine with hardness timing, block/torch
## placement from the hotbar, torch crafting, health.

signal inventory_changed
signal health_changed(health: float, max_health: float)
signal mined(block_id: String, drops: Dictionary)
signal crafted(recipe_id: String)
signal placed(block_id: String)
signal player_event(message: String)

const SPEED := 140.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 820.0
const REACH_TILES := 5.0

## FQ-01 defaults; overridden by data/character_data.json player_defaults
## (see _load_player_defaults). Kept as fallback if keys are missing.
const DEFAULT_BASE_MAX_HEALTH := 100.0
const DEFAULT_HURT_COOLDOWN_SEC := 0.8
const DEFAULT_FOOD_HEAL_AMOUNT := 25.0
const DEFAULT_EAT_COOLDOWN_SEC := 0.5
const DEFAULT_PASSIVE_REGEN_PER_SEC := 1.0
const DEFAULT_SAFE_RADIUS_PX := 160.0
const DEFAULT_COLLAPSE_LOSS_FRACTION := 0.25
const DEFAULT_LOW_HEALTH_FRACTION := 0.25

var world: Node2D
var health := 100.0
var max_health := 100.0
var tool_tier := 1    # pick tier; kept as primary alias for the pick.
var axe_tier := 0     # 0 = no axe; 1+ = axe tier. Wave F.
var base_mine_speed := 1.0
var inventory := InventoryData.new()
## FQ-03: slot_id -> equipment item_id ("" = empty). Character-owned, kept
## separate from the backpack inventory. The pickaxe/axe slots are derived
## from the live tool_tier/axe_tier at read time (see equipped_dict), so the
## mining code path is unchanged; the other slots are slot-ready data that
## FQ-04 will make live.
var equipment: Dictionary = {}

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
var _hurt_flash_timer := 0.0

# FQ-01: data-driven tuning, read from character_data.json player_defaults
# (falls back to the DEFAULT_* consts above when keys are missing).
var _base_max_health := DEFAULT_BASE_MAX_HEALTH
var _hurt_cooldown_sec := DEFAULT_HURT_COOLDOWN_SEC
var _food_heal_amount := DEFAULT_FOOD_HEAL_AMOUNT
var _eat_cooldown_sec := DEFAULT_EAT_COOLDOWN_SEC
var _passive_regen_per_sec := DEFAULT_PASSIVE_REGEN_PER_SEC
var _safe_radius_px := DEFAULT_SAFE_RADIUS_PX
var _collapse_loss_fraction := DEFAULT_COLLAPSE_LOSS_FRACTION
var _low_health_fraction := DEFAULT_LOW_HEALTH_FRACTION

var _eat_cooldown := 0.0
var _regen_active := false     # tracks whether the "feel safe" message already fired
var _low_health_active := false  # tracks whether the "badly hurt" message already fired


func _ready() -> void:
	_load_player_defaults()


## Reads data/character_data.json's player_defaults section (same registry
## pattern as BlockRegistry.character_data) so tuning stays data-driven.
## Missing keys keep the DEFAULT_* fallback values.
func _load_player_defaults() -> void:
	var defaults: Dictionary = BlockRegistry.character_data.get("player_defaults", {})
	_base_max_health = float(defaults.get("base_max_health", DEFAULT_BASE_MAX_HEALTH))
	_hurt_cooldown_sec = float(defaults.get("hurt_cooldown_sec", DEFAULT_HURT_COOLDOWN_SEC))
	_food_heal_amount = float(defaults.get("food_heal_amount", DEFAULT_FOOD_HEAL_AMOUNT))
	_eat_cooldown_sec = float(defaults.get("eat_cooldown_sec", DEFAULT_EAT_COOLDOWN_SEC))
	_passive_regen_per_sec = float(defaults.get("passive_regen_per_sec", DEFAULT_PASSIVE_REGEN_PER_SEC))
	_safe_radius_px = float(defaults.get("safe_radius_px", DEFAULT_SAFE_RADIUS_PX))
	_collapse_loss_fraction = float(defaults.get("collapse_loss_fraction", DEFAULT_COLLAPSE_LOSS_FRACTION))
	_low_health_fraction = float(defaults.get("low_health_fraction", DEFAULT_LOW_HEALTH_FRACTION))


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
	max_health = _base_max_health + float(effects.get("max_health_bonus", 0.0))
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
	# FQ-01 review: only round when a reduction actually applies, so ancestries
	# without one keep fractional max_health from data-driven bonuses intact.
	var _health_reduction := float(effects.get("health_reduction", 1.0))
	if _health_reduction != 1.0:
		max_health = roundf(max_health * _health_reduction)
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
	_eat_cooldown = maxf(0.0, _eat_cooldown - delta)
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer = maxf(0.0, _hurt_flash_timer - delta)
		if _hurt_flash_timer == 0.0:
			modulate = Color(1, 1, 1)

	if Input.is_action_just_pressed("eat_food"):
		_try_eat_food()
	_update_passive_regen(delta)

	if world == null:
		return
	_handle_hotbar()
	_handle_mining(delta)
	if Input.is_action_just_pressed("place"):
		try_place(world.cell_of(get_global_mouse_position()), selected_item())
	if Input.is_action_just_pressed("craft"):
		craft("craft_torch")
	queue_redraw()


## Healing A (active): eat one food from the inventory to heal, gated by an
## eat cooldown. No-op (and no food consumed) at full health or empty cooldown
## not yet expired.
func _try_eat_food() -> void:
	if _eat_cooldown > 0.0:
		return
	if health >= max_health:
		return
	if inventory.count("food") <= 0:
		return
	inventory.remove("food")
	_eat_cooldown = _eat_cooldown_sec
	health = minf(max_health, health + _food_heal_amount)
	inventory_changed.emit()
	health_changed.emit(health, max_health)
	_check_low_health()
	player_event.emit("You eat some food and recover.")


## Healing B (passive): regenerate slowly while near the Town Hall and clear
## of nearby threats. Emits health_changed only when the rounded health value
## changes, and logs the "feel safe" message only on the first tick of a
## regen streak (reset once health reaches max or the player leaves safety).
func _update_passive_regen(delta: float) -> void:
	if world == null or world.hall_info.is_empty():
		_regen_active = false
		return
	if health >= max_health:
		_regen_active = false
		return
	var hall_center: Vector2 = world.cell_center(world.hall_info["center_cell"])
	if global_position.distance_to(hall_center) > _safe_radius_px:
		_regen_active = false
		return
	for threat in get_tree().get_nodes_in_group("threats"):
		if is_instance_valid(threat) and not threat.is_queued_for_deletion():
			if threat.global_position.distance_to(global_position) < 200.0:
				_regen_active = false
				return
	var before := int(round(health))
	health = minf(max_health, health + _passive_regen_per_sec * delta)
	if int(round(health)) != before:
		health_changed.emit(health, max_health)
		_check_low_health()
	if not _regen_active:
		_regen_active = true
		player_event.emit("You feel safe near the Town Hall and begin to recover.")


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


## FQ-03: stores a normalized character equipment dict (every slot present,
## invalid entries emptied). Tool slots are ignored here — tool_tier/axe_tier
## remain the live authority and are merged back in by equipped_dict().
func apply_equipment(raw: Dictionary) -> void:
	equipment = BlockRegistry.normalize_equipment(raw)


## FQ-03: the full 12-slot gear picture used by the HUD and save path. The
## pickaxe/axe slots always reflect the live tool tiers so display and
## persistence can never drift from mining behavior.
func equipped_dict() -> Dictionary:
	var out: Dictionary = BlockRegistry.normalize_equipment(equipment)
	out["pickaxe"] = BlockRegistry.pick_item_for_tier(tool_tier)
	out["axe"] = BlockRegistry.axe_item_for_tier(axe_tier)
	return out


## FQ-03: equips item_id into slot_id ("" clears the slot). Tool slots route
## to the live tool tiers via the item's effects and cannot be cleared —
## picks/axes are gained through forging, and silently resetting a tier via
## an unequip would be a footgun. Returns false for unknown slots, slot/item
## mismatches, or clearing a tool slot.
func equip_item(slot_id: String, item_id: String) -> bool:
	if BlockRegistry.equipment_slot(slot_id).is_empty():
		return false
	if not BlockRegistry.item_fits_slot(item_id, slot_id):
		return false
	var effects: Dictionary = BlockRegistry.equipment_item(item_id).get("effects", {})
	match slot_id:
		"pickaxe":
			if item_id == "":
				return false
			tool_tier = int(effects.get("pick_tier", 1))
		"axe":
			if item_id == "":
				return false
			axe_tier = int(effects.get("axe_tier", 0))
		_:
			equipment[slot_id] = item_id
	inventory_changed.emit()
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
	_hurt_cooldown = _hurt_cooldown_sec
	health = maxf(0.0, health - amount)
	_hurt_flash_timer = 0.2
	modulate = Color(1.0, 0.35, 0.35)
	health_changed.emit(health, max_health)
	_check_low_health()
	if health <= 0.0:
		var _lost := _apply_collapse_loss()
		respawn(_lost)


## FQ-01 collapse consequence: lose a fraction of each carried stack (floor,
## per stack) before respawning. Runs before health is restored so the loss
## is deterministic and independent of the respawn heal.
## Returns true when at least one stack actually shrank.
func _apply_collapse_loss() -> bool:
	if _collapse_loss_fraction <= 0.0:
		return false
	var changed := false
	for item_id in inventory.counts.keys():
		var current: int = inventory.count(item_id)
		var loss: int = int(floor(float(current) * _collapse_loss_fraction))
		if loss > 0:
			inventory.remove(item_id, loss)
			changed = true
	if changed:
		inventory_changed.emit()
	return changed


func respawn(supplies_lost: bool = false) -> void:
	health = max_health
	health_changed.emit(health, max_health)
	_check_low_health()
	if world != null and not world.hall_info.is_empty():
		global_position = world.cell_center(world.hall_info["center_cell"]) + Vector2(-48, -24)
		velocity = Vector2.ZERO
	_regen_active = false
	var _msg := "You collapsed and awoke near the Town Hall."
	if supplies_lost:
		_msg += " Some of your supplies were lost."
	player_event.emit(_msg)


## Low-health state transition: logs "You are badly hurt." once per crossing
## below low_health_fraction of max_health; resets when healed back above it.
func _check_low_health() -> void:
	if max_health <= 0.0:
		return
	var ratio := health / max_health
	if ratio < _low_health_fraction:
		if not _low_health_active:
			_low_health_active = true
			player_event.emit("You are badly hurt.")
	else:
		_low_health_active = false


## Returns true when health is below low_health_fraction of max_health.
## Used by the HUD to tint the health bar/label.
func is_low_health() -> bool:
	if max_health <= 0.0:
		return false
	return (health / max_health) < _low_health_fraction


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
