extends Control

## Hand area component that displays player's hand cards in an arc.

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

func _ready() -> void:
	EventBus.hand_updated.connect(_on_hand_updated)
	# Load card scene
	CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene

func _on_hand_updated(cards: Array, is_player: bool) -> void:
	if is_player:
		_update_hand(cards)

func _update_hand(cards: Array) -> void:
	_current_cards = cards
	
	# Clear existing visuals
	for visual in _card_visuals:
		visual.queue_free()
	_card_visuals.clear()
	
	# Reset hover index
	_hovered_card_index = -1
	
	# Create visuals for each card
	for i in range(cards.size()):
		var card_instance = cards[i]
		if not card_instance:
			continue
		
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
	
	# Position cards in arc after all are created
	_position_cards_in_arc()

func _on_card_clicked(card: CardInstance) -> void:
	EventBus.card_selected.emit(card)

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
