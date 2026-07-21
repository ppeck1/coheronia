extends Node2D
## FQ-09W scenic backdrop: the cosmetic plane behind the whole world — sky,
## far terrain, and a mid silhouette line with stepped parallax. It lives in
## the world canvas (low z_index) so the day/night/storm CanvasModulate tint
## applies to it like everything else. It has no collision, is never mined,
## and never enters saves.
##
## Image hooks (optional, art/generated/backgrounds/): `surface_sky.png`
## (640x360 full frame), `surface_far_terrain.png` and
## `surface_mid_silhouette.png` (horizontally tiling strips with
## transparency). Missing images fall back to the restrained code-drawn
## gradient and silhouettes below — informational, never fatal.

const SKY_TOP := Color(0.30, 0.44, 0.62)
const SKY_HORIZON := Color(0.56, 0.62, 0.70)
const FAR_COL := Color(0.36, 0.43, 0.54)
const MID_COL := Color(0.24, 0.31, 0.40)
const UNDER_COL := Color(0.05, 0.045, 0.05)   # below the horizon, behind walls
const SKY_BANDS := 8
const FAR_PARALLAX := 0.25
const MID_PARALLAX := 0.5
const STEP_PX := 2.0   # parallax offsets snap to hard 2px steps

var _view := Rect2()
var _horizon_py := 480.0
var _under_py := 640.0   # deepest valley line: sky must reach at least here
# PR-07: the world and its per-column surface line drive the contour skirt so
# the backdrop follows the ACTUAL terrain top, not just the flat average horizon.
var _world = null
var _tile := 32.0
# Horizon/under metrics are anchored from the generated surface. The world may
# generate its surface either before or after this node's _ready (setup order
# varies), so anchoring is deferred until the surface exists.
var _metrics_ready := false


func _ready() -> void:
	name = "Backdrop"
	# Backdrop masters are authored at world resolution; Camera2D supplies the
	# sole 2x scale to the 1280x720 viewport.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Distant scenery ignores local 2D lights: a torch must not paint glow
	# blobs onto mountains kilometres away.
	light_mask = 0
	var world := get_parent()
	if world != null and "surface" in world:
		_world = world
		_tile = float(world.tile_size())
		_recompute_metrics()


## Anchor the flat horizon to the AVERAGE surface line and the under-earth fill
## to the DEEPEST valley so low terrain never has a void behind it. Runs from
## _ready and (deferred-safe) from _process until the surface has generated.
## Returns true once anchored.
func _recompute_metrics() -> bool:
	if _world == null or _world.surface.is_empty():
		return false
	var sum := 0.0
	var deepest := 0.0
	for x in _world.surface:
		sum += float(_world.surface[x])
		deepest = maxf(deepest, float(_world.surface[x]))
	_horizon_py = (sum / float(_world.surface.size())) * _tile
	_under_py = (deepest + 1.0) * _tile
	_metrics_ready = true
	return true


func _process(_delta: float) -> void:
	# Pick up a surface that generated after _ready (setup-after-add order).
	if not _metrics_ready and _recompute_metrics():
		queue_redraw()
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	var size := get_viewport_rect().size / cam.zoom
	var new_view := Rect2(center - size / 2.0, size)
	if not new_view.is_equal_approx(_view):
		_view = new_view
		queue_redraw()


## Optional image hook for a named backdrop layer (null = code fallback).
func layer_texture(id: String) -> Texture2D:
	return BlockRegistry.visual_texture("backgrounds", id)


func _draw() -> void:
	if _view.size.x <= 0.0:
		return
	var horizon := _horizon_py
	# Sky: full-frame art when present, else hard gradient bands — always
	# covering the whole view so no camera position shows blank edges.
	var sky := layer_texture("surface_sky")
	if sky != null:
		draw_texture_rect(sky, _view, false)
	else:
		# Sky reaches down to the deepest valley line so no terrain height
		# ever exposes a void; the horizon color simply holds below the
		# painted horizon.
		var sky_bottom := minf(_under_py, _view.end.y)
		if _view.position.y < sky_bottom:
			var band_h := (minf(horizon, sky_bottom) - _view.position.y) / float(SKY_BANDS)
			if band_h > 0.0:
				for i in range(SKY_BANDS):
					var f := float(i) / float(SKY_BANDS - 1)
					draw_rect(Rect2(_view.position.x, _view.position.y + band_h * i,
						_view.size.x, band_h + 1.0), SKY_TOP.lerp(SKY_HORIZON, f))
			if sky_bottom > horizon:
				draw_rect(Rect2(_view.position.x, maxf(horizon, _view.position.y),
					_view.size.x, sky_bottom - maxf(horizon, _view.position.y)), SKY_HORIZON)
	# Below the deepest valley: deep earth tone behind the backing walls, so
	# a missing wall tile or the world's bottom edge never reads as sky.
	if _view.end.y > _under_py:
		draw_rect(Rect2(_view.position.x, _under_py, _view.size.x,
			_view.end.y - _under_py), UNDER_COL)
	# Far and mid silhouette strips with stepped parallax.
	_strip(layer_texture("surface_far_terrain"), horizon, 72.0, FAR_PARALLAX,
		FAR_COL, 64.0, 903)
	_strip(layer_texture("surface_mid_silhouette"), horizon, 40.0, MID_PARALLAX,
		MID_COL, 40.0, 511)
	# PR-07: the contour skirt ties the flat distant horizon to the real terrain.
	_draw_contour_skirt(horizon)


## PR-07: the structural contour skirt. The backdrop's distant scenery is
## anchored to the flat AVERAGE surface line; where the real per-column terrain
## top sits below the mean (valleys) the distant band floated on a flat line
## with sky/void showing in the gap down to the terrain -- the seam. This fills,
## in WORLD space (no parallax, so it never swims), the band between the distant
## horizon and the ACTUAL per-column surface with a mid-ground foothill tone so
## the far terrain descends into valleys to meet the ground, and backs
## everything below the surface contour with the under-earth tone so no void
## shows behind terrain at any camera height. It is drawn in this node (behind
## the backing walls and blocks by z_index) and paints only cosmetic fills, so
## collision, lighting, shelter, saves, and the parallax of the distant strips
## are all unchanged.
func _draw_contour_skirt(horizon: float) -> void:
	if _world == null or _tile <= 0.0:
		return
	var surface: Dictionary = _world.surface
	if surface.is_empty():
		return
	var left := int(floorf(_view.position.x / _tile)) - 1
	var right := int(floorf(_view.end.x / _tile)) + 1
	var x_left := float(left) * _tile
	var x_right := float(right + 1) * _tile
	# foothill: distant flat horizon (top) down to the per-column surface (bottom,
	# clamped so peaks contribute nothing and only valley gaps are filled).
	var foothill := PackedVector2Array([Vector2(x_left, horizon)])
	# earth: per-column surface contour (top) down to the bottom of the view.
	var earth := PackedVector2Array([Vector2(x_left, _view.end.y)])
	for col in range(left, right + 1):
		var top := contour_top_px(col, horizon)
		var x0 := float(col) * _tile
		var x1 := x0 + _tile
		foothill.append(Vector2(x0, maxf(top, horizon)))
		foothill.append(Vector2(x1, maxf(top, horizon)))
		earth.append(Vector2(x0, top))
		earth.append(Vector2(x1, top))
	foothill.append(Vector2(x_right, horizon))
	earth.append(Vector2(x_right, _view.end.y))
	# Deep earth backing first, then the foothill band that meets the terrain.
	draw_colored_polygon(earth, UNDER_COL)
	draw_colored_polygon(foothill, MID_COL)


## PR-07: the skirt's top edge for world column `col`, in world pixels -- the
## ACTUAL per-column surface line (`surface[col] * tile`), so the skirt follows
## the terrain rather than the flat average horizon. Off-world columns clamp to
## the nearest edge (never a void past the bounds); with no world data it falls
## back to the flat horizon. Pure and side-effect free so the smoke can pin it.
func contour_top_px(col: int, fallback_horizon: float = -1.0) -> float:
	var horizon := _horizon_py if fallback_horizon < 0.0 else fallback_horizon
	if _world == null or _tile <= 0.0 or _world.surface.is_empty():
		return horizon
	var w := int(_world.width) if "width" in _world else 0
	var c := clampi(col, 0, w - 1) if w > 0 else col
	var sy: float = float(_world.surface.get(c, -1.0))
	return horizon if sy < 0.0 else sy * _tile


## One parallax strip anchored to the horizon: tiled art when present, else
## a deterministic code-drawn silhouette ridge (stable in world space).
func _strip(tex: Texture2D, horizon: float, strip_h: float, parallax: float,
		col: Color, wavelength: float, seed_val: int) -> void:
	var off := floorf(_view.position.x * (1.0 - parallax) / STEP_PX) * STEP_PX
	if tex != null:
		var w := float(tex.get_width())
		var h := float(tex.get_height())
		var x0 := _view.position.x - fposmod(_view.position.x * parallax + off, w) - w
		var x := x0
		while x < _view.end.x + w:
			draw_texture_rect(tex, Rect2(x, horizon - h, w, h), false)
			x += w
		return
	# Code fallback: hard silhouette polygon sampled on a fixed world grid so
	# the ridge never swims as the camera moves.
	var pts := PackedVector2Array()
	pts.append(Vector2(_view.position.x, horizon))
	var sample_x := floorf((_view.position.x * parallax + off) / wavelength) * wavelength
	while sample_x < _view.end.x * parallax + off + wavelength * 2.0:
		var n := int(floorf(sample_x / wavelength))
		var jag := float(_h(n * 31 + seed_val) % 100) / 100.0
		var px := (sample_x - off) / maxf(parallax, 0.001)
		pts.append(Vector2(px, horizon - strip_h * (0.35 + 0.65 * jag)))
		sample_x += wavelength
	pts.append(Vector2(_view.end.x, horizon))
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)


static func _h(n: int) -> int:
	var x := n * 2654435761
	x = (x ^ (x >> 13)) * 1274126177
	return absi(x ^ (x >> 16))
