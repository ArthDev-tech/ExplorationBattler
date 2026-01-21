class_name HealEffect
extends CardEffect

## Heals a target creature.

@export var amount: int = 1

func execute(context: EffectContext) -> void:
	if context.target:
		context.target.heal(amount)
