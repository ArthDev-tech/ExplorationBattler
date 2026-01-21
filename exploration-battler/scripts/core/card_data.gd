class_name CardData
extends Resource

## Static card definition resource. NEVER modify at runtime - changes persist in editor!

enum CardType {
	CREATURE,
	SPELL,
	TRAP,
	RELIC,
	TOKEN
}

enum Tribe {
	NONE,
	PHANTOM,
	BEAST,
	CONSTRUCT,
	CULTIST,
	NATURE
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY
}

@export var card_id: StringName = &""
@export var display_name: String = ""
## Generic (colorless) cost. Can be paid by any color energy.
@export var cost: int = 1
## Colored pip costs.
@export var cost_red: int = 0
@export var cost_blue: int = 0
@export var cost_green: int = 0
@export var card_type: CardType = CardType.CREATURE
@export var rarity: Rarity = Rarity.COMMON

# Creature-specific properties
@export var attack: int = 0
@export var health: int = 0
@export var tribe: Tribe = Tribe.NONE
@export var keywords: Array[StringName] = []

# Effects (will be expanded when effect system is complete)
@export var on_play_effect: Resource = null  # CardEffect
@export var on_death_effect: Resource = null  # CardEffect
@export var passive_effect: Resource = null  # CardEffect

# Metadata
@export var description: String = ""
@export var artwork: Texture2D = null  # Placeholder for now

# Token-specific
@export var is_token: bool = false
@export var sacrifice_value: int = 1  # Most creatures = 1, tokens = 0, elites = 2

func is_creature() -> bool:
	return card_type == CardType.CREATURE

func has_keyword(keyword: StringName) -> bool:
	return keywords.has(keyword)

func get_generic_cost() -> int:
	return maxi(0, cost)

func get_red_pips() -> int:
	return maxi(0, cost_red)

func get_blue_pips() -> int:
	return maxi(0, cost_blue)

func get_green_pips() -> int:
	return maxi(0, cost_green)

func get_total_cost() -> int:
	return get_generic_cost() + get_red_pips() + get_blue_pips() + get_green_pips()
