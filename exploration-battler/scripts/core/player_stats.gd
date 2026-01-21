class_name PlayerStats
extends RefCounted

## Manages player stats: level, experience, base stats, and calculated totals with equipment.

var _base_data: Resource = null

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

func initialize(data: Resource) -> void:
	_base_data = data
	level = 1
	experience = 0
	
	var exp_val = data.get("base_exp_to_level")
	experience_to_next = exp_val if exp_val != null else 100
	
	var attack_val = data.get("base_attack")
	base_attack = attack_val if attack_val != null else 5
	
	var defense_val = data.get("base_defense")
	base_defense = defense_val if defense_val != null else 3
	
	var health_val = data.get("max_life")
	base_health = health_val if health_val != null else 20
	
	equipment_bonuses = {
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
		# Use data values for progression, or defaults if not initialized
		if _base_data:
			var growth_val = _base_data.get("exp_growth_multiplier")
			var growth: float = growth_val if growth_val != null else 1.5
			
			var atk_val = _base_data.get("attack_per_level")
			var atk_per_lvl: int = atk_val if atk_val != null else 1
			
			var def_val = _base_data.get("defense_per_level")
			var def_per_lvl: int = def_val if def_val != null else 1
			
			var hp_val = _base_data.get("health_per_level")
			var hp_per_lvl: int = hp_val if hp_val != null else 5
			
			experience_to_next = int(experience_to_next * growth)
			base_attack += atk_per_lvl
			base_defense += def_per_lvl
			base_health += hp_per_lvl
		else:
			experience_to_next = int(experience_to_next * 1.5)
			base_attack += 1
			base_defense += 1
			base_health += 5
