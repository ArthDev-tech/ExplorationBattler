extends Control

## Compact horizontal card display for deck list. Shows minimal info in a list-friendly format.

signal card_clicked(card: CardInstance)
signal card_removed(card: CardInstance)

var card_instance: CardInstance = null
var copy_count: int = 1

@onready var _background: Panel = $Background
@onready var _mana_cost_label: Label = $HBox/ManaCostContainer/ManaCostIcon/ManaCostLabel
@onready var _card_name_label: Label = $HBox/CardNameLabel
@onready var _art_thumbnail: ColorRect = $HBox/RightSection/ArtThumbnail
@onready var _rarity_gem: Panel = $HBox/RightSection/RarityGem
@onready var _copy_count_label: Label = $HBox/RightSection/CopyCountBadge/CopyCountLabel

var _rarity_colors: Dictionary = {
	CardData.Rarity.COMMON: Color(0.5, 0.5, 0.7, 1),      # Blue-gray
	CardData.Rarity.UNCOMMON: Color(0.2, 0.8, 0.2, 1),    # Green
	CardData.Rarity.RARE: Color(0.4, 0.4, 0.9, 1),        # Blue
	CardData.Rarity.LEGENDARY: Color(0.9, 0.6, 0.2, 1)    # Orange/Gold
}

var _tribe_colors: Array[Color] = [
	Color(0.5, 0.5, 0.5, 1),  # None
	Color(0.6, 0.5, 0.8, 1),  # Phantom
	Color(0.5, 0.7, 0.4, 1),  # Beast
	Color(0.6, 0.6, 0.5, 1),  # Construct
	Color(0.7, 0.4, 0.4, 1),  # Cultist
	Color(0.4, 0.7, 0.5, 1)   # Nature
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_card(instance: CardInstance, count: int = 1) -> void:
	card_instance = instance
	copy_count = count
	
	if not card_instance or not card_instance.data:
		return
	
	# Ensure nodes are ready before accessing them
	if not _mana_cost_label or not _card_name_label:
		# If nodes aren't ready, defer the call
		call_deferred("set_card", instance, count)
		return
	
	var data: CardData = card_instance.data
	
	# Mana cost (total including colored costs)
	_mana_cost_label.text = str(data.get_total_cost())
	
	# Style mana cost icon with blue background
	var mana_icon_style: StyleBoxFlat = _mana_cost_label.get_parent().get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	if mana_icon_style:
		# Keep the blue crystal look
		pass  # Already styled in scene
	
	# Card name
	_card_name_label.text = data.display_name
	
	# Copy count
	if _copy_count_label:
		if copy_count > 1:
			_copy_count_label.text = "x" + str(copy_count)
			_copy_count_label.visible = true
		else:
			_copy_count_label.visible = false
	
	# Art thumbnail (use tribe color for now, can be replaced with actual artwork later)
	if _art_thumbnail:
		if data.is_creature() and data.tribe < _tribe_colors.size():
			_art_thumbnail.color = _tribe_colors[data.tribe]
		else:
			_art_thumbnail.color = Color(0.3, 0.3, 0.3, 1)
	
	# Rarity gem color
	if _rarity_gem:
		var gem_style: StyleBoxFlat = _rarity_gem.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if not gem_style:
			gem_style = StyleBoxFlat.new()
			gem_style.bg_color = _rarity_colors.get(data.rarity, Color(0.5, 0.5, 0.5, 1))
			gem_style.corner_radius_top_left = 2
			gem_style.corner_radius_top_right = 2
			gem_style.corner_radius_bottom_right = 2
			gem_style.corner_radius_bottom_left = 2
			_rarity_gem.add_theme_stylebox_override("panel", gem_style)
		else:
			gem_style.bg_color = _rarity_colors.get(data.rarity, Color(0.5, 0.5, 0.5, 1))
	
	# Update border color based on rarity
	if _background:
		var bg_style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if bg_style:
			bg_style.border_color = _rarity_colors.get(data.rarity, Color(0.4, 0.4, 0.4, 1))

func _on_mouse_entered() -> void:
	if _background:
		var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if style:
			style.shadow_size = 4
			style.shadow_color = Color(0.5, 0.5, 0.8, 0.5)

func _on_mouse_exited() -> void:
	if _background:
		var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if style:
			style.shadow_size = 2
			style.shadow_color = Color(0, 0, 0, 0.2)

func _get_drag_data(_position: Vector2) -> Variant:
	# Allow dragging deck cards back to collection
	if not card_instance or not card_instance.data:
		return null
	
	# Create drag preview
	var preview: Control = duplicate()
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)
	# Set drag preview
	set_drag_preview(preview)
	
	# Return drag data
	return {
		"card_data": card_instance.data,
		"card_instance": card_instance,
		"source": "deck"
	}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	# Forward drop check to parent DeckList drop zone
	var parent_zone: Node = get_parent()
	if parent_zone and parent_zone.has_method("_can_drop_data"):
		return parent_zone._can_drop_data(_position, data)
	return false

func _drop_data(_position: Vector2, data: Variant) -> void:
	# Forward drop to parent DeckList drop zone
	var parent_zone: Node = get_parent()
	if parent_zone and parent_zone.has_method("_drop_data"):
		parent_zone._drop_data(_position, data)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Double-click to remove
		if event.double_click:
			if card_instance:
				card_removed.emit(card_instance)
		else:
			# Single click to select
			if card_instance:
				card_clicked.emit(card_instance)

func _exit_tree() -> void:
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)
