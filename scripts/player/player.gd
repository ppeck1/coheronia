extends CharacterBody2D
## Player: movement, jump, hold-to-mine with hardness timing, block/torch
## placement from the hotbar, torch crafting, health.

signal inventory_changed
signal health_changed(health: float, max_health: float)
signal attunement_changed(attunement: float, max_attunement: float)
signal attunement_pulsed   # FQ-09U3: fires only when a pulse actually casts
signal mined(block_id: String, drops: Dictionary)
signal crafted(recipe_id: String)
signal placed(block_id: String)
signal player_event(message: String)

const SPEED := 140.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 820.0
const REACH_TILES := 5.0
# FQ-09M: self-freeing action effects (presentation only, never saved).
const ActionFx := preload("res://scripts/fx/action_fx.gd")

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

## FQ-05 attunement defaults; overridden by player_defaults like the above.
const DEFAULT_BASE_MAX_ATTUNEMENT := 50.0
const DEFAULT_ATTUNEMENT_REGEN_PER_SEC := 2.0
const DEFAULT_ATTUNEMENT_PULSE_COST := 15.0
const DEFAULT_ATTUNEMENT_PULSE_COOLDOWN_SEC := 1.0
const DEFAULT_ATTUNEMENT_PULSE_DURATION_SEC := 4.0
const DEFAULT_DOCK_ASSIGNMENTS: Array[String] = ["dirt", "wood", "stone", "torch", "lantern"]

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
var species_id := "human"
var body_variant := "masculine"
## FQ-13P3: character-owned cosmetic body variant index (presentation-only,
## never in world saves — it rides with the character record in the shell).
var visual_variant := 0
var body_color := Color(0.92, 0.83, 0.55)
var trim_color := Color(0.35, 0.25, 0.18)
var trait_mine_mult := 1.0
var reach_bonus := 0.0
var bush_bonus_food := 0
var growth_threshold_delta := 0.0
## The dock/hotbar is a reference row into carried inventory stacks, not
## separate storage. The name hotbar is kept for existing input/HUD paths.
var hotbar: Array[String] = DEFAULT_DOCK_ASSIGNMENTS.duplicate()
var selected_slot := 0

# Ancestry effects (Phase B; reset in apply_character, set by apply_ancestry_effects).
var ancestry_move_mult := 1.0
var ancestry_jump_mult := 1.0
var stone_ore_mine_mult := 1.0
var ancestry_health_bonus := 0.0
var learning_speed_mult := 1.0
# FQ-05 ancestry hooks: additive max-attunement bonus and regen multiplier.
# Every live ancestry defaults to 0.0 / 1.0, so non-magic characters play
# exactly as before; future magic-user lanes set these via player_effects.
var ancestry_attunement_bonus := 0.0
var attunement_regen_mult := 1.0

## FQ-05: the magic resource. Current value is world-saved next to health;
## the maximum is computed live (base + ancestry + gear) via max_attunement().
var attunement := DEFAULT_BASE_MAX_ATTUNEMENT

# FQ-06 perk effects (world-owned progression; recomputed from purchased
# perks by game_root._apply_purchased_perk_effects — never set directly).
var perk_mine_speed_mult := 1.0
var perk_attunement_bonus := 0.0

var mine_target := Vector2i(-99999, -99999)
var mine_progress := 0.0
var mine_required := 0.0

## PR-04: presentation-only weapon swing. Set when a melee hit lands so the
## visual can play a windup -> impact -> recovery slash toward the target; it
## never changes the instant hit, the damage, or any gameplay timing.
const ATTACK_SWING_SEC := 0.32
var attack_swing_t := 0.0
var attack_dir := Vector2.RIGHT

var _hurt_cooldown := 0.0
var _hurt_flash_timer := 0.0
## FQ-08: reused by the crack overlay each draw (re-seeded per frame from the
## target cell) so _draw never heap-allocates.
var _crack_rng := RandomNumberGenerator.new()

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
var _base_max_attunement := DEFAULT_BASE_MAX_ATTUNEMENT
var _attunement_regen_per_sec := DEFAULT_ATTUNEMENT_REGEN_PER_SEC
var _attunement_pulse_cost := DEFAULT_ATTUNEMENT_PULSE_COST
var _attunement_pulse_cooldown_sec := DEFAULT_ATTUNEMENT_PULSE_COOLDOWN_SEC
var _attunement_pulse_duration_sec := DEFAULT_ATTUNEMENT_PULSE_DURATION_SEC

var _pulse_cooldown := 0.0
var _pulse_time_left := 0.0
var _pulse_light: PointLight2D

var _eat_cooldown := 0.0
var _regen_active := false     # tracks whether the "feel safe" message already fired
var _low_health_active := false  # tracks whether the "badly hurt" message already fired

@onready var player_visual = get_node_or_null("PlayerVisual")


func _ready() -> void:
	_load_player_defaults()
	if player_visual != null:
		player_visual.sync_from_player()


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
	# FQ-05: attunement tuning.
	_base_max_attunement = float(defaults.get("base_max_attunement", DEFAULT_BASE_MAX_ATTUNEMENT))
	_attunement_regen_per_sec = float(defaults.get("attunement_regen_per_sec", DEFAULT_ATTUNEMENT_REGEN_PER_SEC))
	_attunement_pulse_cost = float(defaults.get("attunement_pulse_cost", DEFAULT_ATTUNEMENT_PULSE_COST))
	_attunement_pulse_cooldown_sec = float(defaults.get("attunement_pulse_cooldown_sec", DEFAULT_ATTUNEMENT_PULSE_COOLDOWN_SEC))
	_attunement_pulse_duration_sec = float(defaults.get("attunement_pulse_duration_sec", DEFAULT_ATTUNEMENT_PULSE_DURATION_SEC))
	attunement = _base_max_attunement


func selected_item() -> String:
	return hotbar[selected_slot]


func set_dock_assignments(raw_assignments: Array) -> void:
	hotbar.clear()
	var seen := {}
	for i in range(DEFAULT_DOCK_ASSIGNMENTS.size()):
		var fallback: String = DEFAULT_DOCK_ASSIGNMENTS[i]
		var item_id := fallback
		if i < raw_assignments.size():
			item_id = str(raw_assignments[i])
		if not BlockRegistry.is_dock_assignable_item(item_id):
			item_id = ""
		if item_id != "" and seen.has(item_id):
			item_id = fallback
		if not BlockRegistry.is_dock_assignable_item(item_id):
			item_id = ""
		if item_id != "" and seen.has(item_id):
			item_id = ""
		hotbar.append(item_id)
		if item_id != "":
			seen[item_id] = true
	selected_slot = clampi(selected_slot, 0, hotbar.size() - 1)


func dock_assignments_to_array() -> Array:
	return hotbar.duplicate()


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
	ancestry_attunement_bonus = 0.0
	attunement_regen_mult = 1.0
	species_id = str(character.get("species", "human"))
	body_variant = GameState.normalize_body_variant(
		str(character.get("body_variant", "masculine")))
	visual_variant = maxi(0, int(character.get("visual_variant", 0)))
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
	_clamp_attunement()
	if player_visual != null:
		player_visual.set_character_visual(species_id, body_variant, body_color,
			trim_color, visual_variant)
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
	# FQ-05: attunement hooks — additive max bonus and regen multiplier.
	ancestry_attunement_bonus = float(effects.get("attunement_bonus", 0.0))
	attunement_regen_mult = float(effects.get("attunement_regen_mult", 1.0))
	_clamp_attunement()


func _physics_process(delta: float) -> void:
	if GameState.hud_edit_mode:
		velocity = Vector2.ZERO
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY * ancestry_jump_mult
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED * ancestry_move_mult
	move_and_slide()
	_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)
	_eat_cooldown = maxf(0.0, _eat_cooldown - delta)
	attack_swing_t = maxf(0.0, attack_swing_t - delta)
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer = maxf(0.0, _hurt_flash_timer - delta)
		if _hurt_flash_timer == 0.0:
			modulate = Color(1, 1, 1)

	if Input.is_action_just_pressed("eat_food"):
		_try_eat_food()
	if Input.is_action_just_pressed("attune_pulse"):
		_try_attune_pulse()
	if Input.is_action_just_pressed("swap_weapon"):
		swap_weapon()
	_update_passive_regen(delta)
	_update_attunement_regen(delta)
	_tick_pulse(delta)

	if world == null:
		return
	_handle_hotbar()
	_handle_mining(delta)
	if Input.is_action_just_pressed("place"):
		try_place(world.cell_of(get_global_mouse_position()), selected_item())
	if Input.is_action_just_pressed("craft"):
		craft("craft_torch")
	if Input.is_action_just_pressed("farm_action"):
		try_farm(world.cell_of(get_global_mouse_position()))
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


## R-07: why placing `block_id` at `cell` would fail, or "" if it is valid. The
## single authority for both the placement feedback and the build-preview tint.
## Pure -- no side effects. Order matters (reach is reported before occupancy).
func place_reason(cell: Vector2i, block_id: String) -> String:
	if block_id == "" or not BlockRegistry.is_placeable(block_id):
		return "You can't place that."
	if inventory.count(block_id) <= 0:
		return "No %s left to place." % BlockRegistry.display_name(block_id)
	if not _in_reach(cell):
		return "That spot is out of reach."
	if world.block_at(cell) != "air":
		return "Something is already there."
	if _cell_overlaps_body(cell) and BlockRegistry.is_solid(block_id):
		return "You are standing there."
	return ""


func try_place(cell: Vector2i, block_id: String) -> bool:
	# Only a placeable block is a placement attempt; a selected tool right-click
	# is silently ignored (no nagging feedback).
	if block_id == "" or not BlockRegistry.is_placeable(block_id):
		return false
	var reason := place_reason(cell, block_id)
	if reason != "":
		player_event.emit(reason)
		return false
	if not world.place_block(cell, block_id):
		player_event.emit("You can't build there.")
		return false
	inventory.remove(block_id)
	inventory_changed.emit()
	placed.emit(block_id)
	ActionFx.spawn(world, "place_pulse", world.cell_center(cell))
	return true


## FQ-12: context farming on one key (G). Targeting dirt/grass tills it into
## farm_soil; targeting an air cell that sits on tilled soil plants a seed
## (consuming one from the backpack). Returns true if something happened.
func try_farm(cell: Vector2i) -> bool:
	if not _in_reach(cell):
		player_event.emit("That is out of reach.")
		return false
	var target: String = world.block_at(cell)
	if target == "dirt" or target == "grass":
		if world.till_soil(cell):
			ActionFx.spawn(world, "dust_puff", world.cell_center(cell))
			player_event.emit("Tilled the soil. Plant seeds (G) on it.")
			return true
		return false
	if target == "air" and world.block_at(cell + Vector2i(0, 1)) == "farm_soil":
		if inventory.count("crop_seeds") <= 0:
			player_event.emit("No seeds to plant — craft some from food.")
			return false
		if world.plant_crop(cell):
			inventory.remove("crop_seeds")
			inventory_changed.emit()
			ActionFx.spawn(world, "place_pulse", world.cell_center(cell))
			player_event.emit("Planted a crop. Give it time to ripen, then harvest it.")
			return true
		return false
	player_event.emit("Till dirt or grass first, then plant seeds on the tilled soil.")
	return false


## FQ-03: stores a normalized character equipment dict (every slot present,
## invalid entries emptied). Tool slots are ignored here — tool_tier/axe_tier
## remain the live authority and are merged back in by equipped_dict().
func apply_equipment(raw: Dictionary) -> void:
	equipment = BlockRegistry.normalize_equipment(raw)
	_clamp_attunement()
	# Presentation refresh at the equipment boundary: re-resolve so newly
	# equipped gear (including forged gear) picks up the current body art.
	if player_visual != null:
		player_visual.refresh_presentation()


## FQ-03/FQ-23: the full gear picture used by the HUD and save path. The
## pickaxe/axe slots always reflect the live tool tiers so display and
## persistence can never drift from mining behavior.
func equipped_dict() -> Dictionary:
	var out: Dictionary = BlockRegistry.normalize_equipment(equipment)
	out["pickaxe"] = BlockRegistry.pick_item_for_tier(tool_tier)
	out["axe"] = BlockRegistry.axe_item_for_tier(axe_tier)
	return out


## FQ-03: equips item_id into slot_id ("" clears the slot). Tool slots route
## to the live tool tiers via the item's effects.
## clearing a tool slot sets its tier to 0, so inventory UI moves and mining
## authority remain aligned. Returns false for unknown slots or slot/item
## mismatches.
func equip_item(slot_id: String, item_id: String) -> bool:
	if BlockRegistry.equipment_slot(slot_id).is_empty():
		return false
	if not BlockRegistry.item_fits_slot(item_id, slot_id):
		return false
	var effects: Dictionary = BlockRegistry.equipment_item(item_id).get("effects", {})
	match slot_id:
		"pickaxe":
			if item_id == "":
				tool_tier = 0
			else:
				tool_tier = int(effects.get("pick_tier", 1))
		"axe":
			if item_id == "":
				axe_tier = 0
			else:
				axe_tier = int(effects.get("axe_tier", 0))
		_:
			equipment[slot_id] = item_id
	# FQ-05: gear can change max attunement; keep the current value legal.
	_clamp_attunement()
	# Presentation refresh at the forge/equip boundary (town_hall.craft_station
	# and hand-equip both route here) so the overlay re-resolves for this body.
	if player_visual != null:
		player_visual.refresh_presentation()
	inventory_changed.emit()
	return true


func swap_weapon() -> bool:
	var equipped: Dictionary = equipped_dict()
	var active: String = str(equipped.get("weapon", ""))
	var offhand: String = str(equipped.get("offhand_weapon", ""))
	if active == "" and offhand == "":
		return false
	equipment["weapon"] = offhand
	equipment["offhand_weapon"] = active
	if player_visual != null:
		player_visual.refresh_presentation()
	inventory_changed.emit()
	var active_name: String = BlockRegistry.equipment_item_display_name(offhand) \
		if offhand != "" else "bare hands"
	player_event.emit("Switched weapon: %s." % active_name)
	return true


# ---------------------------------------------------------------------------
# FQ-05: Attunement — the player magic resource
# ---------------------------------------------------------------------------

## Max attunement is computed live so ancestry, equipment, and (future) perk
## modifiers can never go stale: base (player_defaults) + ancestry additive
## bonus + the attunement_bonus effect summed over equipped gear. Perk lanes
## should add their modifier here when FQ-06 wires them.
func max_attunement() -> float:
	return maxf(1.0, _base_max_attunement + ancestry_attunement_bonus \
		+ attunement_bonus_from_gear() + perk_attunement_bonus)


## Sum of the "attunement_bonus" effect over all equipped items (data-driven,
## same pattern as armor_total).
func attunement_bonus_from_gear() -> float:
	var total := 0.0
	var equipped: Dictionary = equipped_dict()
	for slot_id in equipped:
		if str(slot_id) == "offhand_weapon":
			continue
		var item_id: String = str(equipped[slot_id])
		if item_id != "":
			total += float(BlockRegistry.equipment_item(item_id).get("effects", {}).get("attunement_bonus", 0.0))
	return total


## Clamps current attunement to the (possibly shrunk) maximum and tells the HUD.
func _clamp_attunement() -> void:
	var cap := max_attunement()
	attunement = clampf(attunement, 0.0, cap)
	attunement_changed.emit(attunement, cap)


## Attunement recovers slowly everywhere — it is a personal resource, not a
## safety-gated one like passive health regen. Ancestry regen multiplier applies.
func _update_attunement_regen(delta: float) -> void:
	if attunement >= max_attunement():
		return
	var before := int(round(attunement))
	attunement = minf(max_attunement(), attunement + _attunement_regen_per_sec * attunement_regen_mult * delta)
	if int(round(attunement)) != before:
		attunement_changed.emit(attunement, max_attunement())


## FQ-05 first active use: a harmless light pulse around the player. Spends
## attunement, gated by its own cooldown; the light fades over the pulse
## duration. Returns true when the pulse fired.
func _try_attune_pulse() -> bool:
	if _pulse_cooldown > 0.0:
		return false
	if attunement < _attunement_pulse_cost:
		player_event.emit("You reach for attunement, but it slips away. (Not enough attunement.)")
		return false
	attunement -= _attunement_pulse_cost
	_pulse_cooldown = _attunement_pulse_cooldown_sec
	_pulse_time_left = _attunement_pulse_duration_sec
	if _pulse_light == null:
		_pulse_light = PointLight2D.new()
		_pulse_light.name = "AttunePulse"
		_pulse_light.texture = _make_pulse_texture()
		_pulse_light.texture_scale = 1.4
		_pulse_light.color = Color(0.65, 0.75, 1.0)
		add_child(_pulse_light)
	_pulse_light.enabled = true
	_pulse_light.energy = 1.5
	# FQ-09M: a stepped star-white ring makes the cast moment itself readable
	# (the light fade was previously the only cue).
	if world != null:
		ActionFx.spawn(world, "cast_ring", global_position)
	attunement_changed.emit(attunement, max_attunement())
	attunement_pulsed.emit()
	player_event.emit("You release a soft pulse of light.")
	return true


## Fades the active pulse light out over its duration.
func _tick_pulse(delta: float) -> void:
	_pulse_cooldown = maxf(0.0, _pulse_cooldown - delta)
	if _pulse_time_left <= 0.0 or _pulse_light == null:
		return
	_pulse_time_left = maxf(0.0, _pulse_time_left - delta)
	if _pulse_time_left <= 0.0:
		_pulse_light.enabled = false
	else:
		_pulse_light.energy = 1.5 * (_pulse_time_left / maxf(0.01, _attunement_pulse_duration_sec))


func _make_pulse_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	return tex


## FQ-04: melee damage per hit — the equipped weapon's attack_damage effect,
## or 1 when fighting bare-handed. Data-driven from equipment.json.
func attack_damage() -> int:
	var weapon_id := str(equipped_dict().get("weapon", ""))
	if weapon_id == "":
		return 1
	return maxi(1, int(BlockRegistry.equipment_item(weapon_id).get("effects", {}).get("attack_damage", 1)))


## FQ-04: flat incoming-damage reduction summed from every equipped item's
## "armor" effect (helmet/torso/feet carry it today; the sum stays data-driven
## so rings or amulets can add armor later without code changes).
func armor_total() -> float:
	var total := 0.0
	var equipped: Dictionary = equipped_dict()
	for slot_id in equipped:
		if str(slot_id) == "offhand_weapon":
			continue
		var item_id: String = str(equipped[slot_id])
		if item_id != "":
			total += float(BlockRegistry.equipment_item(item_id).get("effects", {}).get("armor", 0.0))
	return total


## FQ-06: applies the combined live perk effects (computed by game_root from
## purchased perks). Keys: mining_speed (multiplier), attunement_bonus
## (additive max attunement — the FQ-05 join point, now live).
func apply_perk_effects(effects: Dictionary) -> void:
	perk_mine_speed_mult = float(effects.get("mining_speed", 1.0))
	perk_attunement_bonus = float(effects.get("attunement_bonus", 0.0))
	_clamp_attunement()


## Better picks mine faster: +50% speed per tier above 1; traits and
## purchased Miner perks multiply.
func effective_mine_speed() -> float:
	return base_mine_speed * trait_mine_mult * perk_mine_speed_mult \
		* (1.0 + 0.5 * float(tool_tier - 1))


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
	# FQ-04 review: non-positive amounts stay a no-op (pre-armor contract);
	# the minimum-chip rule below only applies to real landed hits.
	if amount <= 0.0:
		return
	if _hurt_cooldown > 0.0:
		return
	_hurt_cooldown = _hurt_cooldown_sec
	# FQ-04: flat armor mitigation from equipped gear. A landed hit always
	# chips at least 1 health so armor can never grant outright immunity.
	var mitigated := maxf(1.0, amount - armor_total())
	health = maxf(0.0, health - mitigated)
	_hurt_flash_timer = 0.2
	modulate = Color(1.0, 0.35, 0.35)
	# FQ-09M: a brief spark burst joins the tint flash on every landed hit.
	if world != null:
		ActionFx.spawn(world, "hit_spark", global_position, Color(1.0, 0.45, 0.35))
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
		# FQ-09M: dust where the player fell and where they come to.
		ActionFx.spawn(world, "dust_puff", global_position)
		global_position = world.cell_center(world.hall_info["center_cell"]) + Vector2(-48, -24)
		velocity = Vector2.ZERO
		ActionFx.spawn(world, "dust_puff", global_position)
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


## FQ-08: damage stage 0 (untouched) .. 3 (about to break) from mining
## progress; drives the transient crack overlay. Purely visual state: it is
## never saved and resets through _reset_mining whenever the target changes
## or mining stops.
func mine_damage_stage() -> int:
	if mine_required <= 0.0 or mine_progress <= 0.0:
		return 0
	return clampi(int(mine_progress_ratio() * 4.0), 0, 3)


func _reset_mining() -> void:
	mine_target = Vector2i(-99999, -99999)
	mine_progress = 0.0
	mine_required = 0.0


## FQ-09M: the mining tool arc's pose — 0/1/2 (raise, mid, strike) cycling
## six pose-steps per second while a mining target is active, -1 otherwise.
## Pure presentation state derived from mining progress; never persisted and
## never fed back into mining timing.
func swing_phase() -> int:
	if mine_required <= 0.0:
		return -1
	return int(mine_progress * 6.0) % 3


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
			# FQ-04: hits carry the equipped weapon's damage (1 bare-handed).
			threat.take_hit(attack_damage())
			# PR-04: fire the presentation-only weapon swing toward the target.
			start_attack_swing(threat.global_position - global_position)
			return true
	return false


## PR-04: begin the presentation-only weapon swing toward a world direction.
## Presentation only -- it never touches damage, cooldowns, or mining timing.
func start_attack_swing(world_dir: Vector2) -> void:
	if world_dir.length() > 0.001:
		attack_dir = world_dir.normalized()
	attack_swing_t = ATTACK_SWING_SEC


## PR-04: 0..1 progress through the current weapon swing (1.0 = finished / idle).
func attack_swing_progress() -> float:
	if ATTACK_SWING_SEC <= 0.0:
		return 1.0
	return clampf(1.0 - attack_swing_t / ATTACK_SWING_SEC, 0.0, 1.0)


func attack_swing_active() -> bool:
	return attack_swing_t > 0.0


func _draw() -> void:
	# Body, facing, visible equipment, and the arm/tool pose live on the
	# PlayerVisual child so mirroring never touches collision or world UI.
	# FQ-09M: stepped tool swing toward the mining target — an arm plus a
	# pick or axe glyph cycling raise/mid/strike with mining progress.
	# Presentation only: reads mining state, never writes it.
	# Mining target highlight with progress fill at the cursor.
	if world != null and Input.is_action_pressed("mine") and mine_required > 0.0:
		var t: float = float(world.tile_size())
		var local := to_local(Vector2(mine_target) * t)
		draw_rect(Rect2(local, Vector2(t, t)), Color(1, 1, 1, 0.6), false, 1.5)
		var ratio := mine_progress_ratio()
		if ratio > 0.0:
			draw_rect(Rect2(local + Vector2(0, t + 2), Vector2(t, 3)), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(local + Vector2(0, t + 2), Vector2(t * ratio, 3)), Color(1.0, 0.85, 0.3))
		# FQ-08: crack overlay — more cracks per damage stage. Deterministic
		# per cell (seeded from the target) so cracks do not flicker between
		# frames; vanishes with _reset_mining on target change or release.
		# Crack segments are rasterized pixel by pixel through the block's
		# opaque mask so damage never shows outside the visible sprite (thin
		# trunks, leaves, bushes, torches).
		var stage := mine_damage_stage()
		if stage > 0:
			var mask: BitMap = world.block_opaque_mask(world.block_at(mine_target))
			_crack_rng.seed = hash(mine_target)
			for i in range(stage * 3):
				var from := Vector2(
					_crack_rng.randf_range(2.0, t - 2.0), _crack_rng.randf_range(2.0, t - 2.0))
				var to := from + Vector2(
					_crack_rng.randf_range(-5.0, 5.0), _crack_rng.randf_range(-5.0, 5.0))
				to.x = clampf(to.x, 0.0, t - 1.0)
				to.y = clampf(to.y, 0.0, t - 1.0)
				var steps := maxi(int(ceilf(from.distance_to(to))), 1)
				for s in range(steps + 1):
					var p := from.lerp(to, float(s) / float(steps))
					var px := Vector2i(
						clampi(int(p.x), 0, int(t) - 1), clampi(int(p.y), 0, int(t) - 1))
					if mask == null or mask.get_bit(px.x, px.y):
						draw_rect(Rect2(local + Vector2(px), Vector2.ONE),
							Color(0, 0, 0, 0.65))
