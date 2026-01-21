class_name VictoryScreen
extends CanvasLayer

## Victory reward overlay: shows gold reward + 3 card choices, click one to claim.

signal rewards_claimed(gold_amount: int, selected_card: CardData)

const CARD_SCENE: PackedScene = preload("res://scenes/battle/card_ui/card_visual.tscn")

@onready var _gold_label: Label = $Root/Panel/VBox/GoldLabel
@onready var _options_container: HBoxContainer = $Root/Panel/VBox/CardOptions
@onready var _continue_button: Button = $Root/Panel/VBox/ContinueButton

var _gold_amount: int = 0
var _options: Array[CardData] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Hide continue button - single click selection now
	_continue_button.visible = false

func setup(gold_amount: int, card_options: Array[CardData]) -> void:
	_gold_amount = maxi(0, gold_amount)
	_options = card_options.duplicate()
	_gold_label.text = "Gold +" + str(_gold_amount)
	_build_option_cards()

func _build_option_cards() -> void:
	# Clear old cards
	for child in _options_container.get_children():
		child.queue_free()
	
	for i in range(_options.size()):
		var data: CardData = _options[i]
		if not data:
			continue
		
		# Create wrapper panel for click handling - 220x300 size
		var wrapper: PanelContainer = PanelContainer.new()
		wrapper.custom_minimum_size = Vector2(220, 300)
		wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		wrapper.gui_input.connect(_on_card_input.bind(data, wrapper))
		
		# Connect hover signals for green border
		wrapper.mouse_entered.connect(_on_wrapper_hover.bind(wrapper, true))
		wrapper.mouse_exited.connect(_on_wrapper_hover.bind(wrapper, false))
		
		# Create style with transparent background and invisible border initially
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color(0, 0, 0, 0)  # Invisible until hover
		wrapper.add_theme_stylebox_override("panel", style)
		
		# Add wrapper to tree first so card_visual's @onready vars get initialized
		_options_container.add_child(wrapper)
		
		# Instantiate and add card visual
		var card_visual: Control = CARD_SCENE.instantiate()
		var card_instance: CardInstance = CardInstance.new(data)
		wrapper.add_child(card_visual)
		
		# AFTER adding to tree (after _ready runs), disable mouse on card and ALL children
		# This overrides the mouse_filter = STOP that _ready() sets
		_disable_mouse_on_all_children(card_visual)
		
		# Disable card's built-in hover effects (scale/glow)
		if card_visual.has_method("_on_mouse_entered"):
			if card_visual.mouse_entered.is_connected(card_visual._on_mouse_entered):
				card_visual.mouse_entered.disconnect(card_visual._on_mouse_entered)
		if card_visual.has_method("_on_mouse_exited"):
			if card_visual.mouse_exited.is_connected(card_visual._on_mouse_exited):
				card_visual.mouse_exited.disconnect(card_visual._on_mouse_exited)
		card_visual.scale = Vector2(1.0, 1.0)  # Ensure no scale
		
		# Set card data - now safe because card is in the tree
		if card_visual.has_method("set_card"):
			card_visual.set_card(card_instance)

func _on_wrapper_hover(wrapper: PanelContainer, hovered: bool) -> void:
	var style: StyleBoxFlat = wrapper.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if hovered:
			style.border_color = Color(0.2, 0.8, 0.2, 1.0)  # Green border on hover
		else:
			style.border_color = Color(0, 0, 0, 0)  # Invisible when not hovered

func _on_card_input(event: InputEvent, card: CardData, _wrapper: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Single click immediately claims the card and closes
		rewards_claimed.emit(_gold_amount, card)

func _disable_mouse_on_all_children(node: Node) -> void:
	# Recursively set mouse_filter to IGNORE on all Control children
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse_on_all_children(child)
