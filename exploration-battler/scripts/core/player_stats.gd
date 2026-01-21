class_name PlayerStats
extends RefCounted

## Manages player stats: level, experience, base stats, and calculated totals with equipment.

var level: int = 1
var experience: int = 0
var experience_to_next: int = 100

var base_attack: int = 5
var base_defense: int = 3
var base_health: int = 20

var equipment_bonuses: Dictionary = {
	"attack": 0,
	"defense": 0,
	"health": 0
}

func get_total_attack() -> int:
	return base_attack + equipment_bonuses.get("attack", 0)

func get_total_defense() -> int:
	return base_defense + equipment_bonuses.get("defense", 0)

func get_total_health() -> int:
	return base_health + equipment_bonuses.get("health", 0)

func update_equipment_bonuses(equipped_items: Dictionary) -> void:
	equipment_bonuses["attack"] = 0
	equipment_bonuses["defense"] = 0
	equipment_bonuses["health"] = 0
	
	for slot_type in equipped_items:
		var item: ItemInstance = equipped_items[slot_type]
		if item:
			equipment_bonuses["attack"] += item.get_total_attack_bonus()
			equipment_bonuses["defense"] += item.get_total_defense_bonus()
			equipment_bonuses["health"] += item.get_total_health_bonus()

func add_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		experience_to_next = int(experience_to_next * 1.5)  # Exponential growth
		# Level up bonuses
		base_attack += 1
		base_defense += 1
		base_health += 5
