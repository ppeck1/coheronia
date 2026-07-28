extends RefCounted
## Liquid Physics (LQ-1): a leveled cellular-automaton fluid engine owned by
## world.gd. Liquids stay ordinary `cells[cell] = <id>` entries, so every block
## query (block_at / is_solid / contact_damage / emits_light) and the tilemap
## keep working unchanged; this engine layers a parallel per-cell FILL LEVEL on
## top of them (world.liquid_level: Vector2i -> float in (0, 1]). A liquid cell
## ABSENT from liquid_level is treated as level 1.0 — that is exactly a
## generated-at-rest pool, so world-gen output needs no migration.
##
## Design guarantees (see docs/WORK_ORDER_LIQUID_PHYSICS.md):
##   * Mass-conserving, bar an epsilon collapse (MIN_LEVEL) that erases
##     vanishingly thin puddles so liquid never spreads infinitely thin.
##   * Sleep by default: only cells in `active` cost anything per step, so a
##     settled world is free. Mining/placing a neighbour wakes the local liquid
##     (world.break_block/place_block -> wake_neighbours), so a breached pool
##     pours and nothing flows unprompted ("flow on disturbance").
##   * Deterministic: a fixed timestep and a fixed bottom-up (y desc, x asc) cell
##     order make the result independent of frame rate and Dictionary order.
##     step()/settle() are exposed so the smoke suite pumps a known number of
##     steps and asserts outcomes; the pinned gameplay baseline runs paused.
##
## LQ-1 renders liquids with the existing full-cell tile only; the level-quantized
## partial-fill tiles are LQ-2 (a follow-up art pass). The level state, saves, and
## physics are all live now.

const STEP_SECONDS := 1.0 / 15.0   # fixed simulation timestep
const MIN_LEVEL := 0.012           # a cell below this collapses back to air (the
                                   # only place mass is lost — kept small so a
                                   # settle sheds only a tiny epsilon)
const FLOW_FRACTION := 0.6         # fraction of a level gap moved sideways per step
const FLOW_EPS := 0.006            # transfers below this are skipped, so a level
                                   # surface settles and SLEEPS (no asymptotic churn)
const MAX_LEVEL := 1.0
const MAX_CATCHUP_STEPS := 4       # cap steps per frame so a long frame can't spin

var _world: Node2D                 # owning world (cells / liquid_level / tiles / deltas)
var active: Dictionary = {}        # Vector2i -> true: cells to process next step
var _accum := 0.0
var _step_counter := 0


func _init(world: Node2D) -> void:
	_world = world


# ---------------------------------------------------------------------------
# Scheduling
# ---------------------------------------------------------------------------

## Advances the fixed-step accumulator with the frame delta (called from
## world._process). No-op while asleep (empty active set) so a settled world is
## free. Catch-up is bounded so a long/hitched frame never runs many steps.
func tick(delta: float) -> void:
	if active.is_empty():
		_accum = 0.0
		return
	_accum += delta
	var budget := MAX_CATCHUP_STEPS
	while _accum >= STEP_SECONDS and budget > 0:
		_accum -= STEP_SECONDS
		budget -= 1
		step()
		if active.is_empty():
			break   # settled: drop any remaining accumulated time
	if active.is_empty():
		_accum = 0.0


## Marks a cell for processing next step (only meaningful for a liquid cell; an
## air/solid cell simply no-ops when stepped). Cheap and idempotent.
func wake(cell: Vector2i) -> void:
	if _world.cells.get(cell, "air") != "air":
		active[cell] = true


## Wakes the 4-neighbourhood of a disturbed cell plus the cell itself — the
## "flow on disturbance" hook world.break_block/place_block call so a pool starts
## pouring the instant its wall is breached.
func wake_neighbours(cell: Vector2i) -> void:
	wake(cell)
	wake(cell + Vector2i(0, 1))
	wake(cell + Vector2i(0, -1))
	wake(cell + Vector2i(1, 0))
	wake(cell + Vector2i(-1, 0))


func active_count() -> int:
	return active.size()


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

## One deterministic simulation step over the current active set. Returns the
## number of cells that moved mass this step (0 => the world has settled).
func step() -> int:
	_step_counter += 1
	if active.is_empty():
		return 0
	# Fixed order: lowest rows first (y desc), then x asc, so a falling column
	# descends one row per step and the outcome never depends on Dictionary order.
	var cells_list: Array = active.keys()
	cells_list.sort_custom(_order_bottom_up)
	active = {}
	var moved := 0
	for c: Vector2i in cells_list:
		if _step_cell(c):
			moved += 1
	return moved


## Pumps up to `max_steps` steps and stops once the world settles (empty active
## set). Returns the number of steps actually run. Used by the smoke suite for
## deterministic assertions and by world.setup to settle a reloaded mid-flow
## world. Termination is guaranteed: a settled cell is not re-woken, and
## FLOW_EPS makes a level surface stop transferring rather than churn forever.
func settle(max_steps: int = 256) -> int:
	var n := 0
	while n < max_steps and not active.is_empty():
		n += 1
		step()
	return n


func _order_bottom_up(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y > b.y
	return a.x < b.x


## Processes one liquid cell: pour along gravity, then equalize sideways. Returns
## true if any mass moved (which re-wakes the touched cells for the next step).
func _step_cell(c: Vector2i) -> bool:
	var kind: String = _world.cells.get(c, "air")
	if not BlockRegistry.is_liquid(kind):
		return false
	# Viscosity: a thick liquid only moves every Nth step, but stays awake so it
	# resumes on its cadence rather than falling asleep between turns.
	var viscosity := BlockRegistry.liquid_viscosity(kind)
	if _step_counter % viscosity != 0:
		active[c] = true
		return false
	var flow_dir := BlockRegistry.liquid_flow_dir(kind)
	var level: float = _world.liquid_level.get(c, MAX_LEVEL)
	var moved := false

	# 1. Flow along gravity (down for liquids) into air or an unfilled same-liquid.
	var below := c + Vector2i(0, flow_dir)
	if _can_receive(below, kind):
		var move: float = minf(level, MAX_LEVEL - _level_of(below, kind))
		if move > FLOW_EPS:
			_set_level(below, kind, _level_of(below, kind) + move)
			level -= move
			moved = true

	# 2. Spread sideways toward lower neighbours so puddles level out. The
	#    FLOW_EPS gate means a near-level surface stops moving and sleeps rather
	#    than transferring ever-smaller amounts forever.
	if level > MIN_LEVEL:
		for dx in [-1, 1]:
			var n := c + Vector2i(dx, 0)
			if not _can_receive(n, kind):
				continue
			var nl := _level_of(n, kind)
			if nl < level - FLOW_EPS:
				var move2: float = minf((level - nl) * FLOW_FRACTION, MAX_LEVEL - nl)
				if move2 > FLOW_EPS:
					_set_level(n, kind, nl + move2)
					level -= move2
					moved = true

	# 3. Only if mass actually left this cell do we write the reduced level back
	#    (collapsing to air below MIN_LEVEL) and re-wake the neighbourhood. A cell
	#    that could not move is left untouched — no redundant 1.0 entries on
	#    settled full pools, and it simply sleeps.
	if moved:
		_set_level(c, kind, level)
		wake_neighbours(c)
	return moved


## True if `cell` can accept more of `kind`: it is open air, or the same liquid
## not yet full. Solids and other blocks are barriers. Non-liquid decorations
## (torch/bush) read as barriers too — liquid does not flood them (LQ-1 scope).
func _can_receive(cell: Vector2i, kind: String) -> bool:
	# Off-world cells are barriers, so liquid can never flow past the edges.
	if cell.x < 0 or cell.x >= _world.width or cell.y < 0 or cell.y >= _world.height:
		return false
	var b: String = _world.cells.get(cell, "air")
	if b == "air":
		return true
	if b == kind:
		return _world.liquid_level.get(cell, MAX_LEVEL) < MAX_LEVEL - 0.0001
	return false


## The fill level of `cell` as `kind` (its liquid_level, or 1.0 when a same-liquid
## cell has no explicit entry), else 0.0 (an air cell is empty of this liquid).
func _level_of(cell: Vector2i, kind: String) -> float:
	if _world.cells.get(cell, "air") == kind:
		return _world.liquid_level.get(cell, MAX_LEVEL)
	return 0.0


## The single mutation authority for a liquid cell. Filling an air cell and
## draining a liquid cell to air are terrain-id changes, so they write a delta
## (persisted) + retile + emit block_changed, exactly like place/break. A level
## change with no id change only updates liquid_level (LQ-2 will re-tile by
## level here). Never clobbers a solid or a different block.
func _set_level(cell: Vector2i, kind: String, lvl: float) -> void:
	lvl = minf(lvl, MAX_LEVEL)
	var was: String = _world.cells.get(cell, "air")
	if lvl < MIN_LEVEL:
		if was == kind:   # drain our liquid back to air (never touch solids)
			_world.cells.erase(cell)
			_world.liquid_level.erase(cell)
			_world.deltas[cell] = "air"
			_world._set_tile(cell, "air")
			_world.block_changed.emit(cell, "air")
			_refresh_column_tiles(cell, kind)   # the cell above is now a surface
		return
	if was == "air":      # fill empty space with liquid
		_world.cells[cell] = kind
		_world.deltas[cell] = kind
		_world.liquid_level[cell] = lvl
		_world._set_tile(cell, kind)
		_world.block_changed.emit(cell, kind)
		_refresh_column_tiles(cell, kind)       # the cell below is now submerged
	elif was == kind:     # same liquid, level-only change -> retile by level (LQ-2)
		_world.liquid_level[cell] = lvl
		_world._set_tile(cell, kind)


## LQ-2: re-tiles the cells directly above and below `cell` along the flow axis.
## A cell renders full when submerged (same liquid above) and partial at the
## surface, so when `cell` gains or loses liquid its vertical neighbours' surface/
## submerged status changes and must be re-rendered — otherwise a falling column
## flickers between full and laddered slivers.
func _refresh_column_tiles(cell: Vector2i, kind: String) -> void:
	var d := Vector2i(0, BlockRegistry.liquid_flow_dir(kind))
	for nb: Vector2i in [cell + d, cell - d]:
		_world._set_tile(nb, _world.cells.get(nb, "air"))
