class_name EnemyAI
extends RefCounted

## AI decision-making for enemy turns. Stub for Phase 3 implementation.

var enemy_data: EnemyData
var battle_state: BattleState
var deck: Deck

func _init(data: EnemyData, state: BattleState, enemy_deck: Deck) -> void:
	enemy_data = data
	battle_state = state
	deck = enemy_deck

func make_turn_decision() -> Dictionary:
	# Returns action dictionary: {type: "play_card"|"end_turn", ...}
	# Attacks happen automatically in combat resolution, not during turn
	
	# Try to play cards (use all energy)
	for card in battle_state.enemy_hand:
		if card and card.data and battle_state.can_afford_enemy_cost(card.data):
			# Find empty lane
			for lane in range(battle_state.enemy_lanes.size()):
				if battle_state.enemy_lanes[lane] == null:
					return {
						"type": "play_card",
						"card": card,
						"lane": lane
					}
	
	# No more cards to play, end turn
	# Attacks will happen automatically in combat resolution
	return {"type": "end_turn"}

func choose_energy_color() -> int:
	# Random for now - override in subclasses for specific enemy behaviors
	return randi() % 3
