extends Node3D

## =============================================================================
## LanternSway - Procedural Lantern Animation Component
## =============================================================================
## Simple procedural lantern motion (bob + sway) driven by player movement and turning.
## Intended to be attached to the root of `Lanturn.tscn` (instanced under the player's Head).
##
## Motion Types:
## - Vertical bob: Sinusoidal bounce scaled by movement speed
## - Move sway: Roll/pitch based on strafe/forward movement
## - Turn sway: Roll/pitch based on mouse look rotation
##
## Collision Detection:
## - Raycasts from head to target position
## - Pulls lantern back if it would clip into geometry
## - Adjustable padding to prevent z-fighting
##
## HARDCODED: Animation parameters exported below - adjust for different feel.
## =============================================================================

@export var max_speed_for_full_effect: float = 8.0

@export var bob_amplitude: float = 0.02
@export var bob_frequency: float = 2.2

@export var move_sway_roll_deg: float = 6.0
@export var move_sway_pitch_deg: float = 3.0

@export var turn_sway_roll_deg: float = 10.0
@export var turn_sway_pitch_deg: float = 6.0

@export var pos_smooth: float = 10.0
@export var rot_smooth: float = 12.0

@export var collision_enabled: bool = true
@export var collision_mask: int = 1
@export var collision_padding: float = 0.08

var _player: CharacterBody3D = null
var _head: Node3D = null

var _base_pos: Vector3 = Vector3.ZERO
var _base_rot: Vector3 = Vector3.ZERO

var _time: float = 0.0
var _last_head_yaw: float = 0.0
var _last_head_pitch: float = 0.0

func _ready() -> void:
	# This animation should pause with the world (menus/battles set get_tree().paused = true).
	# PlayerController uses PROCESS_MODE_ALWAYS, so we must explicitly opt this node into pausing.
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_base_pos = position
	_base_rot = rotation
	
	_head = get_parent() as Node3D
	if _head:
		_last_head_yaw = _head.rotation.y
		_last_head_pitch = _head.rotation.x
	
	_player = _find_parent_character_body()

func _find_parent_character_body() -> CharacterBody3D:
	var node: Node = self
	while node:
		if node is CharacterBody3D:
			return node as CharacterBody3D
		node = node.get_parent()
	return null

func _process(delta: float) -> void:
	if not _player or not _head:
		return
	
	_time += delta
	
	var max_speed: float = maxf(0.01, max_speed_for_full_effect)
	var vel: Vector3 = _player.velocity
	var horiz: Vector3 = Vector3(vel.x, 0.0, vel.z)
	var speed: float = horiz.length()
	var speed_factor: float = clampf(speed / max_speed, 0.0, 1.0)
	
	# Convert horizontal velocity into head-local space for forward/strafe sway.
	var local_horiz: Vector3 = _head.global_transform.basis.inverse() * horiz
	var strafe_factor: float = clampf(local_horiz.x / max_speed, -1.0, 1.0)
	# Note: in this project forward movement tends to be negative Z.
	var forward_factor: float = clampf(-local_horiz.z / max_speed, -1.0, 1.0)
	
	# Turning inertia from head rotation deltas.
	var yaw: float = _head.rotation.y
	var pitch: float = _head.rotation.x
	var yaw_delta: float = wrapf(yaw - _last_head_yaw, -PI, PI)
	var pitch_delta: float = wrapf(pitch - _last_head_pitch, -PI, PI)
	_last_head_yaw = yaw
	_last_head_pitch = pitch
	
	# Bobbing (scaled by movement speed).
	var bob: float = sin(_time * bob_frequency * TAU) * bob_amplitude * speed_factor
	
	# Position offset: a small vertical bob + slight drift based on strafe/forward.
	var pos_offset: Vector3 = Vector3.ZERO
	pos_offset.y = bob
	pos_offset.x = -strafe_factor * 0.01 * speed_factor
	pos_offset.z = -forward_factor * 0.008 * speed_factor
	
	# Rotation offsets (radians).
	var move_roll: float = deg_to_rad(move_sway_roll_deg) * (-strafe_factor) * speed_factor
	var move_pitch: float = deg_to_rad(move_sway_pitch_deg) * (forward_factor) * speed_factor
	
	# Turn sway uses angular delta directly; clamp deltas to avoid extreme swings.
	var clamped_yaw_delta: float = clampf(yaw_delta, -0.25, 0.25)
	var clamped_pitch_delta: float = clampf(pitch_delta, -0.25, 0.25)
	var turn_roll: float = deg_to_rad(turn_sway_roll_deg) * (-clamped_yaw_delta)
	var turn_pitch: float = deg_to_rad(turn_sway_pitch_deg) * (clamped_pitch_delta)
	
	var target_pos: Vector3 = _base_pos + pos_offset
	var target_rot: Vector3 = _base_rot + Vector3(turn_pitch + move_pitch, 0.0, turn_roll + move_roll)
	
	# Collision pullback: if the target position would be inside geometry, pull it toward the head.
	if collision_enabled:
		var world: World3D = get_world_3d()
		if world:
			var head_origin: Vector3 = _head.global_position
			var target_world: Vector3 = _head.to_global(target_pos)
			var to_target: Vector3 = target_world - head_origin
			var dist: float = to_target.length()
			if dist > 0.001:
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(head_origin, target_world)
				query.collision_mask = collision_mask
				query.exclude = [_player]
				var hit: Dictionary = world.direct_space_state.intersect_ray(query)
				if not hit.is_empty():
					var hit_pos: Vector3 = hit.get("position", target_world)
					var hit_dist: float = (hit_pos - head_origin).length()
					var allowed: float = maxf(0.0, hit_dist - collision_padding)
					var dir: Vector3 = to_target / dist
					var clamped_world: Vector3 = head_origin + dir * allowed
					target_pos = _head.to_local(clamped_world)
	
	var pos_t: float = clampf(pos_smooth * delta, 0.0, 1.0)
	var rot_t: float = clampf(rot_smooth * delta, 0.0, 1.0)
	
	position = position.lerp(target_pos, pos_t)
	rotation = Vector3(
		lerp_angle(rotation.x, target_rot.x, rot_t),
		lerp_angle(rotation.y, target_rot.y, rot_t),
		lerp_angle(rotation.z, target_rot.z, rot_t)
	)
