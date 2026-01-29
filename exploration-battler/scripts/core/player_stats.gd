class_name PlayerStats
extends RefCounted

## =============================================================================
## PlayerStats - Player Stat Manager
## =============================================================================
## Manages player statistics including base stats, equipment bonuses, and
## leveling. Calculates total stats by combining base + equipment.
##
## Stats:
## - Attack: Damage dealt by player avatar in battle
## - Defense: Damage reduction (not yet implemented)
## - Health: Maximum hit points
##
## Equipment bonuses are recalculated whenever items are equipped/unequipped.
## =============================================================================

# -----------------------------------------------------------------------------
# STATE
# -----------------------------------------------------------------------------

## Reference to PlayerData resource for level-up scaling values.
var _base_data: Resource = null

## Current player level (1-indexed).
var level: int = 1

## Current experience points toward next level.
var experience: int = 0

## Experience required to reach next level.
## HARDCODED: Starting value 100, scales by exp_growth_multiplier per level
var experience_to_next: int = 100

## Base stats before equipment bonuses.
## HARDCODED: Default values if PlayerData not loaded
var base_attack: int = 5
var base_defense: int = 3
var base_health: int = 20
var base_intelligence: int = 5
var base_strength: int = 5
var base_agility: int = 5

## Bonuses from equipped items, calculated by update_equipment_bonuses().
var equipment_bonuses: Dictionary = {
	"attack": 0,
	"defense": 0,
	"health": 0,
	"intelligence": 0,
	"strength": 0,
	"agility": 0
}

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

## Initializes stats from a PlayerData resource.
## @param data: PlayerData resource containing base stat definitions
func initialize(data: Resource) -> void:
	_base_data = data
	level = 1
	experience = 0
	
	# Load values from data, with fallback defaults
	var exp_val = data.get("base_exp_to_level")
	experience_to_next = exp_val if exp_val != null else 100
	
	var attack_val = data.get("base_attack")
	base_attack = attack_val if attack_val != null else 5
	
	var defense_val = data.get("base_defense")
	base_defense = defense_val if defense_val != null else 3
	
	var health_val = data.get("max_life")
	base_health = health_val if health_val != null else 20
	
	var int_val = data.get("base_intelligence")
	base_intelligence = int_val if int_val != null else 5
	
	var str_val = data.get("base_strength")
	base_strength = str_val if str_val != null else 5
	
	var agi_val = data.get("base_agility")
	base_agility = agi_val if agi_val != null else 5
	
	# Reset equipment bonuses
	equipment_bonuses = {
		"attack": 0,
		"defense": 0,
		"health": 0,
		"intelligence": 0,
		"strength": 0,
		"agility": 0
	}

# -----------------------------------------------------------------------------
# STAT CALCULATION
# -----------------------------------------------------------------------------

## Returns total attack (base + equipment).
func get_total_attack() -> int:
	return base_attack + equipment_bonuses.get("attack", 0)

## Returns total defense (base + equipment).
func get_total_defense() -> int:
	return base_defense + equipment_bonuses.get("defense", 0)

## Returns total health/max life (base + equipment).
func get_total_health() -> int:
	return base_health + equipment_bonuses.get("health", 0)

## Returns total intelligence (base + equipment).
func get_total_intelligence() -> int:
	return base_intelligence + equipment_bonuses.get("intelligence", 0)

## Returns total strength (base + equipment).
func get_total_strength() -> int:
	return base_strength + equipment_bonuses.get("strength", 0)

## Returns total agility (base + equipment).
func get_total_agility() -> int:
	return base_agility + equipment_bonuses.get("agility", 0)

# -----------------------------------------------------------------------------
# EQUIPMENT
# -----------------------------------------------------------------------------

## Recalculates equipment bonuses from current equipped items.
## @param equipped_items: Dictionary {ItemType: ItemInstance or null}
func update_equipment_bonuses(equipped_items: Dictionary) -> void:
	# Reset all bonuses
	equipment_bonuses["attack"] = 0
	equipment_bonuses["defense"] = 0
	equipment_bonuses["health"] = 0
	
	# Sum bonuses from all equipped items
	for slot_type in equipped_items:
		var item: ItemInstance = equipped_items[slot_type]
		if item:
			equipment_bonuses["attack"] += item.get_total_attack_bonus()
			equipment_bonuses["defense"] += item.get_total_defense_bonus()
			equipment_bonuses["health"] += item.get_total_health_bonus()

# -----------------------------------------------------------------------------
# LEVELING
# -----------------------------------------------------------------------------

## Adds experience and handles level-ups.
## @param amount: Experience points to add
func add_experience(amount: int) -> void:
	experience += amount
	
	# Check for level up (can level multiple times from large XP gains)
	while experience >= experience_to_next:
		experience -= experience_to_next
		level += 1
		
		# Apply level-up stat gains
		if _base_data:
			# Use data-defined scaling values
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
			# HARDCODED: Fallback level-up values if no data loaded
			experience_to_next = int(experience_to_next * 1.5)
			base_attack += 1
			base_defense += 1
			base_health += 5
