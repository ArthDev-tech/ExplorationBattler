extends Control

## Life bar component that displays current/max life and updates from EventBus.

@onready var _progress_bar: ProgressBar = $VBox/ProgressBar
@onready var _life_text: Label = $VBox/LifeText

var _is_player: bool = true

func _ready() -> void:
	EventBus.life_changed.connect(_on_life_changed)

func initialize(is_player: bool, max_life: int) -> void:
	_is_player = is_player
	_progress_bar.max_value = max_life
	_progress_bar.value = max_life
	_update_display(max_life, max_life)

func _on_life_changed(current: int, max_life: int, is_player: bool) -> void:
	if is_player == _is_player:
		_update_display(current, max_life)

func _update_display(current: int, max_life: int) -> void:
	_progress_bar.value = current
	_progress_bar.max_value = max_life
	_life_text.text = str(current) + " / " + str(max_life)
	
	# Color based on life percentage
	var percentage: float = float(current) / float(max_life) if max_life > 0 else 0.0
	if percentage > 0.6:
		_progress_bar.modulate = Color(0.2, 0.8, 0.2, 1)  # Green
	elif percentage > 0.3:
		_progress_bar.modulate = Color(0.8, 0.8, 0.2, 1)  # Yellow
	else:
		_progress_bar.modulate = Color(0.8, 0.2, 0.2, 1)  # Red

func _exit_tree() -> void:
	if EventBus.life_changed.is_connected(_on_life_changed):
		EventBus.life_changed.disconnect(_on_life_changed)
