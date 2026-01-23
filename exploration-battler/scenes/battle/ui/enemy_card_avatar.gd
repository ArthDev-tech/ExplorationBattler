extends Control

## Enemy card avatar - allows the enemy card to be targeted by spells and displays attack value.
## Can also receive player avatar attack drops and plays bump animation when enemy avatar attacks.

signal avatar_clicked(is_player: bool)

const IS_PLAYER_AVATAR: bool = false

var avatar_instance: CardInstance = null
var _is_drag_over: bool = false
var _dragged_card: CardInstance = null
var _is_avatar_attack_drag: bool = false
var _original_position: Vector2 = Vector2.ZERO

@onready var _frame: ColorRect = $Frame
@onready var _attack_label: Label = $AttackLabel
@onready var _border_indicator: Panel = $BorderIndicator

# Border colors for identity indicator
const BORDER_ENEMY_COLOR: Color = Color(0.8, 0.2, 0.2, 1.0)  # Red
const BORDER_WIDTH: int = 3

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	
	# Store original position for animations
	_original_position = global_position
	
	# Connect targeting signals
	EventBus.targeting_started.connect(_on_targeting_started)
	EventBus.targeting_cancelled.connect(_on_targeting_cancelled)
	
	# Ensure Frame doesn't block drop events
	if _frame:
		_frame.mouse_filter = MOUSE_FILTER_PASS
	
	# Initialize border indicator
	_setup_border_indicator()

func _setup_border_indicator() -> void:
	if not _border_indicator:
		return
	
	# Create StyleBoxFlat for the border
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Transparent fill
	style.border_width_left = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.border_color = BORDER_ENEMY_COLOR
	
	_border_indicator.add_theme_stylebox_override("panel", style)

func set_avatar(avatar: CardInstance, _is_player: bool) -> void:
	avatar_instance = avatar
	_update_display()

func _update_display() -> void:
	if avatar_instance and _attack_label:
		_attack_label.text = "ATK: " + str(avatar_instance.current_attack)
	elif _attack_label:
		_attack_label.text = ""

func update_attack(new_attack: int) -> void:
	if avatar_instance:
		avatar_instance.current_attack = new_attack
	_update_display()

func get_avatar() -> CardInstance:
	return avatar_instance

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
	# Reset state
	_dragged_card = null
	_is_avatar_attack_drag = false
	_is_drag_over = false
	
	# Check for avatar attack data (Dictionary with type "avatar_attack")
	if data is Dictionary:
		var dict_data: Dictionary = data as Dictionary
		if dict_data.get("type") == "avatar_attack" and dict_data.get("is_player") == true:
			_is_avatar_attack_drag = true
			_is_drag_over = true
			_update_drag_visual()
			return true
	
	# Handle card drops (spells targeting avatar)
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
	
	# Block plays until player picks start-of-turn energy color
	if battle_manager.get("_awaiting_energy_pick") == true:
		_update_drag_visual()
		return false
	
	# Check if player can afford this card
	if not battle_state.can_afford_player_cost(card.data):
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
	var was_avatar_attack: bool = _is_avatar_attack_drag
	
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
			if battle_manager.has_method("player_avatar_attack_avatar"):
				battle_manager.player_avatar_attack_avatar()
			return
	
	# Handle spell card drops
	if data == null or not data is CardInstance:
		return
	
	var card: CardInstance = data as CardInstance
	if not card:
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

## Play bump animation when enemy avatar attacks a target
## target_position: The global position of the attack target
func play_attack_animation(target_position: Vector2) -> void:
	# Store current position if not set
	if _original_position == Vector2.ZERO:
		_original_position = global_position
	
	var original_pos: Vector2 = global_position
	
	# Calculate bump position (move 30% toward target)
	var bump_pos: Vector2 = original_pos.lerp(target_position, 0.3)
	
	# Create tween animation
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Move toward target
	tween.tween_property(self, "global_position", bump_pos, 0.15)
	
	# Brief pause at bump position
	tween.tween_interval(0.05)
	
	# Return to original position
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", original_pos, 0.15)
	
	await tween.finished

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
		_update_border_hover(true)
	else:
		_frame.color = Color(0.08, 0.08, 0.1, 0.95)  # Default color
		_update_border_hover(false)

func _update_border_hover(hovering: bool) -> void:
	if not _border_indicator:
		return
	
	var style: StyleBoxFlat = _border_indicator.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	
	if hovering:
		# Brighten the border color on hover
		style.border_color = BORDER_ENEMY_COLOR * 1.3
	else:
		style.border_color = BORDER_ENEMY_COLOR

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
	
	if _is_drag_over:
		if _is_avatar_attack_drag:
			_frame.color = Color(0.35, 0.15, 0.15, 0.95)  # Red tint for attack target
		elif _dragged_card:
			_frame.color = Color(0.1, 0.25, 0.15, 0.95)  # Green tint for spell drop
		else:
			_frame.color = Color(0.08, 0.08, 0.1, 0.95)
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
