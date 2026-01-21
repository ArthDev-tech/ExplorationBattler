extends CanvasLayer

## Screen-space motion lines overlay that appears during dash.
## Lines are oriented based on dash direction to create visceral speed effect.

@onready var _overlay: ColorRect = $MotionLinesOverlay
var _player_controller: CharacterBody3D = null
var _material: ShaderMaterial = null
var _fade_speed: float = 8.0  # Speed of fade in/out

func _ready() -> void:
	# Ensure this processes even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Get material from overlay
	if _overlay and _overlay.material:
		_material = _overlay.material as ShaderMaterial
	else:
		push_error("DashMotionLines: Could not find material on overlay")
	
	# Find player controller
	_find_player_controller()

func _find_player_controller() -> void:
	# Search for player controller in scene tree
	var root: Node = get_tree().root
	_player_controller = _search_for_player(root)
	
	if not _player_controller:
		# Try again after a frame delay
		await get_tree().process_frame
		_player_controller = _search_for_player(root)
	
	if not _player_controller:
		push_warning("DashMotionLines: Could not find PlayerController")

func _search_for_player(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		var script_path: String = node.get_script().get_path() if node.get_script() else ""
		if script_path.ends_with("player_controller.gd"):
			return node as CharacterBody3D
	
	for child in node.get_children():
		var result = _search_for_player(child)
		if result:
			return result
	
	return null

func _process(delta: float) -> void:
	if not _material or not _player_controller:
		return
	
	# Check if player is dashing using public getter methods
	var is_dashing: bool = _player_controller.is_dashing()
	var dash_direction: Vector3 = _player_controller.get_dash_direction()
	
	if not is_dashing or dash_direction.length() < 0.1:
		# Not dashing - fade out
		_update_intensity(0.0, delta)
		return
	
	# Convert 3D dash direction to 2D screen space
	var screen_dir: Vector2 = _project_dash_to_screen(dash_direction)
	
	# Update shader parameters
	_material.set_shader_parameter("dash_direction", screen_dir)
	
	# Calculate actual dash speed for speed-based effects
	var dash_velocity: Vector3 = _player_controller.velocity
	var dash_speed: float = Vector3(dash_velocity.x, 0.0, dash_velocity.z).length()
	var max_dash_speed: float = _player_controller.dash_speed
	var speed_multiplier: float = 1.0
	if max_dash_speed > 0.0:
		# Normalize speed (0.0 to 1.0+) and use as multiplier
		speed_multiplier = clampf(dash_speed / max_dash_speed, 0.5, 1.5)
	
	# Pass speed multiplier to shader
	if _material:
		_material.set_shader_parameter("speed_multiplier", speed_multiplier)
	
	# Calculate intensity based on dash timer (stronger at start, fade during dash)
	var dash_timer: float = _player_controller.get_dash_timer()
	var dash_duration: float = _player_controller.dash_duration
	var intensity: float = 1.0
	if dash_duration > 0.0:
		# Fade out slightly during dash, but scale with speed
		intensity = lerpf(1.0, 0.7, 1.0 - (dash_timer / dash_duration))
		intensity *= speed_multiplier  # Scale intensity with speed
	
	_update_intensity(intensity, delta)

func _project_dash_to_screen(dash_dir: Vector3) -> Vector2:
	# Get camera from player controller
	var camera: Camera3D = null
	if _player_controller.has_node("Head/Camera3D"):
		camera = _player_controller.get_node("Head/Camera3D") as Camera3D
	
	if not camera:
		# Fallback: use forward direction
		return Vector2(0.0, -1.0)
	
	# Get camera's basis vectors
	var camera_basis: Basis = camera.global_transform.basis
	
	# Project dash direction onto camera's right and up vectors
	# Right = X axis, Up = Y axis (screen space)
	var screen_x: float = dash_dir.dot(camera_basis.x)  # Right
	var screen_y: float = -dash_dir.dot(camera_basis.y)  # Up (negated for screen coords)
	
	# Normalize to get direction
	var screen_dir: Vector2 = Vector2(screen_x, screen_y)
	if screen_dir.length() > 0.1:
		screen_dir = screen_dir.normalized()
		
		# Snap forward/backward to exact vertical directions for consistency
		if abs(screen_dir.x) < 0.2:  # Primarily vertical
			if screen_dir.y < 0.0:
				screen_dir = Vector2(0.0, -1.0)  # Exact forward
			else:
				screen_dir = Vector2(0.0, 1.0)   # Exact backward
	else:
		# Default to forward if direction is too small
		screen_dir = Vector2(0.0, -1.0)
	
	return screen_dir

func _update_intensity(target_intensity: float, delta: float) -> void:
	if not _material or not _overlay:
		return
	
	# Get current intensity
	var current_intensity: float = _material.get_shader_parameter("dash_intensity") as float
	
	# Smoothly interpolate to target intensity
	var new_intensity: float = move_toward(current_intensity, target_intensity, _fade_speed * delta)
	_material.set_shader_parameter("dash_intensity", new_intensity)
	
	# Update overlay visibility (fade out completely when intensity is 0)
	if new_intensity <= 0.01:
		_overlay.modulate.a = 0.0
	else:
		_overlay.modulate.a = 1.0
