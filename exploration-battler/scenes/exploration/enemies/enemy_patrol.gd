extends CharacterBody3D

## =============================================================================
## EnemyPatrol - Patrolling Enemy Controller
## =============================================================================
## Basic patrol enemy that triggers battle on player contact.
## Handles patrol movement, player pursuit, and battle initiation.
##
## Behavior:
## - Patrol: Moves between patrol_points in ping-pong pattern
## - Pursue: Chases player when within detection_range
## - Battle: Triggers encounter when colliding with player
##
## Animation:
## - Idle bob/sway while moving
## - Fall animation when defeated
##
## Enemy Data:
## - Loads from enemy_data export or defaults to lost_wanderer.tres
## - Different scenes may have different mesh structures (handled dynamically)
##
## HARDCODED: Movement speeds, detection range, animation parameters below.
## =============================================================================

@export var patrol_speed: float = 2.0
@export var pursuit_speed: float = 3.5
@export var detection_range: float = 15.0
@export var patrol_points: Array[Vector3] = []
@export var enemy_data: EnemyData = null

# Animation parameters
@export var bob_amplitude: float = 0.05  # Vertical bob distance
@export var bob_frequency: float = 2.0  # Bob speed
@export var sway_amplitude: float = 0.03  # Horizontal sway distance (rotation)
@export var sway_frequency: float = 1.5  # Sway speed
@export var scale_variation: float = 0.05  # Scale grow/shrink amount (0.05 = 5% variation)

var _current_patrol_index: int = 0
var _patrol_direction: int = 1
var _last_position: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _stuck_threshold: float = 2.0  # Seconds before considering stuck
var _min_movement_distance: float = 0.1  # Minimum movement to not be considered stuck
var is_defeated: bool = false
var _is_pursuing: bool = false
var _patrol_start_position: Vector3 = Vector3.ZERO

@onready var _area: Area3D = $Area3D
var _mesh_instance: Node3D = null  # Found dynamically in _ready
var _raycast: RayCast3D = null
var _player: CharacterBody3D = null

# Animation state
var _animation_time: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _base_mesh_position: Vector3 = Vector3.ZERO
var _base_mesh_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_last_position = global_position
	
	# Find mesh dynamically - different enemy scenes have different structures
	_mesh_instance = get_node_or_null("MeshInstance3D")
	if not _mesh_instance:
		_mesh_instance = get_node_or_null("Area3D/EyeBallMonste")
	if not _mesh_instance:
		# Try to find any MeshInstance3D or Node3D visual child
		for child in get_children():
			if child is MeshInstance3D:
				_mesh_instance = child
				break
		# Also check under Area3D
		if not _mesh_instance and _area:
			for child in _area.get_children():
				if child is Node3D and not child is CollisionShape3D:
					_mesh_instance = child
					break
	
	# Store base mesh transform for animation
	if _mesh_instance:
		_base_scale = _mesh_instance.scale
		_base_mesh_position = _mesh_instance.position
		_base_mesh_rotation = _mesh_instance.rotation
	
	# Create raycast for obstacle detection
	if has_node("RayCast3D"):
		_raycast = $RayCast3D
	else:
		_raycast = RayCast3D.new()
		_raycast.name = "RayCast3D"
		_raycast.enabled = true
		_raycast.collision_mask = 1  # Collision layer 1 (walls/static bodies)
		_raycast.target_position = Vector3(0, 0, -2.0)  # Check 2 units ahead
		add_child(_raycast)
	
	if patrol_points.is_empty():
		# Default patrol: back and forth
		patrol_points = [global_position, global_position + Vector3(5, 0, 0)]
	
	# Validate patrol points are reasonable
	_validate_patrol_points()
	
	# Wait a frame for exported resources to load, then check
	await get_tree().process_frame
	if enemy_data == null:
		# Use call_deferred to ensure all classes are registered
		call_deferred("_load_enemy_data")
	
	# Find player reference
	_find_player()
	
	# Ensure animation pauses with world (menus/battles)
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _load_enemy_data() -> void:
	# Wait a frame to ensure all autoloads and class registrations are complete
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for safety
	
	# Check if enemy_data was already set by the scene file
	if enemy_data != null:
		return  # Scene already set it, don't override
	
	# Try loading with error handling
	var resource_path: String = "res://resources/enemies/lost_wanderer.tres"
	var loaded_data = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if not loaded_data:
		push_error("Failed to load resource: " + resource_path)
		return
	
	# Verify it's the correct type
	if loaded_data.get_script() and loaded_data.get_script().get_path().ends_with("enemy_data.gd"):
		enemy_data = loaded_data as EnemyData
	else:
		push_error("Loaded resource is not EnemyData type")

func _exit_tree() -> void:
	if _area and _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.disconnect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Don't patrol if defeated
	if is_defeated:
		return
	
	# Find player if not found yet
	if not _player:
		_find_player()
	
	# Check player distance
	var player_distance: float = 0.0
	var player_direction: Vector3 = Vector3.ZERO
	if _player:
		player_direction = (_player.global_position - global_position)
		player_distance = player_direction.length()
		player_direction = player_direction.normalized()
	
	# Determine behavior: pursue or patrol
	if _player and player_distance <= detection_range:
		# Player detected - pursue
		if not _is_pursuing:
			_is_pursuing = true
			_patrol_start_position = global_position
		
		# Move toward player
		var direction: Vector3 = player_direction
		
		# Check for obstacles ahead using raycast
		if _raycast:
			_raycast.target_position = direction * 2.0  # Check 2 units in movement direction
			_raycast.force_raycast_update()
			if _raycast.is_colliding():
				# Obstacle ahead, try to navigate around or stop
				# For now, just slow down
				direction = direction * 0.5
		
		# Set velocity
		velocity.x = direction.x * pursuit_speed
		velocity.z = direction.z * pursuit_speed
		velocity.y = 0.0  # Keep on ground level
		
		# Move
		move_and_slide()
		
		# Check for collisions after movement
		var collision_count: int = get_slide_collision_count()
		if collision_count > 0:
			# Hit a wall or obstacle, could try to navigate around
			# For now, just stop
			velocity.x = 0.0
			velocity.z = 0.0
		
		# Update stuck tracking
		var movement_distance: float = global_position.distance_to(_last_position)
		if movement_distance < _min_movement_distance:
			_stuck_timer += delta
		else:
			_stuck_timer = 0.0
			_last_position = global_position
		
		# Face player
		look_at(_player.global_position, Vector3.UP)
		
	else:
		# Player out of range or not found - patrol
		if _is_pursuing:
			_is_pursuing = false
			# Return to patrol - continue from current patrol point
		
		if patrol_points.is_empty():
			return
		
		var target: Vector3 = patrol_points[_current_patrol_index]
		var direction: Vector3 = (target - global_position).normalized()
		
		# Check if reached target
		if global_position.distance_to(target) < 0.5:
			_advance_patrol_point()
			target = patrol_points[_current_patrol_index]
			direction = (target - global_position).normalized()
		
		# Check for obstacles ahead using raycast
		if _raycast:
			_raycast.target_position = direction * 2.0  # Check 2 units in movement direction
			_raycast.force_raycast_update()
			if _raycast.is_colliding():
				# Obstacle ahead, skip to next point
				_advance_patrol_point()
				target = patrol_points[_current_patrol_index]
				direction = (target - global_position).normalized()
		
		# Set velocity
		velocity.x = direction.x * patrol_speed
		velocity.z = direction.z * patrol_speed
		velocity.y = 0.0  # Keep on ground level
		
		# Move
		move_and_slide()
		
		# Check for collisions after movement
		var collision_count: int = get_slide_collision_count()
		if collision_count > 0:
			# Hit a wall or obstacle, advance to next patrol point
			_advance_patrol_point()
			return
		
		# Check if stuck (not moving toward target)
		var movement_distance: float = global_position.distance_to(_last_position)
		if movement_distance < _min_movement_distance:
			_stuck_timer += delta
			if _stuck_timer >= _stuck_threshold:
				# Been stuck too long, skip to next point
				_advance_patrol_point()
				_stuck_timer = 0.0
		else:
			# Moving normally, reset stuck timer
			_stuck_timer = 0.0
			_last_position = global_position
		
		# Face the player if found, otherwise face movement direction
		if _player:
			var player_pos: Vector3 = _player.global_position
			# Make enemy look at player (Y-up convention)
			look_at(player_pos, Vector3.UP)
		elif direction.length() > 0.01:
			# Fallback: face movement direction if no player found
			var target_pos: Vector3 = global_position + direction
			look_at(target_pos, Vector3.UP)

func _process(delta: float) -> void:
	# Don't animate if defeated
	if is_defeated or not _mesh_instance:
		# Reset to base state if defeated
		if is_defeated and _mesh_instance:
			_mesh_instance.position = _base_mesh_position
			_mesh_instance.rotation = _base_mesh_rotation
			_mesh_instance.scale = _base_scale
		return
	
	# Update animation time
	_animation_time += delta
	
	# Check if enemy is moving (has velocity)
	var is_moving: bool = velocity.length() > 0.1
	
	if is_moving:
		# Calculate bob (vertical movement)
		var bob: float = sin(_animation_time * bob_frequency * TAU) * bob_amplitude
		
		# Calculate sway (rotation roll - left/right tilt)
		var sway: float = sin(_animation_time * sway_frequency * TAU) * sway_amplitude
		
		# Calculate scale variation (grow/shrink with slightly different frequency)
		var scale_factor: float = 1.0 + sin(_animation_time * bob_frequency * TAU * 0.7) * scale_variation
		
		# Apply to mesh
		_mesh_instance.position = _base_mesh_position + Vector3(0, bob, 0)
		_mesh_instance.rotation = _base_mesh_rotation + Vector3(0, 0, sway)
		_mesh_instance.scale = _base_scale * scale_factor
	else:
		# Not moving - reset to base state smoothly
		_mesh_instance.position = _mesh_instance.position.lerp(_base_mesh_position, delta * 5.0)
		_mesh_instance.rotation = _mesh_instance.rotation.lerp(_base_mesh_rotation, delta * 5.0)
		_mesh_instance.scale = _mesh_instance.scale.lerp(_base_scale, delta * 5.0)

func _on_body_entered(body: Node3D) -> void:
	if is_defeated:
		return  # Dead enemies don't trigger battles
	
	if body.name == "PlayerController" or body.get_script() and body.get_script().get_path().ends_with("player_controller.gd"):
		trigger_encounter()

func trigger_encounter() -> void:
	if is_defeated:
		return  # Don't start battle if already defeated
	
	if enemy_data:
		EventBus.encounter_triggered.emit(enemy_data)
		# Defer battle start to avoid physics callback issues
		call_deferred("_start_battle_deferred", enemy_data)
	else:
		push_error("trigger_encounter() - enemy_data is NULL!")

func _start_battle_deferred(data: EnemyData) -> void:
	# Pass self as triggering enemy so it can be marked defeated if player wins
	GameManager.start_battle(data, self)

func _advance_patrol_point() -> void:
	_current_patrol_index += _patrol_direction
	if _current_patrol_index >= patrol_points.size():
		_current_patrol_index = patrol_points.size() - 1
		_patrol_direction = -1
	elif _current_patrol_index < 0:
		_current_patrol_index = 0
		_patrol_direction = 1
	_stuck_timer = 0.0  # Reset stuck timer when advancing

func defeated_enemy() -> void:
	is_defeated = true
	# Stop patrol
	set_physics_process(false)
	# Trigger fall animation
	_play_fall_animation()

func _play_fall_animation() -> void:
	# Rotate enemy to fall over (rotate around X axis for forward fall)
	var tween: Tween = create_tween()
	var fall_rotation: Vector3 = rotation + Vector3(PI / 2, 0, 0)
	tween.tween_property(self, "rotation", fall_rotation, 1.0)
	tween.tween_callback(_on_fall_complete)

func _on_fall_complete() -> void:
	# Optional: Change material color or fade out
	# For now, just keep the enemy fallen
	pass

func _validate_patrol_points() -> void:
	# Ensure patrol points are at reasonable height (same as spawn)
	if not patrol_points.is_empty():
		for i in range(patrol_points.size()):
			patrol_points[i].y = global_position.y

func _find_player() -> void:
	var root: Node = get_tree().current_scene
	_player = _search_for_player(root)
	if not _player:
		# Try alternative paths
		_player = get_node_or_null("../../PlayerController")
		if not _player:
			_player = get_node_or_null("../PlayerController")

func _search_for_player(node: Node) -> CharacterBody3D:
	if node.name == "PlayerController" and node is CharacterBody3D:
		return node as CharacterBody3D
	for child in node.get_children():
		var result = _search_for_player(child)
		if result:
			return result
	return null
