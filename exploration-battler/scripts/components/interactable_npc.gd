extends Node3D

## =============================================================================
## InteractableNPC - Reusable E-key dialogue NPC
## =============================================================================
## Attach to the root of an NPC scene. Requires an Area3D child (e.g. TalkZone)
## with a CollisionShape3D so the player is detected in range. When the player
## enters, shows "Press E to talk" and sets itself as the current interactable;
## when E is pressed, emits dialogue_requested with the assigned dialogue_tree
## and pauses the game. Implements get_interact_prompt and on_interact for the
## generic interactable contract.
## =============================================================================

@export var dialogue_tree: Resource = null
@export var shop_inventory: Resource = null
@export var interact_prompt_text: String = "Press E to talk"

var _player: Node = null

@onready var _zone: Area3D = $TalkZone


func _ready() -> void:
	if not _zone:
		push_warning("InteractableNPC: TalkZone Area3D child not found")
		return
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("set_near_interactable"):
		return
	if _player != null:
		return
	_player = body
	body.set_near_interactable(self)
	EventBus.interact_prompt_shown.emit(interact_prompt_text)


func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_player = null
	if body.has_method("set_near_interactable"):
		body.set_near_interactable(null)
	EventBus.interact_prompt_hidden.emit()


func get_interact_prompt() -> String:
	return interact_prompt_text


func on_interact(_player_node: Node) -> void:
	if dialogue_tree:
		GameManager.current_shop_inventory = shop_inventory
		EventBus.dialogue_requested.emit(dialogue_tree)
		get_tree().paused = true
