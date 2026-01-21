extends Control

## Start-of-turn energy picker for the player (Red/Blue/Green).
## Shows when EventBus requests a pick, emits EventBus.energy_color_picked when chosen.

const COLOR_RED: int = 0
const COLOR_BLUE: int = 1
const COLOR_GREEN: int = 2

@onready var _red_button: Button = $Center/Panel/VBox/HBox/RedButton
@onready var _blue_button: Button = $Center/Panel/VBox/HBox/BlueButton
@onready var _green_button: Button = $Center/Panel/VBox/HBox/GreenButton

func _ready() -> void:
	visible = false
	EventBus.energy_color_pick_requested.connect(_on_energy_color_pick_requested)
	_red_button.pressed.connect(_on_red_pressed)
	_blue_button.pressed.connect(_on_blue_pressed)
	_green_button.pressed.connect(_on_green_pressed)

func _on_energy_color_pick_requested(is_player: bool) -> void:
	if not is_player:
		return
	visible = true

func _on_red_pressed() -> void:
	_pick(COLOR_RED)

func _on_blue_pressed() -> void:
	_pick(COLOR_BLUE)

func _on_green_pressed() -> void:
	_pick(COLOR_GREEN)

func _pick(color: int) -> void:
	visible = false
	EventBus.energy_color_picked.emit(color, true)

func _exit_tree() -> void:
	if EventBus.energy_color_pick_requested.is_connected(_on_energy_color_pick_requested):
		EventBus.energy_color_pick_requested.disconnect(_on_energy_color_pick_requested)
