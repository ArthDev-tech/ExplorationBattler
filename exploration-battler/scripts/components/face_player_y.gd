extends StaticBody3D

## =============================================================================
## FacePlayerY - Rotate to Face Player on XZ Plane (Yaw Only)
## =============================================================================
## Attach to a StaticBody3D (e.g. LampPost) so it always faces the player on
## the horizontal plane (X and Z only). Vertical offset is ignored; no pitch.
## Resolves "PlayerController" under the current scene in _ready(); skips in editor.
## =============================================================================

@export var rotation_speed: float = 10.0  ## 0 = instant snap; >0 = smooth lerp per second

var _player: Node3D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_resolve_player")

func _resolve_player() -> void:
	var scene: Node = get_tree().current_scene
	if scene:
		_player = scene.find_child("PlayerController", true, false) as Node3D

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _player:
		return
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.0001:
		return
	to_player = to_player.normalized()
	var target_y: float = atan2(to_player.x, to_player.z)
	if rotation_speed <= 0.0:
		rotation.y = target_y
	else:
		rotation.y = lerp_angle(rotation.y, target_y, clampf(delta * rotation_speed, 0.0, 1.0))
