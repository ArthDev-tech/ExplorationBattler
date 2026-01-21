shader_type spatial;
render_mode unshaded;

// Exposed parameters
uniform vec4 base_color : source_color = vec4(0.3, 0.3, 0.5, 1.0);
uniform vec4 noise_color : source_color = vec4(0.8, 0.6, 0.2, 1.0);
uniform float noise_scale : hint_range(0.1, 20.0) = 5.0;
uniform float animation_speed : hint_range(0.1, 5.0) = 1.0;

// Simple noise function
float random(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise using multiple octaves
float noise(vec2 st) {
	vec2 i = floor(st);
	vec2 f = fract(st);
	
	float a = random(i);
	float b = random(i + vec2(1.0, 0.0));
	float c = random(i + vec2(0.0, 1.0));
	float d = random(i + vec2(1.0, 1.0));
	
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	// Animate noise by offsetting UV with time
	vec2 animated_uv = UV * noise_scale + vec2(TIME * animation_speed, TIME * animation_speed * 0.7);
	
	// Generate noise value
	float noise_value = noise(animated_uv);
	
	// Mix base color with noise color based on noise value
	vec3 final_color = mix(base_color.rgb, noise_color.rgb, noise_value);
	
	// Output final color with emission
	ALBEDO = final_color;
	EMISSION = final_color * noise_value * 0.5;
}
