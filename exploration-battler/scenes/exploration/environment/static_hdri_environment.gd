extends Node3D

## Static HDRI WorldEnvironment setup for true 2:1 equirectangular panoramas.
## Uses Godot's built-in PanoramaSkyMaterial (no custom sky shader needed).

@export var hdri_path: String = "res://assets/HDRIs/8000x4000HDRI.png"
@export var exposure: float = 1.0
@export var radiance_size: Sky.RadianceSize = Sky.RADIANCE_SIZE_128

@onready var _world_environment: WorldEnvironment = $WorldEnvironment

var _environment: Environment = null
var _sky: Sky = null
var _sky_material: PanoramaSkyMaterial = null

func _ready() -> void:
	_setup_environment()

func _setup_environment() -> void:
	if not _world_environment:
		push_error("StaticHDRIEnvironment: WorldEnvironment missing.")
		return
	
	_environment = _world_environment.environment
	if not _environment:
		_environment = Environment.new()
		_world_environment.environment = _environment
	
	var tex: Texture2D = load(hdri_path) as Texture2D
	if not tex:
		push_error("StaticHDRIEnvironment: Failed to load HDRI texture: %s" % hdri_path)
		return
	
	_sky_material = PanoramaSkyMaterial.new()
	_sky_material.panorama = tex
	_sky_material.energy_multiplier = exposure
	
	_sky = Sky.new()
	_sky.sky_material = _sky_material
	_sky.radiance_size = radiance_size
	_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = _sky
	
	# Drive ambient + reflections from the sky (IBL)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_sky_contribution = 1.0
	_environment.reflected_light_source = Environment.ReflectionSource.REFLECTION_SOURCE_SKY
