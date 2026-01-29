extends Node2D

## Manages battle flow, turn state machine, and orchestrates combat.

const COLOR_RED: int = 0
const COLOR_BLUE: int = 1
const COLOR_GREEN: int = 2

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
var _awaiting_energy_pick: bool = false

@onready var _combat_resolver: Node = $CombatResolver
@onready var _ui: CanvasLayer = $UI
@onready var _player_life_bar = $UI/PlayerCard/PlayerHeader/HeaderContainer/PlayerLifeBar
@onready var _enemy_life_bar = $UI/EnemyCard/EnemyHeader/HeaderContainer/EnemyLifeBar
@onready var _player_energy_display = $UI/PlayerEnergyPreviewBackdrop/PlayerEnergyPreview
@onready var _enemy_energy_display = $UI/OpponentEnergyPreviewBackdrop/OpponentEnergyPreview
@onready var _end_turn_button: Button = $UI/EndTurnButton
@onready var _player_lanes: Array[Node] = []
@onready var _enemy_lanes: Array[Node] = []
@onready var _player_avatar_slot: Control = null
@onready var _enemy_avatar_slot: Control = null
@onready var _card_registry: Node = get_node_or_null("/root/CardRegistry")
@onready var _player_backrow_zone: Control = $UI/PlayerBackrow
@onready var _enemy_backrow_zone: Control = $UI/EnemyBackrow
@onready var _screen_flash: ColorRect = $UI/ScreenFlash

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
	EventBus.energy_color_picked.connect(_on_energy_color_picked)
	EventBus.draw_cards_requested.connect(_on_draw_cards_requested)
	
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
	# If enemy_data was already set by a signal (from BattleOverlayManager), don't override it
	if enemy_data != null:
		return  # Battle already started with correct enemy data
	
	var enemy = load("res://resources/enemies/lost_wanderer.tres")
	if enemy:
		_on_battle_started(enemy)

func _load_enemy_deck_from_json(enemy: EnemyData) -> Array[CardData]:
	var result: Array[CardData] = []
	if not enemy:
		return result
	if enemy.deck_json_path.is_empty():
		return result
	if not _card_registry or not _card_registry.has_method("get_card"):
		push_warning("BattleManager: CardRegistry autoload missing; cannot load enemy deck json: " + enemy.deck_json_path)
		return result
	
	var file: FileAccess = FileAccess.open(enemy.deck_json_path, FileAccess.READ)
	if not file:
		push_warning("BattleManager: could not open enemy deck json: " + enemy.deck_json_path)
		return result
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("BattleManager: invalid enemy deck json (expected Dictionary): " + enemy.deck_json_path)
		return result
	
	var counts: Dictionary = parsed as Dictionary
	for key in counts.keys():
		var cid_str: String = String(key)
		var cid: StringName = StringName(cid_str)
		var count_raw: Variant = counts.get(key, 0)
		var count: int = 0
		if typeof(count_raw) == TYPE_INT:
			count = int(count_raw)
		elif typeof(count_raw) == TYPE_FLOAT:
			count = int(count_raw)
		elif typeof(count_raw) == TYPE_STRING:
			count = int(String(count_raw).to_int())
		
		if count <= 0:
			continue
		
		var cd: CardData = _card_registry.call("get_card", cid) as CardData
		if not cd:
			push_warning("BattleManager: enemy deck json references unknown card_id '" + cid_str + "' (" + enemy.deck_json_path + ")")
			continue
		
		for i in range(count):
			result.append(cd)
	
	return result

func _load_player_starter_deck_from_json() -> Array[CardData]:
	var result: Array[CardData] = []
	var path: String = "res://resources/player/decks/starting_deck.json"
	
	if not _card_registry or not _card_registry.has_method("get_card"):
		push_warning("BattleManager: CardRegistry autoload missing; cannot load player starter deck json")
		return result
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("BattleManager: could not open player starter deck json: " + path)
		return result
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("BattleManager: invalid player starter deck json (expected Dictionary): " + path)
		return result
	
	var counts: Dictionary = parsed as Dictionary
	for key in counts.keys():
		var cid_str: String = String(key)
		var cid: StringName = StringName(cid_str)
		var count_raw: Variant = counts.get(key, 0)
		var count: int = 0
		if typeof(count_raw) == TYPE_INT:
			count = int(count_raw)
		elif typeof(count_raw) == TYPE_FLOAT:
			count = int(count_raw)
		elif typeof(count_raw) == TYPE_STRING:
			count = int(String(count_raw).to_int())
		
		if count <= 0:
			continue
		
		var cd: CardData = _card_registry.call("get_card", cid) as CardData
		if not cd:
			push_warning("BattleManager: player starter deck json references unknown card_id '" + cid_str + "'")
			continue
		
		for i in range(count):
			result.append(cd)
	
	return result

func _setup_lanes() -> void:
	_player_lanes.clear()
	_enemy_lanes.clear()
	
	var player_lanes_container = $UI/PlayerSide
	var enemy_lanes_container = $UI/EnemySide
	
	if player_lanes_container:
		for i in range(min(3, player_lanes_container.get_child_count())):
			var lane = player_lanes_container.get_child(i)
			if lane and lane.has_method("set_lane_index"):
				lane.set_lane_index(i)
				lane.is_player_lane = true
				_player_lanes.append(lane)
	
	if enemy_lanes_container:
		for i in range(min(3, enemy_lanes_container.get_child_count())):
			var lane = enemy_lanes_container.get_child(i)
			if lane and lane.has_method("set_lane_index"):
				lane.set_lane_index(i)
				lane.is_player_lane = false
				_enemy_lanes.append(lane)
	
	# Setup backrow zones
	if _player_backrow_zone and _player_backrow_zone.has_method("set_player_zone"):
		_player_backrow_zone.set_player_zone(true)
	if _enemy_backrow_zone and _enemy_backrow_zone.has_method("set_player_zone"):
		_enemy_backrow_zone.set_player_zone(false)

func _connect_lane_clicks() -> void:
	# Connect lane click signals for card placement
	for i in range(_player_lanes.size()):
		var lane = _player_lanes[i]
		if lane and lane.has_signal("lane_clicked"):
			# Signal already emits lane_index, no need to bind
			if not lane.lane_clicked.is_connected(_on_lane_clicked):
				lane.lane_clicked.connect(_on_lane_clicked)

func _on_lane_clicked(lane_index: int) -> void:
	if _awaiting_energy_pick:
		return
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
	# Use persistent health if available, otherwise use max_life (first battle)
	var current_life: int = GameManager.player_max_life
	if GameManager.player_current_life >= 0:
		current_life = GameManager.player_current_life
	else:
		# First battle - initialize health
		GameManager.player_current_life = GameManager.player_max_life
		current_life = GameManager.player_max_life
	battle_state.initialize_player(GameManager.player_max_life, current_life, 3)
	battle_state.initialize_enemy(enemy_data.max_life, 3)
	
	# Initialize UI components
	if _player_life_bar and _player_life_bar.has_method("initialize"):
		_player_life_bar.initialize(true, battle_state.player_max_life, battle_state.player_life)
	if _enemy_life_bar and _enemy_life_bar.has_method("initialize"):
		_enemy_life_bar.initialize(false, battle_state.enemy_max_life)
	if _player_energy_display and _player_energy_display.has_method("initialize"):
		_player_energy_display.initialize(true, battle_state.get_player_max_energy_total())
	if _enemy_energy_display and _enemy_energy_display.has_method("initialize"):
		_enemy_energy_display.initialize(false, battle_state.get_enemy_max_energy_total())
	
	# Create decks
	if GameManager.player_deck:
		# IMPORTANT: The exploration deck builder uses GameManager.player_deck as the persistent deck list.
		# Battles should use a runtime copy so draws/discards don't mutate the persistent deck.
		if GameManager.player_deck is Deck:
			var persistent_deck: Deck = GameManager.player_deck as Deck
			var card_data_list: Array[CardData] = []
			for inst in persistent_deck.cards:
				if inst and inst.data:
					card_data_list.append(inst.data)
			player_deck = Deck.new(card_data_list)
		else:
			# Fallback: if player_deck isn't a Deck instance, use it as-is.
			player_deck = GameManager.player_deck
	else:
		# Create starter deck from JSON
		var starter_cards: Array[CardData] = _load_player_starter_deck_from_json()
		if starter_cards.is_empty():
			push_warning("BattleManager: Could not load starter deck from JSON, using minimal fallback")
			# Minimal fallback deck
			var fallback_card: CardData = load("res://resources/cards/starter/wandering_soul.tres")
			if fallback_card:
				for i in range(10):
					starter_cards.append(fallback_card)
		player_deck = Deck.new(starter_cards)
		# Also set the persistent deck list for deck builder usage.
		GameManager.player_deck = Deck.new(starter_cards)
	
	# Create enemy deck (prefer JSON if configured; fallback to embedded deck_list)
	var enemy_card_list: Array[CardData] = _load_enemy_deck_from_json(enemy_data)
	if enemy_card_list.is_empty():
		for resource in enemy_data.deck_list:
			if resource is CardData:
				enemy_card_list.append(resource as CardData)
	enemy_deck = Deck.new(enemy_card_list)
	
	# Create AI
	enemy_ai = EnemyAI.new(enemy_data, battle_state, enemy_deck)
	
	# Initialize avatars
	var player_avatar_data: CardData = load("res://resources/cards/avatars/player_avatar.tres") as CardData
	var enemy_avatar_data: CardData = load("res://resources/cards/avatars/enemy_avatar.tres") as CardData
	
	if player_avatar_data and GameManager.player_stats:
		var player_attack: int = GameManager.player_stats.get_total_attack()
		battle_state.initialize_player_avatar(player_attack, player_avatar_data)
	
	if enemy_avatar_data and enemy_data:
		battle_state.initialize_enemy_avatar(enemy_data.base_attack, enemy_avatar_data)
	
	# Initialize avatar UI if available
	_initialize_avatar_ui()
	
	# Update enemy visuals (portrait and name) from enemy_data
	_update_enemy_visuals()
	
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

func _initialize_avatar_ui() -> void:
	# Use PlayerCard and EnemyCard as avatar slots
	_player_avatar_slot = _ui.get_node_or_null("PlayerCard")
	_enemy_avatar_slot = _ui.get_node_or_null("EnemyCard")
	
	# Initialize player avatar slot
	if _player_avatar_slot and battle_state.player_avatar:
		if _player_avatar_slot.has_method("set_avatar"):
			_player_avatar_slot.set_avatar(battle_state.player_avatar, true)
	
	# Initialize enemy avatar slot
	if _enemy_avatar_slot and battle_state.enemy_avatar:
		if _enemy_avatar_slot.has_method("set_avatar"):
			_enemy_avatar_slot.set_avatar(battle_state.enemy_avatar, false)

func _update_enemy_visuals() -> void:
	if not enemy_data:
		return
	
	# Update portrait texture
	var portrait_rect: TextureRect = _ui.get_node_or_null("EnemyCard/Frame/Portrait")
	if portrait_rect and enemy_data.portrait:
		portrait_rect.texture = enemy_data.portrait
	
	# Update enemy name label
	var name_label: Label = _ui.get_node_or_null("EnemyCard/EnemyHeader/HeaderContainer/EnemyPortrait")
	if name_label and not enemy_data.display_name.is_empty():
		name_label.text = enemy_data.display_name

func _on_draw_cards_requested(count: int, is_player: bool) -> void:
	if not battle_state:
		return
	var safe_count: int = maxi(0, count)
	if safe_count <= 0:
		return
	
	var drawn: Array[CardInstance] = []
	if is_player:
		if not player_deck:
			return
		drawn = player_deck.draw(safe_count)
		for card in drawn:
			battle_state.player_hand.append(card)
			EventBus.card_drawn.emit(card, true)
		EventBus.hand_updated.emit(battle_state.player_hand, true)
	else:
		if not enemy_deck:
			return
		drawn = enemy_deck.draw(safe_count)
		for card in drawn:
			battle_state.enemy_hand.append(card)
			EventBus.card_drawn.emit(card, false)
		EventBus.hand_updated.emit(battle_state.enemy_hand, false)

func start_player_turn() -> void:
	current_state = TurnPhase.PLAYER_TURN
	battle_state.start_player_turn()
	_awaiting_energy_pick = true
	if _end_turn_button:
		_end_turn_button.disabled = true
	
	# Draw card
	var drawn: Array[CardInstance] = player_deck.draw(1)
	if not drawn.is_empty():
		battle_state.player_hand.append(drawn[0])
		EventBus.card_drawn.emit(drawn[0], true)
		EventBus.hand_updated.emit(battle_state.player_hand, true)
	
	EventBus.turn_started.emit(battle_state.turn_number, true)
	EventBus.energy_color_pick_requested.emit(true)

func start_enemy_turn() -> void:
	current_state = TurnPhase.ENEMY_TURN
	battle_state.start_enemy_turn()
	_awaiting_energy_pick = false
	if _end_turn_button:
		_end_turn_button.disabled = true
	
	# Draw card
	var drawn: Array[CardInstance] = enemy_deck.draw(1)
	if not drawn.is_empty():
		battle_state.enemy_hand.append(drawn[0])
		EventBus.card_drawn.emit(drawn[0], false)
		EventBus.hand_updated.emit(battle_state.enemy_hand, false)
	
	# Enemy auto-picks an energy color after drawing.
	var enemy_pick: int = _choose_enemy_energy_color()
	battle_state.apply_enemy_energy_pick(enemy_pick)
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
				if await play_enemy_card_animated(card, lane):
					action_count += 1
					await get_tree().create_timer(0.2).timeout  # Brief delay between actions
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
	
	# Enemy avatar attack (once per turn)
	if can_enemy_avatar_attack():
		await get_tree().create_timer(0.3).timeout  # Brief delay before avatar attack
		await enemy_avatar_attack()
		await get_tree().create_timer(0.2).timeout  # Brief delay after attack
	
	# End turn after all actions
	end_turn()

func play_card(card: CardInstance, lane: int, is_player: bool) -> bool:
	if not card:
		return false
	if is_player and _awaiting_energy_pick:
		return false
	
	var state: BattleState = battle_state
	if not state or not card.data:
		return false
	
	# Affordability check (generic + colored pips).
	if is_player:
		if not state.can_afford_player_cost(card.data):
			return false
	else:
		if not state.can_afford_enemy_cost(card.data):
			return false
	
	# Place in lane (only for creatures)
	if card.data.is_creature():
		# Validate lane for creatures
		if lane < 0:
			# Invalid lane for creature
			return false
		var lane_count: int = state.player_lanes.size() if is_player else state.enemy_lanes.size()
		if lane >= lane_count:
			return false
		var lanes_arr: Array[CardInstance] = state.player_lanes if is_player else state.enemy_lanes
		if lanes_arr[lane] != null:
			return false
		
		# Spend energy now that placement is valid.
		var spent: bool = state.spend_player_cost(card.data) if is_player else state.spend_enemy_cost(card.data)
		if not spent:
			return false
		
		# Remove from hand
		if is_player:
			var index_p: int = state.player_hand.find(card)
			if index_p >= 0:
				state.player_hand.remove_at(index_p)
				EventBus.hand_updated.emit(state.player_hand, true)
		else:
			var index_e: int = state.enemy_hand.find(card)
			if index_e >= 0:
				state.enemy_hand.remove_at(index_e)
				EventBus.hand_updated.emit(state.enemy_hand, false)
		
		# Place in lane state
		lanes_arr[lane] = card
		
		# Update lane visual
		var lanes: Array = _player_lanes if is_player else _enemy_lanes
		if lane >= 0 and lane < lanes.size() and lanes[lane]:
			var lane_node = lanes[lane]
			if lane_node.has_method("place_card"):
				lane_node.place_card(card)
	elif card.data.card_type == CardData.CardType.TRAP or card.data.card_type == CardData.CardType.RELIC:
		# Handle traps and relics - place in backrow instead of executing
		var backrow: Array[CardInstance] = state.player_backrow if is_player else state.enemy_backrow
		if backrow.size() >= 3:
			return false  # Backrow is full
		
		# Spend energy
		var spent_backrow: bool = state.spend_player_cost(card.data) if is_player else state.spend_enemy_cost(card.data)
		if not spent_backrow:
			return false
		
		# Remove from hand
		if is_player:
			var index_br: int = state.player_hand.find(card)
			if index_br >= 0:
				state.player_hand.remove_at(index_br)
				EventBus.hand_updated.emit(state.player_hand, true)
		else:
			var index_bre: int = state.enemy_hand.find(card)
			if index_bre >= 0:
				state.enemy_hand.remove_at(index_bre)
				EventBus.hand_updated.emit(state.enemy_hand, false)
		
		# Add to backrow state
		backrow.append(card)
		
		# Update backrow zone visual
		var zone: Control = _player_backrow_zone if is_player else _enemy_backrow_zone
		if zone and zone.has_method("place_card"):
			zone.place_card(card, backrow.size() - 1)
	else:
		# Spend energy for non-creature cards (spells).
		var spent_spell: bool = state.spend_player_cost(card.data) if is_player else state.spend_enemy_cost(card.data)
		if not spent_spell:
			return false
		
		# Remove from hand
		if is_player:
			var index_ps: int = state.player_hand.find(card)
			if index_ps >= 0:
				state.player_hand.remove_at(index_ps)
				EventBus.hand_updated.emit(state.player_hand, true)
		else:
			var index_es: int = state.enemy_hand.find(card)
			if index_es >= 0:
				state.enemy_hand.remove_at(index_es)
				EventBus.hand_updated.emit(state.enemy_hand, false)
		
		# Non-creature cards (spells) - execute effects immediately
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

func play_spell_animated(card: CardInstance, is_player: bool = true) -> bool:
	## Play a spell with animated feedback. Returns true if spell was executed.
	## This is called after the animation completes for spells dropped in the play area.
	if not card or not card.data:
		return false
	if is_player and _awaiting_energy_pick:
		return false
	
	var state: BattleState = battle_state
	if not state:
		return false
	
	# Check affordability
	if is_player:
		if not state.can_afford_player_cost(card.data):
			return false
	else:
		if not state.can_afford_enemy_cost(card.data):
			return false
	
	# Spend energy
	var spent: bool = state.spend_player_cost(card.data) if is_player else state.spend_enemy_cost(card.data)
	if not spent:
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
	
	# Execute effect
	if card.data.on_play_effect:
		var context = EffectContext.new(state, card, is_player)
		context.target_lane = -1
		if card.data.on_play_effect.has_method("execute"):
			card.data.on_play_effect.execute(context)
	
	# Flash screen in spell color
	var spell_color: Color = get_card_color(card)
	flash_screen(spell_color, 0.3)
	
	EventBus.card_played.emit(card, -1, is_player)
	return true

const CARD_SCENE_PATH: String = "res://scenes/battle/card_ui/card_visual.tscn"
const CARD_ANIMATION_DURATION: float = 0.25

func play_card_animated_to_backrow(card: CardInstance, from_pos: Vector2, is_player: bool = true) -> void:
	## Animate a non-creature card from a position to the backrow, then execute it.
	## Used when dropping spells/traps/relics on lanes or the play area.
	if not card or not card.data:
		return
	
	# Get backrow zone for target position
	var backrow_zone: Control = _player_backrow_zone if is_player else _enemy_backrow_zone
	var target_pos: Vector2 = from_pos  # Default fallback
	
	if backrow_zone:
		target_pos = backrow_zone.global_position + backrow_zone.size / 2
	
	# Create temporary card visual
	var temp_visual: Control = _create_temp_card_visual(card, from_pos)
	if not temp_visual:
		# Fallback: just execute the action without animation
		_execute_backrow_card(card, is_player)
		return
	
	# Animate to backrow area
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Move and scale down slightly
	var target_visual_pos: Vector2 = target_pos - temp_visual.custom_minimum_size * 0.35
	tween.tween_property(temp_visual, "global_position", target_visual_pos, CARD_ANIMATION_DURATION)
	tween.parallel().tween_property(temp_visual, "scale", Vector2(0.7, 0.7), CARD_ANIMATION_DURATION)
	
	# On complete: handle based on card type
	tween.tween_callback(func():
		if is_instance_valid(temp_visual):
			_on_backrow_animation_complete(card, temp_visual, is_player)
	)

func _on_backrow_animation_complete(card: CardInstance, temp_visual: Control, is_player: bool) -> void:
	if not card or not card.data:
		if is_instance_valid(temp_visual):
			temp_visual.queue_free()
		return
	
	var card_type: int = card.data.card_type
	
	if card_type == CardData.CardType.SPELL:
		# Spell: flash screen, execute effect, remove visual
		play_spell_animated(card, is_player)
		
		# Fade out and remove the visual
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(temp_visual, "modulate:a", 0.0, 0.2)
		fade_tween.tween_callback(func():
			if is_instance_valid(temp_visual):
				temp_visual.queue_free()
		)
	else:
		# Trap or Relic: place in backrow, remove temp visual
		if is_instance_valid(temp_visual):
			temp_visual.queue_free()
		play_card(card, -1, is_player)

func _execute_backrow_card(card: CardInstance, is_player: bool) -> void:
	## Fallback execution when animation can't be created
	var card_type: int = card.data.card_type
	
	if card_type == CardData.CardType.SPELL:
		play_spell_animated(card, is_player)
	else:
		play_card(card, -1, is_player)

func _create_temp_card_visual(card: CardInstance, start_pos: Vector2) -> Control:
	## Create a temporary card visual for animation purposes
	var card_scene: PackedScene = load(CARD_SCENE_PATH) as PackedScene
	if not card_scene:
		return null
	
	var card_visual: Control = card_scene.instantiate() as Control
	if not card_visual:
		return null
	
	# Add to UI layer so it's visible above everything
	if _ui:
		_ui.add_child(card_visual)
	else:
		add_child(card_visual)
	
	# Position at start
	card_visual.global_position = start_pos - card_visual.custom_minimum_size / 2
	card_visual.z_index = 50  # Above other UI elements
	
	# Set the card data
	if card_visual.has_method("set_card"):
		card_visual.set_card(card)
	
	# Disable mouse interaction on the temp visual
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	return card_visual

const ENEMY_CARD_SCENE_PATH: String = "res://scenes/battle/card_ui/card_visual.tscn"
const ENEMY_ANIMATION_DURATION: float = 0.35

func play_enemy_card_animated(card: CardInstance, lane: int) -> bool:
	## Play an enemy card with animation from top of screen.
	## Returns true if card was successfully played.
	if not card or not card.data:
		return false
	
	var state: BattleState = battle_state
	if not state:
		return false
	
	# Check affordability before starting animation
	if not state.can_afford_enemy_cost(card.data):
		return false
	
	# Determine target position based on card type
	var target_pos: Vector2
	var is_creature: bool = card.data.is_creature()
	var is_spell: bool = card.data.card_type == CardData.CardType.SPELL
	
	if is_creature:
		# Target: enemy lane
		if lane < 0 or lane >= _enemy_lanes.size():
			return false
		var lane_node: Control = _enemy_lanes[lane] as Control
		if not lane_node:
			return false
		target_pos = lane_node.global_position + lane_node.size / 2
	else:
		# Target: enemy backrow zone
		if _enemy_backrow_zone:
			target_pos = _enemy_backrow_zone.global_position + _enemy_backrow_zone.size / 2
		else:
			# Fallback position
			target_pos = Vector2(get_viewport().get_visible_rect().size.x / 2, 200)
	
	# Create temporary card visual
	var card_scene: PackedScene = load(ENEMY_CARD_SCENE_PATH) as PackedScene
	if not card_scene:
		# Fallback: play without animation
		if is_spell:
			return play_spell_animated(card, false)
		else:
			return play_card(card, lane, false)
	
	var temp_visual: Control = card_scene.instantiate() as Control
	if not temp_visual:
		if is_spell:
			return play_spell_animated(card, false)
		else:
			return play_card(card, lane, false)
	
	# Add to UI layer
	_ui.add_child(temp_visual)
	
	# Position at top-center of screen
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var card_size: Vector2 = temp_visual.custom_minimum_size
	var start_pos: Vector2 = Vector2(viewport_size.x / 2 - card_size.x / 2, -card_size.y - 20)
	temp_visual.global_position = start_pos
	temp_visual.z_index = 50
	temp_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set the card data for visual display
	if temp_visual.has_method("set_card"):
		temp_visual.set_card(card)
	
	# Calculate target visual position (centered on target)
	var target_visual_pos: Vector2 = target_pos - card_size / 2
	if not is_creature:
		# Scale down for backrow
		target_visual_pos = target_pos - card_size * 0.35
	
	# Animate to destination
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(temp_visual, "global_position", target_visual_pos, ENEMY_ANIMATION_DURATION)
	if not is_creature:
		tween.parallel().tween_property(temp_visual, "scale", Vector2(0.7, 0.7), ENEMY_ANIMATION_DURATION)
	
	# Wait for animation to complete
	await tween.finished
	
	# Execute the card play
	var success: bool = false
	if is_spell:
		# Spell: execute with flash, then fade out visual
		success = play_spell_animated(card, false)
		
		# Fade out and remove
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(temp_visual, "modulate:a", 0.0, 0.2)
		await fade_tween.finished
		temp_visual.queue_free()
	else:
		# Creature, Trap, or Relic: play card and remove visual
		temp_visual.queue_free()
		success = play_card(card, lane, false)
	
	return success

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
	if _awaiting_energy_pick:
		return
	
	# Check if card is playable
	if not battle_state or not battle_state.can_afford_player_cost(card.data):
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

func _create_and_execute_effect_from_description(spell: CardInstance, target: CardInstance, lane: int, state: BattleState, is_player_target: bool) -> void:
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
		
		# Check for immediate death
		_combat_resolver.check_immediate_death(target, lane, is_player_target, state)
	
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
	var state: BattleState = battle_state
	
	# Spend energy
	if not state.spend_player_cost(spell_to_cast.data):
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
		# Check for immediate death after effect execution
		_combat_resolver.check_immediate_death(target_card, lane, _is_player, state)
	else:
		# Spell has no effect resource - create one based on description
		_create_and_execute_effect_from_description(spell_to_cast, target_card, lane, state, _is_player)
	
	# Flash screen for targeting spell visual feedback
	var spell_color: Color = get_card_color(spell_to_cast)
	flash_screen(spell_color, 0.3)
	
	# Emit card played signal
	EventBus.card_played.emit(spell_to_cast, lane, true)
	
	# Exit targeting mode if we were in it
	if _targeting_mode:
		_targeting_spell = null
		_targeting_mode = false
		EventBus.targeting_cancelled.emit()

func _on_target_selected(target: CardInstance, lane: int, is_player: bool) -> void:
	target_creature(target, lane, is_player)

func target_avatar(avatar_target: CardInstance, is_player_target: bool, spell: CardInstance = null) -> void:
	# Allow spell to be passed directly (for drag-and-drop) or use _targeting_spell (for click targeting)
	var spell_to_cast: CardInstance = spell if spell else _targeting_spell
	
	if not spell_to_cast:
		return
	
	# If using click targeting mode, verify we're in targeting mode
	if not spell and (not _targeting_mode or not _targeting_spell):
		return
	
	# Validate target
	if not avatar_target:
		return
	
	# Play the spell with avatar as target
	var state: BattleState = battle_state
	
	# Spend energy
	if not state.spend_player_cost(spell_to_cast.data):
		if _targeting_mode:
			cancel_targeting()
		return
	
	# Remove from hand
	var index: int = state.player_hand.find(spell_to_cast)
	if index >= 0:
		state.player_hand.remove_at(index)
		EventBus.hand_updated.emit(state.player_hand, true)
	
	# Execute effect - for avatars, damage goes to life total
	if spell_to_cast.data.on_play_effect:
		# For avatars, we need special handling
		# If it's a damage effect, apply damage to life total
		var desc_lower: String = spell_to_cast.data.description.to_lower()
		if desc_lower.contains("deal") and desc_lower.contains("damage"):
			var damage_amount: int = 2  # Default
			var words: Array = spell_to_cast.data.description.split(" ")
			for i in range(words.size()):
				if words[i].to_lower() == "deal":
					if i + 1 < words.size():
						var num_str: String = words[i + 1]
						if num_str.is_valid_int():
							damage_amount = num_str.to_int()
			
			if is_player_target:
				state.deal_damage_to_player(damage_amount)
			else:
				state.deal_damage_to_enemy(damage_amount)
	
	# Emit card played signal
	EventBus.card_played.emit(spell_to_cast, -1, true)
	
	# Exit targeting mode if we were in it
	if _targeting_mode:
		_targeting_spell = null
		_targeting_mode = false
		EventBus.targeting_cancelled.emit()

## Avatar Attack Methods

func can_player_avatar_attack() -> bool:
	if current_state != TurnPhase.PLAYER_TURN:
		return false
	if _awaiting_energy_pick:
		return false
	if not battle_state or not battle_state.player_avatar:
		return false
	if battle_state.player_avatar.has_attacked_this_turn:
		return false
	return true

func player_avatar_attack_avatar() -> void:
	if not can_player_avatar_attack():
		return
	
	if not battle_state.enemy_avatar:
		return
	
	# Player avatar attacks enemy avatar - damage goes to enemy life
	var damage: int = battle_state.player_avatar.current_attack
	battle_state.deal_damage_to_enemy(damage)
	battle_state.player_avatar.has_attacked_this_turn = true
	
	# Emit avatar attacked event
	EventBus.avatar_attacked.emit(true, false, damage)
	
	# Check for battle end
	if battle_state.is_battle_over():
		end_battle()

func player_avatar_attack_creature(lane: int) -> void:
	if not can_player_avatar_attack():
		return
	
	if lane < 0 or lane >= battle_state.enemy_lanes.size():
		return
	
	var target: CardInstance = battle_state.enemy_lanes[lane]
	if not target or not target.is_alive():
		return
	
	# Use combat resolver for avatar attacking creature
	if _combat_resolver and _combat_resolver.has_method("avatar_attack_creature"):
		_combat_resolver.avatar_attack_creature(battle_state.player_avatar, target, battle_state, true)
	
	# Sync lane visuals after attack
	_sync_lane_visuals()
	
	# Check for battle end
	if battle_state.is_battle_over():
		end_battle()

func can_enemy_avatar_attack() -> bool:
	if current_state != TurnPhase.ENEMY_TURN:
		return false
	if not battle_state or not battle_state.enemy_avatar:
		return false
	if battle_state.enemy_avatar.has_attacked_this_turn:
		return false
	return true

func enemy_avatar_attack() -> void:
	if not can_enemy_avatar_attack():
		return
	
	# Simple AI: Prefer attacking player avatar directly, but attack creatures if they exist
	var target_type: String = "avatar"  # Default to avatar
	var target_lane: int = -1
	
	# Check if there are player creatures to attack
	for i in range(battle_state.player_lanes.size()):
		var card: CardInstance = battle_state.player_lanes[i]
		if card and card.is_alive():
			# Found a creature, may attack it instead
			# For now, still prefer direct damage to avatar
			target_lane = i
			break
	
	# Get target position for animation
	var target_pos: Vector2 = Vector2.ZERO
	
	if target_type == "avatar":
		# Attack player avatar
		if _player_avatar_slot:
			target_pos = _player_avatar_slot.global_position + _player_avatar_slot.size / 2
		
		# Play bump animation on enemy avatar
		if _enemy_avatar_slot and _enemy_avatar_slot.has_method("play_attack_animation"):
			await _enemy_avatar_slot.play_attack_animation(target_pos)
		
		# Deal damage to player
		var damage: int = battle_state.enemy_avatar.current_attack
		battle_state.deal_damage_to_player(damage)
		battle_state.enemy_avatar.has_attacked_this_turn = true
		
		# Emit avatar attacked event
		EventBus.avatar_attacked.emit(false, true, damage)
	else:
		# Attack player creature
		if target_lane >= 0 and target_lane < _player_lanes.size():
			var lane_node = _player_lanes[target_lane]
			if lane_node:
				target_pos = lane_node.global_position + lane_node.size / 2
		
		# Play bump animation
		if _enemy_avatar_slot and _enemy_avatar_slot.has_method("play_attack_animation"):
			await _enemy_avatar_slot.play_attack_animation(target_pos)
		
		# Use combat resolver
		var target: CardInstance = battle_state.player_lanes[target_lane]
		if target and target.is_alive() and _combat_resolver and _combat_resolver.has_method("avatar_attack_creature"):
			_combat_resolver.avatar_attack_creature(battle_state.enemy_avatar, target, battle_state, false)
		
		# Sync lane visuals
		_sync_lane_visuals()
	
	# Check for battle end
	if battle_state.is_battle_over():
		end_battle()

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
	if _awaiting_energy_pick:
		return
	
	# Check if card is playable
	if not card or not battle_state:
		return
	
	if not battle_state.can_afford_player_cost(card.data):
		# Not enough energy, don't select
		return
	
	# Select the card
	_selected_card = card

func _on_card_deselected() -> void:
	_selected_card = null

func resolve_combat() -> void:
	current_state = TurnPhase.RESOLVING
	
	if _combat_resolver:
		await _combat_resolver.resolve_combat(battle_state, self)
	
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
		if _awaiting_energy_pick:
			return
		EventBus.turn_ended.emit(battle_state.turn_number, true)
		resolve_combat()
	elif current_state == TurnPhase.ENEMY_TURN:
		EventBus.turn_ended.emit(battle_state.turn_number, false)
		resolve_combat()

func _choose_enemy_energy_color() -> int:
	# Delegate to enemy AI for extensibility
	return enemy_ai.choose_energy_color()
	
	# Old heuristic (kept for reference):
	# Picks color based on unmet pip needs in hand
	# var need_r: int = 0
	# var need_b: int = 0
	# var need_g: int = 0
	# for card in battle_state.enemy_hand:
	# 	if not card or not card.data:
	# 		continue
	# 	need_r += maxi(0, card.data.get_red_pips() - battle_state.enemy_energy_red)
	# 	need_b += maxi(0, card.data.get_blue_pips() - battle_state.enemy_energy_blue)
	# 	need_g += maxi(0, card.data.get_green_pips() - battle_state.enemy_energy_green)
	# if need_r >= need_b and need_r >= need_g:
	# 	return COLOR_RED
	# if need_b >= need_r and need_b >= need_g:
	# 	return COLOR_BLUE
	# return COLOR_GREEN

func _on_energy_color_picked(color: int, is_player: bool) -> void:
	if not is_player:
		return
	if current_state != TurnPhase.PLAYER_TURN:
		return
	if not _awaiting_energy_pick:
		return
	if not battle_state:
		return
	battle_state.apply_player_energy_pick(color)
	_awaiting_energy_pick = false
	if _end_turn_button:
		_end_turn_button.disabled = false

func end_battle() -> void:
	current_state = TurnPhase.END
	
	# Save persistent health before battle ends
	if battle_state:
		# Save current life (stays at 0 if player died, no auto-heal)
		GameManager.player_current_life = battle_state.player_life
		# Emit signal to notify UI systems of health change
		EventBus.player_health_changed.emit(GameManager.player_current_life, GameManager.player_max_life)
	
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

func flash_screen(color: Color, duration: float = 0.3) -> void:
	## Flash the screen with the given color for visual feedback.
	if not _screen_flash:
		return
	
	# Set the flash color with alpha
	var flash_color: Color = color
	flash_color.a = 0.5
	_screen_flash.color = flash_color
	
	# Create tween for fade out
	var tween: Tween = create_tween()
	tween.tween_property(_screen_flash, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)

func get_card_color(card: CardInstance) -> Color:
	## Get the dominant color of a card based on its cost pips.
	if not card or not card.data:
		return Color(1, 1, 1, 0.5)  # White default
	
	var data: CardData = card.data
	var red: int = data.cost_red
	var blue: int = data.cost_blue
	var green: int = data.cost_green
	
	if red > blue and red > green:
		return Color(1.0, 0.3, 0.3, 0.5)  # Red
	elif blue > red and blue > green:
		return Color(0.3, 0.5, 1.0, 0.5)  # Blue
	elif green > red and green > blue:
		return Color(0.3, 1.0, 0.4, 0.5)  # Green
	elif red > 0 or blue > 0 or green > 0:
		# Mixed or equal - pick highest or default to first non-zero
		if red >= blue and red >= green and red > 0:
			return Color(1.0, 0.3, 0.3, 0.5)
		elif blue >= red and blue >= green and blue > 0:
			return Color(0.3, 0.5, 1.0, 0.5)
		elif green > 0:
			return Color(0.3, 1.0, 0.4, 0.5)
	
	return Color(0.8, 0.8, 0.8, 0.5)  # Gray for colorless

func _exit_tree() -> void:
	if EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.disconnect(_on_battle_started)
	if EventBus.card_played.is_connected(_on_card_played):
		EventBus.card_played.disconnect(_on_card_played)
	if EventBus.card_selected.is_connected(_on_card_selected):
		EventBus.card_selected.disconnect(_on_card_selected)
	if EventBus.card_deselected.is_connected(_on_card_deselected):
		EventBus.card_deselected.disconnect(_on_card_deselected)
	if EventBus.energy_color_picked.is_connected(_on_energy_color_picked):
		EventBus.energy_color_picked.disconnect(_on_energy_color_picked)
	if EventBus.draw_cards_requested.is_connected(_on_draw_cards_requested):
		EventBus.draw_cards_requested.disconnect(_on_draw_cards_requested)
	if _end_turn_button and _end_turn_button.pressed.is_connected(end_turn):
		_end_turn_button.pressed.disconnect(end_turn)
