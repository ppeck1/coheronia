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

// Perception veil (Perception + Resonance arc). A width*height R8 mask, one texel
// per cell: 0 = unseen, 0.5 = remembered, 1 = currently visible. `perception_enabled`
// 0 keeps this shader byte-identical to the pre-perception build (default off), so
// existing screenshots/smoke are undisturbed until the feature is turned on. The veil
// only ever REMOVES information from occluded cells; a VISIBLE cell renders exactly as
// it did before (visibility and lighting stay separate axes — a visible cell can still
// be dark and need a torch).
// filter_NEAREST: crisp per-cell occlusion. Linear filtering bilinearly bleeds a
// visible cell's value into a diagonally-touching hidden cell's corner, which reads as
// a light leak at every 1x1 diagonal. The FOV rim is smoothed by the per-pixel radial
// edge below (not by blurring the mask), so occlusion edges can stay hard and correct.
uniform sampler2D perception_tex : filter_nearest, repeat_disable;
uniform float perception_enabled = 0.0;
uniform float world_height = 80.0;
uniform vec4 veil_unseen_color : source_color = vec4(0.02, 0.02, 0.045, 1.0);
uniform float veil_unseen_strength = 0.92;   // how far an unseen cell sinks to the veil
uniform float remembered_desat = 0.55;       // 0 keep hue .. 1 full grey silhouette
uniform float remembered_dim = 0.68;         // brightness of the remembered silhouette
// Radial sight edge, in world pixels, tracking the character's continuous position so
// the FOV rim glides smoothly as they move (instead of popping cell-by-cell). 0 radius
// disables the radial edge (occlusion feathering from the mask still applies).
uniform vec2 perception_origin = vec2(0.0);
uniform float perception_radius_px = 0.0;
uniform float perception_edge_px = 48.0;

varying vec2 world_pos;

// Sample the veil mask at this fragment's cell centre. R8: 0 unseen, 0.5 remembered,
// 1 visible (linearly blended near boundaries for a soft edge).
float perception_state() {
	float px = (floor(world_pos.x / tile_size) + 0.5) / world_width;
	float py = (floor(world_pos.y / tile_size) + 0.5) / world_height;
	return texture(perception_tex, vec2(px, py)).r;
}

// Smooth circular falloff toward the sight radius (world-space, per-pixel), so the
// left/right rim of the character's perspective fades gently instead of snapping.
float perception_radial_edge() {
	if (perception_radius_px <= 0.0) {
		return 1.0;
	}
	float d = distance(world_pos, perception_origin);
	return 1.0 - smoothstep(perception_radius_px - perception_edge_px, perception_radius_px, d);
}

// How "currently in view" a fragment is (0..1): the mask's visible weight feathered by
// occlusion, times the smooth radial rim. Used to blend the veil AND gate dynamic light.
float perception_sight() {
	return smoothstep(0.5, 0.9, perception_state()) * perception_radial_edge();
}

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

	// Perception veil, applied AFTER the depth tint. A remembered silhouette is built
	// from the raw albedo (not the depth-dimmed COLOR) so it stays legible at any
	// depth — remembered geometry must remain navigable, not sink into the cave dark.
	// Smooth weights (linear-filtered mask) feather every boundary over ~one cell.
	if (perception_enabled > 0.5) {
		float p = perception_state();
		// Remembered: quiet desaturated silhouette (depth-independent).
		vec4 alb = texture(TEXTURE, UV);
		float lum = dot(alb.rgb, vec3(0.299, 0.587, 0.114));
		vec3 remembered = mix(alb.rgb, vec3(lum), remembered_desat) * remembered_dim;
		// Never seen: sink the depth-tinted base to the atmospheric veil (near-black).
		vec3 unseen = mix(COLOR.rgb, veil_unseen_color.rgb, veil_unseen_strength);
		// 0 unseen .. 1 remembered, then blend the whole hidden look toward the live
		// visible render by how in-sight the cell is.
		float seenness = smoothstep(0.08, 0.5, p);
		vec3 hidden = mix(unseen, remembered, seenness);
		COLOR.rgb = mix(hidden, COLOR.rgb, perception_sight());
	}
}

void light() {
	// Illuminate the tile's TRUE albedo (pre depth-darken), NOT the dimmed COLOR, so
	// a 2D light brightens a deep tile fully regardless of the viewer's depth — a
	// torch below the player, or an underground torch at a cave mouth, still reads.
	// LIGHT_COLOR already carries the light's texture falloff + colour; LIGHT_ENERGY
	// its energy. Matches Godot's default light() with COLOR swapped for the albedo.
	vec4 albedo = texture(TEXTURE, UV);
	// Perception does NOT gate light per-fragment (a hard per-cell cut sliced torch
	// glows along cell edges — a "linear line" in the light and a blocky diagonal
	// leak). Instead each dynamic light is switched off at its SOURCE when its own
	// cell isn't visible (see world.gd _apply_light_visibility), so visible lights
	// render as clean, uncut glows and hidden ones simply don't shine.
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * albedo.rgb, LIGHT_COLOR.a * albedo.a);
}
