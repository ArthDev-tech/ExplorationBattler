shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// Fake glass (screen-space refraction + tint + fresnel edge highlight).

uniform vec4 tint_color : source_color = vec4(0.65, 0.85, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.18;
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.02;
uniform float fresnel_power : hint_range(0.1, 10.0) = 4.0;
uniform float fresnel_strength : hint_range(0.0, 2.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float specular : hint_range(0.0, 1.0) = 0.6;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

void fragment() {
	// Fresnel term (stronger at glancing angles).
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);
	
	// Screen-space refraction: distort screen UVs using normal XY.
	// Reduce distortion near edges so the fresnel highlight reads cleanly.
	vec2 offset = normalize(NORMAL.xy) * refraction_strength * (1.0 - fresnel);
	vec3 refracted = texture(screen_tex, SCREEN_UV + offset).rgb;
	
	// Tint the refracted background toward tint_color.
	vec3 tinted = mix(refracted, tint_color.rgb, 0.20);
	
	// Add a subtle fresnel edge highlight (also slightly colored).
	vec3 edge = tint_color.rgb * fresnel * fresnel_strength;
	
	ALBEDO = tinted + edge;
	ALPHA = opacity;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}

