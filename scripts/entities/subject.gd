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
const WORK_RADIUS_CELLS := 22     # bounded roam around home (fallback; data-owned)
# Settlement Coherence (M1) fallback bounds in CELLS if settlement_rules omits them.
const BOUND_HALF_WIDTH_CELLS := 28
const BOUND_UP_CELLS := 12
const BOUND_DOWN_CELLS := 10
# Stuck detection: a citizen that intends to move but makes no horizontal progress
# for this long has its goal dropped and hops to recover (then drifts home).
const STUCK_SECONDS := 2.5
const STUCK_EPS := 1.0
const HARVEST_DIST := 14.0
const REPAIR_DIST := 20.0         # the hall is wider than a crop cell
const HOME_IDLE_DIST := 10.0
const HAUL_DIST := 14.0
# M3-C defender: engages a threat within this radius of its guard post, closes to
# attack range, strikes on a cooldown, then (no threat) drifts back to its post.
# The settlement clamp keeps it in bounds; guard radius keeps it near its post.
const GUARD_RADIUS_PX := 150.0
const DEFEND_ATTACK_RANGE := 18.0
const DEFEND_ATTACK_DAMAGE := 2
const DEFEND_ATTACK_COOLDOWN := 0.8
const BODY_COL := Color(0.52, 0.78, 0.5)
const REPAIRER_COL := Color(0.5, 0.62, 0.82)
const HAULER_COL := Color(0.78, 0.66, 0.42)
const DEFENDER_COL := Color(0.72, 0.4, 0.4)   # M3-C
const HUNGRY_COL := Color(0.82, 0.62, 0.38)
const TRIM_COL := Color(0.30, 0.24, 0.18)

var world = null
var town_hall = null
var subject_id := "farmhand_1"
var job := "farmhand"
var hungry := false
var _home := Vector2.ZERO
var _target := Vector2i(-1, -1)
var _stuck_time := 0.0
var _last_x := 0.0
var _attack_cd := 0.0   # M3-C: defender attack cooldown
# Idle patrol: when a citizen has no work it paces gently near its post instead of
# standing frozen, so the settlement reads as alive.
var _patrol_dir := 1.0
var _patrol_timer := 0.0
var _patrol_moving := false
const PATROL_RADIUS := 34.0
const PATROL_SPEED := 16.0
# M3: per-citizen persisted identity. The sprite reuses the player body pipeline
# (BlockRegistry.player_body_id -> the live ancestry PNG); a job overlay still
# marks the trade. Generated deterministically at spawn, then PERSISTED (never
# regenerated on load), so a citizen keeps its face across saves.
var species := "human"
var body_variant := "masculine"
var visual_variant := 0
var _body_tex: Texture2D = null
# Citizen profile (persisted): an ancestry-aligned name, the day the citizen joined
# the settlement (for "days alive"), and a small set of settler stats.
var citizen_name := ""
var birth_day := 1
var stats: Dictionary = {}
var want := ""   # a persisted want id (see citizen_names.json wants); flavor + a need hook
var seed_pouch := 3   # crop seeds the farmhand carries; harvest refills, planting spends
var work_rect := Rect2i()   # cell-space work zone; empty (0 area) = radius around home

const BODY_RECT := Rect2(-8, -32, 16, 32)   # 16x32 body, feet at the origin


func _ready() -> void:
	add_to_group("subjects")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 24)
	shape.shape = rect
	# The sprite is drawn with its FEET at the origin (BODY_RECT bottom = 0), so the
	# collision box is lifted half its height to put its bottom at the origin too —
	# otherwise the body rests 12px (≈ one tile) above the ground and looks to float.
	shape.position = Vector2(0, -12)
	add_child(shape)
	# Settlement Coherence (M1): settlers collide with the WORLD (layer 1) so they
	# walk on the ground, but occupy NO collision layer themselves — so they never
	# shove the player or each other (a citizen spawned on the player's tile must
	# not block player movement). Terrain collision is unchanged.
	collision_layer = 0
	collision_mask = 1


func setup(w: Node, hall: Node, id: String = "farmhand_1") -> void:
	world = w
	town_hall = hall
	subject_id = id
	_home = hall.global_position
	_last_x = global_position.x


## Gentle idle pacing within PATROL_RADIUS of the post: alternate short walks and
## pauses, turning back at the edge. Keeps citizens visibly alive when there is no
## job to do, without wandering out of the settlement.
func _idle_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_patrol_moving = not _patrol_moving
		_patrol_timer = randf_range(1.0, 2.6)
		if _patrol_moving:
			var dx := global_position.x - _home.x
			_patrol_dir = -signf(dx) if absf(dx) > PATROL_RADIUS * 0.6 \
				else (1.0 if randf() < 0.5 else -1.0)
			if _patrol_dir == 0.0:
				_patrol_dir = 1.0
	if _patrol_moving:
		# Turn back before leaving the patrol radius.
		if absf(global_position.x - _home.x) > PATROL_RADIUS \
				and signf(global_position.x - _home.x) == _patrol_dir:
			_patrol_dir = -_patrol_dir
		velocity.x = _patrol_dir * PATROL_SPEED
	else:
		velocity.x = 0.0


## M3: set (and resolve the sprite for) this citizen's ancestry look. Reuses the
## same body-id + art authority the player uses, so citizens draw from the live
## ancestry imagery; unknown/absent art falls back to the procedural body.
func set_identity(sp: String, variant: String, vv: int = 0) -> void:
	species = sp
	body_variant = BlockRegistry.normalize_body_variant(variant)
	visual_variant = vv
	_resolve_body_tex()
	queue_redraw()


func _resolve_body_tex() -> void:
	_body_tex = null
	var body_id: String = BlockRegistry.player_body_id(species, body_variant)
	if body_id != "":
		_body_tex = BlockRegistry.visual_texture("players", body_id)


## Set the persisted citizen profile (name, join day, stats). game_root generates
## these deterministically from the citizen's identity seed.
func set_profile(cname: String, born: int, cstats: Dictionary, cwant: String = "") -> void:
	citizen_name = cname
	birth_day = born
	stats = cstats.duplicate()
	want = cwant


## Days this citizen has been part of the settlement, given the current day.
func days_alive(current_day: int) -> int:
	return maxi(0, current_day - birth_day)


## A stat value (defaults to a middling 5 for a citizen with no rolled stats).
func stat(id: String) -> int:
	return int(stats.get(id, 5))


## Stat-driven effectiveness. Vigor makes a settler move a little faster on the
## job; Guard makes a defender hit harder. (Craft/Spirit feed settlement
## contentment — see game_root.citizen_report.)
func effective_move_speed() -> float:
	return MOVE_SPEED * (0.8 + 0.04 * float(stat("vigor")))


func defend_damage() -> int:
	return maxi(1, DEFEND_ATTACK_DAMAGE + int(float(stat("guard")) / 3.0))


## Settlement Coherence (M1): a citizen's home/guard post. Persisted, and the
## anchor it idles at and returns to. game_root assigns each starting citizen a
## distinct post around the hall; load restores the saved one.
func set_home(pos: Vector2) -> void:
	_home = pos


## M1: bounded roam radius (cells) for finding work — data-owned, hall-relative.
func work_radius_cells() -> int:
	return BlockRegistry.settlement_bound_cells("work_radius_cells", WORK_RADIUS_CELLS)


## The effective work area in CELLS: the player-assigned `work_rect` if one is set,
## otherwise a radius box around home. Always clamped to the settlement bounds so the
## (movement-clamped) settler can actually reach every cell it is told to work. Job
## target searches (crops, planting, hauling) run inside this rect.
func work_bounds() -> Rect2i:
	var t := float(BlockRegistry.tile_size)
	var b := settlement_bounds_px()
	var smin := Vector2i(int(floor(b["min_x"] / t)), int(floor(b["min_y"] / t)))
	var smax := Vector2i(int(ceil(b["max_x"] / t)), int(ceil(b["max_y"] / t)))
	var rect: Rect2i
	if work_rect.size.x > 0 and work_rect.size.y > 0:
		rect = work_rect
	else:
		var hc: Vector2i = world.cell_of(_home)
		var r := work_radius_cells()
		rect = Rect2i(hc.x - r, hc.y - r, r * 2, r * 2)
	var x0 := maxi(rect.position.x, smin.x)
	var y0 := maxi(rect.position.y, smin.y)
	var x1 := mini(rect.position.x + rect.size.x, smax.x)
	var y1 := mini(rect.position.y + rect.size.y, smax.y)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


## Assign (or clear, with an empty rect) this settler's work zone.
func set_work_rect(rect: Rect2i) -> void:
	work_rect = rect


## M1: the settlement rectangle in WORLD PIXELS, centred on the Town Hall. Citizens
## hard-clamp inside it so a settler can never wander off the map (the left-edge
## bug) — target selection was already radius-bounded, but the body itself was not.
func settlement_bounds_px() -> Dictionary:
	var t := float(BlockRegistry.tile_size)
	var c: Vector2 = town_hall.global_position
	return {
		"min_x": c.x - BlockRegistry.settlement_bound_cells("half_width_cells", BOUND_HALF_WIDTH_CELLS) * t,
		"max_x": c.x + BlockRegistry.settlement_bound_cells("half_width_cells", BOUND_HALF_WIDTH_CELLS) * t,
		"min_y": c.y - BlockRegistry.settlement_bound_cells("up_cells", BOUND_UP_CELLS) * t,
		"max_y": c.y + BlockRegistry.settlement_bound_cells("down_cells", BOUND_DOWN_CELLS) * t,
	}


## M1: clamp a position into the settlement rectangle. Pure so the smoke can assert
## it without running physics.
func clamp_to_settlement(pos: Vector2) -> Vector2:
	var b := settlement_bounds_px()
	return Vector2(clampf(pos.x, b["min_x"], b["max_x"]), clampf(pos.y, b["min_y"], b["max_y"]))


## M1: advance stuck detection for one tick. A citizen that wants to move
## (|velocity.x| intent) but is not making horizontal progress accumulates stuck
## time; past the threshold it drops its goal and hops to recover, then the normal
## idle logic drifts it home. Returns true the tick recovery fires. Public so the
## smoke can drive it deterministically.
func update_stuck(delta: float) -> bool:
	if absf(global_position.x - _last_x) < STUCK_EPS and absf(velocity.x) > 1.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	_last_x = global_position.x
	if _stuck_time >= STUCK_SECONDS:
		_stuck_time = 0.0
		_target = Vector2i(-1, -1)       # drop the goal so idle logic returns home
		velocity.y = JUMP_VELOCITY       # hop to clear a one-tile lip
		return true
	return false


func _physics_process(delta: float) -> void:
	if world == null or town_hall == null:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	refresh_hunger()
	var acted := false
	# Defense is critical and is NOT gated by hunger — a defender always answers a
	# threat in its guard zone. Other jobs pause when the settlement has no food.
	if job == "defender" or not hungry:
		acted = run_job(delta)
	if not acted:
		# No work (or a hungry non-defender): patrol near the post if we have drifted
		# away, otherwise pace gently — never freeze in place.
		var dx := _home.x - global_position.x
		if absf(dx) > PATROL_RADIUS:
			velocity.x = signf(dx) * effective_move_speed()
		else:
			_idle_patrol(delta)
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY
	update_stuck(delta)                  # M1: recover a wedged citizen
	move_and_slide()
	global_position = clamp_to_settlement(global_position)   # M1: hard settlement bounds
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
		"hauler":
			return _run_hauler(delta)
		"defender":
			return _run_defender(delta)
	return false


## Farmhand: target the nearest ripe crop within the work radius of home; steer
## to it and, once in range, harvest it into the hall stockpile.
func _run_farmhand(_delta: float) -> bool:
	var home_cell: Vector2i = world.cell_of(_home)
	var zone := work_bounds()
	if _target.x < 0 or world.block_at(_target) != "crop_ripe":
		_target = world.nearest_ripe_crop_in(zone, home_cell)
	# No ripe crop to reap: if the farmhand still carries seed, tend the beds by
	# planting on empty tilled soil in its work area (a self-sustaining harvest ->
	# replant loop). TODO(future): also till dirt/grass into farm_soil first.
	var planting := false
	if _target.x < 0 and seed_pouch > 0:
		_target = world.nearest_plantable_soil_in(zone, home_cell)
		planting = _target.x >= 0
	if _target.x < 0:
		return false
	var tpos: Vector2 = world.cell_center(_target)
	if global_position.distance_to(tpos) <= HARVEST_DIST:
		if planting:
			if world.plant_crop(_target):
				seed_pouch -= 1
		else:
			_harvest(_target)
		_target = Vector2i(-1, -1)
		velocity.x = 0.0
		return true
	velocity.x = signf(tpos.x - global_position.x) * effective_move_speed()
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
	velocity.x = signf(hpos.x - global_position.x) * effective_move_speed()
	return true


## Hauler: gather loose ground items (mined yield, enemy loot) within the work
## radius of home and carry them to the hall stockpile. Targets the nearest drop;
## once in range, deposits the whole stack. Idle when the ground is clear. Like
## the farmhand this is PRODUCTION for the settlement -- it only ADDS to the
## stockpile and never spends food.
func _run_hauler(_delta: float) -> bool:
	var home_cell: Vector2i = world.cell_of(_home)
	var drop = world.nearest_item_drop_in(work_bounds(), home_cell)
	if drop == null:
		return false
	var dpos: Vector2 = drop.global_position
	if global_position.distance_to(dpos) <= HAUL_DIST:
		_deposit_drop(drop)
		velocity.x = 0.0
		return true
	velocity.x = signf(dpos.x - global_position.x) * effective_move_speed()
	return true


## M3-C Defender: guard the settlement. Engage the nearest threat within the guard
## radius of the post; close to attack range and strike on a cooldown (reusing the
## enemy's take_hit combat, so a defender kill routes through the same death/XP/
## contract path as a player kill). When no threat is in the guard zone this returns
## false, so the shared idle logic drifts the defender back to its post. Bounded to
## the settlement by the M1 movement clamp, and to its post by the guard radius —
## this is an assigned role, not direct player control.
func _run_defender(delta: float) -> bool:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var threat = _nearest_threat_in_guard_zone()
	if threat == null:
		return false
	var tpos: Vector2 = threat.global_position
	if global_position.distance_to(tpos) <= DEFEND_ATTACK_RANGE:
		velocity.x = 0.0
		if _attack_cd <= 0.0:
			threat.take_hit(defend_damage())
			_attack_cd = DEFEND_ATTACK_COOLDOWN
		return true
	velocity.x = signf(tpos.x - global_position.x) * effective_move_speed()
	return true


## M3-C: the nearest live threat within GUARD_RADIUS of this defender's post, or
## null. Measuring from the POST (not the body) keeps the defender anchored to its
## guard zone instead of chasing a fleeing enemy across the map.
func _nearest_threat_in_guard_zone():
	var best = null
	var best_d := GUARD_RADIUS_PX + 1.0
	for t in get_tree().get_nodes_in_group("threats"):
		if not is_instance_valid(t) or t.is_queued_for_deletion():
			continue
		var d: float = _home.distance_to(t.global_position)
		if d <= GUARD_RADIUS_PX and d < best_d:
			best_d = d
			best = t
	return best


## Deposit a ground drop's whole stack into the stockpile and remove it. Guards a
## drop already reaped this frame so the stack is never double-counted. Eligibility
## uses the SAME BlockRegistry.is_stockpile_material authority as the manual
## deposit (town_hall.deposit_all), so a hauler can never sneak a tool, gear, or
## world-state id into the material stockpile that a manual deposit would refuse.
## An ineligible drop is left on the ground (the hauler simply ignores it).
func _deposit_drop(drop) -> void:
	if drop == null or not is_instance_valid(drop) or drop.is_queued_for_deletion():
		return
	if not BlockRegistry.is_stockpile_material(str(drop.item_id)):
		return
	town_hall.stockpile[drop.item_id] = int(town_hall.stockpile.get(drop.item_id, 0)) + int(drop.count)
	drop.queue_free()
	town_hall.stockpile_changed.emit()


## Harvest a ripe crop cell and deposit its yield (food + seed) into the stockpile.
## This is PRODUCTION -- it only ADDS to the stockpile. Food consumption is owned
## solely by the abstract population model (see the contract note at the top).
func _harvest(cell: Vector2i) -> void:
	var drops: Dictionary = world.harvest_crop(cell)
	var deposited := false
	for item_id in drops:
		# Keep harvested seed in the farmhand's pouch to replant (seeds are not
		# stockpile-eligible by design); everything else (food) goes to the stockpile.
		if str(item_id) == "crop_seeds":
			seed_pouch += int(drops[item_id])
			continue
		town_hall.stockpile[item_id] = int(town_hall.stockpile.get(item_id, 0)) + int(drops[item_id])
		deposited = true
	if deposited:
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
	# M3: prefer the ancestry body sprite (live imagery via the player pipeline);
	# a warm pale tint reads "hungry". A job overlay still marks the trade.
	if _body_tex != null:
		var mod := Color(1.0, 0.86, 0.7) if hungry else Color(1, 1, 1)
		draw_texture_rect(_body_tex, BODY_RECT, false, mod)
		_draw_job_marker()
		return
	# Procedural fallback when no ancestry art is present.
	var base_col: Color = BODY_COL
	if job == "repairer":
		base_col = REPAIRER_COL
	elif job == "hauler":
		base_col = HAULER_COL
	elif job == "defender":
		base_col = DEFENDER_COL
	var col: Color = HUNGRY_COL if hungry else base_col
	draw_rect(Rect2(-5, -22, 10, 22), col)          # torso/legs
	draw_circle(Vector2(0, -26), 5, col)            # head
	draw_rect(Rect2(-5, -22, 10, 4), TRIM_COL)      # belt/hem
	_draw_job_marker()


## M3: a small tool overlay by the citizen's hand marking its trade, drawn over
## either the sprite or the procedural fallback.
func _draw_job_marker() -> void:
	if job == "repairer":
		draw_line(Vector2(6, -18), Vector2(11, -27), TRIM_COL, 2.0)   # hammer handle
		draw_rect(Rect2(9, -30, 5, 4), TRIM_COL)                      # hammer head
	elif job == "hauler":
		draw_rect(Rect2(4, -20, 8, 8), TRIM_COL)                      # a crate on the back
	elif job == "defender":
		draw_line(Vector2(7, -8), Vector2(7, -28), Color(0.85, 0.86, 0.9), 2.0)  # sword blade
		draw_line(Vector2(4, -24), Vector2(10, -24), TRIM_COL, 2.0)              # crossguard
	else:
		draw_line(Vector2(5, -20), Vector2(11, -28), TRIM_COL, 2.0)   # a hoe


func to_dict() -> Dictionary:
	return {
		"id": subject_id, "job": job, "hungry": hungry,
		"x": global_position.x, "y": global_position.y,
		# M1: persist the citizen's home/guard post so it survives save/load.
		"home_x": _home.x, "home_y": _home.y,
		# M3: persist the ancestry identity so it is never regenerated on load.
		"species": species, "body_variant": body_variant, "visual_variant": visual_variant,
		# Citizen profile: name/join-day/stats/want persist verbatim.
		"name": citizen_name, "birth_day": birth_day, "stats": stats.duplicate(), "want": want,
		"seed_pouch": seed_pouch,
		# Per-settler work zone (cells); [x, y, w, h], all zero = unset (radius default).
		"work_zone": [work_rect.position.x, work_rect.position.y, work_rect.size.x, work_rect.size.y],
	}


func from_dict(d: Dictionary) -> void:
	subject_id = str(d.get("id", subject_id))
	job = str(d.get("job", "farmhand"))
	hungry = bool(d.get("hungry", false))
	global_position = Vector2(
		float(d.get("x", global_position.x)), float(d.get("y", global_position.y)))
	# M1: restore home; a pre-M1 save (no home key) keeps the setup() default (hall).
	_home = Vector2(float(d.get("home_x", _home.x)), float(d.get("home_y", _home.y)))
	_last_x = global_position.x
	# M3: restore the persisted identity (pre-M3 saves default to human/masculine).
	set_identity(str(d.get("species", species)),
		str(d.get("body_variant", body_variant)), int(d.get("visual_variant", visual_variant)))
	# Restore the citizen profile (name/join-day/stats).
	citizen_name = str(d.get("name", citizen_name))
	birth_day = int(d.get("birth_day", birth_day))
	var raw_stats: Dictionary = d.get("stats", {})
	if not raw_stats.is_empty():
		stats = {}
		for k in raw_stats:
			stats[str(k)] = int(raw_stats[k])
	want = str(d.get("want", want))
	seed_pouch = int(d.get("seed_pouch", seed_pouch))
	var wz: Array = d.get("work_zone", [])
	if wz.size() >= 4:
		work_rect = Rect2i(int(wz[0]), int(wz[1]), int(wz[2]), int(wz[3]))
