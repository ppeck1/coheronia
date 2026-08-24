shader_type canvas_item;
// Perception + Resonance: recolours a sprite toward a mark colour, masked to its own
// alpha (silhouette), and brightens it. Unlike `modulate` (which only MULTIPLIES and so
// can't add red to a non-red sprite), this MIXES toward the mark colour, so a resonance
// pulse can light any creature/item up in a strong, readable hue. Applied to an entity's
// CanvasItem for the pulse duration, with `strength` animated by the highlight envelope.

uniform vec4 mark_color : source_color = vec4(1.0, 0.15, 0.12, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float brighten = 1.7;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// COLOR carries the node's modulate + any per-draw tint; preserve it as the base.
	vec3 base = tex.rgb * COLOR.rgb;
	vec3 rgb = mix(base, mark_color.rgb, strength);
	rgb *= mix(1.0, brighten, strength);
	COLOR = vec4(rgb, tex.a * COLOR.a);
}
