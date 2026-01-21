extends Node

## Resolves combat: damage calculation, lane-by-lane processing.
## 
## Damage Logic:
## - Creatures attack directly across their lane
## - If opposing lane is empty, creature deals direct damage to opponent (their attack value)
## - If opposing lane has a creature, creatures attack each other (both deal damage)
## - Combat resolves left-to-right during end of turn phase

func resolve_combat(state: BattleState) -> void:
	# Process all lanes left-to-right
	for lane in range(5):
		resolve_lane(lane, state)
	
	# Process death triggers
	process_deaths(state)
	
	# Process end-of-combat effects
	process_end_of_combat(state)

func resolve_lane(lane: int, state: BattleState) -> void:
	var player_card: CardInstance = state.player_lanes[lane]
	var enemy_card: CardInstance = state.enemy_lanes[lane]
	
	# Player attacks
	if player_card and player_card.can_attack():
		if enemy_card:
			# Attack opposing creature
			deal_damage(player_card, enemy_card, state, true)
		else:
			# Direct damage to enemy
			state.deal_damage_to_enemy(player_card.current_attack)
		
		player_card.has_attacked_this_turn = true
		
		# Frenzy: attack again
		if player_card.has_keyword(&"Frenzy") and player_card.can_attack():
			if enemy_card and enemy_card.is_alive():
				deal_damage(player_card, enemy_card, state, true)
			elif not enemy_card:
				state.deal_damage_to_enemy(player_card.current_attack)
	
	# Enemy attacks
	if enemy_card and enemy_card.can_attack():
		if player_card and player_card.is_alive():
			# Attack opposing creature
			deal_damage(enemy_card, player_card, state, false)
		else:
			# Direct damage to player
			state.deal_damage_to_player(enemy_card.current_attack)
		
		enemy_card.has_attacked_this_turn = true
		
		# Frenzy: attack again
		if enemy_card.has_keyword(&"Frenzy") and enemy_card.can_attack():
			if player_card and player_card.is_alive():
				deal_damage(enemy_card, player_card, state, false)
			elif not player_card:
				state.deal_damage_to_player(enemy_card.current_attack)

func deal_damage(attacker: CardInstance, defender: CardInstance, state: BattleState, is_player_attacker: bool) -> void:
	if not attacker or not defender:
		return
	
	var damage: int = attacker.current_attack
	
	# Apply damage reduction (for keywords like Ironclad Guardian)
	# This is a simplified version - full implementation would check all modifiers
	
	# Deathtouch: any damage kills
	if attacker.has_keyword(&"Deathtouch"):
		defender.current_health = 0
	else:
		defender.take_damage(damage)
	
	# Lifesteal: heal attacker's owner
	if attacker.has_keyword(&"Lifesteal"):
		if is_player_attacker:
			state.player_life = mini(state.player_max_life, state.player_life + damage)
			EventBus.life_changed.emit(state.player_life, state.player_max_life, true)
		else:
			state.enemy_life = mini(state.enemy_max_life, state.enemy_life + damage)
			EventBus.life_changed.emit(state.enemy_life, state.enemy_max_life, false)
	
	# Poison: damage attacker
	if defender.has_keyword(&"Poison"):
		attacker.take_damage(1)  # Poison 1
	
	# Defender counterattacks if still alive
	if defender.is_alive() and defender.can_attack():
		var counter_damage: int = defender.current_attack
		
		if defender.has_keyword(&"Deathtouch"):
			attacker.current_health = 0
		else:
			attacker.take_damage(counter_damage)
		
		# Lifesteal on counterattack
		if defender.has_keyword(&"Lifesteal"):
			if not is_player_attacker:
				state.player_life = mini(state.player_max_life, state.player_life + counter_damage)
				EventBus.life_changed.emit(state.player_life, state.player_max_life, true)
			else:
				state.enemy_life = mini(state.enemy_max_life, state.enemy_life + counter_damage)
				EventBus.life_changed.emit(state.enemy_life, state.enemy_max_life, false)
		
		# Poison on counterattack
		if attacker.has_keyword(&"Poison"):
			defender.take_damage(1)

func process_deaths(state: BattleState) -> void:
	# Check player lanes
	for lane in range(5):
		var card: CardInstance = state.player_lanes[lane]
		if card and not card.is_alive():
			# Emit death signal before removing from state
			EventBus.card_died.emit(card, lane, true)
			state.player_lanes[lane] = null
			# Trigger death effects
			if card.data.on_death_effect:
				var context: EffectContext = EffectContext.new(state, card, true)
				card.data.on_death_effect.execute(context)
			# Soulbound: return to hand
			if card.has_keyword(&"Soulbound") and not card.soulbound_used:
				card.soulbound_used = true
				card.current_health = card.data.health
				state.player_hand.append(card)
				EventBus.hand_updated.emit(state.player_hand, true)
			# Card is discarded (handled by BattleManager via signal)
	
	# Check enemy lanes
	for lane in range(5):
		var card: CardInstance = state.enemy_lanes[lane]
		if card and not card.is_alive():
			# Emit death signal before removing from state
			EventBus.card_died.emit(card, lane, false)
			state.enemy_lanes[lane] = null
			# Trigger death effects
			if card.data.on_death_effect:
				var context: EffectContext = EffectContext.new(state, card, false)
				card.data.on_death_effect.execute(context)
			# Soulbound: return to hand
			if card.has_keyword(&"Soulbound") and not card.soulbound_used:
				card.soulbound_used = true
				card.current_health = card.data.health
				state.enemy_hand.append(card)
				EventBus.hand_updated.emit(state.enemy_hand, false)
			# Card is discarded (handled by BattleManager via signal)

func process_end_of_combat(state: BattleState) -> void:
	# Regenerate keyword: heal at start of turn
	# This is called after combat, so it applies to next turn's start
	# For now, we'll handle it in turn start
	
	# Process any end-of-combat triggers
	pass
