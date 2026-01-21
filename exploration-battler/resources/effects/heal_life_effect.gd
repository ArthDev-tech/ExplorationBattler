class_name HealLifeEffect
extends CardEffect

## Heals the caster's life total.

@export var amount: int = 1

func execute(context: EffectContext) -> void:
	var heal_amount: int = maxi(0, amount)
	if heal_amount <= 0:
		return
	if context.is_player:
		context.battle_state.player_life = mini(context.battle_state.player_max_life, context.battle_state.player_life + heal_amount)
		EventBus.life_changed.emit(context.battle_state.player_life, context.battle_state.player_max_life, true)
	else:
		context.battle_state.enemy_life = mini(context.battle_state.enemy_max_life, context.battle_state.enemy_life + heal_amount)
		EventBus.life_changed.emit(context.battle_state.enemy_life, context.battle_state.enemy_max_life, false)
