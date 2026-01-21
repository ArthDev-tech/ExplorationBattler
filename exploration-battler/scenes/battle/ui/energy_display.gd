extends Control

## Energy display component showing current/max energy with visual icons.

@onready var _energy_text: Label = $HBox/EnergyText
@onready var _energy_icons: HBoxContainer = $HBox/EnergyIcons

var _is_player: bool = true
var _icon_scene: PackedScene = null

func _ready() -> void:
	EventBus.energy_changed.connect(_on_energy_changed)
	_create_icon_scene()

func _create_icon_scene() -> void:
	# Create a simple colored rectangle as energy icon
	# In a full implementation, this would be a proper icon
	pass

func initialize(is_player: bool, max_energy: int) -> void:
	_is_player = is_player
	_update_display(0, max_energy)

func _on_energy_changed(current: int, max_energy: int, is_player: bool) -> void:
	if is_player == _is_player:
		_update_display(current, max_energy)

func _update_display(current: int, max_energy: int) -> void:
	_energy_text.text = str(current) + " / " + str(max_energy)
	_update_icons(current, max_energy)

func _update_icons(current: int, max_energy: int) -> void:
	# Clear existing icons
	for child in _energy_icons.get_children():
		child.queue_free()
	
	# Create icons for each energy
	for i in range(max_energy):
		var icon: ColorRect = ColorRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		if i < current:
			icon.color = Color(0.2, 0.6, 1.0, 1.0)  # Blue for available
		else:
			icon.color = Color(0.3, 0.3, 0.3, 1.0)  # Gray for spent
		_energy_icons.add_child(icon)

func _exit_tree() -> void:
	if EventBus.energy_changed.is_connected(_on_energy_changed):
		EventBus.energy_changed.disconnect(_on_energy_changed)
