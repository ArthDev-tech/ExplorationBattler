shader_type canvas_item;

// Exposed parameters
uniform float swirl_speed : hint_range(0.1, 5.0) = 1.0;
uniform float swirl_intensity : hint_range(0.1, 2.0) = 1.0;
uniform vec4 overlay_color : source_color = vec4(0.3, 0.3, 0.5, 0.7);

void fragment() {
	// Get UV coordinates centered at (0.5, 0.5)
	vec2 centered_uv = UV - vec2(0.5, 0.5);
	
	// Calculate distance from center and angle
	float dist = length(centered_uv);
	float angle = atan(centered_uv.y, centered_uv.x);
	
	// Create swirl effect by rotating based on distance and time
	float swirl_angle = angle + dist * swirl_intensity * 3.0 - TIME * swirl_speed;
	
	// Create spiral pattern using sin/cos of the swirled angle
	float spiral = sin(swirl_angle * 4.0) * 0.5 + 0.5;
	
	// Fade out at edges for smooth transition
	float edge_fade = 1.0 - smoothstep(0.3, 0.5, dist);
	
	// Combine spiral pattern with edge fade
	float alpha = spiral * edge_fade * overlay_color.a;
	
	// Output color with swirl pattern
	COLOR = vec4(overlay_color.rgb, alpha);
}
