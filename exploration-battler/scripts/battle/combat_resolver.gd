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
	var lane_count: int = mini(state.player_lanes.size(), state.enemy_lanes.size())
	for lane in range(lane_count):
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
		EventBus.card_stats_changed.emit(defender)
	else:
		defender.take_damage(damage)
	
	# Check if defender died immediately
	var defender_died: bool = check_immediate_death(defender, _find_lane(defender, state, not is_player_attacker), not is_player_attacker, state)
	
	# Lifesteal: heal attacker's owner
	if attacker.has_keyword(&"Lifesteal"):
		if is_player_attacker:
			state.player_life = mini(state.player_max_life, state.player_life + damage)
			EventBus.life_changed.emit(state.player_life, state.player_max_life, true)
		else:
			state.enemy_life = mini(state.enemy_max_life, state.enemy_life + damage)
			EventBus.life_changed.emit(state.enemy_life, state.enemy_max_life, false)
	
	# Poison: damage attacker (only if defender was alive to poison)
	if not defender_died and defender.has_keyword(&"Poison"):
		attacker.take_damage(1)  # Poison 1
		# Check if attacker died from poison
		check_immediate_death(attacker, _find_lane(attacker, state, is_player_attacker), is_player_attacker, state)
	
	# Defender counterattacks if still alive
	if not defender_died and defender.is_alive() and defender.can_attack():
		var counter_damage: int = defender.current_attack
		
		if defender.has_keyword(&"Deathtouch"):
			attacker.current_health = 0
			EventBus.card_stats_changed.emit(attacker)
		else:
			attacker.take_damage(counter_damage)
		
		# Check if attacker died from counterattack
		check_immediate_death(attacker, _find_lane(attacker, state, is_player_attacker), is_player_attacker, state)
		
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
			# Check if defender died from poison
			check_immediate_death(defender, _find_lane(defender, state, not is_player_attacker), not is_player_attacker, state)

func process_deaths(state: BattleState) -> void:
	# Check player lanes
	var lane_count: int = mini(state.player_lanes.size(), state.enemy_lanes.size())
	for lane in range(lane_count):
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
	for lane in range(lane_count):
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

## Immediate Death Check
## Called after any damage to check if a creature should die immediately

func check_immediate_death(creature: CardInstance, lane: int, is_player: bool, state: BattleState) -> bool:
	if not creature or creature.is_alive():
		return false
	
	# Get the correct lane array
	var lanes: Array[CardInstance] = state.player_lanes if is_player else state.enemy_lanes
	if lane < 0 or lane >= lanes.size() or lanes[lane] != creature:
		return false
	
	# Emit death signal
	EventBus.card_died.emit(creature, lane, is_player)
	lanes[lane] = null
	
	# Trigger death effects
	if creature.data.on_death_effect:
		var context: EffectContext = EffectContext.new(state, creature, is_player)
		creature.data.on_death_effect.execute(context)
	
	# Soulbound: return to hand
	if creature.has_keyword(&"Soulbound") and not creature.soulbound_used:
		creature.soulbound_used = true
		creature.current_health = creature.data.health
		var hand: Array[CardInstance] = state.player_hand if is_player else state.enemy_hand
		hand.append(creature)
		EventBus.hand_updated.emit(hand, is_player)
	
	return true

func _find_lane(creature: CardInstance, state: BattleState, is_player: bool) -> int:
	var lanes: Array[CardInstance] = state.player_lanes if is_player else state.enemy_lanes
	for i in range(lanes.size()):
		if lanes[i] == creature:
			return i
	return -1

## Avatar Combat Methods

func deal_damage_to_avatar(attacker: CardInstance, target_avatar: CardInstance, state: BattleState, is_player_target: bool) -> void:
	if not attacker or not target_avatar:
		return
	
	var damage: int = attacker.current_attack
	
	# Damage goes directly to life total instead of avatar health
	if is_player_target:
		state.deal_damage_to_player(damage)
	else:
		state.deal_damage_to_enemy(damage)
	
	# Lifesteal: heal attacker's owner
	if attacker.has_keyword(&"Lifesteal"):
		if not is_player_target:  # Attacking enemy avatar means attacker is player's
			state.player_life = mini(state.player_max_life, state.player_life + damage)
			EventBus.life_changed.emit(state.player_life, state.player_max_life, true)
		else:  # Attacking player avatar means attacker is enemy's
			state.enemy_life = mini(state.enemy_max_life, state.enemy_life + damage)
			EventBus.life_changed.emit(state.enemy_life, state.enemy_max_life, false)
	
	# Mark as attacked
	attacker.has_attacked_this_turn = true
	
	# Emit avatar attacked event
	if EventBus.has_signal("avatar_attacked"):
		EventBus.avatar_attacked.emit(not is_player_target, is_player_target, damage)

func avatar_attack_creature(avatar: CardInstance, target: CardInstance, state: BattleState, is_player_avatar: bool) -> void:
	if not avatar or not target:
		return
	
	var damage: int = avatar.current_attack
	
	# Avatar deals damage to creature
	target.take_damage(damage)
	
	# Check for immediate death
	var target_died: bool = check_immediate_death(target, _find_lane(target, state, not is_player_avatar), not is_player_avatar, state)
	
	# Lifesteal
	if avatar.has_keyword(&"Lifesteal"):
		if is_player_avatar:
			state.player_life = mini(state.player_max_life, state.player_life + damage)
			EventBus.life_changed.emit(state.player_life, state.player_max_life, true)
		else:
			state.enemy_life = mini(state.enemy_max_life, state.enemy_life + damage)
			EventBus.life_changed.emit(state.enemy_life, state.enemy_max_life, false)
	
	# Creature counterattacks if still alive
	if not target_died and target.is_alive():
		var counter_damage: int = target.current_attack
		# Damage to avatar goes to life total
		if is_player_avatar:
			state.deal_damage_to_player(counter_damage)
		else:
			state.deal_damage_to_enemy(counter_damage)
	
	# Mark avatar as attacked
	avatar.has_attacked_this_turn = true
