shader_type spatial;

// Exposed parameters
uniform vec3 reference_position = vec3(0.0, 0.0, 0.0);
uniform vec4 near_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Red = close
uniform vec4 far_color : source_color = vec4(0.0, 0.0, 1.0, 1.0); // Blue = far
uniform float max_distance : hint_range(1.0, 100.0) = 10.0;
uniform float band_width : hint_range(0.0, 5.0) = 1.0;
uniform float band_sharpness : hint_range(0.1, 10.0) = 2.0;

void fragment() {
	// Calculate distance from reference position
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = distance(world_pos, reference_position);
	
	// Normalize distance (0.0 to 1.0)
	float normalized_dist = clamp(dist / max_distance, 0.0, 1.0);
	
	// Apply banding if enabled
	float band_factor = 1.0;
	if (band_width > 0.0) {
		float band = mod(dist, band_width * 2.0) / band_width;
		band = abs(band - 1.0);
		band_factor = pow(band, band_sharpness);
	}
	
	// Mix colors based on distance
	vec3 color = mix(near_color.rgb, far_color.rgb, normalized_dist);
	
	// Apply banding effect
	color = mix(color, color * 0.5, band_factor * 0.3);
	
	ALBEDO = color;
	EMISSION = color * 0.2; // Subtle emission for visibility
}
