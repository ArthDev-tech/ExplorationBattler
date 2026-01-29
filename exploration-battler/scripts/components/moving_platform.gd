extends AnimatableBody3D

## =============================================================================
## MovingPlatform - Moving Climbable Platform
## =============================================================================
## Use on AnimatableBody3D for platforms that move and are still climbable.
## PlayerController treats this as climbable (ledge grab) like Climbable.
##
## Set move_enabled = true and add waypoints via export move_points or a child
## Node3D named "MovementPath" with Marker3D children. Platform moves between
## waypoints at move_speed, ping-pong style.
## =============================================================================

@export var move_enabled: bool = false
@export var move_speed: float = 2.0
@export var move_points: Array[Vector3] = []
@export var pause_on_reverse_seconds: float = 0.0  ## Pause at first/last waypoint before reversing. 0 = no pause.
@export var pause_at_waypoint_seconds: float = 0.0  ## Pause at every waypoint (e.g. elevator floors). 0 = no pause.
@export var slow_near_waypoint_radius: float = 0.0  ## Within this distance of target, speed scales down linearly. 0 = no slowdown.
@export_range(0.0, 1.0) var slow_min_speed_percent: float = 0.0  ## Min speed at waypoint as % of move_speed (0 = full stop, 1 = no slowdown).

var _move_index: int = 0
var _move_direction: int = 1
var _pause_timer: float = 0.0

func _ready() -> void:
	if not move_enabled:
		return
	call_deferred("_build_move_path")

func _build_move_path() -> void:
	var path_node: Node3D = get_node_or_null("MovementPath") as Node3D
	if path_node:
		var points: Array[Vector3] = []
		for child in path_node.get_children():
			if child is Node3D:
				points.append((child as Node3D).global_position)
		if points.size() >= 2:
			move_points = points
	if move_points.size() < 2:
		move_enabled = false

func _physics_process(delta: float) -> void:
	if not move_enabled or move_points.size() < 2:
		return
	if _pause_timer > 0.0:
		_pause_timer -= delta
		return
	var target: Vector3 = move_points[_move_index]
	var to_target: Vector3 = target - global_position
	var dist: float = to_target.length()
	var at_end: bool = (_move_index == move_points.size() - 1 and _move_direction == 1) or (_move_index == 0 and _move_direction == -1)
	if dist < 0.1:
		if pause_on_reverse_seconds > 0.0 and at_end:
			_pause_timer = pause_on_reverse_seconds
			return
		if pause_at_waypoint_seconds > 0.0:
			_pause_timer = pause_at_waypoint_seconds
			return
		_move_index += _move_direction
		if _move_index >= move_points.size():
			_move_index = move_points.size() - 1
			_move_direction = -1
		elif _move_index < 0:
			_move_index = 0
			_move_direction = 1
		return
	var effective_speed: float = move_speed
	if slow_near_waypoint_radius > 0.0 and dist < slow_near_waypoint_radius:
		var t: float = dist / slow_near_waypoint_radius
		effective_speed = lerpf(move_speed * slow_min_speed_percent, move_speed, t)
	var step: float = effective_speed * delta
	if step >= dist:
		global_position = target
		if pause_on_reverse_seconds > 0.0 and at_end:
			_pause_timer = pause_on_reverse_seconds
			return
		if pause_at_waypoint_seconds > 0.0:
			_pause_timer = pause_at_waypoint_seconds
			return
		_move_index += _move_direction
		if _move_index >= move_points.size():
			_move_index = move_points.size() - 1
			_move_direction = -1
		elif _move_index < 0:
			_move_index = 0
			_move_direction = 1
	else:
		global_position += to_target.normalized() * step
