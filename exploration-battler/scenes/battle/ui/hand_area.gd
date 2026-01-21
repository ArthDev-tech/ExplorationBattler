extends Control

## Hand area component that displays player's hand cards horizontally.

@onready var _card_container: HBoxContainer = $ScrollContainer/CardContainer

var CARD_SCENE: PackedScene = null
var _current_cards: Array[CardInstance] = []
var _card_visuals: Array[Control] = []

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
	
	# Create visuals for each card
	for card_instance in cards:
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

func _on_card_clicked(card: CardInstance) -> void:
	EventBus.card_selected.emit(card)

func _exit_tree() -> void:
	if EventBus.hand_updated.is_connected(_on_hand_updated):
		EventBus.hand_updated.disconnect(_on_hand_updated)
	# Disconnect card clicked signals from visuals
	for visual in _card_visuals:
		if visual and visual.has_signal("card_clicked"):
			if visual.card_clicked.is_connected(_on_card_clicked):
				visual.card_clicked.disconnect(_on_card_clicked)
