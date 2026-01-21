extends Control

## Player card avatar - allows the player card to be targeted by spells, displays attack value,
## and can be dragged to attack enemy avatar or creatures once per turn.

signal avatar_clicked(is_player: bool)

const IS_PLAYER_AVATAR: bool = true

var avatar_instance: CardInstance = null
var _is_drag_over: bool = false
var _dragged_card: CardInstance = null
var _original_position: Vector2 = Vector2.ZERO

@onready var _frame: ColorRect = $Frame
@onready var _attack_label: Label = $AttackLabel
@onready var _attack_border: Panel = $AttackBorder

# Border colors for attack state indicator
const BORDER_CAN_ATTACK: Color = Color(0.6, 0.6, 0.6)  # Light grey
const BORDER_ALREADY_ATTACKED: Color = Color(0.3, 0.3, 0.3)  # Dark grey
const BORDER_WIDTH: int = 4

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	# Store original position for drag return
	_original_position = position
	
	# Connect targeting signals
	EventBus.targeting_started.connect(_on_targeting_started)
	EventBus.targeting_cancelled.connect(_on_targeting_cancelled)
	
	# Connect turn signals to update border state
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.avatar_attacked.connect(_on_avatar_attacked)
	
	# Ensure Frame doesn't block drop events
	if _frame:
		_frame.mouse_filter = MOUSE_FILTER_PASS
	
	# Initialize attack border
	_setup_attack_border()
	_update_attack_border()

func set_avatar(avatar: CardInstance, _is_player: bool) -> void:
	avatar_instance = avatar
	_update_display()
	_update_attack_border()

func _update_display() -> void:
	if avatar_instance and _attack_label:
		_attack_label.text = "ATK: " + str(avatar_instance.current_attack)
	elif _attack_label:
		_attack_label.text = ""

func _setup_attack_border() -> void:
	if not _attack_border:
		return
	
	# Create StyleBoxFlat for the border
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Transparent fill
	style.border_width_left = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.border_color = BORDER_CAN_ATTACK
	
	_attack_border.add_theme_stylebox_override("panel", style)

func _update_attack_border() -> void:
	if not _attack_border:
		return
	
	var style: StyleBoxFlat = _attack_border.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	
	if can_avatar_attack():
		style.border_color = BORDER_CAN_ATTACK  # Light grey - can attack
	else:
		style.border_color = BORDER_ALREADY_ATTACKED  # Dark grey - already attacked

func _on_turn_started(_turn: int, is_player: bool) -> void:
	if is_player:
		# Refresh border state when player turn starts
		_update_attack_border()

func _on_avatar_attacked(attacker_is_player: bool, _target_is_player: bool, _damage: int) -> void:
	if attacker_is_player:
		# Player avatar just attacked, update border to show attacked state
		_update_attack_border()

func update_attack(new_attack: int) -> void:
	if avatar_instance:
		avatar_instance.current_attack = new_attack
	_update_display()

func get_avatar() -> CardInstance:
	return avatar_instance

func can_avatar_attack() -> bool:
	if not avatar_instance:
		return false
	
	# Check if avatar has already attacked this turn
	if avatar_instance.has_attacked_this_turn:
		return false
	
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		return false
	
	# Check if it's player turn
	var current_state = battle_manager.get("current_state")
	if current_state != 1:  # TurnPhase.PLAYER_TURN = 1
		return false
	
	# Check if awaiting energy pick
	if battle_manager.get("_awaiting_energy_pick") == true:
		return false
	
	return true

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not can_avatar_attack():
		return null
	
	# Store original position
	_original_position = global_position
	
	# Create drag preview - duplicate this control for a proper visual
	var preview: Control = duplicate()
	preview.size = size
	preview.modulate = Color(1.0, 1.0, 1.0, 0.7)  # Semi-transparent
	preview.mouse_filter = MOUSE_FILTER_IGNORE
	preview.z_index = 100  # Ensure it appears above other UI
	
	# Disable mouse on all children to prevent interference
	_disable_mouse_recursively(preview)
	
	set_drag_preview(preview)
	
	# Return data identifying this as an avatar attack
	return {"type": "avatar_attack", "is_player": true, "avatar": avatar_instance}

func _disable_mouse_recursively(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse_recursively(child)

func _on_mouse_entered() -> void:
	if _is_targeting_mode():
		_update_targeting_visual()
	else:
		_update_hover_visual(true)

func _on_mouse_exited() -> void:
	_dragged_card = null
	_is_drag_over = false
	_update_drag_visual()
	
	if _is_targeting_mode():
		_update_targeting_visual_reset()
	else:
		_update_hover_visual(false)

func _on_gui_input(event: InputEvent) -> void:
	# Handle targeting clicks
	if _is_targeting_mode():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not event.is_echo():
				_handle_targeting_click()
				accept_event()
				return
	
	# Handle avatar clicks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.is_echo():
			avatar_clicked.emit(IS_PLAYER_AVATAR)

func _get_battle_manager() -> Node:
	var paths = [
		"/root/BattleArena",
		"../../BattleArena",
		"../../../BattleArena",
		"../../../../BattleArena"
	]
	for path in paths:
		var manager = get_node_or_null(path)
		if manager and manager.has_method("play_card"):
			return manager
	return null

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if data == null or not data is CardInstance:
		_dragged_card = null
		_is_drag_over = false
		_update_drag_visual()
		return false
	
	var card: CardInstance = data as CardInstance
	if not card or not card.data:
		_dragged_card = null
		_is_drag_over = false
		_update_drag_visual()
		return false
	
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		_dragged_card = null
		_is_drag_over = false
		_update_drag_visual()
		return false
	
	var battle_state = battle_manager.get("battle_state")
	if not battle_state:
		_dragged_card = null
		_is_drag_over = false
		_update_drag_visual()
		return false
	
	# Block plays until player picks start-of-turn energy color
	if battle_manager.get("_awaiting_energy_pick") == true:
		_dragged_card = null
		_is_drag_over = false
		_update_drag_visual()
		return false
	
	# Check if player can afford this card
	if not battle_state.can_afford_player_cost(card.data):
		_dragged_card = null
		_is_drag_over = false
		_update_drag_visual()
		return false
	
	_dragged_card = card
	var can_drop: bool = false
	
	# Only spells can target avatars
	if not card.data.is_creature():
		var needs_target: bool = false
		if battle_manager.has_method("spell_needs_target"):
			needs_target = battle_manager.spell_needs_target(card)
		
		if needs_target:
			can_drop = _can_be_targeted()
		else:
			can_drop = false
	
	_is_drag_over = can_drop
	_update_drag_visual()
	
	return can_drop

func _drop_data(_position: Vector2, data: Variant) -> void:
	_dragged_card = null
	_is_drag_over = false
	_update_drag_visual()
	
	if data == null or not data is CardInstance:
		return
	
	var card: CardInstance = data as CardInstance
	if not card:
		return
	
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		return
	
	# Handle spells targeting avatar
	if not card.data.is_creature():
		var needs_target: bool = false
		if battle_manager.has_method("spell_needs_target"):
			needs_target = battle_manager.spell_needs_target(card)
		
		if needs_target and _can_be_targeted():
			if battle_manager.has_method("target_avatar"):
				battle_manager.target_avatar(avatar_instance, IS_PLAYER_AVATAR, card)

func _is_targeting_mode() -> bool:
	var battle_manager = _get_battle_manager()
	if battle_manager and battle_manager.has_method("get") and battle_manager.get("_targeting_mode"):
		return battle_manager._targeting_mode
	return false

func _can_be_targeted() -> bool:
	if not avatar_instance:
		return false
	return true

func _handle_targeting_click() -> void:
	if not _can_be_targeted():
		return
	
	var battle_manager = _get_battle_manager()
	if battle_manager and battle_manager.has_method("target_avatar"):
		battle_manager.target_avatar(avatar_instance, IS_PLAYER_AVATAR)

func _on_targeting_started(_card: CardInstance) -> void:
	pass

func _on_targeting_cancelled() -> void:
	_update_hover_visual(false)

func _update_hover_visual(hovering: bool) -> void:
	if not _frame:
		return
	
	if hovering:
		_frame.color = Color(0.15, 0.15, 0.2, 0.95)  # Slightly lighter on hover
	else:
		_frame.color = Color(0.08, 0.08, 0.1, 0.95)  # Default color

func _update_targeting_visual() -> void:
	if not _frame:
		return
	
	if _can_be_targeted():
		_frame.color = Color(0.1, 0.2, 0.3, 0.95)  # Blue tint when targetable

func _update_targeting_visual_reset() -> void:
	_frame.color = Color(0.08, 0.08, 0.1, 0.95)

func _update_drag_visual() -> void:
	if not _frame:
		return
	
	if _is_drag_over and _dragged_card:
		_frame.color = Color(0.1, 0.25, 0.15, 0.95)  # Green tint for valid drop
	else:
		_frame.color = Color(0.08, 0.08, 0.1, 0.95)

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
	if EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.disconnect(_on_turn_started)
	if EventBus.avatar_attacked.is_connected(_on_avatar_attacked):
		EventBus.avatar_attacked.disconnect(_on_avatar_attacked)
