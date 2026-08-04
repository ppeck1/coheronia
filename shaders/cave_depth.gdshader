shader_type canvas_item;
// Underground-lighting rework: per-column depth darkening.
//
// The global CanvasModulate darkens the whole scene by the PLAYER's depth, so a
// mined cross-section viewed from the surface stayed lit. This shader darkens each
// terrain fragment by ITS OWN depth below the local sky line, minus how dark the
// CanvasModulate has ALREADY made the viewer's own depth. That difference is only
// positive for terrain DEEPER than the viewer, so on the surface the whole
// underground reads dark while, once the player descends, the shader contributes
// nothing extra at the player's depth (the global tint already handles it) — no
// double-darkening, no behaviour change for entities.
//
// No `render_mode unshaded`: the fragment output is albedo, so torch/lava/sun
// PointLight2D lights still additively brighten these darkened tiles, keeping lit
// pockets readable — exactly the desired cave feel.

// R channel = first solid cell y (in TILES) for that column, one texel per column.
uniform sampler2D sky_tex : filter_nearest, repeat_disable;
uniform float tile_size = 16.0;
uniform float world_width = 240.0;
uniform float cave_fade_cells = 6.0;      // smooth band below the sky line
uniform vec4 cave_tint : source_color = vec4(0.10, 0.11, 0.16, 1.0);
uniform float viewer_darkness = 0.0;      // the player's own 0..1 depth factor

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// This column's sky line (first solid from the top), sampled at texel centre.
	float col = floor(world_pos.x / tile_size);
	float u = (col + 0.5) / world_width;
	float sky_y_tiles = texture(sky_tex, vec2(u, 0.5)).r;

	float frag_y_tiles = world_pos.y / tile_size;
	float depth = frag_y_tiles - sky_y_tiles;
	float frag_factor = clamp(depth / cave_fade_cells, 0.0, 1.0);

	// Only the darkening the global CanvasModulate has NOT already applied.
	float extra = clamp(frag_factor - viewer_darkness, 0.0, 1.0);
	COLOR.rgb *= mix(vec3(1.0), cave_tint.rgb, extra);
}
