shader_type sky;
render_mode use_debanding;

uniform sampler2D panorama_tex;
uniform float exposure : hint_range(0.0, 4.0) = 1.0;

// For 16:9 sources, crop vertically to emulate a 2:1 equirectangular.
// Default: crop 1080 -> 960 (trim 60px top and 60px bottom) => 60/1080 = 0.055555...
uniform float v_min : hint_range(0.0, 0.5) = 0.0555556;
uniform float v_max : hint_range(0.5, 1.0) = 0.9444444;

void sky() {
	vec2 uv = SKY_COORDS;
	uv.y = mix(v_min, v_max, uv.y);
	vec3 col = texture(panorama_tex, uv).rgb * exposure;
	COLOR = col;
}

