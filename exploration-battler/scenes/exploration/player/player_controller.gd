extends CharacterBody3D

## First-person player controller for 3D exploration.

const ClimbableScript = preload("res://scripts/components/climbable.gd")

enum PlayerState {
	NORMAL,
	LEDGE_GRABBING,
	CLIMBING
}

@export var speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 10.0
@export var friction: float = 10.0

@export var ledge_grab_distance: float = 1.5
@export var ledge_grab_height: float = 1.2
@export var grab_hold_time: float = 0.25
@export var climb_speed: float = 3.0
@export var climb_height: float = 2.0
@export var climb_forward_offset: float = 0.5

@export var dash_speed: float = 15.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var max_jumps: int = 2

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _is_sprinting: bool = false
var _stamina: float = 100.0
var _max_stamina: float = 100.0

var _current_state: PlayerState = PlayerState.NORMAL
var _grab_timer: float = 0.0
var _climb_start_position: Vector3 = Vector3.ZERO
var _climb_target_position: Vector3 = Vector3.ZERO
var _climb_progress: float = 0.0
var _ledge_normal: Vector3 = Vector3.ZERO
var _ledge_point: Vector3 = Vector3.ZERO

var _dash_cooldown_timer: float = 0.0
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _jump_count: int = 0
var _auto_run_enabled: bool = false

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _ledge_detector: RayCast3D = $LedgeDetector
@onready var _space_check: RayCast3D = $SpaceCheck

func _init() -> void:
	# Allow input processing even when paused (for debugging and auto-run toggle)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Don't process if game is paused
	if get_tree().paused:
		return
	
	_handle_dash_cooldown(delta)
	
	match _current_state:
		PlayerState.NORMAL:
			_handle_dash(delta)
			_check_ledge_grab()
			_handle_gravity(delta)
			_handle_movement(delta)
			_handle_stamina(delta)
		PlayerState.LEDGE_GRABBING:
			_handle_ledge_grab(delta)
		PlayerState.CLIMBING:
			_handle_climbing(delta)
	
	move_and_slide()

func _handle_gravity(delta: float) -> void:
	if _current_state != PlayerState.NORMAL:
		return
	
	# Reset jump count when on floor
	if is_on_floor():
		if _jump_count > 0:
			_jump_count = 0
			EventBus.jump_count_changed.emit(_jump_count, max_jumps)
		velocity.y = -0.1  # Small downward force to keep on floor
		if Input.is_action_just_pressed("ui_accept"):
			_jump_count = 1
			velocity.y = jump_velocity
			EventBus.jump_count_changed.emit(_jump_count, max_jumps)
	else:
		velocity.y -= _gravity * delta
		# Allow double jump
		if Input.is_action_just_pressed("ui_accept") and _jump_count < max_jumps:
			_jump_count += 1
			velocity.y = jump_velocity
			EventBus.jump_count_changed.emit(_jump_count, max_jumps)

func _handle_movement(delta: float) -> void:
	# Check if W or S is pressed - if so, disable auto-run
	if _auto_run_enabled:
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
			_auto_run_enabled = false
	
	if _current_state != PlayerState.NORMAL:
		return
	
	# Skip normal movement during dash
	if _is_dashing:
		return
	
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Apply auto-run: if enabled, simulate forward input
	if _auto_run_enabled:
		# Check if backward key is actively pressed - if so, don't apply auto-run
		var backward_pressed: bool = Input.is_action_pressed("ui_down")
		if not backward_pressed:
			# Apply forward movement (y = -1 is forward)
			# If player is already moving forward (W pressed), keep that, otherwise force forward
			if input_dir.y > -0.1:  # Not already moving forward
				input_dir.y = -1.0  # Force forward movement
	
	# Input.get_vector returns: x = -1 (left) to +1 (right), y = -1 (up/W) to +1 (down/S)
	# For 3D: forward is -Z, backward is +Z
	# W (y=-1) should move forward (-Z), S (y=+1) should move backward (+Z)
	var direction: Vector3 = (_head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	_is_sprinting = Input.is_action_pressed("sprint") and _stamina > 0.0
	var current_speed: float = sprint_speed if _is_sprinting else speed
	
	if direction.length() > 0.1:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
	
	EventBus.player_moved.emit(global_position)

func _handle_stamina(delta: float) -> void:
	if _is_sprinting:
		_stamina = maxf(0.0, _stamina - 30.0 * delta)
	else:
		_stamina = minf(_max_stamina, _stamina + 20.0 * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_head.rotate_y(-event.relative.x * 0.001)
		_camera.rotate_x(-event.relative.y * 0.001)
		_camera.rotation.x = clampf(_camera.rotation.x, -PI / 2, PI / 2)
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Toggle auto-run on numpad period press
	if event.is_action_pressed("autorun"):
		_auto_run_enabled = not _auto_run_enabled

func _check_ledge_grab() -> void:
	# Only check for ledge grab when in air
	if is_on_floor():
		return
	
	if not _ledge_detector:
		return
	
	# Update raycast direction to match player's look direction
	var forward_dir: Vector3 = -_head.transform.basis.z  # Forward is -Z
	_ledge_detector.target_position = forward_dir * ledge_grab_distance
	_ledge_detector.force_raycast_update()
	
	if _ledge_detector.is_colliding():
		var collision_point: Vector3 = _ledge_detector.get_collision_point()
		var collision_normal: Vector3 = _ledge_detector.get_collision_normal()
		
		# Check if the collider is a climbable StaticBody3D
		var collider: Node = _ledge_detector.get_collider()
		if not collider or not collider is StaticBody3D:
			return
		
		var collider_script: Script = collider.get_script()
		if not collider_script or collider_script != ClimbableScript:
			return
		
		# Check if there's space above the ledge using a temporary raycast
		var space_ray: RayCast3D = _space_check if _space_check else null
		if space_ray:
			space_ray.global_position = collision_point + collision_normal * 0.1
			space_ray.target_position = Vector3.UP * climb_height
			space_ray.force_raycast_update()
			
			# If space check hits something, there's no room to climb
			if space_ray.is_colliding():
				return
		else:
			# Fallback: use a simple height check
			var space_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				collision_point + collision_normal * 0.1,
				collision_point + Vector3.UP * climb_height
			)
			space_query.collision_mask = 1
			var space_result: Dictionary = get_world_3d().direct_space_state.intersect_ray(space_query)
			if space_result:
				return
		
		# Check if player is at appropriate height (not too high or low)
		var height_diff: float = collision_point.y - global_position.y
		if height_diff > 0.5 and height_diff < 2.5:
			# Start ledge grab
			_start_ledge_grab(collision_point, collision_normal)

func _start_ledge_grab(ledge_point: Vector3, ledge_normal: Vector3) -> void:
	_current_state = PlayerState.LEDGE_GRABBING
	_grab_timer = 0.0
	_ledge_point = ledge_point
	_ledge_normal = ledge_normal
	
	# Stop vertical velocity
	velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	
	# Position player at ledge grab point
	var grab_position: Vector3 = ledge_point - ledge_normal * 0.3
	grab_position.y = global_position.y  # Keep current Y, adjust X/Z
	global_position = grab_position

func _handle_ledge_grab(delta: float) -> void:
	_grab_timer += delta
	
	# Hold position at ledge
	var target_position: Vector3 = _ledge_point - _ledge_normal * 0.3
	target_position.y = global_position.y
	global_position = global_position.lerp(target_position, 10.0 * delta)
	
	# After hold time, start climbing
	if _grab_timer >= grab_hold_time:
		_start_climbing()

func _start_climbing() -> void:
	_current_state = PlayerState.CLIMBING
	_climb_progress = 0.0
	_climb_start_position = global_position
	
	# Calculate target position: top of ledge + forward offset
	var forward_dir: Vector3 = -_head.transform.basis.z
	# Position player on top of the ledge surface, slightly forward
	_climb_target_position = _ledge_point + Vector3.UP * 1.0 + forward_dir * climb_forward_offset
	# Ensure player's feet are on the ledge surface (account for capsule height)
	_climb_target_position.y = _ledge_point.y + 1.0

func _handle_climbing(delta: float) -> void:
	_climb_progress += climb_speed * delta
	
	# Interpolate position
	global_position = _climb_start_position.lerp(_climb_target_position, _climb_progress)
	
	# Check if reached target
	if _climb_progress >= 1.0:
		global_position = _climb_target_position
		_finish_climbing()

func _finish_climbing() -> void:
	_current_state = PlayerState.NORMAL
	velocity = Vector3.ZERO
	_climb_progress = 0.0

func _handle_dash_cooldown(delta: float) -> void:
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
		if _dash_cooldown_timer < 0.0:
			_dash_cooldown_timer = 0.0
		EventBus.dash_cooldown_changed.emit(_dash_cooldown_timer, dash_cooldown)

func _handle_dash(delta: float) -> void:
	# Check if dash is being triggered
	var dash_input: bool = Input.is_action_just_pressed("dash")
	var move_input: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Start dash if available
	if dash_input and _dash_cooldown_timer <= 0.0 and not _is_dashing:
		_start_dash(move_input)
	
	# Handle active dash
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()
		else:
			# Apply dash velocity
			velocity.x = _dash_direction.x * dash_speed
			velocity.z = _dash_direction.z * dash_speed

func _start_dash(move_input: Vector2) -> void:
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	
	# Determine dash direction
	if move_input.length() > 0.1:
		# Dash in movement direction
		_dash_direction = (_head.transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	else:
		# Dash forward (camera direction)
		_dash_direction = -_head.transform.basis.z
	
	EventBus.dash_cooldown_changed.emit(_dash_cooldown_timer, dash_cooldown)

func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0

# Public getters for dash state (used by motion lines overlay)
func is_dashing() -> bool:
	return _is_dashing

func get_dash_direction() -> Vector3:
	return _dash_direction

func get_dash_timer() -> float:
	return _dash_timer
