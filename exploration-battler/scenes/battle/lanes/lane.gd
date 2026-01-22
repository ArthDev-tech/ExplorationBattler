extends Control

## Manages a single lane in the battle arena with visual representation.

signal card_placed(card: CardInstance)
signal card_removed(card: CardInstance)

var lane_index: int = 0
var current_card: CardInstance = null
var is_player_lane: bool = true
var _card_visual: Control = null
var _is_drag_over: bool = false
var _dragged_card: CardInstance = null
var _is_avatar_attack_drag: bool = false

@onready var _background: Panel = $Background
@onready var _lane_label: Label = $LaneLabel
@onready var _card_slot: Control = $CardSlot

var CARD_SCENE: PackedScene = null

signal lane_clicked(lane_index: int)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP  # Ensure lanes receive mouse input
	_lane_label.text = "Lane " + str(lane_index + 1)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	# Connect targeting signals
	EventBus.targeting_started.connect(_on_targeting_started)
	EventBus.targeting_cancelled.connect(_on_targeting_cancelled)
	
	# Connect card stat change signals
	EventBus.card_stats_changed.connect(_on_card_stats_changed)
	EventBus.card_died.connect(_on_card_died)
	
	# Ensure Background Panel doesn't block drop events - set to PASS so events reach parent Control
	if _background:
		_background.mouse_filter = MOUSE_FILTER_PASS
		# Create a unique StyleBoxFlat instance for this lane to avoid shared state
		var existing_style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if existing_style:
			var new_style: StyleBoxFlat = existing_style.duplicate()
			_background.add_theme_stylebox_override("panel", new_style)
	
	# Ensure CardSlot doesn't block events either
	if _card_slot:
		_card_slot.mouse_filter = MOUSE_FILTER_PASS
	
	# Lane initialized

func set_lane_index(index: int) -> void:
	lane_index = index
	if _lane_label:
		_lane_label.text = "Lane " + str(index + 1)

func place_card(card: CardInstance) -> bool:
	if current_card != null:
		return false  # Lane occupied
	
	current_card = card
	
	# Create visual representation
	if not CARD_SCENE:
		CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene
	
	if CARD_SCENE:
		_card_visual = CARD_SCENE.instantiate()
		_card_slot.add_child(_card_visual)
		# Ensure card maintains its size and centers in the slot
		_card_visual.size = _card_visual.custom_minimum_size
		_card_visual.anchors_preset = Control.PRESET_CENTER
		if _card_visual.has_method("set_card"):
			_card_visual.set_card(card)
		# Store original position for animations (after card is placed and positioned)
		if _card_visual.has_method("_store_original_position"):
			_card_visual.call_deferred("_store_original_position")
	
	card_placed.emit(card)
	_update_visual_state()
	return true

func remove_card() -> CardInstance:
	var card: CardInstance = current_card
	current_card = null
	
	# Remove visual
	if _card_visual:
		_card_visual.queue_free()
		_card_visual = null
	
	if card:
		card_removed.emit(card)
	
	_update_visual_state()
	return card

func has_card() -> bool:
	return current_card != null

func get_card() -> CardInstance:
	return current_card

func get_card_visual() -> Control:
	## Returns the card visual Control node if it exists.
	return _card_visual

func is_empty() -> bool:
	return current_card == null

func _update_visual_state() -> void:
	# Update background color based on state
	if _background:
		var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if style:
			if current_card:
				style.bg_color = Color(0.4, 0.4, 0.4, 0.7)  # Occupied
			else:
				style.bg_color = Color(0.3, 0.3, 0.3, 0.5)  # Empty

func _on_mouse_entered() -> void:
	if _is_targeting_mode():
		# Only highlight THIS lane if it can be targeted
		_update_targeting_visual()
	else:
		# Normal hover - only highlight THIS lane
		_update_hover_visual(true)

func _on_mouse_exited() -> void:
	# Reset drag visual state when mouse exits
	_dragged_card = null
	_is_drag_over = false
	_update_drag_visual()
	
	if _is_targeting_mode():
		# Reset THIS lane's targeting visual (but keep it targetable)
		_update_targeting_visual_reset()
	else:
		# Reset hover highlight for THIS lane
		_update_hover_visual(false)

func _on_gui_input(event: InputEvent) -> void:
	# Handle targeting clicks
	if _is_targeting_mode():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.is_echo():
				_handle_targeting_click()
				accept_event()
				return
	
	# Only handle clicks if not during a drag operation
	# Don't consume events that might be part of drag-and-drop
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if this is part of a drag operation - if so, don't handle it
		if not event.is_echo():
			if is_player_lane:
				lane_clicked.emit(lane_index)

func _get_battle_manager() -> Node:
	# Try multiple paths to find battle manager
	var paths = [
		"/root/BattleArena",
		"../../BattleArena",
		"../../../BattleArena"
	]
	for path in paths:
		var manager = get_node_or_null(path)
		if manager and manager.has_method("play_card"):
			return manager
	return null

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	# Reset state
	_dragged_card = null
	_is_avatar_attack_drag = false
	_is_drag_over = false
	
	# Check for avatar attack data (Dictionary with type "avatar_attack")
	if data is Dictionary:
		var dict_data: Dictionary = data as Dictionary
		if dict_data.get("type") == "avatar_attack" and dict_data.get("is_player") == true:
			# Avatar attacks can only target enemy lanes with creatures
			if not is_player_lane and current_card != null and current_card.is_alive():
				_is_avatar_attack_drag = true
				_is_drag_over = true
				_update_drag_visual()
				return true
			_update_drag_visual()
			return false
	
	# Check if data is a CardInstance - use proper type checking
	if data == null or not data is CardInstance:
		_update_drag_visual()
		return false
	
	var card: CardInstance = data as CardInstance
	if not card or not card.data:
		_update_drag_visual()
		return false
	
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		_update_drag_visual()
		return false
	
	var battle_state = battle_manager.get("battle_state")
	if not battle_state:
		_update_drag_visual()
		return false
	
	# Block plays until player picks start-of-turn energy color.
	if battle_manager.get("_awaiting_energy_pick") == true:
		_update_drag_visual()
		return false
	
	# Check if player can afford this card (generic + colored pips).
	if not battle_state.can_afford_player_cost(card.data):
		_update_drag_visual()
		return false
	
	# Track drag state for visual feedback
	_dragged_card = card
	var can_drop: bool = false
	
	# Handle creatures: only on player lanes, lane must be empty
	if card.data.is_creature():
		if is_player_lane and current_card == null:
			can_drop = true
	
	# Handle spells: can target creatures in any lane (player or enemy)
	elif not card.data.is_creature():
		var needs_target: bool = false
		if battle_manager.has_method("spell_needs_target"):
			needs_target = battle_manager.spell_needs_target(card)
		
		if needs_target:
			# Spell needs target - check if this lane has a valid target
			can_drop = _can_be_targeted()
		else:
			# Spell doesn't need target - can drop anywhere
			can_drop = true
	
	# Update visual state
	_is_drag_over = can_drop
	_update_drag_visual()
	
	return can_drop

func _drop_data(_position: Vector2, data: Variant) -> void:
	var was_avatar_attack: bool = _is_avatar_attack_drag
	
	# Reset drag visual state
	_dragged_card = null
	_is_drag_over = false
	_is_avatar_attack_drag = false
	_update_drag_visual()
	
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		return
	
	# Handle avatar attack drop
	if was_avatar_attack and data is Dictionary:
		var dict_data: Dictionary = data as Dictionary
		if dict_data.get("type") == "avatar_attack" and dict_data.get("is_player") == true:
			# Player avatar attacks creature in this lane
			if not is_player_lane and current_card != null and current_card.is_alive():
				if battle_manager.has_method("player_avatar_attack_creature"):
					battle_manager.player_avatar_attack_creature(lane_index)
			return
	
	# Verify data is CardInstance
	if data == null or not data is CardInstance:
		return
	
	var card: CardInstance = data as CardInstance
	if not card:
		return
	
	# Handle creatures: play in lane
	if card.data.is_creature():
		if is_player_lane and battle_manager.has_method("play_card"):
			battle_manager.play_card(card, lane_index, true)
		return
	
	# Handle spells
	if not card.data.is_creature():
		var needs_target: bool = false
		if battle_manager.has_method("spell_needs_target"):
			needs_target = battle_manager.spell_needs_target(card)
		
		if needs_target:
			# Spell needs target - check if lane has valid target
			if _can_be_targeted() and battle_manager.has_method("target_creature"):
				# Pass spell directly to target_creature (drag-and-drop mode)
				battle_manager.target_creature(current_card, lane_index, is_player_lane, card)
			else:
				pass
		else:
			# Spell doesn't need target - play immediately
			if battle_manager.has_method("play_card"):
				battle_manager.play_card(card, -1, true)

func _is_targeting_mode() -> bool:
	var battle_manager = _get_battle_manager()
	if battle_manager and battle_manager.has_method("get") and battle_manager.get("_targeting_mode"):
		return battle_manager._targeting_mode
	return false

func _can_be_targeted() -> bool:
	# Check if this lane has a creature that can be targeted
	if not current_card:
		return false
	
	if not current_card.is_alive():
		return false
	
	# Check if target is phasing (can't be targeted)
	if current_card.is_phasing:
		return false
	
	return true

func _handle_targeting_click() -> void:
	if not _can_be_targeted():
		return
	
	var battle_manager = _get_battle_manager()
	if battle_manager and battle_manager.has_method("target_creature"):
		battle_manager.target_creature(current_card, lane_index, is_player_lane)
	else:
		pass

func _on_targeting_started(_card: CardInstance) -> void:
	# Don't highlight immediately - only highlight on hover
	# Just ensure we're ready for targeting mode
	pass

func _on_targeting_cancelled() -> void:
	# Reset visual state when targeting is cancelled
	_update_visual_state()

func _on_card_stats_changed(card: CardInstance) -> void:
	# Update visual if this lane's card stats changed
	if card == current_card and _card_visual:
		if _card_visual.has_method("update_visual_state"):
			_card_visual.update_visual_state()

func _on_card_died(card: CardInstance, lane: int, is_player: bool) -> void:
	# Remove card visual if this card died in this lane
	if card == current_card and lane == lane_index and is_player == is_player_lane:
		remove_card()

func _update_hover_visual(hovering: bool) -> void:
	# Update hover highlight for this lane only
	if not _background:
		return
	
	var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	if not style:
		return
	
	if hovering:
		# Yellow highlight for hover
		style.border_color = Color(0.8, 0.8, 0.2, 1)  # Yellow highlight
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	else:
		# Reset to default
		style.border_color = Color(0.5, 0.5, 0.5, 1)  # Default
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2

func _update_targeting_visual() -> void:
	# Highlight if this lane can be targeted (only called on hover during targeting mode)
	if not _background:
		return
	
	var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	if not style:
		return
	
	if _can_be_targeted():
		# Highlight valid target with blue border
		style.border_color = Color(0.2, 0.6, 1.0, 1.0)  # Blue highlight
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
	else:
		# Gray out invalid targets
		style.border_color = Color(0.3, 0.3, 0.3, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2

func _update_targeting_visual_reset() -> void:
	# Reset targeting visual but keep lane in targeting mode (called on mouse exit)
	if not _background:
		return
	
	var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	if not style:
		return
	
	# Reset to default border, but keep targeting mode state
	style.border_color = Color(0.5, 0.5, 0.5, 0.5)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

func _update_drag_visual() -> void:
	# Highlight valid drop targets while dragging
	if not _background:
		return
	
	var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	if not style:
		return
	
	if _is_drag_over:
		if _is_avatar_attack_drag:
			# Red border for avatar attack target
			style.border_color = Color(1.0, 0.3, 0.3, 1.0)  # Red highlight
			style.border_width_left = 4
			style.border_width_top = 4
			style.border_width_right = 4
			style.border_width_bottom = 4
		elif _dragged_card:
			# Highlight valid drop target with green border
			style.border_color = Color(0.2, 1.0, 0.4, 1.0)  # Green highlight
			style.border_width_left = 4
			style.border_width_top = 4
			style.border_width_right = 4
			style.border_width_bottom = 4
		else:
			# Reset to normal state
			style.border_color = Color(0.5, 0.5, 0.5, 0.5)
			style.border_width_left = 1
			style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1

func _exit_tree() -> void:
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)
	if gui_input.is_connected(_on_gui_input):
		gui_input.disconnect(_on_gui_input)
	if EventBus.targeting_started.is_connected(_on_targeting_started):
		EventBus.targeting_started.disconnect(_on_targeting_started)
	if EventBus.targeting_cancelled.is_connected(_on_targeting_cancelled):
		EventBus.targeting_cancelled.disconnect(_on_targeting_cancelled)
	if EventBus.card_stats_changed.is_connected(_on_card_stats_changed):
		EventBus.card_stats_changed.disconnect(_on_card_stats_changed)
	if EventBus.card_died.is_connected(_on_card_died):
		EventBus.card_died.disconnect(_on_card_died)
