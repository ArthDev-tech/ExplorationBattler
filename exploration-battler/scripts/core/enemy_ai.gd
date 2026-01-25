class_name EnemyAI
extends RefCounted

## =============================================================================
## EnemyAI - Enemy Decision Making
## =============================================================================
## Handles AI decision-making for enemy turns during battle.
## Currently implements basic behavior; will be expanded in future phases.
##
## Decision Flow:
## 1. Check hand for playable cards
## 2. Find empty lanes to play creatures
## 3. When no more plays possible, end turn
##
## Note: Combat attacks happen automatically in CombatResolver, not here.
## This class only decides what cards to play and where.
## =============================================================================

# -----------------------------------------------------------------------------
# STATE
# -----------------------------------------------------------------------------

## Reference to enemy configuration (stats, behavior type).
var enemy_data: EnemyData

## Reference to current battle state.
var battle_state: BattleState

## Reference to enemy's deck for draw decisions.
var deck: Deck

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

## Creates an AI instance for the given enemy and battle.
## @param data: EnemyData defining AI behavior type
## @param state: Current BattleState reference
## @param enemy_deck: Enemy's Deck instance
func _init(data: EnemyData, state: BattleState, enemy_deck: Deck) -> void:
	enemy_data = data
	battle_state = state
	deck = enemy_deck

# -----------------------------------------------------------------------------
# DECISION MAKING
# -----------------------------------------------------------------------------

## Makes a single turn decision.
## @return: Dictionary with decision details:
##   - {type: "play_card", card: CardInstance, lane: int}
##   - {type: "end_turn"}
##
## Called repeatedly by BattleManager until "end_turn" is returned.
func make_turn_decision() -> Dictionary:
	# BASIC AI: Play any affordable card to any empty lane
	# TODO: Implement AGGRESSIVE, DEFENSIVE, ADAPTIVE, SWARM behaviors
	
	# Iterate through hand looking for playable cards
	for card in battle_state.enemy_hand:
		if card and card.data and battle_state.can_afford_enemy_cost(card.data):
			# Only creatures go in lanes
			if card.data.is_creature():
				# Find first empty lane
				for lane in range(battle_state.enemy_lanes.size()):
					if battle_state.enemy_lanes[lane] == null:
						return {
							"type": "play_card",
							"card": card,
							"lane": lane
						}
			# TODO: Handle spells, traps, relics for advanced AI
	
	# No more cards to play - end turn
	# Note: Attacks happen automatically in combat resolution phase
	return {"type": "end_turn"}

## Chooses an energy color when max energy increases.
## @return: EnergyColor index (0=Red, 1=Blue, 2=Green)
##
## HARDCODED: Currently random - override for specific behaviors
func choose_energy_color() -> int:
	# TODO: Make intelligent choices based on deck composition
	# - AGGRESSIVE: Favor red
	# - DEFENSIVE: Favor green
	# - ADAPTIVE: Match player's weakness
	return randi() % 3
