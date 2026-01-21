class_name EffectContext
extends RefCounted

## Context data passed to card effects during execution.

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
