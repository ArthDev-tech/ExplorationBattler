extends Node2D

## Manages battle flow, turn state machine, and orchestrates combat.

enum TurnPhase {
	SETUP,
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLVING,
	END
}

var current_state: TurnPhase = TurnPhase.SETUP
var battle_state: BattleState = null
var player_deck: Deck = null
var enemy_deck: Deck = null
var enemy_data: EnemyData = null
var enemy_ai: EnemyAI = null
var _selected_card: CardInstance = null
var _targeting_spell: CardInstance = null
var _targeting_mode: bool = false

@onready var _combat_resolver: Node = $CombatResolver
@onready var _ui: CanvasLayer = $UI
@onready var _player_life_bar = $UI/PlayerHeader/HeaderContainer/PlayerLifeBar
@onready var _enemy_life_bar = $UI/EnemyHeader/HeaderContainer/EnemyLifeBar
@onready var _player_energy_display = $UI/PlayerHeader/HeaderContainer/PlayerEnergyDisplay
@onready var _enemy_energy_display = $UI/EnemyHeader/HeaderContainer/EnemyEnergyDisplay
@onready var _end_turn_button: Button = $UI/EndTurnButton
@onready var _player_lanes: Array[Node] = []
@onready var _enemy_lanes: Array[Node] = []

func _ready() -> void:
	# Ensure battle processes even when world is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Release mouse cursor for UI interaction in battle scene
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.card_played.connect(_on_card_played)
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_deselected.connect(_on_card_deselected)
	EventBus.target_selected.connect(_on_target_selected)
	
	# Connect end turn button
	if _end_turn_button:
		_end_turn_button.pressed.connect(end_turn)
	
	# Get lane references
	_setup_lanes()
	
	# Connect lane clicks for card placement
	_connect_lane_clicks()
	
	# If scene loaded directly (for testing), auto-start with Lost Wanderer
	if not enemy_data:
		call_deferred("_auto_start_battle")

func _auto_start_battle() -> void:
	var enemy = load("res://resources/enemies/lost_wanderer.tres")
	if enemy:
		_on_battle_started(enemy)

func _setup_lanes() -> void:
	_player_lanes.clear()
	_enemy_lanes.clear()
	
	var player_lanes_container = $UI/PlayerSide
	var enemy_lanes_container = $UI/EnemySide
	
	if player_lanes_container:
		for i in range(min(5, player_lanes_container.get_child_count())):
			var lane = player_lanes_container.get_child(i)
			if lane and lane.has_method("set_lane_index"):
				lane.set_lane_index(i)
				lane.is_player_lane = true
				_player_lanes.append(lane)
	
	if enemy_lanes_container:
		for i in range(min(5, enemy_lanes_container.get_child_count())):
			var lane = enemy_lanes_container.get_child(i)
			if lane and lane.has_method("set_lane_index"):
				lane.set_lane_index(i)
				lane.is_player_lane = false
				_enemy_lanes.append(lane)

func _connect_lane_clicks() -> void:
	# Connect lane click signals for card placement
	for i in range(_player_lanes.size()):
		var lane = _player_lanes[i]
		if lane and lane.has_signal("lane_clicked"):
			# Signal already emits lane_index, no need to bind
			if not lane.lane_clicked.is_connected(_on_lane_clicked):
				lane.lane_clicked.connect(_on_lane_clicked)

func _on_lane_clicked(lane_index: int) -> void:
	if _selected_card and current_state == TurnPhase.PLAYER_TURN:
		# Try to play the selected card in this lane
		if play_card(_selected_card, lane_index, true):
			# Card played successfully, deselect
			_selected_card = null
			EventBus.card_deselected.emit()
		else:
			# Play failed (not enough energy, lane occupied, etc.)
			# Keep card selected so player can try another lane
			pass

func _on_battle_started(enemy: Resource) -> void:
	enemy_data = enemy as EnemyData
	if not enemy_data:
		# Try to cast as Resource and check script
		if enemy and enemy.get_script():
			var script_path = enemy.get_script().get_path()
			if script_path.ends_with("enemy_data.gd"):
				enemy_data = enemy as EnemyData
		
		if not enemy_data:
			push_error("BattleManager: Invalid enemy data")
			return
	
	start_battle()

func start_battle() -> void:
	current_state = TurnPhase.SETUP
	
	# Initialize battle state
	battle_state = BattleState.new()
	battle_state.initialize_player(GameManager.player_max_life, 3)
	battle_state.initialize_enemy(enemy_data.max_life, 3)
	
	# Initialize UI components
	if _player_life_bar and _player_life_bar.has_method("initialize"):
		_player_life_bar.initialize(true, battle_state.player_max_life)
	if _enemy_life_bar and _enemy_life_bar.has_method("initialize"):
		_enemy_life_bar.initialize(false, battle_state.enemy_max_life)
	if _player_energy_display and _player_energy_display.has_method("initialize"):
		_player_energy_display.initialize(true, battle_state.player_max_energy)
	if _enemy_energy_display and _enemy_energy_display.has_method("initialize"):
		_enemy_energy_display.initialize(false, battle_state.enemy_max_energy)
	
	# Emit initial energy state to update displays
	EventBus.energy_changed.emit(battle_state.player_energy, battle_state.player_max_energy, true)
	EventBus.energy_changed.emit(battle_state.enemy_energy, battle_state.enemy_max_energy, false)
	
	# Create decks
	if GameManager.player_deck:
		player_deck = GameManager.player_deck
	else:
		# Create starter deck
		var starter_cards: Array[CardData] = []
		var wandering_soul: CardData = load("res://resources/cards/starter/wandering_soul.tres")
		var forest_whelp: CardData = load("res://resources/cards/starter/forest_whelp.tres")
		var stone_sentry: CardData = load("res://resources/cards/starter/stone_sentry.tres")
		var soul_strike: CardData = load("res://resources/cards/starter/soul_strike.tres")
		
		for i in range(3):
			starter_cards.append(wandering_soul)
		for i in range(2):
			starter_cards.append(forest_whelp)
		for i in range(2):
			starter_cards.append(stone_sentry)
		starter_cards.append(load("res://resources/cards/starter/vengeful_spirit.tres"))
		starter_cards.append(load("res://resources/cards/starter/thornback_wolf.tres"))
		starter_cards.append(load("res://resources/cards/starter/hollow_knight.tres"))
		for i in range(2):
			starter_cards.append(soul_strike)
		starter_cards.append(load("res://resources/cards/starter/mend.tres"))
		starter_cards.append(load("res://resources/cards/starter/spectral_surge.tres"))
		starter_cards.append(load("res://resources/cards/starter/cracked_lantern.tres"))
		player_deck = Deck.new(starter_cards)
	
	# Create enemy deck
	var enemy_card_list: Array[CardData] = []
	for resource in enemy_data.deck_list:
		if resource is CardData:
			enemy_card_list.append(resource as CardData)
	enemy_deck = Deck.new(enemy_card_list)
	
	# Create AI
	enemy_ai = EnemyAI.new(enemy_data, battle_state, enemy_deck)
	
	# Draw starting hands
	draw_starting_hand(true)
	draw_starting_hand(false)
	
	# Start player turn
	start_player_turn()

func draw_starting_hand(is_player: bool) -> void:
	var drawn: Array[CardInstance] = player_deck.draw(5) if is_player else enemy_deck.draw(5)
	if is_player:
		battle_state.player_hand = drawn
		EventBus.hand_updated.emit(drawn, true)
	else:
		battle_state.enemy_hand = drawn
		EventBus.hand_updated.emit(drawn, false)

func start_player_turn() -> void:
	current_state = TurnPhase.PLAYER_TURN
	battle_state.start_player_turn()
	
	# Draw card
	var drawn: Array[CardInstance] = player_deck.draw(1)
	if not drawn.is_empty():
		battle_state.player_hand.append(drawn[0])
		EventBus.card_drawn.emit(drawn[0], true)
		EventBus.hand_updated.emit(battle_state.player_hand, true)
	
	EventBus.turn_started.emit(battle_state.turn_number, true)

func start_enemy_turn() -> void:
	current_state = TurnPhase.ENEMY_TURN
	battle_state.start_enemy_turn()
	
	# Draw card
	var drawn: Array[CardInstance] = enemy_deck.draw(1)
	if not drawn.is_empty():
		battle_state.enemy_hand.append(drawn[0])
		EventBus.card_drawn.emit(drawn[0], false)
		EventBus.hand_updated.emit(battle_state.enemy_hand, false)
	
	EventBus.turn_started.emit(battle_state.turn_number, false)
	
	# AI makes decisions (stub - will be expanded in Phase 3)
	await get_tree().create_timer(1.0).timeout
	process_enemy_turn()

func process_enemy_turn() -> void:
	# AI decision making - loop until no more actions can be taken
	var max_actions: int = 20  # Safety limit
	var action_count: int = 0
	
	while action_count < max_actions:
		var decision: Dictionary = enemy_ai.make_turn_decision()
		
		match decision.get("type", ""):
			"play_card":
				var card: CardInstance = decision.get("card")
				var lane: int = decision.get("lane", 0)
				if play_card(card, lane, false):
					action_count += 1
					await get_tree().create_timer(0.3).timeout  # Brief delay between actions
					continue  # Try another action
				else:
					# Can't play card, end turn
					break
			"attack":
				# Attacks happen in combat resolution, not during turn
				# No action needed here
				break
			"end_turn":
				break
		
		# If we get here, no valid action was taken
		break
	
	# End turn after all actions
	end_turn()

func play_card(card: CardInstance, lane: int, is_player: bool) -> bool:
	if not card:
		return false
	
	var cost: int = card.data.cost
	var state: BattleState = battle_state
	
	if is_player:
		if not state.spend_player_energy(cost):
			return false
	else:
		if not state.spend_enemy_energy(cost):
			return false
	
	# Remove from hand
	if is_player:
		var index: int = state.player_hand.find(card)
		if index >= 0:
			state.player_hand.remove_at(index)
			EventBus.hand_updated.emit(state.player_hand, true)
	else:
		var index: int = state.enemy_hand.find(card)
		if index >= 0:
			state.enemy_hand.remove_at(index)
			EventBus.hand_updated.emit(state.enemy_hand, false)
	
	# Place in lane (only for creatures)
	if card.data.is_creature():
		# Validate lane for creatures
		if lane < 0:
			# Invalid lane for creature
			if is_player:
				state.player_energy += cost
			else:
				state.enemy_energy += cost
			return false
		
		if not state.place_card_in_lane(card, lane, is_player):
			# Refund energy
			if is_player:
				state.player_energy += cost
			else:
				state.enemy_energy += cost
			return false
		
		# Update lane visual
		var lanes: Array = _player_lanes if is_player else _enemy_lanes
		if lane >= 0 and lane < lanes.size() and lanes[lane]:
			var lane_node = lanes[lane]
			if lane_node.has_method("place_card"):
				lane_node.place_card(card)
	else:
		# Non-creature cards (spells/relics) - execute effects immediately
		# Note: If spell needs targeting, it should be handled via enter_targeting_mode()
		# This path is for spells that don't need targets or are being played with a target
		if card.data.on_play_effect:
			var context = EffectContext.new(state, card, is_player)
			context.target_lane = lane  # May be -1, which is fine for spells
			# Target should be set by target_creature() if this was called from targeting
			if card.data.on_play_effect.has_method("execute"):
				card.data.on_play_effect.execute(context)
	
	EventBus.card_played.emit(card, lane, is_player)
	return true

func spell_needs_target(card: CardInstance) -> bool:
	# Check if spell needs a target (has effect that requires target)
	if not card or not card.data:
		return false
	
	# First check if card has on_play_effect resource
	if card.data.on_play_effect:
		# DamageEffect and BuffEffect need targets (unless can_target_opponent is true for damage)
		if card.data.on_play_effect is DamageEffect:
			var damage_effect: DamageEffect = card.data.on_play_effect as DamageEffect
			# Needs target if can't target opponent directly
			return not damage_effect.can_target_opponent
		elif card.data.on_play_effect is BuffEffect:
			# Buff effects always need a target
			return true
	
	# Fallback: Check card description for "target" keyword (for spells without effect resources yet)
	if not card.data.is_creature():
		var desc_lower: String = card.data.description.to_lower()
		if desc_lower.contains("target"):
			return true
	
	return false

func enter_targeting_mode(card: CardInstance) -> void:
	if not card or current_state != TurnPhase.PLAYER_TURN:
		return
	
	# Check if card is playable
	if not battle_state or battle_state.player_energy < card.data.cost:
		return
	
	# Check if spell needs targeting
	if not spell_needs_target(card):
		# No target needed, play immediately
		play_card(card, -1, true)
		return
	
	_targeting_spell = card
	_targeting_mode = true
	EventBus.targeting_started.emit(card)

func cancel_targeting() -> void:
	if _targeting_mode:
		_targeting_mode = false
		_targeting_spell = null
		EventBus.targeting_cancelled.emit()

func _create_and_execute_effect_from_description(spell: CardInstance, target: CardInstance, lane: int, state: BattleState) -> void:
	# Create effect based on spell description for spells without effect resources
	var desc_lower: String = spell.data.description.to_lower()
	
	if desc_lower.contains("deal") and desc_lower.contains("damage"):
		# Damage spell - extract amount
		var damage_amount: int = 2  # Default
		var words: Array = spell.data.description.split(" ")
		for i in range(words.size()):
			if words[i].to_lower() == "deal":
				if i + 1 < words.size():
					var num_str: String = words[i + 1]
					if num_str.is_valid_int():
						damage_amount = num_str.to_int()
		
		target.take_damage(damage_amount)
	
	elif desc_lower.contains("give") and (desc_lower.contains("attack") or desc_lower.contains("+") or desc_lower.contains("buff")):
		# Buff spell - extract amount
		var buff_amount: int = 2  # Default
		var words: Array = spell.data.description.split(" ")
		for i in range(words.size()):
			if words[i].contains("+") or words[i].is_valid_int():
				var num_str: String = words[i].trim_prefix("+")
				if num_str.is_valid_int():
					buff_amount = num_str.to_int()
		
		target.modify_attack(buff_amount)

func target_creature(target_card: CardInstance, lane: int, _is_player: bool, spell: CardInstance = null) -> void:
	# Allow spell to be passed directly (for drag-and-drop) or use _targeting_spell (for click targeting)
	var spell_to_cast: CardInstance = spell if spell else _targeting_spell
	
	if not spell_to_cast:
		return
	
	# If using click targeting mode, verify we're in targeting mode
	if not spell and (not _targeting_mode or not _targeting_spell):
		return
	
	# Validate target
	if not target_card or not target_card.is_alive():
		return
	
	# Check if target is phasing (can't be targeted)
	if target_card.is_phasing:
		return
	
	# Play the spell with target
	var cost: int = spell_to_cast.data.cost
	var state: BattleState = battle_state
	
	# Spend energy
	if not state.spend_player_energy(cost):
		if _targeting_mode:
			cancel_targeting()
		return
	
	# Remove from hand
	var index: int = state.player_hand.find(spell_to_cast)
	if index >= 0:
		state.player_hand.remove_at(index)
		EventBus.hand_updated.emit(state.player_hand, true)
	
	# Execute effect with target
	if spell_to_cast.data.on_play_effect:
		var context = EffectContext.new(state, spell_to_cast, true)
		context.target = target_card
		context.target_lane = lane
		if spell_to_cast.data.on_play_effect.has_method("execute"):
			spell_to_cast.data.on_play_effect.execute(context)
	else:
		# Spell has no effect resource - create one based on description
		_create_and_execute_effect_from_description(spell_to_cast, target_card, lane, state)
	
	# Emit card played signal
	EventBus.card_played.emit(spell_to_cast, lane, true)
	
	# Exit targeting mode if we were in it
	if _targeting_mode:
		_targeting_spell = null
		_targeting_mode = false
		EventBus.targeting_cancelled.emit()

func _on_target_selected(target: CardInstance, lane: int, is_player: bool) -> void:
	target_creature(target, lane, is_player)

func _unhandled_input(event: InputEvent) -> void:
	# Cancel targeting with ESC or right-click
	if _targeting_mode:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			cancel_targeting()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_targeting()
			get_viewport().set_input_as_handled()

func _on_card_played(_card: CardInstance, _lane: int, _is_player: bool) -> void:
	# Apply on-play effects here
	pass

func _on_card_selected(card: CardInstance) -> void:
	# Only allow selection during player turn
	if current_state != TurnPhase.PLAYER_TURN:
		return
	
	# Check if card is playable
	if not card or not battle_state:
		return
	
	var cost: int = card.data.cost
	if battle_state.player_energy < cost:
		# Not enough energy, don't select
		return
	
	# Select the card
	_selected_card = card

func _on_card_deselected() -> void:
	_selected_card = null

func resolve_combat() -> void:
	current_state = TurnPhase.RESOLVING
	
	if _combat_resolver:
		_combat_resolver.resolve_combat(battle_state)
	
	# Sync lane visuals after combat
	_sync_lane_visuals()
	
	# Check for battle end
	if battle_state.is_battle_over():
		end_battle()
		return
	
	# Continue to next turn
	battle_state.end_turn()
	if battle_state.is_player_turn:
		start_player_turn()
	else:
		start_enemy_turn()

func end_turn() -> void:
	if current_state == TurnPhase.PLAYER_TURN:
		EventBus.turn_ended.emit(battle_state.turn_number, true)
		resolve_combat()
	elif current_state == TurnPhase.ENEMY_TURN:
		EventBus.turn_ended.emit(battle_state.turn_number, false)
		resolve_combat()

func end_battle() -> void:
	current_state = TurnPhase.END
	var winner: int = battle_state.get_winner()
	EventBus.battle_ended.emit(winner)
	# BattleOverlayManager will handle hiding the overlay after a delay

func _sync_lane_visuals() -> void:
	# Sync player lanes
	for i in range(min(_player_lanes.size(), battle_state.player_lanes.size())):
		var lane_node = _player_lanes[i]
		var state_card = battle_state.player_lanes[i]
		
		if lane_node and lane_node.has_method("get_card"):
			var visual_card = lane_node.get_card()
			
			# If state has no card but visual does, remove it
			if not state_card and visual_card:
				if lane_node.has_method("remove_card"):
					lane_node.remove_card()
			# If state has card but visual doesn't match, update visual
			elif state_card:
				if visual_card != state_card:
					# Card changed - update visual
					if lane_node.has_method("place_card"):
						# Remove old card if exists
						if visual_card:
							lane_node.remove_card()
						# Place new card
						lane_node.place_card(state_card)
				elif visual_card == state_card and lane_node.has_method("get_card"):
					# Same card - refresh visual stats
					var card_visual = lane_node.get("_card_visual")
					if card_visual and card_visual.has_method("update_visual_state"):
						card_visual.update_visual_state()
	
	# Sync enemy lanes
	for i in range(min(_enemy_lanes.size(), battle_state.enemy_lanes.size())):
		var lane_node = _enemy_lanes[i]
		var state_card = battle_state.enemy_lanes[i]
		
		if lane_node and lane_node.has_method("get_card"):
			var visual_card = lane_node.get_card()
			
			# If state has no card but visual does, remove it
			if not state_card and visual_card:
				if lane_node.has_method("remove_card"):
					lane_node.remove_card()
			# If state has card but visual doesn't match, update visual
			elif state_card:
				if visual_card != state_card:
					# Card changed - update visual
					if lane_node.has_method("place_card"):
						# Remove old card if exists
						if visual_card:
							lane_node.remove_card()
						# Place new card
						lane_node.place_card(state_card)
				elif visual_card == state_card and lane_node.has_method("get_card"):
					# Same card - refresh visual stats
					var card_visual = lane_node.get("_card_visual")
					if card_visual and card_visual.has_method("update_visual_state"):
						card_visual.update_visual_state()

func _exit_tree() -> void:
	if EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.disconnect(_on_battle_started)
	if EventBus.card_played.is_connected(_on_card_played):
		EventBus.card_played.disconnect(_on_card_played)
	if EventBus.card_selected.is_connected(_on_card_selected):
		EventBus.card_selected.disconnect(_on_card_selected)
	if EventBus.card_deselected.is_connected(_on_card_deselected):
		EventBus.card_deselected.disconnect(_on_card_deselected)
	if _end_turn_button and _end_turn_button.pressed.is_connected(end_turn):
		_end_turn_button.pressed.disconnect(end_turn)
