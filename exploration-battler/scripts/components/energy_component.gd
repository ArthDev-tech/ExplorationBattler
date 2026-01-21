class_name EnergyComponent
extends Node

## Energy management component for battle turns.

signal energy_changed(current: int, maximum: int)

@export var max_energy: int = 3
var current_energy: int

func _ready() -> void:
	current_energy = max_energy

func spend(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		energy_changed.emit(current_energy, max_energy)
		return true
	return false

func refill() -> void:
	current_energy = max_energy
	energy_changed.emit(current_energy, max_energy)

func increase_max(amount: int = 1) -> void:
	max_energy = mini(10, max_energy + amount)  # Cap at 10
	refill()

func can_afford(cost: int) -> bool:
	return current_energy >= cost
