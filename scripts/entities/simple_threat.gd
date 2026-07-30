extends CharacterBody2D
## Enemy entity configured from a def (enemy_id, family, drops, loot_mult).
## All live enemy definitions reuse this scene; family/id drive authored art,
## fallback tint, movement pressure, and special behavior.
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
## M4-B: a lava slime is molten, not a generic cave dweller — its body glows the
## lighter lava-red of its own bubbles rather than the underground green.
const SLIME_BODY_COL := Color(0.92, 0.42, 0.2, 0.95)

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
## M4-A raider_sapper: when blocked by a structural wall/door, break through it
## (on a cooldown) instead of climbing over — this is what tests the settlement's
## walls, doors, and defenders. Set by the spawner from the def's breaks_walls flag.
var breaks_walls := false
var _sap_cd := 0.0
const SAP_BREAK_COOLDOWN := 1.0
## M4-B lava_slime: immune to the lava hazard, and emits a small, HARD-CAPPED field
## of molten bubbles (array dicts, never scene nodes — reuses the lava_bubbles.gd
## look/behaviour as a per-entity capped budget, so a swarm can never spawn 1000
## nodes). Set by the spawner from the def.
var emits_bubbles := false
var lava_immune := false
var _bubbles: Array = []
const MAX_SLIME_BUBBLES := 10          # hard cap on simultaneous visible bubbles
const SLIME_BUBBLE_RATE := 7.0         # expected births/sec (variable, gated by the cap)
const SLIME_BUBBLE_RISE := 10.0
const SLIME_BUBBLE_POP := 0.28
const BUBBLE_CORE := Color(1.0, 0.74, 0.30)
const BUBBLE_EDGE := Color(0.87, 0.31, 0.11)
const BUBBLE_HILITE := Color(1.0, 0.92, 0.64)

## FQ-01: data-driven contact damage/speed, set by the spawner from the enemy
## def's "contact_damage"/"speed" fields (fallback to the PLAYER_DAMAGE/SPEED
## consts above when the def omits them). contact_damage is pre-scaled by
## config().difficulty("enemy") at spawn time, mirroring hall_dps.
var contact_damage := PLAYER_DAMAGE
var move_speed := SPEED

## Liquid Physics: accumulates fractional lava-burn damage so a per-frame hazard
## applies as whole integer hits against the int hp (weak enemies die fast, tough
## ones last a few ticks) — mirroring the player's paced burn.
var _hazard_accum := 0.0

## FQ-13: the thornrat's distinct pressure. When true, the threat hunts the
## nearest crop within CROP_SEEK_CELLS and eats it (removing it, no drop) before
## falling back to the hall — so it pressures early agriculture, not just the
## player. Set by the spawner from the def's "targets_crops" flag.
var targets_crops := false
const CROP_SEEK_CELLS := 12
const CROP_EAT_DIST := 22.0

## FQ-07: optional sprite from art/generated/enemies/<enemy_id>.png; null
## keeps the drawn-rect fallback below.
var _art: Texture2D = null
## FQ-13P1: which variant of the enemy pool this instance drew (-1 = no pool,
## canonical or code-drawn). Chosen once at creation, fixed for life.
var variant_index := -1


func _ready() -> void:
	add_to_group("threats")
	max_hp = maxi(max_hp, hp)
	_select_sprite()


## FQ-13P1: pick this enemy's sprite once at creation and keep it for life.
## Prefers a deterministic variant from the FQ-09V enemies pool (so two enemies
## of the same kind can visibly differ), else the canonical single image, else
## the code-drawn body in _draw. Presentation-only: the choice is recomputed
## from the same enemy_id + spawn cell + world seed on load, so it is never saved
## and never changes during damage, movement, pause, or redraw.
func _select_sprite() -> void:
	var pool: Array = BlockRegistry.visual_variant_textures("enemies", enemy_id)
	if not pool.is_empty():
		var cell: Vector2i = Vector2i.ZERO
		var seed_val: int = 0
		if world != null:
			cell = world.cell_of(global_position)
			seed_val = world.world_seed
		variant_index = variant_for(enemy_id, cell, seed_val, pool.size())
		_art = pool[variant_index]
	else:
		variant_index = -1
		_art = BlockRegistry.visual_texture("enemies", enemy_id)


## FQ-13P1: deterministic variant index for an enemy pool (mirrors the block
## variant rule). enemy_id salts the hash so different kinds sharing a cell can
## differ; posmod keeps it in range. Returns -1 for an empty pool.
static func variant_for(id: String, cell: Vector2i, seed_val: int, pool_size: int) -> int:
	if pool_size <= 0:
		return -1
	return posmod(hash("%s:%d:%d:%d" % [id, cell.x, cell.y, seed_val]), pool_size)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var at_hall := false
	# FQ-13: crop hunters steer to the nearest crop first; eating it clears the
	# cell (the player gets nothing — the lost harvest is the pressure).
	if _seek_and_eat_crop():
		pass
	elif town_hall != null:
		var dx := town_hall.global_position.x - global_position.x
		var near := absf(dx) < 26.0 and absf(town_hall.global_position.y - global_position.y) < 40.0
		if near:
			at_hall = true
			velocity.x = 0.0
			town_hall.take_damage(hall_dps * delta)
		else:
			velocity.x = signf(dx) * move_speed
	if is_on_wall() and is_on_floor() and not at_hall:
		# M4-A: a sapper breaches a structural wall/door in its path; everyone else
		# (and a sapper facing non-structural terrain) climbs over as before.
		if not (breaks_walls and _try_sap_wall(delta)):
			velocity.y = JUMP_VELOCITY
	move_and_slide()
	apply_environmental_hazard(delta)   # Liquid Physics: lava burns enemies too
	if not is_inside_tree():
		return                          # died in lava this frame; skip the rest
	if player != null and global_position.distance_to(player.global_position) < 18.0:
		player.take_damage(contact_damage)
	if emits_bubbles:
		_tick_bubbles(delta)   # M4-B: capped molten-bubble field
	queue_redraw()


## M4-A: the sapper stops and breaks the structural block directly ahead (toward
## the hall) on a cooldown, returning true while it is digging so the caller does
## not also make it jump. Only solid, non-protected STRUCTURE/DEFENSE/door blocks
## are sappable — player walls and doors, never bedrock, the hall core, or natural
## ground. break_block removes the wall without spawning loot.
func _try_sap_wall(delta: float) -> bool:
	_sap_cd = maxf(0.0, _sap_cd - delta)
	if world == null or town_hall == null:
		return false
	var dir := signf(town_hall.global_position.x - global_position.x)
	if dir == 0.0:
		return false
	var t := float(BlockRegistry.tile_size)
	var front: Vector2i = world.cell_of(global_position + Vector2(dir * t, 0.0))
	if not _is_sappable(world.block_at(front)):
		return false
	velocity.x = 0.0
	if _sap_cd <= 0.0:
		world.break_block(front)
		SimpleThreatFx.spawn(get_parent(), "dust_puff", world.cell_center(front))
		_sap_cd = SAP_BREAK_COOLDOWN
	return true


func _is_sappable(block_id: String) -> bool:
	if not BlockRegistry.is_solid(block_id) or BlockRegistry.has_tag(block_id, "protected"):
		return false
	return BlockRegistry.has_tag(block_id, "structure") \
		or BlockRegistry.has_tag(block_id, "defense") \
		or BlockRegistry.has_tag(block_id, "door")


## M4-B: advance the capped molten-bubble field (local to the body). Poisson-ish
## births gated by the hard cap, a slow wobbling rise, and a short burst at the top
## — the same behaviour as the lava-tile overlay, but as lightweight state, never
## scene nodes. Purely decorative: it touches no world/save state.
func _tick_bubbles(delta: float) -> void:
	var expected := SLIME_BUBBLE_RATE * delta
	while expected > 0.0 and _bubbles.size() < MAX_SLIME_BUBBLES:
		if randf() < expected:
			_bubbles.append({
				"x": randf_range(-5.0, 5.0), "y": randf_range(2.0, 5.0),
				"r": randf_range(1.0, 2.2),
				"speed": SLIME_BUBBLE_RISE * randf_range(0.7, 1.4),
				"wob": randf() * TAU, "amp": randf_range(1.5, 4.0),
				"pop": -1.0,
			})
		expected -= 1.0
	var kept: Array = []
	for b in _bubbles:
		if b["pop"] >= 0.0:
			b["pop"] += delta
			if b["pop"] < SLIME_BUBBLE_POP:
				kept.append(b)
			continue
		b["wob"] += delta * 3.0
		b["y"] -= b["speed"] * delta
		b["x"] += sin(b["wob"]) * b["amp"] * delta
		if b["y"] <= -8.0:            # broke the top of the body -> burst
			b["y"] = -8.0
			b["pop"] = 0.0
		kept.append(b)
	_bubbles = kept


func _draw_bubbles() -> void:
	for b in _bubbles:
		var pos := Vector2(b["x"], b["y"])
		if b["pop"] >= 0.0:
			var f: float = b["pop"] / SLIME_BUBBLE_POP
			draw_arc(pos, b["r"] * (1.0 + f * 2.0), 0.0, TAU, 10,
				Color(BUBBLE_CORE.r, BUBBLE_CORE.g, BUBBLE_CORE.b, 1.0 - f), 0.6, true)
		else:
			draw_circle(pos, b["r"] + 0.5, BUBBLE_EDGE)
			draw_circle(pos, b["r"], BUBBLE_CORE)
			draw_circle(pos - Vector2(b["r"] * 0.3, b["r"] * 0.3),
				maxf(b["r"] * 0.4, 0.4), BUBBLE_HILITE)


## Liquid Physics: environmental contact hazard. A threat standing in a
## contact-damage block (lava) burns like the player — sampled at the body cell
## and the cell above — with damage accumulated into whole hits via take_hit, so
## a weak enemy dies quickly in lava and a tough one lasts a few ticks.
func apply_environmental_hazard(delta: float) -> void:
	if world == null or lava_immune:   # M4-B: a lava slime is at home in the molten rock
		return
	var base_cell: Vector2i = world.cell_of(global_position)
	var dmg := 0.0
	for probe in [base_cell, base_cell + Vector2i(0, -1)]:
		dmg = maxf(dmg, BlockRegistry.contact_damage(world.block_at(probe)))
	if dmg <= 0.0:
		return
	_hazard_accum += dmg * delta
	if _hazard_accum >= 1.0:
		var whole := floori(_hazard_accum)
		_hazard_accum -= float(whole)
		take_hit(whole)


## FQ-13: if this threat eats crops and one is in range, steer toward it and eat
## it on contact. Returns true while a crop is being targeted (so the caller
## skips hall-seeking this frame). Returns false when there is nothing to hunt,
## letting the normal hall behavior run.
func _seek_and_eat_crop() -> bool:
	if not targets_crops or world == null:
		return false
	var crop: Vector2i = world.nearest_crop(world.cell_of(global_position), CROP_SEEK_CELLS)
	if crop.x < 0:
		return false
	var target: Vector2 = world.cell_center(crop)
	if global_position.distance_to(target) <= CROP_EAT_DIST:
		if world.eat_crop(crop):
			SimpleThreatFx.spawn(get_parent(), "dust_puff", target)
		velocity.x = 0.0
	else:
		velocity.x = signf(target.x - global_position.x) * move_speed
	return true


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


## Roll each drop entry and spill won items onto the ground at the point of death.
## R-08 slice 3: loot is no longer teleported into the player's backpack -- it
## drops as a loose ground item that the player auto-collects when adjacent and a
## hauler settler carries off otherwise.
func _roll_drops() -> void:
	if world == null or drops.is_empty():
		return
	for drop in drops:
		var chance: float = float(drop.get("chance", 0.0))
		if drop_chance_override >= 0.0:
			chance = drop_chance_override
		if randf() < chance * loot_mult:
			world.spawn_item_drop(global_position, str(drop.get("item_id", "")), 1)


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
		var body: Color = SLIME_BODY_COL if emits_bubbles \
			else FAMILY_COLORS.get(family, FAMILY_COLORS["surface"])
		if hurt > 0.0:
			body = body.lightened(hurt)
		draw_rect(Rect2(-7, -6, 14, 12), body)
		draw_rect(Rect2(-4, -3, 3, 3), Color.WHITE)
		draw_rect(Rect2(1, -3, 3, 3), Color.WHITE)
	if emits_bubbles:   # M4-B: molten bubbles rise over the body
		_draw_bubbles()
	# FQ-08: mini health bar above the body once damaged — damage is visible
	# well before death on both the art and fallback paths.
	if hp < max_hp:
		draw_rect(Rect2(-8, -12, 16, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-8, -12, 16.0 * health_bar_ratio(), 3), Color(0.85, 0.2, 0.2))
