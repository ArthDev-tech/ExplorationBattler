class_name ItemInstance
extends RefCounted

## Runtime item instance with mutable state. Created from ItemData.

var data: ItemData
var quantity: int = 1
var durability: int = 100  # For future use
var max_durability: int = 100

func _init(item_data: ItemData, item_quantity: int = 1) -> void:
	data = item_data
	quantity = item_quantity
	if data:
		max_durability = 100  # Default, can be customized per item

func get_total_attack_bonus() -> int:
	if not data:
		return 0
	return data.attack_bonus

func get_total_defense_bonus() -> int:
	if not data:
		return 0
	return data.defense_bonus

func get_total_health_bonus() -> int:
	if not data:
		return 0
	return data.health_bonus
