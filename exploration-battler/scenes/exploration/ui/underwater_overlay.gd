extends CanvasLayer

## Full-screen overlay when the player is underwater. Fades in/out based on
## EventBus.player_entered_water / player_exited_water (ref count).

@onready var _overlay: ColorRect = $UnderwaterOverlayRect
var _material: ShaderMaterial
var _underwater_count: int = 0
var _target_intensity: float = 0.0
var _current_intensity: float = 0.0
const FADE_SPEED: float = 3.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _overlay and _overlay.material:
		_material = _overlay.material as ShaderMaterial
	if not EventBus.player_entered_water.is_connected(_on_player_entered_water):
		EventBus.player_entered_water.connect(_on_player_entered_water)
	if not EventBus.player_exited_water.is_connected(_on_player_exited_water):
		EventBus.player_exited_water.connect(_on_player_exited_water)
	if _overlay:
		_overlay.modulate.a = 0.0

func _exit_tree() -> void:
	if EventBus.player_entered_water.is_connected(_on_player_entered_water):
		EventBus.player_entered_water.disconnect(_on_player_entered_water)
	if EventBus.player_exited_water.is_connected(_on_player_exited_water):
		EventBus.player_exited_water.disconnect(_on_player_exited_water)

func _on_player_entered_water() -> void:
	_underwater_count += 1
	_target_intensity = 1.0 if _underwater_count > 0 else 0.0

func _on_player_exited_water() -> void:
	_underwater_count -= 1
	if _underwater_count < 0:
		_underwater_count = 0
	_target_intensity = 1.0 if _underwater_count > 0 else 0.0

func _process(delta: float) -> void:
	_current_intensity = move_toward(_current_intensity, _target_intensity, FADE_SPEED * delta)
	if _material:
		_material.set_shader_parameter("intensity", _current_intensity)
	if _overlay:
		_overlay.visible = _current_intensity > 0.01
		_overlay.modulate.a = 1.0
