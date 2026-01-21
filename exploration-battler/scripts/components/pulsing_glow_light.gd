extends MeshInstance3D

## Automatically creates and syncs a Light3D node with the pulsing glow shader.
## Attach this script to a MeshInstance3D that uses the pulsing_glow_material.
## The light will pulse in sync with the shader's visual glow.

@export var light_range: float = 5.0
@export var light_intensity: float = 1.0
@export var light_color_override: Color = Color(0, 0, 0, 0)  # Alpha 0 = use shader color
@export var auto_create_light: bool = true

var _light: OmniLight3D = null
var _shader_material: ShaderMaterial = null

func _ready() -> void:
	# Get the shader material from this mesh instance
	_shader_material = get_surface_override_material(0) as ShaderMaterial
	if not _shader_material:
		push_warning("PulsingGlowLight: No ShaderMaterial found on MeshInstance3D. Make sure pulsing_glow_material is applied.")
		return
	
	# Find or create light node
	if auto_create_light:
		_setup_light()

func _setup_light() -> void:
	# Check if light already exists
	_light = get_node_or_null("PulsingGlowLight") as OmniLight3D
	
	if not _light:
		# Create new OmniLight3D
		_light = OmniLight3D.new()
		_light.name = "PulsingGlowLight"
		add_child(_light)
	
	# Set initial light properties
	_light.omni_range = light_range
	_light.shadow_enabled = true

func _process(_delta: float) -> void:
	if not _light or not _shader_material:
		return
	
	# Get shader parameters
	var pulse_speed: float = _shader_material.get_shader_parameter("pulse_speed")
	if pulse_speed == 0.0:
		pulse_speed = 1.0  # Default if not set
	
	var glow_color: Color = _shader_material.get_shader_parameter("glow_color")
	if glow_color == Color(0, 0, 0, 0):
		glow_color = Color(0.0, 0.8, 1.0, 1.0)  # Default glow color
	
	# Calculate pulse value using same formula as shader
	# TIME in shaders is seconds since engine start
	var time_seconds: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = sin(time_seconds * pulse_speed) * 0.5 + 0.5
	
	# Sync light energy with pulse
	_light.light_energy = pulse * light_intensity
	
	# Sync light color (use override if set, otherwise use shader's glow_color)
	if light_color_override.a > 0.0:
		_light.light_color = light_color_override
	else:
		_light.light_color = glow_color
	
	# Update light range if changed in inspector
	_light.omni_range = light_range
