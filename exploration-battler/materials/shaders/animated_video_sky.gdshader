shader_type sky;
render_mode use_debanding;

uniform sampler2D panorama_tex;
uniform float exposure : hint_range(0.0, 4.0) = 1.0;

void sky() {
	// SKY_COORDS is the equirectangular UV for the sky dome.
	// The video should be authored as an equirectangular panorama (2:1).
	vec3 col = vec3(0.0);
	vec4 sample_col = texture(panorama_tex, SKY_COORDS);
	col = sample_col.rgb * exposure;
	COLOR = col;
}
