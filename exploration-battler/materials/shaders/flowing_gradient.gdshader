shader_type spatial;
render_mode unshaded;

// Exposed parameters
uniform vec4 color1 : source_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform vec4 color2 : source_color = vec4(0.8, 0.4, 0.2, 1.0);
uniform float flow_speed : hint_range(0.1, 5.0) = 1.0;
uniform vec2 flow_direction = vec2(1.0, 0.0);

void fragment() {
	// Calculate UV offset based on time and flow direction
	vec2 flow_offset = flow_direction * TIME * flow_speed;
	
	// Create gradient using UV coordinates with flow offset
	float gradient = fract(UV.x + UV.y + flow_offset.x + flow_offset.y);
	
	// Mix between the two colors based on gradient position
	vec3 final_color = mix(color1.rgb, color2.rgb, gradient);
	
	// Output final color
	ALBEDO = final_color;
	EMISSION = final_color * 0.3; // Subtle emission
}
