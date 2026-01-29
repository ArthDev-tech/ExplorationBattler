extends Node

## =============================================================================
## CombatResolver - Combat Phase Handler
## =============================================================================
## Resolves combat between creatures in lanes during the end-of-turn phase.
## Handles all damage calculation, keyword effects, and death processing.
##
## Combat Flow:
## 1. Lanes are processed left-to-right (0 -> 1 -> 2)
## 2. For each lane:
##    a. Player creature attacks first (if able)
##    b. If opposing creature exists: mutual combat with counterattack
##    c. If opposing lane empty: direct damage to enemy life
##    d. Frenzy keyword allows second attack
##    e. Enemy creature attacks (same logic)
## 3. Deaths are processed after all lanes resolve
## 4. Death triggers (Soulbound, on_death effects) fire
##
## Keyword Interactions:
## - Deathtouch: Any damage kills the target
## - Lifesteal: Heal owner for damage dealt
## - Poison: Deal 1 damage back to attacker
## - Frenzy: Attack twice per turn
## - Soulbound: Return to hand on death (once per battle)
## =============================================================================

# -----------------------------------------------------------------------------
# MAIN COMBAT RESOLUTION
# -----------------------------------------------------------------------------

## Resolves all combat for the current turn.
## @param state: BattleState containing all battle data
## @param battle_manager: Reference to BattleManager for animations (optional)
func resolve_combat(state: BattleState, battle_manager: Node = null) -> void:
	# Process all lanes left-to-right
	# HARDCODED: Assumes 3 lanes - adjust if lane count changes
	var lane_count: int = mini(state.player_lanes.size(), state.enemy_lanes.size())
	for lane in range(lane_count):
		await resolve_lane(lane, state, battle_manager)
	
	# Process death triggers for any creatures that died
	process_deaths(state)
	
	# Process end-of-combat effects (reserved for future expansion)
	process_end_of_combat(state)

## Resolves combat in a single lane.
## @param lane: Lane index (0-2)
## @param state: BattleState reference
## @param battle_manager: For animation callbacks (optional)
func resolve_lane(lane: int, state: BattleState, battle_manager: Node = null) -> void:
	var player_card: CardInstance = state.player_lanes[lane]
	var enemy_card: CardInstance = state.enemy_lanes[lane]
	
	# --- Player creature attacks first ---
	if player_card and player_card.can_attack():
		# Play attack animation before dealing damage
		if battle_manager:
			var target_pos: Vector2 = _get_target_position_for_attack(lane, true, state, battle_manager)
			if target_pos != Vector2.ZERO:
				var attacker_visual: Control = _get_card_visual_from_lane(lane, true, battle_manager)
				if attacker_visual and attacker_visual.has_method("play_attack_animation"):
					await attacker_visual.play_attack_animation(target_pos)
		
		if enemy_card:
			# Attack opposing creature (triggers counterattack)
			deal_damage(player_card, enemy_card, state, true)
		else:
			# Direct damage to enemy life
			state.deal_damage_to_enemy(player_card.current_attack)
		
		player_card.has_attacked_this_turn = true
		
		# Frenzy: attack again if still able
		if player_card.has_keyword(&"Frenzy") and player_card.can_attack():
			if battle_manager:
				var target_pos: Vector2 = _get_target_position_for_attack(lane, true, state, battle_manager)
				if target_pos != Vector2.ZERO:
					var attacker_visual: Control = _get_card_visual_from_lane(lane, true, battle_manager)
					if attacker_visual and attacker_visual.has_method("play_attack_animation"):
						await attacker_visual.play_attack_animation(target_pos)
			
			if enemy_card and enemy_card.is_alive():
				deal_damage(player_card, enemy_card, state, true)
			elif not enemy_card:
				state.deal_damage_to_enemy(player_card.current_attack)
	
	# --- Enemy creature attacks ---
	if enemy_card and enemy_card.can_attack():
		# Play attack animation
		if battle_manager:
			var target_pos: Vector2 = _get_target_position_for_attack(lane, false, state, battle_manager)
			if target_pos != Vector2.ZERO:
				var attacker_visual: Control = _get_card_visual_from_lane(lane, false, battle_manager)
				if attacker_visual and attacker_visual.has_method("play_attack_animation"):
					await attacker_visual.play_attack_animation(target_pos)
		
		if player_card and player_card.is_alive():
			# Attack opposing creature
			deal_damage(enemy_card, player_card, state, false)
		else:
			# Direct damage to player life
			state.deal_damage_to_player(enemy_card.current_attack)
		
		enemy_card.has_attacked_this_turn = true
		
		# Frenzy: attack again
		if enemy_card.has_keyword(&"Frenzy") and enemy_card.can_attack():
			if battle_manager:
				var target_pos: Vector2 = _get_target_position_for_attack(lane, false, state, battle_manager)
				if target_pos != Vector2.ZERO:
					var attacker_visual: Control = _get_card_visual_from_lane(lane, false, battle_manager)
					if attacker_visual and attacker_visual.has_method("play_attack_animation"):
						await attacker_visual.play_attack_animation(target_pos)
			
			if player_card and player_card.is_alive():
				deal_damage(enemy_card, player_card, state, false)
			elif not player_card:
				state.deal_damage_to_player(enemy_card.current_attack)

# -----------------------------------------------------------------------------
# DAMAGE DEALING
# -----------------------------------------------------------------------------

## Deals damage from attacker to defender, handling all keyword interactions.
## @param attacker: The attacking CardInstance
## @param defender: The defending CardInstance
## @param state: BattleState for life/state updates
## @param is_player_attacker: True if attacker belongs to player
func deal_damage(attacker: CardInstance, defender: CardInstance, state: BattleState, is_player_attacker: bool) -> void:
	if not attacker or not defender:
		return
	
	var damage: int = attacker.current_attack
	
	# --- Deathtouch: instant kill ---
	if attacker.has_keyword(&"Deathtouch"):
		defender.current_health = 0
		EventBus.card_stats_changed.emit(defender)
	else:
		defender.take_damage(damage)
	
	# Check if defender died immediately
	var defender_died: bool = check_immediate_death(defender, _find_lane(defender, state, not is_player_attacker), not is_player_attacker, state)
	
	# --- Lifesteal: heal attacker's owner ---
	if attacker.has_keyword(&"Lifesteal"):
		if is_player_attacker:
			state.player_life = mini(state.player_max_life, state.player_life + damage)
			EventBus.life_changed.emit(state.player_life, state.player_max_life, true)
		else:
			state.enemy_life = mini(state.enemy_max_life, state.enemy_life + damage)
			EventBus.life_changed.emit(state.enemy_life, state.enemy_max_life, false)
	
	# --- Poison: damage attacker (only if defender survived to poison) ---
	if not defender_died and defender.has_keyword(&"Poison"):
		# HARDCODED: Poison deals 1 damage - adjust for stronger poison effects
		attacker.take_damage(1)
		check_immediate_death(attacker, _find_lane(attacker, state, is_player_attacker), is_player_attacker, state)
	
	# --- Counterattack: defender strikes back if alive ---
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
			check_immediate_death(defender, _find_lane(defender, state, not is_player_attacker), not is_player_attacker, state)

# -----------------------------------------------------------------------------
# DEATH PROCESSING
# -----------------------------------------------------------------------------

## Processes all deaths at end of combat resolution.
## Handles death effects and Soulbound keyword.
func process_deaths(state: BattleState) -> void:
	var lane_count: int = mini(state.player_lanes.size(), state.enemy_lanes.size())
	
	# Check player lanes for dead creatures
	for lane in range(lane_count):
		var card: CardInstance = state.player_lanes[lane]
		if card and not card.is_alive():
			EventBus.card_died.emit(card, lane, true)
			state.player_lanes[lane] = null
			
			# Execute on_death effect if defined
			if card.data.on_death_effect:
				var context: EffectContext = EffectContext.new(state, card, true)
				card.data.on_death_effect.execute(context)
			
			# Soulbound: return to hand (once per battle)
			if card.has_keyword(&"Soulbound") and not card.soulbound_used:
				card.soulbound_used = true
				card.current_health = card.data.health  # Reset health
				state.player_hand.append(card)
				EventBus.hand_updated.emit(state.player_hand, true)
	
	# Check enemy lanes for dead creatures
	for lane in range(lane_count):
		var card: CardInstance = state.enemy_lanes[lane]
		if card and not card.is_alive():
			EventBus.card_died.emit(card, lane, false)
			state.enemy_lanes[lane] = null
			
			if card.data.on_death_effect:
				var context: EffectContext = EffectContext.new(state, card, false)
				card.data.on_death_effect.execute(context)
			
			if card.has_keyword(&"Soulbound") and not card.soulbound_used:
				card.soulbound_used = true
				card.current_health = card.data.health
				state.enemy_hand.append(card)
				EventBus.hand_updated.emit(state.enemy_hand, false)

## End-of-combat hook for future expansion.
func process_end_of_combat(state: BattleState) -> void:
	# Reserved for end-of-combat triggers
	# e.g., Regenerate keyword healing
	pass

# -----------------------------------------------------------------------------
# IMMEDIATE DEATH CHECK
# -----------------------------------------------------------------------------

## Checks if a creature should die immediately after taking damage.
## Used during combat to handle mid-combat deaths (before process_deaths).
## @return: True if creature died and was removed
func check_immediate_death(creature: CardInstance, lane: int, is_player: bool, state: BattleState) -> bool:
	if not creature or creature.is_alive():
		return false
	
	var lanes: Array[CardInstance] = state.player_lanes if is_player else state.enemy_lanes
	if lane < 0 or lane >= lanes.size() or lanes[lane] != creature:
		return false
	
	# Emit death signal and remove from lane
	EventBus.card_died.emit(creature, lane, is_player)
	lanes[lane] = null
	
	# Execute death effect
	if creature.data.on_death_effect:
		var context: EffectContext = EffectContext.new(state, creature, is_player)
		creature.data.on_death_effect.execute(context)
	
	# Soulbound handling
	if creature.has_keyword(&"Soulbound") and not creature.soulbound_used:
		creature.soulbound_used = true
		creature.current_health = creature.data.health
		var hand: Array[CardInstance] = state.player_hand if is_player else state.enemy_hand
		hand.append(creature)
		EventBus.hand_updated.emit(hand, is_player)
	
	return true

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

## Finds which lane a creature is in.
func _find_lane(creature: CardInstance, state: BattleState, is_player: bool) -> int:
	var lanes: Array[CardInstance] = state.player_lanes if is_player else state.enemy_lanes
	for i in range(lanes.size()):
		if lanes[i] == creature:
			return i
	return -1

## Gets the card visual Control node from a lane for animations.
func _get_card_visual_from_lane(lane: int, is_player: bool, battle_manager: Node) -> Control:
	if not battle_manager:
		return null
	
	var lanes_array: Array = battle_manager.get("_player_lanes") if is_player else battle_manager.get("_enemy_lanes")
	if not lanes_array or lane < 0 or lane >= lanes_array.size():
		return null
	
	var lane_node: Node = lanes_array[lane]
	if not lane_node or not lane_node.has_method("get_card_visual"):
		return null
	
	return lane_node.get_card_visual() as Control

## Gets the target position for attack animation.
## Returns Vector2.ZERO if position cannot be determined.
func _get_target_position_for_attack(lane: int, is_player_attacker: bool, state: BattleState, battle_manager: Node) -> Vector2:
	if not battle_manager:
		return Vector2.ZERO
	
	# Determine opposing creature
	var opposing_lane_card: CardInstance = null
	if is_player_attacker:
		opposing_lane_card = state.enemy_lanes[lane] if lane < state.enemy_lanes.size() else null
	else:
		opposing_lane_card = state.player_lanes[lane] if lane < state.player_lanes.size() else null
	
	# If opposing lane has a creature, target it
	if opposing_lane_card and opposing_lane_card.is_alive():
		var opposing_lanes_array: Array = battle_manager.get("_enemy_lanes") if is_player_attacker else battle_manager.get("_player_lanes")
		if opposing_lanes_array and lane < opposing_lanes_array.size():
			var opposing_lane_node: Node = opposing_lanes_array[lane]
			if opposing_lane_node and opposing_lane_node.has_method("get_card_visual"):
				var target_visual: Control = opposing_lane_node.get_card_visual() as Control
				if target_visual:
					return target_visual.global_position + target_visual.size / 2
	
	# If opposing lane empty, target the avatar
	var avatar_slot: Control = null
	if is_player_attacker:
		avatar_slot = battle_manager.get("_enemy_avatar_slot") as Control
	else:
		avatar_slot = battle_manager.get("_player_avatar_slot") as Control
	
	if avatar_slot:
		return avatar_slot.global_position + avatar_slot.size / 2
	
	return Vector2.ZERO

# -----------------------------------------------------------------------------
# AVATAR COMBAT
# -----------------------------------------------------------------------------

## Deals damage from a creature to an avatar.
func deal_damage_to_avatar(attacker: CardInstance, target_avatar: CardInstance, state: BattleState, is_player_target: bool) -> void:
	if not attacker or not target_avatar:
		return
	
	var damage: int = attacker.current_attack
	
	# Avatar damage goes to life total
	if is_player_target:
		state.deal_damage_to_player(damage)
	else:
		state.deal_damage_to_enemy(damage)
	
	# Lifesteal
	if attacker.has_keyword(&"Lifesteal"):
		if not is_player_target:
			state.player_life = mini(state.player_max_life, state.player_life + damage)
			EventBus.life_changed.emit(state.player_life, state.player_max_life, true)
		else:
			state.enemy_life = mini(state.enemy_max_life, state.enemy_life + damage)
			EventBus.life_changed.emit(state.enemy_life, state.enemy_max_life, false)
	
	attacker.has_attacked_this_turn = true
	
	if EventBus.has_signal("avatar_attacked"):
		EventBus.avatar_attacked.emit(not is_player_target, is_player_target, damage)

## Avatar attacks a creature.
func avatar_attack_creature(avatar: CardInstance, target: CardInstance, state: BattleState, is_player_avatar: bool) -> void:
	if not avatar or not target:
		return
	
	var damage: int = avatar.current_attack
	
	target.take_damage(damage)
	var target_died: bool = check_immediate_death(target, _find_lane(target, state, not is_player_avatar), not is_player_avatar, state)
	
	# Lifesteal
	if avatar.has_keyword(&"Lifesteal"):
		if is_player_avatar:
			state.player_life = mini(state.player_max_life, state.player_life + damage)
			EventBus.life_changed.emit(state.player_life, state.player_max_life, true)
		else:
			state.enemy_life = mini(state.enemy_max_life, state.enemy_life + damage)
			EventBus.life_changed.emit(state.enemy_life, state.enemy_max_life, false)
	
	# Counterattack from creature
	if not target_died and target.is_alive():
		var counter_damage: int = target.current_attack
		if is_player_avatar:
			state.deal_damage_to_player(counter_damage)
		else:
			state.deal_damage_to_enemy(counter_damage)
	
	avatar.has_attacked_this_turn = true
