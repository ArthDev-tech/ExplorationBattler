extends Control

## Energy display component showing current/max energy with visual icons.

@onready var _energy_text: Label = $HBox/EnergyText
@onready var _energy_icons: HBoxContainer = $HBox/EnergyIcons
@onready var _energy_prefix: Label = $HBox/Label

const HEX_ICON_SCRIPT: Script = preload("res://scenes/battle/ui/hex_energy_icon.gd")

var _is_player: bool = true
var _has_color_data: bool = false
var _current_r: int = 0
var _current_b: int = 0
var _current_g: int = 0
var _max_r: int = 0
var _max_b: int = 0
var _max_g: int = 0

func _ready() -> void:
	# Icons-only: hide all numeric/text indicators.
	if _energy_prefix:
		_energy_prefix.visible = false
	if _energy_text:
		_energy_text.visible = false
	EventBus.energy_changed.connect(_on_energy_changed)
	if EventBus.has_signal("energy_colors_changed"):
		EventBus.energy_colors_changed.connect(_on_energy_colors_changed)

func initialize(is_player: bool, max_energy: int) -> void:
	_is_player = is_player
	_has_color_data = false
	_current_r = 0
	_current_b = 0
	_current_g = 0
	_max_r = 0
	_max_b = 0
	_max_g = 0
	_update_display(0, max_energy)

func _on_energy_changed(current: int, max_energy: int, is_player: bool) -> void:
	if is_player == _is_player:
		_update_display(current, max_energy)

func _on_energy_colors_changed(current_r: int, current_b: int, current_g: int, max_r: int, max_b: int, max_g: int, is_player: bool) -> void:
	if is_player != _is_player:
		return
	_has_color_data = true
	_current_r = current_r
	_current_b = current_b
	_current_g = current_g
	_max_r = max_r
	_max_b = max_b
	_max_g = max_g
	var total_current: int = _current_r + _current_b + _current_g
	var total_max: int = _max_r + _max_b + _max_g
	_update_display(total_current, total_max)

func _update_display(current: int, max_energy: int) -> void:
	# Intentionally no numeric/text display; icons are the sole indicator.
	_update_icons(current, max_energy)

func _update_icons(current: int, max_energy: int) -> void:
	# Clear existing icons
	for child in _energy_icons.get_children():
		child.queue_free()
	
	if not _has_color_data:
		# Fallback: single-color icons for each energy
		for i in range(max_energy):
			var icon_fallback: Control = HEX_ICON_SCRIPT.new() as Control
			icon_fallback.custom_minimum_size = Vector2(18, 18)
			icon_fallback.set("fill_color", Color(0.2, 0.6, 1.0, 1.0))
			icon_fallback.set("is_available", i < current)
			icon_fallback.queue_redraw()
			_energy_icons.add_child(icon_fallback)
		return
	
	_add_color_icons(_current_r, _max_r, Color(0.9, 0.2, 0.2, 1.0))
	_add_spacer()
	_add_color_icons(_current_b, _max_b, Color(0.2, 0.6, 1.0, 1.0))
	_add_spacer()
	_add_color_icons(_current_g, _max_g, Color(0.2, 0.85, 0.35, 1.0))

func _add_color_icons(current: int, max_energy: int, color: Color) -> void:
	for i in range(max_energy):
		var icon: Control = HEX_ICON_SCRIPT.new() as Control
		icon.custom_minimum_size = Vector2(18, 18)
		icon.set("fill_color", color)
		icon.set("is_available", i < current)
		icon.queue_redraw()
		_energy_icons.add_child(icon)

func _add_spacer() -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(8, 1)
	_energy_icons.add_child(spacer)

func _exit_tree() -> void:
	if EventBus.energy_changed.is_connected(_on_energy_changed):
		EventBus.energy_changed.disconnect(_on_energy_changed)
	if EventBus.has_signal("energy_colors_changed") and EventBus.energy_colors_changed.is_connected(_on_energy_colors_changed):
		EventBus.energy_colors_changed.disconnect(_on_energy_colors_changed)
