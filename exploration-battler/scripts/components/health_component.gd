class_name HealthComponent
extends Node

## Health tracking component with signals for health changes.

signal health_changed(current: int, maximum: int)
signal died

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit()

func heal(amount: int) -> void:
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func set_max_health(new_max: int) -> void:
	max_health = new_max
	current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0
