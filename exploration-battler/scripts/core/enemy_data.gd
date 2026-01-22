class_name EnemyData
extends Resource

## Static enemy definition resource.

# Preload CardData to ensure class is registered
const CardDataScript = preload("res://scripts/core/card_data.gd")

enum AIBehaviorType {
	BASIC,      # Play cards, attack
	AGGRESSIVE, # Prioritize damage
	DEFENSIVE,  # Prioritize survival
	ADAPTIVE,   # Counters player strategy
	SWARM       # Flood board with cheap creatures
}

@export var enemy_id: StringName = &""
@export var display_name: String = ""
@export var max_life: int = 10
@export var base_attack: int = 3  # Enemy avatar attack value
@export var difficulty_stars: int = 1  # 1-4 stars
@export var ai_behavior_type: AIBehaviorType = AIBehaviorType.BASIC

# Deck definition - array of CardData resources
@export var deck_list: Array[Resource] = []

# Optional deck definition (editable outside Godot): JSON counts map { "card_id": count }.
# If set, battle startup will build the enemy deck from this file and fall back to `deck_list` on error/empty.
@export_file("*.json") var deck_json_path: String = ""

# Special rules
@export var special_rules: Array[String] = []

# Rewards
@export var gold_reward: int = 10
@export var guaranteed_cards: Array[Resource] = []  # Cards always dropped
@export var card_pool: Array[Resource] = []  # Random card from pool
# Optional reward card pool (editable outside Godot): JSON array of card IDs ["card_id1", "card_id2", ...].
# If set, victory screen will pick reward cards from this pool instead of card_pool or global pool.
@export_file("*.json") var reward_card_json_path: String = ""

# Visual
@export var portrait: Texture2D = null  # Placeholder for now
