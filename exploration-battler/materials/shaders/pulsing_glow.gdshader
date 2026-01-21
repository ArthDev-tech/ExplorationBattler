shader_type spatial;

// Exposed parameters
uniform vec4 base_color : source_color = vec4(0.5, 0.5, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	// Calculate pulsing effect using sine wave
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5; // Range: 0.0 to 1.0
	
	// Mix base color with glow color based on pulse
	vec3 final_color = mix(base_color.rgb, glow_color.rgb, pulse * glow_intensity);
	
	// Output final color with full alpha
	ALBEDO = final_color;
	EMISSION = final_color * pulse * glow_intensity;
}
