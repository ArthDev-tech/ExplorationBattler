extends CharacterBody3D

## Basic patrol enemy that triggers battle on contact. Stub for Phase 3.

@export var patrol_speed: float = 2.0
@export var patrol_points: Array[Vector3] = []
@export var enemy_data: EnemyData = null

var _current_patrol_index: int = 0
var _patrol_direction: int = 1
var _last_position: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _stuck_threshold: float = 2.0  # Seconds before considering stuck
var _min_movement_distance: float = 0.1  # Minimum movement to not be considered stuck
var is_defeated: bool = false

@onready var _area: Area3D = $Area3D
var _raycast: RayCast3D = null

func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_last_position = global_position
	
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
	
	if enemy_data == null:
		# Use call_deferred to ensure all classes are registered
		call_deferred("_load_enemy_data")

func _load_enemy_data() -> void:
	# Wait a frame to ensure all autoloads and class registrations are complete
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for safety
	
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
