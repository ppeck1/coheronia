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
// The depth darkening is AMBIENT ONLY. fragment() dims the unlit base by depth, but
// a matching light() illuminates each tile's TRUE albedo (the texture, before the
// depth dim), so a torch/lava/sun PointLight2D brightens a deep tile FULLY no matter
// how far below the viewer it sits. Without this, the darkened fragment COLOR
// multiplies the light too, so a lit pocket below the viewer — or an underground
// torch seen from a cave mouth — read as dark. Lit pockets now stay readable from
// any depth; only the ambient (unlit) surfaces recede with depth.

// R channel = first solid cell y (in TILES) for that column, one texel per column.
uniform sampler2D sky_tex : filter_nearest, repeat_disable;
uniform float tile_size = 16.0;
uniform float world_width = 240.0;
uniform float cave_fade_cells = 6.0;      // smooth band below the sky line
uniform vec4 cave_tint : source_color = vec4(0.10, 0.11, 0.16, 1.0);
uniform float viewer_darkness = 0.0;      // the player's own 0..1 depth factor
// Celestial admission: normalized direction (world space, +y = down) from a
// terrain cell TOWARD the sun/moon, so a fragment with an unobstructed slant path
// to the body keeps ambient light even when its OWN column has a solid roof (a
// window / doorway / cave mouth, not just a vertical shaft). `sky_admit_strength`
// 0 disables the march (kept for A/B and for a body low on the horizon).
uniform vec2 sky_dir = vec2(0.0, -1.0);
uniform float sky_admit_strength = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// How much of the open sky this cell can see along the sun/moon direction: 1 when
// the slant ray toward the body clears the terrain silhouette (`sky_line`) at every
// column it crosses before exiting above the world, 0 when solid terrain blocks it.
// A bounded 1D horizon march over the already-uploaded per-column sky-line texture
// (no per-pixel terrain raytrace) — cheap, deterministic, viewport-scale.
float sky_admittance(float frag_x_tiles, float frag_y_tiles) {
	// March in whole-column steps along the ray toward the body. A near-vertical ray
	// (a shaft straight up) resolves in the first step; a slanted ray (a side window)
	// walks sideways, testing each column's silhouette.
	vec2 d = sky_dir;
	if (abs(d.x) < 0.0001 && abs(d.y) < 0.0001) {
		return 0.0;
	}
	// Normalize so one step advances exactly one column in x (or, for a steep ray,
	// climbs toward the surface in y). Cap the walk at the world width.
	float step_x = (abs(d.x) > abs(d.y)) ? sign(d.x) : d.x / max(abs(d.y), 0.0001);
	float step_y = (abs(d.x) > abs(d.y)) ? d.y / max(abs(d.x), 0.0001) : sign(d.y);
	float cx = frag_x_tiles;
	float cy = frag_y_tiles;
	// The fragment's own column silhouette: if it is already at/above its sky line the
	// straight-up path is open (a shaft or the open surface) — fully admitted.
	for (int i = 0; i < 64; i++) {
		float u = (floor(cx) + 0.5) / world_width;
		float col_sky = texture(sky_tex, vec2(u, 0.5)).r;
		// The ray has climbed to (or above) this column's first solid block: it has
		// reached open sky for this column. If we are above the silhouette here, the
		// remaining path to the body is over open terrain — admit the light.
		if (cy <= col_sky) {
			return 1.0;
		}
		cx += step_x;
		cy += step_y;
		if (cx < 0.0 || cx >= world_width || cy <= 0.0) {
			return 1.0;   // walked off the top/side of the world into open sky
		}
	}
	return 0.0;
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

	// A cell with a clear slant path to the sun/moon (a window/doorway/cave mouth, not
	// just a vertical shaft) keeps its ambient light: lift the depth darkening back
	// toward "surface" for those fragments. The vertical-column model above already
	// handles a straight shaft; this admits the LATERAL openings it missed.
	if (sky_admit_strength > 0.0 && extra > 0.0) {
		float admit = sky_admittance(world_pos.x / tile_size, frag_y_tiles);
		extra *= (1.0 - admit * sky_admit_strength);
	}

	COLOR.rgb *= mix(vec3(1.0), cave_tint.rgb, extra);
}

void light() {
	// Illuminate the tile's TRUE albedo (pre depth-darken), NOT the dimmed COLOR, so
	// a 2D light brightens a deep tile fully regardless of the viewer's depth — a
	// torch below the player, or an underground torch at a cave mouth, still reads.
	// LIGHT_COLOR already carries the light's texture falloff + colour; LIGHT_ENERGY
	// its energy. Matches Godot's default light() with COLOR swapped for the albedo.
	vec4 albedo = texture(TEXTURE, UV);
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * albedo.rgb, LIGHT_COLOR.a * albedo.a);
}
