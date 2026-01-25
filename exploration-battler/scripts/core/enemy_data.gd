class_name EnemyData
extends Resource

## =============================================================================
## EnemyData - Static Enemy Definition (Resource)
## =============================================================================
## Defines an enemy type: stats, AI behavior, deck composition, and rewards.
## This is a Resource saved to .tres files - one per enemy type.
##
## Enemy decks can be defined two ways:
## 1. deck_list: Array of CardData resources (set in Inspector)
## 2. deck_json_path: Path to JSON file with card_id -> count mapping
##
## The JSON approach is preferred for easier editing outside Godot.
## =============================================================================

# Preload CardData to ensure class is registered before resource loads
const CardDataScript = preload("res://scripts/core/card_data.gd")

# -----------------------------------------------------------------------------
# AI BEHAVIOR TYPES
# -----------------------------------------------------------------------------

## Determines how the enemy AI makes decisions.
enum AIBehaviorType {
	BASIC,      # Simple: play cards when affordable, attack when possible
	AGGRESSIVE, # Prioritizes damage over defense, goes face
	DEFENSIVE,  # Prioritizes survival, plays blockers and heals
	ADAPTIVE,   # Analyzes player board state and counters
	SWARM       # Floods board with cheap creatures
}

# -----------------------------------------------------------------------------
# CORE PROPERTIES
# -----------------------------------------------------------------------------

## Unique identifier for this enemy type.
@export var enemy_id: StringName = &""

## Display name shown in battle UI.
@export var display_name: String = ""

## HARDCODED: Default enemy max life - adjust per enemy for difficulty
@export var max_life: int = 10

## Enemy avatar attack power (damage dealt when attacking directly).
## HARDCODED: Default 3 - increase for harder enemies
@export var base_attack: int = 3

## Difficulty indicator (1-4 stars) for player reference.
## HARDCODED: Affects nothing mechanically yet - purely visual
@export var difficulty_stars: int = 1

## AI behavior pattern to use for decision making.
@export var ai_behavior_type: AIBehaviorType = AIBehaviorType.BASIC

# -----------------------------------------------------------------------------
# DECK DEFINITION
# -----------------------------------------------------------------------------

## Array of CardData resources making up the enemy deck.
## Less flexible than JSON approach but works in Inspector.
@export var deck_list: Array[Resource] = []

## Path to JSON file defining deck: {"card_id": count, ...}
## If set and valid, overrides deck_list. Falls back to deck_list on error.
## HARDCODED: Expected format - change requires code updates
@export_file("*.json") var deck_json_path: String = ""

# -----------------------------------------------------------------------------
# SPECIAL RULES
# -----------------------------------------------------------------------------

## List of special rule identifiers that modify battle behavior.
## Example: ["double_damage", "no_healing"]
## HARDCODED: Rule names - must match handling code
@export var special_rules: Array[String] = []

# -----------------------------------------------------------------------------
# REWARDS
# -----------------------------------------------------------------------------

## Gold/currency given on victory.
## HARDCODED: Default 10 - adjust per enemy
@export var gold_reward: int = 10

## Cards always given as rewards (guaranteed drops).
@export var guaranteed_cards: Array[Resource] = []  # Array[CardData]

## Pool of cards to randomly select rewards from.
@export var card_pool: Array[Resource] = []  # Array[CardData]

## Path to JSON file defining reward pool: ["card_id1", "card_id2", ...]
## If set, victory screen uses this instead of card_pool.
@export_file("*.json") var reward_card_json_path: String = ""

# -----------------------------------------------------------------------------
# VISUAL
# -----------------------------------------------------------------------------

## Enemy portrait texture for battle UI.
@export var portrait: Texture2D = null
