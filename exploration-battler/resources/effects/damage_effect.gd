class_name DamageEffect
extends CardEffect

## =============================================================================
## DamageEffect - Damage Dealing Effect
## =============================================================================
## Deals damage to a target creature or directly to opponent.
##
## Parameters:
## - amount: Damage dealt (HARDCODED default 1)
## - can_target_opponent: If true, can deal direct damage when no target
##
## Targeting:
## - If target specified in context: damages that creature
## - If no target and can_target_opponent: damages opponent life
## =============================================================================

@export var amount: int = 1
@export var can_target_opponent: bool = false  # Can deal direct damage to opponent

func execute(context: EffectContext) -> void:
	if context.target:
		context.target.take_damage(amount)
	elif can_target_opponent:
		if context.is_player:
			context.battle_state.deal_damage_to_enemy(amount)
		else:
			context.battle_state.deal_damage_to_player(amount)
