shader_type spatial;
render_mode unshaded;

// Color parameters
uniform vec4 color_low : source_color = vec4(0.5, 0.0, 0.0, 1.0); // Dark red
uniform vec4 color_high : source_color = vec4(0.0, 0.0, 1.0, 1.0); // Blue

// Y position range for gradient
uniform float y_min : hint_range(-250.0, 250.0) = 0.0;
uniform float y_max : hint_range(-250.0, 250.0) = 10.0;

// Varying to pass world position from vertex to fragment shader
varying vec3 world_position;

void vertex() {
	// Calculate world position by transforming local vertex with model matrix
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Get world Y position from varying
	float world_y = world_position.y;
	
	// Normalize Y position to 0-1 range based on y_min and y_max
	float y_range = y_max - y_min;
	float normalized_y = 0.0;
	if (y_range > 0.001) {
		normalized_y = clamp((world_y - y_min) / y_range, 0.0, 1.0);
	}
	
	// Mix between dark red (low Y) and blue (high Y)
	vec3 final_color = mix(color_low.rgb, color_high.rgb, normalized_y);
	
	// Output final color
	ALBEDO = final_color;
}
