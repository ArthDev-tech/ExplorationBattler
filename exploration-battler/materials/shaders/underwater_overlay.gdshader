shader_type canvas_item;
render_mode blend_mix;

uniform vec4 tint_color : source_color = vec4(0.15, 0.35, 0.55, 0.45);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.7;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center) * 2.0;
	float vignette = 1.0 - smoothstep(vignette_radius - 0.2, vignette_radius + 0.2, dist) * vignette_strength;
	vec4 color = tint_color * intensity * vignette;
	COLOR = color;
}
