class_name DrawCardsEffect
extends CardEffect

## =============================================================================
## DrawCardsEffect - Card Draw Effect
## =============================================================================
## Requests drawing cards from deck to hand for the caster's side.
## Emits draw_cards_requested signal handled by BattleManager.
##
## Parameters:
## - count: Number of cards to draw (HARDCODED default 1)
##
## Uses EventBus signal rather than direct state manipulation to ensure
## proper animation and hand updates are triggered.
## =============================================================================

@export var count: int = 1

func execute(context: EffectContext) -> void:
	var safe_count: int = maxi(0, count)
	if safe_count <= 0:
		return
	EventBus.draw_cards_requested.emit(safe_count, context.is_player)
