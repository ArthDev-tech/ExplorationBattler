extends Node3D

## =============================================================================
## Ladder - Interactable Ladder with E-to-Climb Prompt
## =============================================================================
## Attach to the root Node3D of the Ladder scene. Requires an Area3D child
## (e.g. "LadderZone") with a CollisionShape3D (SphereShape3D radius 4) so
## the player is detected within 4 units. When the player enters, shows
## "Press E to climb" via EventBus; when they press E, PlayerController
## calls get_approach_position and get_climb_top_position to run the climb.
## =============================================================================

@export var approach_distance: float = 0.8
@export var ladder_height: float = 1.5

var _player: Node = null

@onready var _zone: Area3D = $LadderZone

func _ready() -> void:
	if not _zone:
		push_warning("Ladder: LadderZone Area3D child not found")
		return
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("set_near_ladder"):
		return
	if _player != null:
		return
	_player = body
	body.set_near_ladder(self)
	EventBus.interact_prompt_shown.emit("Press E to climb")

func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_player = null
	if body.has_method("set_near_ladder"):
		body.set_near_ladder(null)
	EventBus.interact_prompt_hidden.emit()

## Position in front of the ladder at the player's height for approach phase.
func get_approach_position(player_global_pos: Vector3) -> Vector3:
	var front: Vector3 = -global_transform.basis.z * approach_distance
	var approach: Vector3 = global_position + front
	approach.y = player_global_pos.y
	return approach

## Position above the ladder where the player ends the climb.
func get_climb_top_position() -> Vector3:
	return global_position + Vector3.UP * ladder_height + (-global_transform.basis.z * 0.3)
