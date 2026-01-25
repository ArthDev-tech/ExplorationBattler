class_name CardEffect
extends Resource

## =============================================================================
## CardEffect - Base Effect Class
## =============================================================================
## Base class for all card effects. Subclasses implement specific behaviors.
## Effects are Resources attached to CardData and executed by BattleManager.
##
## Trigger Types:
## - ON_PLAY: When card is played from hand
## - ON_DEATH: When creature dies
## - ON_ATTACK: When creature attacks
## - START_OF_TURN: At beginning of owner's turn
## - END_OF_TURN: At end of owner's turn
## - ON_DAMAGE_TAKEN: When creature takes damage
## - ON_DAMAGE_DEALT: When creature deals damage
##
## Subclasses:
## - DamageEffect: Deals damage to target
## - HealEffect: Heals a creature
## - BuffEffect: Modifies attack/health
## - DrawCardsEffect: Draws cards from deck
## - SummonEffect: Creates token creatures
##
## Usage: Override execute() in subclasses.
## =============================================================================

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
