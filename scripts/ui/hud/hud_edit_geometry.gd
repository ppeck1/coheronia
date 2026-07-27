extends RefCounted
## R-06.2 (ownership decomposition): the portable HUD edit-mode geometry math --
## widget measurement, min/max size, the corner-grip rect, and viewport
## position clamping -- lifted out of hud.gd behind a preserved facade. Pure
## functions of their Control / Vector2 inputs plus the geometry tuning consts
## below; no scene state and no hud back-reference. hud.gd keeps thin delegating
## wrappers (_hud_widget_size / _hud_natural_size / _hud_grip_rect /
## _hud_min_size / _hud_max_size / _clamp_hud_widget) so its surface -- and the
## fq17/fq20/fq21 smoke that drives _hud_widget_size / _hud_grip_rect /
## _resize_hud_widget -- is unchanged. The interactive controller (input,
## overlay, drag/resize state, layout load/save) intentionally stays in hud:
## its internals are smoke-driven and it reaches into ~7 HUD nodes, so a full
## node lift would add net coupling (R-06.2 scope decision, 2026-07-27).
##
## No `class_name` (repo cache-safety rule): consumers `preload` this script.

const GRIP_SIZE := 18.0
const MIN_SIZE_FACTOR := 0.5
const MAX_SIZE_FACTOR := 2.0
const SAFE_MARGIN := 12.0
const MIN_FLOOR := Vector2(120.0, 56.0)
const SIZE_FALLBACK := Vector2(160.0, 80.0)


## The live extent of a widget: its size lifted to custom_minimum_size and to a
## nonzero fallback, rounded.
static func widget_size(control: Control) -> Vector2:
	var measured := control.size
	var minimum := control.custom_minimum_size
	if minimum.x > measured.x:
		measured.x = minimum.x
	if minimum.y > measured.y:
		measured.y = minimum.y
	if measured.x <= 0.0:
		measured.x = SIZE_FALLBACK.x
	if measured.y <= 0.0:
		measured.y = SIZE_FALLBACK.y
	return measured.round()


## The content-driven natural size: the combined minimum lifted to the live
## custom-minimum and size. `_register_hud_widgets` measures this in `_ready`
## before containers lay out, so it must match the settled live size.
static func natural_size(control: Control) -> Vector2:
	var natural := control.get_combined_minimum_size()
	var minimum := control.custom_minimum_size
	natural.x = maxf(natural.x, maxf(minimum.x, control.size.x))
	natural.y = maxf(natural.y, maxf(minimum.y, control.size.y))
	if natural.x <= 0.0:
		natural.x = SIZE_FALLBACK.x
	if natural.y <= 0.0:
		natural.y = SIZE_FALLBACK.y
	return natural.round()


static func min_size(base_size: Vector2) -> Vector2:
	return Vector2(maxf(base_size.x * MIN_SIZE_FACTOR, MIN_FLOOR.x),
		maxf(base_size.y * MIN_SIZE_FACTOR, MIN_FLOOR.y)).round()


static func max_size(base_size: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(minf(base_size.x * MAX_SIZE_FACTOR, viewport_size.x - SAFE_MARGIN * 2.0),
		minf(base_size.y * MAX_SIZE_FACTOR, viewport_size.y - SAFE_MARGIN * 2.0)).round()


## The bottom-right corner-grip rect for a widget's global rect.
static func grip_rect(global_rect: Rect2) -> Rect2:
	return Rect2(global_rect.end - Vector2(GRIP_SIZE, GRIP_SIZE),
		Vector2(GRIP_SIZE, GRIP_SIZE))


## Clamp a widget position into the safe viewport region, per axis only where
## there is slack -- a full-width band has no horizontal slack and is left as-is
## rather than snapped to the margin.
static func clamp_position(position: Vector2, extent: Vector2,
		viewport_size: Vector2) -> Vector2:
	var out := position
	var max_position := viewport_size - extent - Vector2.ONE * SAFE_MARGIN
	if max_position.x >= SAFE_MARGIN:
		out.x = clampf(position.x, SAFE_MARGIN, max_position.x)
	if max_position.y >= SAFE_MARGIN:
		out.y = clampf(position.y, SAFE_MARGIN, max_position.y)
	return out
