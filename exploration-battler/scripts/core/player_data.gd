class_name PlayerData
extends Resource

## Static player data resource. Edit values in the .tres file.

@export var display_name: String = "Player"
@export var max_life: int = 20
@export var base_attack: int = 5
@export var base_defense: int = 3
@export var starting_gold: int = 0
@export var starting_energy: int = 3

# Level progression
@export var attack_per_level: int = 1
@export var defense_per_level: int = 1
@export var health_per_level: int = 5
@export var base_exp_to_level: int = 100
@export var exp_growth_multiplier: float = 1.5
