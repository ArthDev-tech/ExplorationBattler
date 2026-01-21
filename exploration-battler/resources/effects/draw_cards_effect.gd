class_name DrawCardsEffect
extends CardEffect

## Requests drawing cards for the caster's side.

@export var count: int = 1

func execute(context: EffectContext) -> void:
	var safe_count: int = maxi(0, count)
	if safe_count <= 0:
		return
	EventBus.draw_cards_requested.emit(safe_count, context.is_player)
