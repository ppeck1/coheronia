extends RefCounted
## Shared lighting helpers — the ONE place radial glow textures are authored, so
## torches, lava, and the sun/moon all cast the same soft, source-weighted light
## instead of each script hand-rolling its own gradient. Keeps lighting from
## sprawling across world.gd + celestial.gd.
##
## No `class_name` (repo runtime-global gotcha): callers `preload` this as a const
## and call the static helpers (e.g. `const LightingScript := preload(...)`).
##
## The old per-site textures used a single LINEAR centre->edge alpha ramp, which
## reads as a hard-edged disc that "just stops". `glow_texture` instead lays down a
## multi-stop EASE-OUT curve: a bright plateau at the source, then a long, gentle
## tail to zero — brighter near the middle and a soft, gradual edge.

## A soft radial glow: bright core, gradual falloff, feathered rim. `warmth` tints
## the whole texture (default white so callers set colour via the light's `color`).
static func glow_texture(size := 256, warmth := Color(1, 1, 1)) -> GradientTexture2D:
	var grad := Gradient.new()
	# Approximates an ease-out (roughly (1-r)^2) falloff so most of the brightness
	# hugs the source and the outer half fades away smoothly rather than clipping.
	var stops := [
		[0.00, 1.00], [0.12, 0.98], [0.28, 0.82], [0.45, 0.58],
		[0.62, 0.34], [0.78, 0.16], [0.90, 0.05], [1.00, 0.00],
	]
	grad.offsets = _offsets(stops)
	grad.colors = _colors(stops, warmth)
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


static func _offsets(stops: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for s in stops:
		out.append(float(s[0]))
	return out


static func _colors(stops: Array, warmth: Color) -> PackedColorArray:
	var out := PackedColorArray()
	for s in stops:
		out.append(Color(warmth.r, warmth.g, warmth.b, float(s[1])))
	return out
