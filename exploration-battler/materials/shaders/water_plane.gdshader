shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

// ---- Colors ----
uniform vec4 shallow_color : source_color = vec4(0.2, 0.5, 0.7, 0.85);
uniform vec4 deep_color : source_color = vec4(0.05, 0.15, 0.35, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform float shallow_depth_falloff : hint_range(0.01, 2.0) = 0.5;

// ---- Waves (primary layer) ----
uniform float wave_amplitude : hint_range(0.0, 2.0) = 0.08;
uniform float wave_frequency : hint_range(0.01, 2.0) = 0.4;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.5;
uniform vec2 wave_direction = vec2(1.0, 0.0);

// ---- Waves (secondary layer, for variation) ----
uniform float wave2_amplitude : hint_range(0.0, 2.0) = 0.04;
uniform float wave2_frequency : hint_range(0.01, 2.0) = 0.7;
uniform float wave2_speed : hint_range(0.0, 3.0) = 0.35;
uniform vec2 wave2_direction = vec2(0.7, 0.7);

// ---- Optional noise texture (UV distortion for organic waves) ----
uniform sampler2D wave_noise_texture : hint_default_white;
uniform float wave_noise_scale : hint_range(0.001, 0.5) = 0.05;
uniform float wave_noise_strength : hint_range(0.0, 1.0) = 0.3;

// ---- Fresnel (edge highlight / reflection falloff) ----
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;
uniform float fresnel_scale : hint_range(0.0, 2.0) = 1.0;
uniform float fresnel_bias : hint_range(-1.0, 1.0) = 0.1;

// ---- Foam (peaks / crests) ----
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float foam_sharpness : hint_range(1.0, 20.0) = 8.0;
uniform float foam_coverage : hint_range(0.0, 1.0) = 0.15;

// ---- Transparency & alpha ----
uniform float base_alpha : hint_range(0.0, 1.0) = 0.9;
uniform float alpha_at_grazing : hint_range(0.0, 1.0) = 0.4;

// ---- Specular / roughness (PBR) ----
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// ---- Tiling (UV scale for noise / future textures) ----
uniform float uv_scale : hint_range(0.1, 10.0) = 1.0;

varying vec3 vert_world_pos;
varying vec3 vert_world_normal;
varying float vert_wave_height;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise_2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 dir1 = normalize(wave_direction);
	vec2 dir2 = normalize(wave2_direction);

	float t = TIME;
	float wave1 = sin(world_pos.x * wave_frequency * dir1.x + world_pos.z * wave_frequency * dir1.y + t * wave_speed)
		* wave_amplitude;
	float wave2 = sin(world_pos.x * wave2_frequency * dir2.x + world_pos.z * wave2_frequency * dir2.y + t * wave2_speed * 1.3)
		* wave2_amplitude;

	float noise_val = 0.0;
	if (wave_noise_strength > 0.001) {
		vec2 noise_uv = world_pos.xz * wave_noise_scale * uv_scale;
		noise_val = texture(wave_noise_texture, noise_uv).r;
		noise_val = (noise_val - 0.5) * 2.0 * wave_noise_strength;
	}

	float height = wave1 + wave2 + noise_val;
	vert_wave_height = height;

	vec3 local_vertex = VERTEX + vec3(0.0, height, 0.0);

	float eps = 0.01;
	float hL = sin((world_pos.x - eps) * wave_frequency * dir1.x + world_pos.z * wave_frequency * dir1.y + t * wave_speed) * wave_amplitude
		+ sin((world_pos.x - eps) * wave2_frequency * dir2.x + world_pos.z * wave2_frequency * dir2.y + t * wave2_speed * 1.3) * wave2_amplitude;
	float hR = sin((world_pos.x + eps) * wave_frequency * dir1.x + world_pos.z * wave_frequency * dir1.y + t * wave_speed) * wave_amplitude
		+ sin((world_pos.x + eps) * wave2_frequency * dir2.x + world_pos.z * wave2_frequency * dir2.y + t * wave2_speed * 1.3) * wave2_amplitude;
	float hD = sin(world_pos.x * wave_frequency * dir1.x + (world_pos.z - eps) * wave_frequency * dir1.y + t * wave_speed) * wave_amplitude
		+ sin(world_pos.x * wave2_frequency * dir2.x + (world_pos.z - eps) * wave2_frequency * dir2.y + t * wave2_speed * 1.3) * wave2_amplitude;
	float hU = sin(world_pos.x * wave_frequency * dir1.x + (world_pos.z + eps) * wave_frequency * dir1.y + t * wave_speed) * wave_amplitude
		+ sin(world_pos.x * wave2_frequency * dir2.x + (world_pos.z + eps) * wave2_frequency * dir2.y + t * wave2_speed * 1.3) * wave2_amplitude;

	vec3 tangent = normalize(vec3(2.0 * eps, hR - hL, 0.0));
	vec3 bitangent = normalize(vec3(0.0, hU - hD, 2.0 * eps));
	vec3 normal_local = normalize(cross(bitangent, tangent));
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(normal_local, 0.0)).xyz);

	vert_world_pos = (MODEL_MATRIX * vec4(local_vertex, 1.0)).xyz;
	vert_world_normal = world_normal;

	VERTEX = local_vertex;
	NORMAL = (INV_VIEW_MATRIX * vec4(world_normal, 0.0)).xyz;
}

void fragment() {
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - vert_world_pos);
	float NdotV = clamp(dot(vert_world_normal, view_dir), 0.0, 1.0);

	// Fresnel: more reflection/color at grazing angles
	float fresnel = fresnel_bias + fresnel_scale * pow(1.0 - NdotV, fresnel_power);
	fresnel = clamp(fresnel, 0.0, 1.0);

	// Shallow vs deep: use view angle as proxy for "depth" (simplified)
	float depth_factor = 1.0 - pow(NdotV, 1.0 / shallow_depth_falloff);
	vec4 water_color = mix(deep_color, shallow_color, depth_factor);
	water_color = mix(water_color, vec4(shallow_color.rgb, 1.0), fresnel * 0.5);

	// Foam on wave peaks: normalize height to 0..1 relative to wave amplitude
	float wave_scale = max(wave_amplitude + wave2_amplitude, 0.01);
	float foam_level = (vert_wave_height / wave_scale + 1.0) * 0.5;
	float foam_mask = smoothstep(foam_threshold - foam_coverage, foam_threshold + foam_coverage, foam_level);
	foam_mask = pow(foam_mask, foam_sharpness);
	water_color = mix(water_color, foam_color, foam_mask);

	ALBEDO = water_color.rgb;
	ALPHA = mix(alpha_at_grazing, base_alpha, 1.0 - fresnel * 0.5);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
