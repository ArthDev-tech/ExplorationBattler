class_name EffectContext
extends RefCounted

## =============================================================================
## EffectContext - Effect Execution Context
## =============================================================================
## Context data passed to card effects during execution.
## Provides all information an effect needs to resolve.
##
## Core Properties:
## - source: The card that triggered the effect
## - target: Target creature (if applicable)
## - target_lane: Lane index of target (if applicable)
## - battle_state: Current BattleState for state queries/mutations
## - is_player: True if effect is from player side
##
## Effect Values:
## - damage_amount: For damage effects
## - heal_amount: For heal effects
## - buff_attack/buff_health: For buff effects
##
## Created by BattleManager before executing any effect.
## =============================================================================

var source: CardInstance  # Card that triggered the effect
var target: CardInstance = null  # Target card (if applicable)
var target_lane: int = -1  # Target lane (if applicable)
var battle_state: BattleState  # Current battle state
var is_player: bool = true  # Whether effect is from player side
var damage_amount: int = 0  # For damage effects
var heal_amount: int = 0  # For heal effects
var buff_attack: int = 0  # For buff effects
var buff_health: int = 0  # For buff effects

func _init(state: BattleState, source_card: CardInstance, player_side: bool) -> void:
	battle_state = state
	source = source_card
	is_player = player_side
