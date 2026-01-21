shader_type spatial;
render_mode unshaded;

// Exposed parameters
uniform vec4 pattern_color1 : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform vec4 pattern_color2 : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float pattern_size : hint_range(0.1, 10.0) = 2.0;
uniform float rotation_speed : hint_range(-5.0, 5.0) = 1.0;

void fragment() {
	// Center UV coordinates
	vec2 centered_uv = UV - vec2(0.5, 0.5);
	
	// Calculate rotation angle based on time
	float angle = TIME * rotation_speed;
	
	// Rotation matrix
	float cos_angle = cos(angle);
	float sin_angle = sin(angle);
	mat2 rotation = mat2(vec2(cos_angle, -sin_angle), vec2(sin_angle, cos_angle));
	
	// Rotate UV coordinates
	vec2 rotated_uv = rotation * centered_uv;
	
	// Create checkerboard pattern
	vec2 pattern_coord = rotated_uv * pattern_size;
	vec2 pattern_cell = floor(pattern_coord);
	float checker = mod(pattern_cell.x + pattern_cell.y, 2.0);
	
	// Mix between pattern colors
	vec3 final_color = mix(pattern_color1.rgb, pattern_color2.rgb, checker);
	
	// Output final color
	ALBEDO = final_color;
}
