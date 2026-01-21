extends Control

## Turn indicator showing current turn number and whose turn it is.

@onready var _turn_text: Label = $VBox/TurnText
@onready var _player_text: Label = $VBox/PlayerText

func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)

func _on_turn_started(turn: int, is_player: bool) -> void:
	_turn_text.text = "Turn " + str(turn)
	_player_text.text = "Player Turn" if is_player else "Enemy Turn"
	
	# Color coding
	if is_player:
		_player_text.modulate = Color(0.2, 0.6, 1.0, 1.0)  # Blue
	else:
		_player_text.modulate = Color(1.0, 0.2, 0.2, 1.0)  # Red

func _exit_tree() -> void:
	if EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.disconnect(_on_turn_started)
