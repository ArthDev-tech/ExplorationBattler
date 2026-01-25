class_name BuffEffect
extends CardEffect

## =============================================================================
## BuffEffect - Stat Modification Effect
## =============================================================================
## Modifies a creature's attack and/or health stats.
##
## Parameters:
## - attack_modifier: Amount to add/subtract from attack
## - health_modifier: Amount to add/subtract from health
## - is_permanent: If false, stores for end-of-turn reset (not yet implemented)
##
## HARDCODED: Default modifiers are 0 - set per effect instance.
## =============================================================================

@export var attack_modifier: int = 0
@export var health_modifier: int = 0
@export var is_permanent: bool = false  # If false, resets at end of turn

func execute(context: EffectContext) -> void:
	if context.target:
		context.target.modify_attack(attack_modifier)
		context.target.modify_health(health_modifier)
		if not is_permanent:
			# Store original values to reset later
			context.target.status_effects.append({
				"type": &"buff",
				"attack": attack_modifier,
				"health": health_modifier,
				"permanent": false
			})
