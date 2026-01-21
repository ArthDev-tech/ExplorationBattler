extends Node3D

## Plays an equirectangular HDRI video and feeds it into a sky shader.
## Intended to be instanced into exploration levels as a reusable component.

@export var enabled: bool = false
@export var video_path: String = "res://assets/Vidieo/TwilightHDRI.ogv"
@export var exposure: float = 1.0
@export var realtime_radiance: bool = true
@export var radiance_size: Sky.RadianceSize = Sky.RADIANCE_SIZE_128
@export var show_video_debug: bool = false
@export var drive_ibl: bool = true

@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _video_player: VideoStreamPlayer = $VideoStreamPlayer

var _environment: Environment = null
var _sky: Sky = null
var _sky_material: ShaderMaterial = null
var _sky_shader: Shader = null
var _last_video_texture: Texture2D = null
var _has_warned_aspect: bool = false
var _decode_watchdog_time: float = 0.0
var _has_warned_decode: bool = false
var _has_logged_stream_type: bool = false

func _ready() -> void:
	_setup_environment()
	if enabled:
		_setup_video_player()
	else:
		_disable_video_player()

func _setup_video_player() -> void:
	if not _video_player:
		push_error("AnimatedHDRISky: VideoStreamPlayer missing.")
		return
	
	# We only want the video decoded for use as a texture, not drawn fullscreen.
	# You can toggle it back on for debugging via `show_video_debug`.
	_video_player.visible = show_video_debug
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_video_player.volume_db = -80.0
	_video_player.autoplay = true
	_video_player.loop = true
	
	_decode_watchdog_time = 0.0
	_has_warned_decode = false
	_last_video_texture = null
	_has_warned_aspect = false

	var stream: VideoStream = load(video_path) as VideoStream
	if not stream:
		push_error(
			"AnimatedHDRISky: Failed to load VideoStream: %s" % video_path
			+ "\nThis usually means the .ogv isn't encoded as Theora (Godot-compatible). "
			+ "Re-encode with ffmpeg/libtheora and try again."
		)
		return
	
	if not _has_logged_stream_type:
		_has_logged_stream_type = true
		push_warning("AnimatedHDRISky: Loaded stream type: %s" % stream.get_class())

	_video_player.stream = stream
	if not _video_player.is_playing():
		_video_player.play()

func _setup_environment() -> void:
	if not _world_environment:
		push_error("AnimatedHDRISky: WorldEnvironment missing.")
		return
	
	_environment = _world_environment.environment
	if not _environment:
		_environment = Environment.new()
		_world_environment.environment = _environment
	
	_sky = Sky.new()
	_sky.radiance_size = radiance_size
	_sky.process_mode = Sky.PROCESS_MODE_REALTIME if realtime_radiance else Sky.PROCESS_MODE_QUALITY
	
	if enabled:
		_sky_shader = load("res://materials/shaders/animated_video_sky.gdshader") as Shader
		if not _sky_shader:
			push_error("AnimatedHDRISky: Failed to load sky shader.")
			return
		
		_sky_material = ShaderMaterial.new()
		_sky_material.shader = _sky_shader
		_sky_material.set_shader_parameter("exposure", exposure)
		
		_sky.sky_material = _sky_material
	else:
		# Fallback: simple procedural sky.
		var proc: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
		# Dark-ish twilight defaults.
		proc.sky_top_color = Color(0.05, 0.08, 0.15, 1.0)
		proc.sky_horizon_color = Color(0.20, 0.12, 0.10, 1.0)
		proc.ground_bottom_color = Color(0.02, 0.02, 0.03, 1.0)
		proc.ground_horizon_color = Color(0.08, 0.06, 0.06, 1.0)
		_sky.sky_material = proc
		# No need for realtime radiance if sky is static.
		_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = _sky
	if drive_ibl:
		_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_environment.ambient_light_sky_contribution = 1.0
		_environment.reflected_light_source = Environment.ReflectionSource.REFLECTION_SOURCE_SKY
	else:
		_environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
		_environment.reflected_light_source = Environment.ReflectionSource.REFLECTION_SOURCE_DISABLED
		_environment.ambient_light_sky_contribution = 0.0
	
	if enabled:
		# Try to set initial texture immediately (may be null on first frame).
		_update_sky_texture(0.0)
		set_process(true)
	else:
		set_process(false)

func _process(delta: float) -> void:
	_update_sky_texture(delta)

func _update_sky_texture(delta: float) -> void:
	if not enabled:
		return
	if not _video_player or not _sky_material:
		return
	
	var tex: Texture2D = _video_player.get_video_texture()
	if tex == null:
		# If the stream is set and playing but no texture ever appears, surface it clearly.
		if _video_player.stream and _video_player.is_playing() and not _has_warned_decode:
			_decode_watchdog_time += maxf(delta, 0.0)
			if _decode_watchdog_time >= 1.0:
				_has_warned_decode = true
				push_error(
					"AnimatedHDRISky: Video is playing but no frames decoded (video texture is null). "
					+ "This often means the codec isn't supported (use Theora .ogv), or the file is corrupted: %s"
					% video_path
				)
		return

	# Warn once if the video texture isn't 2:1 (common cause of distortion/pixelation for equirect skies).
	if not _has_warned_aspect:
		var size: Vector2i = tex.get_size()
		if size.y > 0:
			var aspect: float = float(size.x) / float(size.y)
			if absf(aspect - 2.0) > 0.05:
				push_warning(
					"AnimatedHDRISky: Video texture aspect is %.3f (expected ~2.0 for equirectangular). " % aspect
					+ "For best results, re-encode to 2:1 (e.g. 1920x960, 4096x2048)."
				)
			elif size.x < 2048:
				push_warning(
					"AnimatedHDRISky: Video texture is %dx%d. Starfields often look blocky at low resolutions/bitrates. " % [size.x, size.y]
					+ "Consider re-encoding at 4096x2048 with higher quality."
				)
		_has_warned_aspect = true
	
	# Avoid redundant sets; Viewport/video textures update internally.
	if tex == _last_video_texture:
		return
	
	_last_video_texture = tex
	_sky_material.set_shader_parameter("panorama_tex", tex)

func _disable_video_player() -> void:
	if not _video_player:
		return
	_video_player.visible = false
	_video_player.autoplay = false
	if _video_player.is_playing():
		_video_player.stop()
	_video_player.stream = null

func _exit_tree() -> void:
	set_process(false)
