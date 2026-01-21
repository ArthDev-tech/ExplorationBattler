class_name SummonEffect
extends CardEffect

## Summons token creatures.

@export var token_card_data: CardData = null
@export var count: int = 1
@export var target_lane: int = -1  # -1 = choose automatically

func execute(context: EffectContext) -> void:
	if not token_card_data:
		push_error("SummonEffect: token_card_data not set")
		return
	
	for i in range(count):
		var token_instance: CardInstance = CardInstance.new(token_card_data)
		var lane: int = target_lane
		var lane_count: int = context.battle_state.player_lanes.size() if context.is_player else context.battle_state.enemy_lanes.size()
		
		# Find empty lane if not specified
		if lane < 0:
			var lanes: Array = context.battle_state.player_lanes if context.is_player else context.battle_state.enemy_lanes
			for j in range(lane_count):
				if lanes[j] == null:
					lane = j
					break
		
		if lane >= 0 and lane < lane_count:
			if context.is_player:
				context.battle_state.player_lanes[lane] = token_instance
			else:
				context.battle_state.enemy_lanes[lane] = token_instance
			EventBus.card_played.emit(token_instance, lane, context.is_player)
