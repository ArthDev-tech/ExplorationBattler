extends Node3D

## Water volume: trigger and logic for entering/leaving water live here.
## On body_entered/body_exited (Area3D), if body is the player (PlayerController from
## player_controller.tscn): calls body.enter_water()/exit_water() and emits EventBus for overlay.

@onready var _water_area: Area3D = $WaterVolume

const PLAYER_GROUP: StringName = &"player"

func _ready() -> void:
	if not _water_area:
		return
	if not _water_area.body_entered.is_connected(_on_body_entered):
		_water_area.body_entered.connect(_on_body_entered)
	if not _water_area.body_exited.is_connected(_on_body_exited):
		_water_area.body_exited.connect(_on_body_exited)

func _is_player(body: Node) -> bool:
	if body.is_in_group(PLAYER_GROUP):
		return true
	if body.name == "PlayerController":
		return true
	var scr: Script = body.get_script()
	if scr and scr.resource_path.get_file() == "player_controller.gd":
		return true
	return false

func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	if body.has_method("enter_water"):
		body.enter_water()
	EventBus.player_entered_water.emit()

func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	if body.has_method("exit_water"):
		body.exit_water()
	EventBus.player_exited_water.emit()
