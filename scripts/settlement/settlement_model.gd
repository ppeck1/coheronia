extends Node
## Computes Coherence / Load / Resilience from actual game state on a tick.
## Formulas and clamps come from data/settlement_rules.json (authoritative);
## this node evaluates them with Godot's Expression class.

signal updated(coherence: float, load_value: float, resilience: float, inputs: Dictionary, labels: Array)

const SHELTER_RADIUS := 6
const LIGHT_RADIUS := 8

var world: Node2D
var town_hall: Node2D
var game_root: Node

var coherence := 50.0
var load_value := 50.0
var resilience := 50.0
var inputs: Dictionary = {}
var status_labels: Array = []

var _expressions: Dictionary = {}
var _input_names: PackedStringArray = []
var _timer: Timer


func _ready() -> void:
	var rules: Dictionary = BlockRegistry.settlement_rules
	_input_names = PackedStringArray()
	for input_name in rules.get("inputs", []):
		_input_names.append(str(input_name))
	for key in rules.get("formulas", {}):
		var expr := Expression.new()
		if expr.parse(str(rules["formulas"][key]), _input_names) == OK:
			_expressions[key] = expr
		else:
			push_error("SettlementModel: failed to parse formula '%s'" % key)
	_timer = Timer.new()
	_timer.wait_time = float(rules.get("tick_seconds", 5.0))
	_timer.timeout.connect(compute)
	add_child(_timer)
	_timer.start()


## Gathers the eight MVP observables from real world state.
func gather_inputs() -> Dictionary:
	var hall_cell: Vector2i = world.hall_info.get("center_cell", Vector2i.ZERO)
	var core_cells: Array = world.hall_info.get("core_cells", [])

	var shelter_count: int = world.count_near(hall_cell, SHELTER_RADIUS,
		func(block_id: String, cell: Vector2i) -> bool:
			return BlockRegistry.is_solid(block_id) and not cell in core_cells)
	var torch_count: int = world.count_near(hall_cell, LIGHT_RADIUS,
		func(block_id: String, _cell: Vector2i) -> bool:
			return BlockRegistry.emits_light(block_id))
	var defense_count: int = world.count_near(hall_cell, SHELTER_RADIUS,
		func(block_id: String, _cell: Vector2i) -> bool:
			return BlockRegistry.has_tag(block_id, "defense"))

	var total_stock: int = town_hall.total_stock()
	var food_stock: int = int(town_hall.stockpile.get("food", 0))
	var food_short := maxf(0.0, float(town_hall.population) - float(food_stock))
	var threat_severity: float = 0.0
	if game_root != null:
		threat_severity = game_root.current_threat_severity()

	return {
		"shelter_score": minf(shelter_count * 0.5, 30.0),
		"light_score": minf(torch_count * 8.0, 30.0),
		"stockpile_score": minf(total_stock * 0.5, 30.0),
		"defense_score": minf(defense_count * 0.75, 25.0),
		"damage_score": minf(town_hall.damage * 0.3, 30.0),
		"threat_score": minf(threat_severity, 40.0),
		"scarcity_penalty": clampf((10.0 - total_stock) * 1.0 + food_short, 0.0, 15.0),
		"population_pressure": clampf(town_hall.population * 2.0 - total_stock * 0.1, 0.0, 20.0),
	}


func compute() -> void:
	if world == null or town_hall == null:
		return
	inputs = gather_inputs()
	var rules: Dictionary = BlockRegistry.settlement_rules
	var lo := float(rules.get("clamp_min", 0))
	var hi := float(rules.get("clamp_max", 100))
	var values: Array = []
	for input_name in _input_names:
		values.append(float(inputs.get(input_name, 0.0)))
	coherence = clampf(_eval("coherence", values, coherence), lo, hi)
	load_value = clampf(_eval("load", values, load_value), lo, hi)
	resilience = clampf(_eval("resilience", values, resilience), lo, hi)
	status_labels = _build_labels()
	updated.emit(coherence, load_value, resilience, inputs, status_labels)


func _eval(key: String, values: Array, fallback: float) -> float:
	if not _expressions.has(key):
		return fallback
	var result = _expressions[key].execute(values)
	if _expressions[key].has_execute_failed():
		return fallback
	return float(result)


func _build_labels() -> Array:
	var labels: Array = []
	if coherence >= 60.0:
		labels.append("Stable")
	elif coherence >= 30.0:
		labels.append("Strained")
	else:
		labels.append("Critical")
	if inputs.get("light_score", 0.0) >= 16.0:
		labels.append("Well-lit")
	if inputs.get("shelter_score", 0.0) < 10.0:
		labels.append("Exposed")
	if inputs.get("scarcity_penalty", 0.0) > 0.0:
		labels.append("Undersupplied")
	return labels
