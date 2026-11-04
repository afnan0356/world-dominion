shader_type canvas_item;
// Atmospheric vignette drawn over the procedural backdrop.
//
// The vignette darkens (or warms, in the light theme) the outer band of the
// screen so the content plane reads as a single composed surface instead of a
// wireframe. A very small per-pixel noise is added to the alpha to prevent
// visible banding on large gradients — a detail that keeps the backdrop looking
// authored rather than generated.

render_mode blend_mix, unshaded;

uniform vec4 edge_tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.18;
uniform float outer_radius : hint_range(0.0, 1.5) = 0.78;
uniform float dither_amount : hint_range(0.0, 0.02) = 0.004;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.1; // Slightly wider falloff: the frame should feel rectangular.
	float distance_from_centre = length(uv);
	float v = smoothstep(inner_radius, outer_radius, distance_from_centre) * strength;
	float dither = (hash(FRAGCOORD.xy) - 0.5) * dither_amount * v;
	COLOR = vec4(edge_tint.rgb, clamp(v + dither, 0.0, 1.0));
}
