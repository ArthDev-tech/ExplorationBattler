class_name DamageEffect
extends CardEffect

## Deals damage to a target.

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
