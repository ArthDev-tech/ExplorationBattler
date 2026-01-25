class_name CardData
extends Resource

## =============================================================================
## CardData - Static Card Definition (Resource)
## =============================================================================
## Defines the base stats, effects, and metadata for a card type.
## This is a Resource that is saved to .tres files and shared across instances.
##
## IMPORTANT: NEVER modify CardData at runtime! Changes will persist in the
## editor and affect all instances. Use CardInstance for mutable runtime state.
##
## Card Types:
## - CREATURE: Placed in lanes, has attack/health, can fight
## - SPELL: One-time effect, immediately discarded after use
## - TRAP: Placed face-down, triggered by conditions
## - RELIC: Permanent passive effect on the field
## - TOKEN: Summoned creatures (not in deck, created by effects)
## =============================================================================

# -----------------------------------------------------------------------------
# ENUMS
# -----------------------------------------------------------------------------

## The fundamental type of card, determining where it can be played.
enum CardType {
	CREATURE,  # Lane creatures that attack/defend
	SPELL,     # Instant effects
	TRAP,      # Triggered effects (backrow)
	RELIC,     # Persistent effects (backrow)
	TOKEN      # Summoned creatures (not added to deck)
}

## Creature tribes for synergy effects.
enum Tribe {
	NONE,      # No tribe affiliation
	PHANTOM,   # Ghost/spirit creatures
	BEAST,     # Animal creatures
	CONSTRUCT, # Mechanical/golem creatures
	CULTIST,   # Dark magic users
	NATURE     # Plant/forest creatures
}

## Card rarity affects drop rates and deck building limits.
enum Rarity {
	COMMON,    # Frequently found, unlimited copies
	UNCOMMON,  # Less common, limited copies
	RARE,      # Difficult to obtain
	LEGENDARY  # Very rare, typically 1 per deck
}

# -----------------------------------------------------------------------------
# EXPORTED PROPERTIES - Edit these in the Inspector
# -----------------------------------------------------------------------------

## Unique identifier used by CardRegistry and deck JSON. Must be unique!
@export var card_id: StringName = &""

## Display name shown in UI.
@export var display_name: String = ""

## Generic (colorless) cost. Can be paid by any color energy.
## HARDCODED: Default cost of 1 - adjust per card
@export var cost: int = 1

## Colored pip costs - must be paid with specific energy colors.
@export var cost_red: int = 0
@export var cost_blue: int = 0
@export var cost_green: int = 0

## The type of card (see CardType enum).
@export var card_type: CardType = CardType.CREATURE

## Rarity tier for collection/deckbuilding.
@export var rarity: Rarity = Rarity.COMMON

# -----------------------------------------------------------------------------
# CREATURE PROPERTIES - Only relevant for CREATURE and TOKEN types
# -----------------------------------------------------------------------------

## Base attack power (damage dealt in combat).
@export var attack: int = 0

## Base health (damage required to destroy).
@export var health: int = 0

## Tribal affiliation for synergy cards.
@export var tribe: Tribe = Tribe.NONE

## Keyword abilities (e.g., &"Haste", &"Shield", &"Frenzy").
## See keywords.gd for available keywords.
@export var keywords: Array[StringName] = []

# -----------------------------------------------------------------------------
# EFFECTS - CardEffect resources attached to this card
# -----------------------------------------------------------------------------

## Effect triggered when this card is played.
@export var on_play_effect: Resource = null  # CardEffect

## Effect triggered when this creature dies.
@export var on_death_effect: Resource = null  # CardEffect

## Passive effect active while card is on field.
@export var passive_effect: Resource = null  # CardEffect

# -----------------------------------------------------------------------------
# METADATA
# -----------------------------------------------------------------------------

## Card description/flavor text shown in UI.
@export var description: String = ""

## Card artwork texture. Currently placeholder.
@export var artwork: Texture2D = null

## Cost in currency to purchase this card from shops.
@export var currency_cost: int = 0

# -----------------------------------------------------------------------------
# TOKEN PROPERTIES
# -----------------------------------------------------------------------------

## True if this is a token (summoned, not from deck).
@export var is_token: bool = false

## Sacrifice value for effects that sacrifice creatures.
## HARDCODED: Default values - regular creatures = 1, tokens = 0, elites = 2
@export var sacrifice_value: int = 1

# -----------------------------------------------------------------------------
# HELPER METHODS
# -----------------------------------------------------------------------------

## Returns true if this card is a creature type.
func is_creature() -> bool:
	return card_type == CardType.CREATURE

## Checks if this card has a specific keyword ability.
func has_keyword(keyword: StringName) -> bool:
	return keywords.has(keyword)

## Returns the generic (colorless) cost portion.
func get_generic_cost() -> int:
	return maxi(0, cost)

## Returns red pip cost.
func get_red_pips() -> int:
	return maxi(0, cost_red)

## Returns blue pip cost.
func get_blue_pips() -> int:
	return maxi(0, cost_blue)

## Returns green pip cost.
func get_green_pips() -> int:
	return maxi(0, cost_green)

## Returns total cost (generic + all colored pips).
func get_total_cost() -> int:
	return get_generic_cost() + get_red_pips() + get_blue_pips() + get_green_pips()
