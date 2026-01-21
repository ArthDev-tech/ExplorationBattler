class_name CardEffect
extends Resource

## Base class for all card effects. Subclasses implement specific behaviors.

enum Trigger {
	ON_PLAY,
	ON_DEATH,
	ON_ATTACK,
	START_OF_TURN,
	END_OF_TURN,
	ON_DAMAGE_TAKEN,
	ON_DAMAGE_DEALT
}

@export var trigger: Trigger = Trigger.ON_PLAY
@export var description: String = ""

func execute(context: EffectContext) -> void:
	push_error("CardEffect.execute() not implemented in subclass")

func can_execute(context: EffectContext) -> bool:
	return true
