shader_type canvas_item;
render_mode blend_mix;

// Exposed parameters
uniform vec2 dash_direction = vec2(0.0, -1.0);  // Screen space direction (normalized)
uniform float dash_intensity : hint_range(0.0, 1.0) = 0.0;  // 0.0 = off, 1.0 = full
uniform float line_density : hint_range(5.0, 50.0) = 20.0;  // Lines per screen
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.3);  // Line color
uniform float line_speed : hint_range(1.0, 20.0) = 5.0;  // Animation speed
uniform float line_thickness : hint_range(0.001, 0.1) = 0.02;  // Line thickness

// New enhancement parameters
uniform bool use_radial_mode = false;  // Use radial lines instead of parallel
uniform float line_taper : hint_range(0.0, 1.0) = 0.5;  // Tapering strength
uniform float noise_strength : hint_range(0.0, 1.0) = 0.3;  // Amount of noise variation
uniform float noise_scale : hint_range(1.0, 20.0) = 5.0;  // Scale of noise pattern
uniform vec4 gradient_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);  // Color at edges
uniform bool use_streak_mode = false;  // Use streaks instead of lines
uniform float center_fade_distance : hint_range(0.0, 1.0) = 0.3;  // Distance from center for radial fade
uniform float speed_multiplier : hint_range(0.0, 2.0) = 1.0;  // Multiplier for speed-based effects

// Simple procedural noise function
float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise using bilinear interpolation
float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);  // Smoothstep
	
	float a = noise(i);
	float b = noise(i + vec2(1.0, 0.0));
	float c = noise(i + vec2(0.0, 1.0));
	float d = noise(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// Calculate distance from center for radial effects
	vec2 centered_uv = UV - vec2(0.5, 0.5);
	float dist_from_center = length(centered_uv);
	float max_dist = length(vec2(0.5, 0.5));  // Maximum distance (corner)
	float normalized_dist = dist_from_center / max_dist;
	
	// Detect forward/backward motion (primarily vertical)
	// With normalized directions, this should be very reliable
	bool is_forward_backward = abs(dash_direction.x) < 0.2;
	bool use_auto_radial = is_forward_backward;
	
	// Calculate line coordinates based on mode
	float line_coord = 0.0;
	float animated_coord = 0.0;
	
	if (use_auto_radial || use_radial_mode) {
		// Radial mode: lines emanate from center
		// Use angle for line spacing
		float angle = atan(centered_uv.y, centered_uv.x);
		line_coord = angle * line_density / (2.0 * 3.14159);
		// Animate based on distance from center
		animated_coord = line_coord + dist_from_center * line_speed * TIME * speed_multiplier;
	} else {
		// Parallel mode: lines perpendicular to dash direction
		vec2 perp_dir = vec2(-dash_direction.y, dash_direction.x);
		line_coord = dot(UV, perp_dir) * line_density;
		animated_coord = line_coord + dot(UV, dash_direction) * line_speed * TIME * speed_multiplier;
	}
	
	// Add noise variation to break up uniformity
	// Disable noise for forward/backward radial mode to ensure consistent pattern
	float noise_value = 0.0;
	if (noise_strength > 0.0 && !use_auto_radial) {
		// Only apply noise for non-radial modes to keep forward/backward consistent
		noise_value = smooth_noise(UV * noise_scale + TIME * 0.5) * noise_strength;
		animated_coord += noise_value * 0.5;  // Vary line position
	}
	
	// Create repeating line pattern
	float line_pattern = fract(animated_coord);
	
	// Calculate line thickness with tapering
	float current_thickness = line_thickness;
	if (line_taper > 0.0) {
		// Taper thickness based on distance from center
		float taper_factor = 1.0 - (normalized_dist * line_taper);
		current_thickness *= max(0.1, taper_factor);  // Don't go below 10% thickness
	}
	
	// Directional thickness: varies based on motion type
	if (use_auto_radial) {
		// Forward/backward motion: thickness based on distance from center
		if (dash_direction.y < 0.0) {
			// Forward: thicker at edges
			float thickness_boost = normalized_dist;  // 1.0 at edges, 0.0 at center
			current_thickness *= (1.0 + thickness_boost * 2.0);
		} else {
			// Backward: thicker at center
			float thickness_boost = 1.0 - normalized_dist;  // 1.0 at center, 0.0 at edges
			current_thickness *= (1.0 + thickness_boost * 2.0);
		}
	} else {
		// Other directions: thicker in direction opposite to dash motion
		vec2 from_center = centered_uv;
		float from_center_len = length(from_center);
		if (from_center_len > 0.001) {
			from_center = normalize(from_center);
			
			// Direction opposite to dash (trailing direction)
			vec2 opposite_dir = -dash_direction;
			
			// Dot product: positive = in opposite direction, negative = in motion direction
			float direction_factor = dot(from_center, opposite_dir);
			
			// Map to 0.0-1.0 range and use for thickness boost
			// 1.0 when in opposite direction, 0.0 when in motion direction
			float thickness_boost = (direction_factor + 1.0) * 0.5;  // 0.0 to 1.0
			
			// Apply thickness boost: up to 3x thicker in opposite direction
			current_thickness *= (1.0 + thickness_boost * 2.0);
		}
	}
	
	// Apply noise to thickness variation
	// Disable for radial mode to ensure consistency
	if (noise_strength > 0.0 && !use_auto_radial) {
		current_thickness *= (1.0 + noise_value * 0.3);  // Vary thickness by up to 30%
	}
	
	// Create lines or streaks
	float line = 0.0;
	if (use_streak_mode) {
		// Streak mode: soft streaks following dash direction
		float streak_coord = dot(UV, dash_direction) * line_density * 2.0 + TIME * line_speed * speed_multiplier;
		float streak_pattern = fract(streak_coord);
		// Use smoothstep for softer appearance
		line = smoothstep(0.0, current_thickness * line_density, streak_pattern) * 
		       smoothstep(1.0, 1.0 - current_thickness * line_density, streak_pattern);
	} else {
		// Line mode: sharp lines
		line = step(1.0 - current_thickness * line_density, line_pattern) + 
		       step(line_pattern, current_thickness * line_density);
	}
	
	// Edge-focused falloff: strong at edges, fade toward center
	vec2 edge_dist = min(UV, vec2(1.0) - UV);
	float edge_strength = 1.0 - (min(edge_dist.x, edge_dist.y) * 2.0);  // 1.0 at edges, 0.0 at center
	edge_strength = clamp(edge_strength, 0.0, 1.0);
	
	// Center fade: fade from edges toward center (inverted from before)
	float center_fade = 1.0;
	if (center_fade_distance > 0.0) {
		// 1.0 at edges, 0.0 at center
		center_fade = smoothstep(0.0, center_fade_distance, normalized_dist);
	}
	
	// Combine falloffs: strongest at edges
	float combined_fade = edge_strength * center_fade;
	
	// Color gradient: interpolate between line_color and gradient_color
	vec4 final_color = line_color;
	if (gradient_color.a > 0.0 || length(gradient_color.rgb) > 0.0) {
		float gradient_factor = normalized_dist;
		final_color = mix(line_color, gradient_color, gradient_factor);
	}
	
	// Combine line pattern with intensity and falloffs
	float alpha = line * dash_intensity * final_color.a * combined_fade * speed_multiplier;
	
	// Output color
	COLOR = vec4(final_color.rgb, alpha);
}
