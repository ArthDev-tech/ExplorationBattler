extends Control

## =============================================================================
## HandArea - Player Hand Display Controller
## =============================================================================
## Displays the player's hand cards in a curved arc layout.
## Handles card positioning, hover effects, and draw animations.
##
## Arc Layout:
## - Cards are positioned along a circular arc for a natural "hand" appearance
## - Hovering a card pops it up and straightens it for better visibility
## - Cards spread more as hand size increases (up to MAX_SPREAD_ANGLE)
##
## Draw Animation:
## - New cards slide up from below the hand area
## - Staggered timing for multiple cards drawn at once
## - Uses TRANS_BACK easing for a satisfying "snap into place" effect
##
## HARDCODED: Arc parameters defined as constants below - adjust for different
## card sizes or hand positions.
## =============================================================================

@onready var _card_container: Control = $CardContainer

var CARD_SCENE: PackedScene = null
var _current_cards: Array[CardInstance] = []
var _card_visuals: Array[Control] = []
var _hovered_card_index: int = -1

# Arc layout parameters (tunable)
const ARC_RADIUS: float = 1200.0  # Increased for smoother curve
const MAX_SPREAD_ANGLE: float = 40.0  # degrees - Reduced to bring cards closer
const VERTICAL_OFFSET: float = -180.0  # Negative to position cards upward from bottom
const HOVER_POP_HEIGHT: float = 100.0  # Increased for better visibility
const HOVER_SCALE: float = 1.25  # Slightly larger scale

# Draw animation parameters
const DRAW_ANIMATION_DURATION: float = 0.3
const DRAW_STAGGER_DELAY: float = 0.1
const DRAW_START_OFFSET_Y: float = 400.0  # How far below final position cards start

func _ready() -> void:
	EventBus.hand_updated.connect(_on_hand_updated)
	# Load card scene
	CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene

func _on_hand_updated(cards: Array, is_player: bool) -> void:
	if is_player:
		_update_hand(cards)

func _update_hand(cards: Array) -> void:
	# Determine which cards are new (for animation)
	var old_card_ids: Array = []
	for card in _current_cards:
		if card:
			old_card_ids.append(card.get_instance_id())
	
	# Properly copy cards to typed array (direct assignment can fail with type mismatch)
	_current_cards.clear()
	for c in cards:
		if c:
			_current_cards.append(c)
	
	# Clear existing visuals
	for visual in _card_visuals:
		visual.queue_free()
	_card_visuals.clear()
	
	# Reset hover index
	_hovered_card_index = -1
	
	# Create visuals for each card
	var new_card_indices: Array[int] = []
	for i in range(cards.size()):
		var card_instance = cards[i]
		if not card_instance:
			continue
		
		# Check if this card is new (wasn't in previous hand)
		var is_new_card: bool = not old_card_ids.has(card_instance.get_instance_id())
		if is_new_card:
			new_card_indices.append(i)
		
		if not CARD_SCENE:
			CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene
		
		if CARD_SCENE:
			var card_visual: Control = CARD_SCENE.instantiate()
			# Ensure card maintains its size in hand
			card_visual.size = card_visual.custom_minimum_size
			card_visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_card_container.add_child(card_visual)
			_card_visuals.append(card_visual)
			
			# Set card data
			if card_visual.has_method("set_card"):
				card_visual.set_card(card_instance)
			
			# Connect click signal
			if card_visual.has_signal("card_clicked"):
				card_visual.card_clicked.connect(_on_card_clicked)
			
			# Connect hover signals for arc positioning
			card_visual.mouse_entered.connect(_on_card_hovered.bind(i))
			card_visual.mouse_exited.connect(_on_card_unhovered)
	
	# Position cards and animate new ones
	if new_card_indices.size() > 0:
		print("[HandArea] Animating ", new_card_indices.size(), " new cards: ", new_card_indices)
	_position_cards_with_animation(new_card_indices)

func _on_card_clicked(card: CardInstance) -> void:
	EventBus.card_selected.emit(card)

func _position_cards_with_animation(new_card_indices: Array[int]) -> void:
	## Position all cards, animating new cards from below the hand area.
	var card_count = _card_visuals.size()
	if card_count == 0:
		return
	
	# Get the bottom-center position of the hand area as reference
	var container_center_x = _card_container.size.x / 2.0
	var container_bottom_y = _card_container.size.y
	
	# Arc parameters
	var max_spread_angle_rad = deg_to_rad(MAX_SPREAD_ANGLE)
	var card_spacing_angle = max_spread_angle_rad / max(1, card_count - 1) if card_count > 1 else 0.0
	
	# Track animation index for staggering new cards
	var animation_index: int = 0
	
	for i in range(card_count):
		var card = _card_visuals[i]
		if not card:
			continue
		
		var center_offset = (card_count - 1) / 2.0
		var angle = (i - center_offset) * card_spacing_angle
		
		# Calculate final position on arc
		var x = sin(angle) * ARC_RADIUS
		var y = (1.0 - cos(angle)) * ARC_RADIUS + VERTICAL_OFFSET
		var final_local_pos = Vector2(container_center_x + x, container_bottom_y + y)
		var final_rotation = angle
		
		# Check if this is a new card that needs animation
		var is_new: bool = new_card_indices.has(i)
		
		if is_new:
			# Start position: same X as final, but below the hand area
			var start_local_pos = Vector2(final_local_pos.x, container_bottom_y + DRAW_START_OFFSET_Y)
			card.position = start_local_pos
			card.rotation = 0.0  # Start straight
			card.modulate.a = 1.0  # Fully visible from start
			card.z_index = 100 + animation_index  # High z-index during animation
			card.scale = Vector2(0.85, 0.85)  # Start slightly smaller
			
			# Animate to final position with stagger
			var tween: Tween = create_tween()
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_BACK)
			
			var delay: float = animation_index * DRAW_STAGGER_DELAY
			if delay > 0:
				tween.tween_interval(delay)
			
			# Move to final position
			tween.tween_property(card, "position", final_local_pos, DRAW_ANIMATION_DURATION)
			# Rotate to final angle
			tween.parallel().tween_property(card, "rotation", final_rotation, DRAW_ANIMATION_DURATION)
			# Scale to normal
			tween.parallel().tween_property(card, "scale", Vector2(1.0, 1.0), DRAW_ANIMATION_DURATION)
			# Reset z_index after animation (check validity in case hand was updated)
			tween.tween_callback(func():
				if is_instance_valid(card):
					card.z_index = 0
			)
			
			animation_index += 1
		else:
			# Existing card - position instantly
			card.position = final_local_pos
			card.rotation = final_rotation
			card.z_index = 0
			card.scale = Vector2(1.0, 1.0)
			card.modulate.a = 1.0

func _position_cards_in_arc() -> void:
	var card_count = _card_visuals.size()
	if card_count == 0:
		return
	
	# Get the bottom-center position of the hand area as reference
	var container_center_x = _card_container.size.x / 2.0
	var container_bottom_y = _card_container.size.y
	
	# Arc parameters
	var max_spread_angle_rad = deg_to_rad(MAX_SPREAD_ANGLE)
	var card_spacing_angle = max_spread_angle_rad / max(1, card_count - 1) if card_count > 1 else 0.0
	
	for i in range(card_count):
		var card = _card_visuals[i]
		if not card:
			continue
		
		var center_offset = (card_count - 1) / 2.0
		var angle = (i - center_offset) * card_spacing_angle
		
		# Calculate position on arc (using bottom-center as pivot)
		var x = sin(angle) * ARC_RADIUS
		var y = (1.0 - cos(angle)) * ARC_RADIUS + VERTICAL_OFFSET  # Positive for downward fan arc
		
		# Apply rotation to match arc
		card.rotation = angle
		
		# Special handling for hovered card
		if i == _hovered_card_index:
			# Pop up the hovered card
			y -= HOVER_POP_HEIGHT
			card.rotation = 0  # Straighten card
			card.z_index = 50  # Ensure it's on top
			card.scale = Vector2(HOVER_SCALE, HOVER_SCALE)
		else:
			card.z_index = 0
			card.scale = Vector2(1.0, 1.0)
		
		# Set card position relative to bottom-center
		card.position = Vector2(container_center_x + x, container_bottom_y + y)

func _on_card_hovered(card_index: int) -> void:
	_hovered_card_index = card_index
	_position_cards_in_arc()

func _on_card_unhovered() -> void:
	_hovered_card_index = -1
	_position_cards_in_arc()

func _exit_tree() -> void:
	if EventBus.hand_updated.is_connected(_on_hand_updated):
		EventBus.hand_updated.disconnect(_on_hand_updated)
	# Disconnect card signals from visuals
	for visual in _card_visuals:
		if visual:
			if visual.has_signal("card_clicked") and visual.card_clicked.is_connected(_on_card_clicked):
				visual.card_clicked.disconnect(_on_card_clicked)
			if visual.mouse_entered.is_connected(_on_card_hovered):
				visual.mouse_entered.disconnect(_on_card_hovered)
			if visual.mouse_exited.is_connected(_on_card_unhovered):
				visual.mouse_exited.disconnect(_on_card_unhovered)
