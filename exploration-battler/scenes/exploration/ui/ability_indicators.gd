extends Control

## UI indicators for player abilities: dash cooldown and double jump availability.

@onready var _dash_indicator: ProgressBar = $Container/DashIndicator
@onready var _double_jump_indicator: Label = $Container/DoubleJumpIndicator

func _ready() -> void:
	EventBus.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	EventBus.jump_count_changed.connect(_on_jump_count_changed)
	
	# Initialize indicators
	_on_dash_cooldown_changed(0.0, 1.0)
	_on_jump_count_changed(0, 2)

func _on_dash_cooldown_changed(cooldown: float, max_cooldown: float) -> void:
	if not _dash_indicator:
		return
	
	var progress: float = 1.0 - (cooldown / max_cooldown) if max_cooldown > 0.0 else 1.0
	_dash_indicator.value = progress * 100.0
	
	# Visual feedback: change color based on availability
	if progress >= 1.0:
		_dash_indicator.modulate = Color(0.2, 1.0, 0.2, 1.0)  # Green when ready
	else:
		_dash_indicator.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Gray when on cooldown

func _on_jump_count_changed(current: int, max_jumps: int) -> void:
	if not _double_jump_indicator:
		return
	
	var remaining: int = max_jumps - current
	
	if remaining <= 0 or current == 0:
		# On ground or all jumps used - hide indicator
		_double_jump_indicator.visible = false
	else:
		_double_jump_indicator.visible = true
		_double_jump_indicator.text = str(remaining)
		
		# Visual feedback: change color based on remaining jumps
		if remaining == 2:
			_double_jump_indicator.modulate = Color(0.2, 1.0, 0.2, 1.0)  # Green for double jump available
		elif remaining == 1:
			_double_jump_indicator.modulate = Color(1.0, 0.8, 0.2, 1.0)  # Orange for single jump remaining

func _exit_tree() -> void:
	if EventBus.dash_cooldown_changed.is_connected(_on_dash_cooldown_changed):
		EventBus.dash_cooldown_changed.disconnect(_on_dash_cooldown_changed)
	if EventBus.jump_count_changed.is_connected(_on_jump_count_changed):
		EventBus.jump_count_changed.disconnect(_on_jump_count_changed)
