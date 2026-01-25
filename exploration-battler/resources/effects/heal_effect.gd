class_name HealEffect
extends CardEffect

## =============================================================================
## HealEffect - Healing Effect
## =============================================================================
## Heals a target creature's health.
## Cannot heal above the creature's base max health (from CardData).
##
## Parameters:
## - amount: Health to restore (HARDCODED default 1)
##
## Requires a valid target in context.
## =============================================================================

@export var amount: int = 1

func execute(context: EffectContext) -> void:
	if context.target:
		context.target.heal(amount)
