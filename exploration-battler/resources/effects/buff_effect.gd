class_name BuffEffect
extends CardEffect

## Modifies a creature's stats.

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
