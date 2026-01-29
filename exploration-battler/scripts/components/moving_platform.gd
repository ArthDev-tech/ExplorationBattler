@tool
extends AnimatableBody3D

## =============================================================================
## MovingPlatform - Moving Climbable Platform
## =============================================================================
## Use on AnimatableBody3D for platforms that move and are still climbable.
## PlayerController treats this as climbable (ledge grab) like Climbable.
##
## Set move_enabled = true and add waypoints via export move_points or a child
## Node3D named "MovementPath" with Marker3D children. Platform moves between
## waypoints at move_speed. Use loop_path = true to wrap last-to-first; false = ping-pong (reverse at ends).
## When move_rotations has the same size as move_points, platform interpolates
## rotation toward each waypoint (Euler degrees per waypoint).
## =============================================================================

@export var move_enabled: bool = false
@export var move_speed: float = 2.0
@export var move_points: Array[Vector3] = []
@export var move_rotations: Array[Vector3] = []  ## Euler angles in degrees (X, Y, Z) per waypoint; same length as move_points when used.
@export var loop_path: bool = false  ## If true, wrap from last to first (and first to last when going back). If false, ping-pong (reverse at ends).
@export var pause_on_reverse_seconds: float = 0.0  ## Pause at first/last waypoint before reversing. 0 = no pause.
@export var pause_at_waypoint_seconds: float = 0.0  ## Pause at every waypoint (e.g. elevator floors). 0 = no pause.
@export var slow_near_waypoint_radius: float = 0.0  ## Within this distance of target, speed scales down linearly. 0 = no slowdown.
@export_range(0.0, 1.0) var slow_min_speed_percent: float = 0.0  ## Min speed at waypoint as % of move_speed (0 = full stop, 1 = no slowdown).
@export var show_path_preview: bool = true  ## When true, draw the movement path in the editor (lines between waypoints). Hidden at runtime.
@export var animate_in_editor: bool = true  ## When false, platform does not move when running the scene in the editor. Ignored at runtime.

var _move_index: int = 0
var _move_direction: int = 1
var _pause_timer: float = 0.0
var _editor_last_move_points_size: int = -1
var _path_preview_material: StandardMaterial3D = null  ## Reused for editor path preview mesh.

func _ready() -> void:
	if not Engine.is_editor_hint():
		var preview: Node = get_node_or_null("PathPreview")
		if preview:
			preview.queue_free()
	if Engine.is_editor_hint():
		_editor_last_move_points_size = move_points.size()
	if not move_enabled:
		return
	call_deferred("_build_move_path")

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var n: int = move_points.size()
	if _editor_last_move_points_size < 0:
		_editor_last_move_points_size = n
		return
	if n > _editor_last_move_points_size:
		for i in range(_editor_last_move_points_size, n):
			move_points[i] = global_position
		while move_rotations.size() < n:
			move_rotations.append(Vector3(rad_to_deg(global_rotation.x), rad_to_deg(global_rotation.y), rad_to_deg(global_rotation.z)))
		_editor_last_move_points_size = n
	elif n < _editor_last_move_points_size:
		_editor_last_move_points_size = n
		if move_rotations.size() > n:
			move_rotations.resize(n)
	if show_path_preview and n >= 2:
		var preview: MeshInstance3D = get_node_or_null("PathPreview") as MeshInstance3D
		if not preview:
			preview = MeshInstance3D.new()
			preview.name = "PathPreview"
			add_child(preview)
		_update_path_preview_mesh(preview)
	elif not show_path_preview or n < 2:
		var preview: Node = get_node_or_null("PathPreview")
		if preview:
			preview.queue_free()

func _update_path_preview_mesh(preview: MeshInstance3D) -> void:
	if _path_preview_material == null:
		_path_preview_material = StandardMaterial3D.new()
		_path_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_path_preview_material.albedo_color = Color(1.0, 1.0, 0.0, 0.8)
	var mesh_im: ImmediateMesh = ImmediateMesh.new()
	mesh_im.surface_begin(Mesh.PRIMITIVE_LINES, _path_preview_material)
	for i in range(move_points.size() - 1):
		mesh_im.surface_add_vertex(to_local(move_points[i]))
		mesh_im.surface_add_vertex(to_local(move_points[i + 1]))
	if loop_path and move_points.size() >= 2:
		mesh_im.surface_add_vertex(to_local(move_points[move_points.size() - 1]))
		mesh_im.surface_add_vertex(to_local(move_points[0]))
	mesh_im.surface_end()
	preview.mesh = mesh_im

func _build_move_path() -> void:
	var path_node: Node3D = get_node_or_null("MovementPath") as Node3D
	if path_node:
		var points: Array[Vector3] = []
		var rots: Array[Vector3] = []
		for child in path_node.get_children():
			if child is Node3D:
				var node_3d: Node3D = child as Node3D
				points.append(node_3d.global_position)
				rots.append(Vector3(rad_to_deg(node_3d.global_rotation.x), rad_to_deg(node_3d.global_rotation.y), rad_to_deg(node_3d.global_rotation.z)))
		if points.size() >= 2:
			move_points = points
			move_rotations = rots
	if move_points.size() < 2:
		move_enabled = false

func _physics_process(delta: float) -> void:
	if not move_enabled or move_points.size() < 2:
		return
	if Engine.is_editor_hint() and not animate_in_editor:
		return
	if _pause_timer > 0.0:
		_pause_timer -= delta
		return
	var target: Vector3 = move_points[_move_index]
	var to_target: Vector3 = target - global_position
	var dist: float = to_target.length()
	var use_rotation: bool = move_rotations.size() == move_points.size()
	var target_rot_rad: Vector3 = Vector3.ZERO
	if use_rotation:
		var rot_deg: Vector3 = move_rotations[_move_index]
		target_rot_rad = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var at_end: bool = (_move_index == move_points.size() - 1 and _move_direction == 1) or (_move_index == 0 and _move_direction == -1)
	if dist < 0.1:
		if use_rotation:
			global_transform = Transform3D(Basis.from_euler(target_rot_rad), target)
		if pause_on_reverse_seconds > 0.0 and at_end:
			_pause_timer = pause_on_reverse_seconds
			return
		if pause_at_waypoint_seconds > 0.0:
			_pause_timer = pause_at_waypoint_seconds
			return
		_move_index += _move_direction
		if loop_path:
			if _move_index >= move_points.size():
				_move_index = 0
			elif _move_index < 0:
				_move_index = move_points.size() - 1
		else:
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
		if use_rotation:
			global_transform = Transform3D(Basis.from_euler(target_rot_rad), target)
		else:
			global_position = target
		if pause_on_reverse_seconds > 0.0 and at_end:
			_pause_timer = pause_on_reverse_seconds
			return
		if pause_at_waypoint_seconds > 0.0:
			_pause_timer = pause_at_waypoint_seconds
			return
		_move_index += _move_direction
		if loop_path:
			if _move_index >= move_points.size():
				_move_index = 0
			elif _move_index < 0:
				_move_index = move_points.size() - 1
		else:
			if _move_index >= move_points.size():
				_move_index = move_points.size() - 1
				_move_direction = -1
			elif _move_index < 0:
				_move_index = 0
				_move_direction = 1
	else:
		var new_pos: Vector3 = global_position + to_target.normalized() * step
		if use_rotation:
			var t: float = clampf(step / dist, 0.0, 1.0)
			var new_rot_rad: Vector3 = Vector3(
				lerp_angle(global_rotation.x, target_rot_rad.x, t),
				lerp_angle(global_rotation.y, target_rot_rad.y, t),
				lerp_angle(global_rotation.z, target_rot_rad.z, t)
			)
			global_transform = Transform3D(Basis.from_euler(new_rot_rad), new_pos)
		else:
			global_position = new_pos
