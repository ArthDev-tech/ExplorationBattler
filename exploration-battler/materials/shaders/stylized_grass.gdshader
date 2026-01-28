shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, shadows_disabled;

// ---- Texture uniforms (modular: swap these for different grass images) ----
uniform sampler2D albedo_texture;
uniform sampler2D wind_noise_texture;
uniform sampler2D color_patch_noise_texture;
uniform sampler2D accent_texture;

// ---- Wind ----
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.3;
uniform float wind_noise_scale : hint_range(0.001, 1.0) = 0.02;
uniform float wind_divergence_angle : hint_range(0.0, 1.0) = 0.2;
uniform float wind_divergence_scale : hint_range(0.1, 3.0) = 1.5;
uniform float wind_brightness_offset : hint_range(-1.0, 1.0) = 0.1;

// ---- Stepped framerate ----
uniform float wind_frame_time : hint_range(0.01, 0.5) = 0.08333; // ~1/12
uniform float wind_phase_scale : hint_range(0.0, 1.0) = 0.5;

// ---- Fake perspective ----
uniform float perspective_scale : hint_range(0.0, 2.0) = 0.5;
uniform float perspective_wind_alignment : hint_range(0.0, 1.0) = 1.0;

// ---- Color patches ----
uniform float color_patch_threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec4 grass_color_1 : source_color = vec4(0.2, 0.5, 0.15, 1.0);
uniform vec4 grass_color_2 : source_color = vec4(0.25, 0.45, 0.2, 1.0);
uniform float color_patch_noise_scale : hint_range(0.001, 0.5) = 0.02;

// ---- Accent grass ----
uniform float accent_threshold : hint_range(0.0, 1.0) = 0.08;
uniform vec4 accent_color : source_color = vec4(0.9, 0.85, 0.4, 1.0);
uniform float accent_height_scale : hint_range(0.5, 2.0) = 1.2;
uniform float accent_size_scale : hint_range(0.5, 2.0) = 1.1;

// ---- Character displacement (vec4: xyz = world pos, w = radius) ----
const int MAX_CHARACTERS = 64;
uniform vec4 character_positions[MAX_CHARACTERS];
uniform float displacement_strength : hint_range(0.0, 2.0) = 0.5;
uniform float displacement_radius_falloff_exponent : hint_range(0.5, 5.0) = 2.0;

// ---- Hybrid toon ----
uniform int toon_bands : hint_range(1, 8) = 3;
uniform float toon_gradient_size : hint_range(0.0, 1.0) = 0.15;
uniform bool use_hybrid_toon = false;

// ---- Base ----
uniform float alpha_cutout : hint_range(0.0, 1.0) = 0.5;

// ---- Varyings ----
varying vec2 vert_uv;
varying float vert_wind_noise;
varying float vert_displacement_perspective;
varying flat float vert_is_accent;
varying vec3 vert_world_pos;

// Hash for instance-based randomness (from instance ID and world pos)
float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float hash_from_id(int id) {
	return fract(sin(float(id) * 78.233) * 43758.5453);
}

vec3 rotate_around_axis(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void vertex() {
	vec3 world_center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 camera_pos = CAMERA_POSITION_WORLD;
	vec3 view_dir = normalize(camera_pos - world_center);

	// Accent: per-instance seed from INSTANCE_ID
	float seed = hash_from_id(INSTANCE_ID);
	vert_is_accent = (seed < accent_threshold) ? 1.0 : 0.0;

	vec3 local_vertex = VERTEX;
	if (vert_is_accent > 0.5) {
		local_vertex.y *= accent_height_scale;
		local_vertex.xz *= accent_size_scale;
	}

	// Stepped time + per-instance phase
	vec3 seed_pos = world_center + vec3(float(INSTANCE_ID) * wind_phase_scale, 0.0, 0.0);
	float phase = fract(hash(seed_pos)) * wind_frame_time;
	float stepped_time = floor(TIME / wind_frame_time) * wind_frame_time + phase;

	// Wind: two noise directions with divergence (irrational factor to avoid repetition)
	vec2 dir_n = normalize(wind_direction);
	float cosa = cos(wind_divergence_angle * PI);
	float sina = sin(wind_divergence_angle * PI);
	vec2 dir_a = vec2(dir_n.x * cosa - dir_n.y * sina, dir_n.x * sina + dir_n.y * cosa);
	vec2 dir_b = vec2(dir_n.x * cosa + dir_n.y * sina, -dir_n.x * sina + dir_n.y * cosa);

	vec2 uv_a = world_center.xz * wind_noise_scale + dir_a * wind_speed * stepped_time;
	vec2 uv_b = world_center.xz * wind_noise_scale * wind_divergence_scale + dir_b * wind_speed * stepped_time * PI * 0.318;

	float n_a = texture(wind_noise_texture, uv_a).r;
	float n_b = texture(wind_noise_texture, uv_b).r;
	float wind_noise = clamp(n_a * n_b + wind_brightness_offset, 0.0, 1.0);

	vert_wind_noise = wind_noise;

	// Wind rotation in world space around axis perpendicular to wind
	vec3 wind_axis = vec3(-wind_direction.y, 0.0, wind_direction.x);
	wind_axis = normalize(wind_axis);
	float wind_angle = (wind_noise - 0.5) * 2.0 * wind_strength * PI * 0.5;

	vec3 world_v = (MODEL_MATRIX * vec4(local_vertex, 1.0)).xyz;
	vec3 world_after_wind = world_center + rotate_around_axis(world_v - world_center, wind_axis, wind_angle);

	// Character displacement: view-space X and Z rotation from each character
	float disp_x = 0.0;
	float disp_z = 0.0;
	vec3 view_forward = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	vec3 view_right = normalize((INV_VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);

	for (int i = 0; i < MAX_CHARACTERS; i++) {
		vec4 ch = character_positions[i];
		float r = ch.w;
		if (r <= 0.0) { continue; }
		vec3 ch_pos = ch.xyz;
		float dist = distance(world_center, ch_pos);
		float mask = 1.0 - clamp(dist / r, 0.0, 1.0);
		mask = pow(mask, displacement_radius_falloff_exponent);

		vec3 to_grass = normalize(world_center - ch_pos);
		float dot_forward = dot(to_grass, view_forward);
		float dot_right = dot(to_grass, view_right);
		disp_x += dot_forward * mask * displacement_strength;
		disp_z += dot_right * mask * displacement_strength;
	}
	disp_x = clamp(disp_x, -1.0, 1.0);
	disp_z = clamp(disp_z, -1.0, 1.0);
	vert_displacement_perspective = disp_z;

	// Apply character displacement in view space (rotate around blade base, not camera)
	vec3 view_center = (VIEW_MATRIX * vec4(world_center, 1.0)).xyz;
	vec3 view_pos = (VIEW_MATRIX * vec4(world_after_wind, 1.0)).xyz;
	vec3 view_offset = view_pos - view_center;
	view_offset = rotate_around_axis(view_offset, vec3(1.0, 0.0, 0.0), disp_x * 0.3);
	view_offset = rotate_around_axis(view_offset, vec3(0.0, 0.0, 1.0), disp_z * 0.3);
	view_pos = view_center + view_offset;
	world_after_wind = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;

	// Y-axis billboard: rotate blade only around world Y to face camera in XZ (avoids flip at grazing angles)
	vec3 view_xz = vec3(camera_pos.x - world_center.x, 0.0, camera_pos.z - world_center.z);
	float view_xz_len = length(view_xz);
	vec3 world_final = world_after_wind;
	if (view_xz_len > 0.0001) {
		view_xz /= view_xz_len;
		vec3 current_normal = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
		vec3 blade_forward_xz = vec3(current_normal.x, 0.0, current_normal.z);
		float blade_xz_len = length(blade_forward_xz);
		float yaw = 0.0;
		if (blade_xz_len > 0.0001) {
			blade_forward_xz /= blade_xz_len;
			yaw = atan(view_xz.x, view_xz.z) - atan(blade_forward_xz.x, blade_forward_xz.z);
		}
		world_final = world_center + rotate_around_axis(world_after_wind - world_center, vec3(0.0, 1.0, 0.0), yaw);
	}

	vert_world_pos = world_final;
	vert_uv = UV;

	vec4 clip_pos = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_final, 1.0);
	POSITION = clip_pos;
	NORMAL = (VIEW_MATRIX * vec4(view_dir, 0.0)).xyz;
	UV = vert_uv;
}

void fragment() {
	// Fake perspective: scale UV.x around 0.5, stronger toward top (UV.y)
	vec2 uv = vert_uv;
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - vert_world_pos);
	vec2 wind_dir_n = normalize(wind_direction);
	float alignment = max(0.0, dot(view_dir.xz, wind_dir_n)) * perspective_wind_alignment;
	float scale = 1.0 + (1.0 - uv.y) * vert_wind_noise * perspective_scale * alignment;
	uv.x = (uv.x - 0.5) * scale + 0.5;
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// Sample albedo (accent uses accent texture, else main albedo)
	vec4 tex_color;
	if (vert_is_accent > 0.5) {
		tex_color = texture(accent_texture, uv);
		tex_color.rgb = mix(tex_color.rgb, accent_color.rgb, 0.6);
	} else {
		tex_color = texture(albedo_texture, uv);
	}

	// Color patches from world-space noise
	vec2 patch_uv = vert_world_pos.xz * color_patch_noise_scale;
	float patch_noise = texture(color_patch_noise_texture, patch_uv).r;
	vec3 patch_color = mix(grass_color_1.rgb, grass_color_2.rgb, step(color_patch_threshold, patch_noise));
	tex_color.rgb *= patch_color;

	// Alpha cutout (values below threshold are discarded by the engine)
	ALPHA_SCISSOR_THRESHOLD = alpha_cutout;
	ALPHA = tex_color.a;

	// Hybrid toon: smooth steps between lighting bands (fake NdotL when unshaded)
	vec3 albedo_out = tex_color.rgb;
	if (use_hybrid_toon && toon_bands > 1) {
		float ndotl = clamp(dot(NORMAL, normalize(vec3(0.5, 1.0, 0.3))), 0.0, 1.0);
		float band_width = 1.0 / float(toon_bands);
		float rounded = floor(ndotl * float(toon_bands) + 0.5) * band_width;
		float grad_half = toon_gradient_size * band_width * 0.5;
		float dist = abs(ndotl - rounded);
		float t = smoothstep(grad_half, 0.0, dist);
		float lower = max(0.0, rounded - band_width * 0.5);
		float upper = min(1.0, rounded + band_width * 0.5);
		float lit = mix(rounded, mix(lower, upper, t), t);
		albedo_out *= (0.4 + 0.6 * lit);
	}

	ALBEDO = albedo_out;
}
