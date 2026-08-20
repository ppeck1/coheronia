extends Node2D
## Perception + Resonance (Phase B): a resonance highlight that lights up the object an
## Attunement pulse revealed, MASKED to that object, for the pulse duration. Two modes:
##   ENTITY — tints the actual entity sprite via `modulate` (masked to its silhouette)
##            and follows it, restoring the original tint when it ends.
##   CELL   — additively fills a terrain cell in its category colour (masked to the tile),
##            on an undimmed CanvasLayer so it glows through the veil and the dark.
## Presentation-only; never saved, never touches gameplay state.

const MarkShader := preload("res://shaders/resonance_mark.gdshader")

var _life := 0.0
var _duration := 8.0
var _color := Color(0.65, 0.8, 1.0)
var _size := Vector2(16, 16)
var _strength := 1.0                   # per-category fill opacity scale (cell mode)
var _target: CanvasItem = null
var _entity_mode := false
var _batch_mode := false
var _cells: Array = []                 # batch: [[Vector2 world_pos, Color color, float strength], ...]
var _mat: ShaderMaterial = null       # recolour material driven while highlighting an entity
var _orig_material: Material = null    # the entity's material to restore afterwards


## CELL mode: a fixed additive fill of one tile-sized box at `world_pos`. `strength`
## scales the fill opacity (lower for subtle categories like ore, so a dense vein does
## not wash out the screen).
func setup_cell(world_pos: Vector2, color: Color, box_size: Vector2, duration: float,
		strength: float = 1.0) -> void:
	global_position = world_pos
	_color = color
	_size = box_size
	_strength = strength
	_duration = maxf(duration, 0.1)
	_entity_mode = false
	z_index = 80
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_life = 0.0
	queue_redraw()


## BATCH mode: draw MANY terrain cells in one node/one _draw (so the whole screen's
## worth of ore/structures can light up without thousands of nodes). `entries` =
## [[world_pos, color, strength], ...]; the node sits at the origin and draws in world
## coordinates on the undimmed follow-viewport layer.
func setup_cells(entries: Array, box_size: Vector2, duration: float) -> void:
	global_position = Vector2.ZERO
	_cells = entries
	_size = box_size
	_duration = maxf(duration, 0.1)
	_batch_mode = true
	_entity_mode = false
	z_index = 80
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_life = 0.0
	queue_redraw()


## ENTITY mode: recolour the entity's sprite toward `mark_color` (masked to its
## silhouette) via a shader material, restoring the original material on end.
func setup_entity(target: CanvasItem, mark_color: Color, brighten: float, duration: float) -> void:
	_target = target
	_duration = maxf(duration, 0.1)
	_entity_mode = true
	_life = 0.0
	_orig_material = target.material
	_mat = ShaderMaterial.new()
	_mat.shader = MarkShader
	_mat.set_shader_parameter("mark_color", mark_color)
	_mat.set_shader_parameter("brighten", brighten)
	_mat.set_shader_parameter("strength", 0.0)
	target.material = _mat


## Re-trigger an existing entity highlight (a fresh pulse), reusing the same material.
func refresh_entity(mark_color: Color, brighten: float, duration: float) -> void:
	_duration = maxf(duration, 0.1)
	_life = 0.0
	if _mat != null:
		_mat.set_shader_parameter("mark_color", mark_color)
		_mat.set_shader_parameter("brighten", brighten)


func _process(delta: float) -> void:
	_life += delta
	if _entity_mode:
		if not is_instance_valid(_target) or _life >= _duration:
			queue_free()   # _exit_tree restores the material
			return
		if _mat != null:
			_mat.set_shader_parameter("strength", _envelope() * 0.9)
	else:
		# CELL and BATCH modes both just fade a fill.
		if _life >= _duration:
			queue_free()
			return
		queue_redraw()


func _exit_tree() -> void:
	if _entity_mode and is_instance_valid(_target):
		_target.material = _orig_material


## Long, steady highlight: a quick onset, hold near full most of its life, then ease out.
func _envelope() -> float:
	var t := clampf(_life / _duration, 0.0, 1.0)
	var a := 1.0 - smoothstep(0.72, 1.0, t)
	a *= clampf(_life / 0.16, 0.0, 1.0)
	a *= 0.9 + 0.1 * sin(_life * 4.0)
	return clampf(a, 0.0, 1.0)


func _draw() -> void:
	if _entity_mode:
		return
	var a := _envelope()
	if a <= 0.01:
		return
	# A single, edge-inset fill per cell (no compounding halo — that stacked across
	# dense veins and washed the screen out). Opacity scaled by per-category strength.
	var inset := Vector2(1.0, 1.0)
	var box := _size - inset * 2.0
	if _batch_mode:
		var off := -_size * 0.5 + inset
		for e in _cells:
			var col: Color = e[1]
			draw_rect(Rect2((e[0] as Vector2) + off, box),
				Color(col.r, col.g, col.b, a * 0.4 * float(e[2])), true)
		return
	draw_rect(Rect2(-_size * 0.5 + inset, box),
		Color(_color.r, _color.g, _color.b, a * 0.4 * _strength), true)
