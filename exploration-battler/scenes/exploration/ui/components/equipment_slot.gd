@tool
extends Control

## Equipment slot UI component for weapon, armor, and accessories.

signal slot_clicked(slot: Control, button_index: int)
signal slot_drag_started(slot: Control, item: ItemInstance)

var _slot_type: ItemData.ItemType = ItemData.ItemType.WEAPON

@export var slot_type: ItemData.ItemType = ItemData.ItemType.WEAPON:
	set(value):
		_slot_type = value
		# Update label immediately when changed (works in editor and runtime)
		_update_label()
	get:
		return _slot_type

var item: ItemInstance = null

var _is_hovered: bool = false
var _current_stylebox: StyleBoxFlat = null

@onready var _background: Panel = $Background
@onready var _item_icon: TextureRect = $ItemIcon
@onready var _slot_label: Label = $SlotLabel
@onready var _item_name_label: Label = $ItemNameLabel

func _ready() -> void:
	# Only connect signals at runtime, not in editor
	if not Engine.is_editor_hint():
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
	
	# Ensure child nodes don't block mouse events
	if _item_icon:
		_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _slot_label:
		_slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _background:
		_background.mouse_filter = Control.MOUSE_FILTER_PASS
		# Create a unique StyleBoxFlat instance for this slot to avoid shared state
		var existing_style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if existing_style:
			var new_style: StyleBoxFlat = existing_style.duplicate()
			_background.add_theme_stylebox_override("panel", new_style)
	
	# Update label in both editor and runtime
	_update_label()
	
	# Only update display at runtime (item is null in editor)
	if not Engine.is_editor_hint():
		_update_display()

func set_item(new_item: ItemInstance) -> void:
	item = new_item
	_update_display()

func clear_item() -> void:
	item = null
	_update_display()

func set_slot_type(new_type: ItemData.ItemType) -> void:
	slot_type = new_type

func _update_label() -> void:
	# Get label node - works in both editor and runtime
	var label: Label = null
	if Engine.is_editor_hint():
		label = get_node_or_null("SlotLabel")
	else:
		label = _slot_label
	
	if not label:
		return
	
	_update_label_text(label, _slot_type)

func _update_label_text(label: Label, type: ItemData.ItemType) -> void:
	match type:
		ItemData.ItemType.WEAPON:
			label.text = "Weapon"
		ItemData.ItemType.ARMOR:
			label.text = "Armor"
		ItemData.ItemType.HELM:
			label.text = "Helm"
		ItemData.ItemType.BOOTS:
			label.text = "Boots"
		ItemData.ItemType.BELT:
			label.text = "Belt"
		ItemData.ItemType.LEGS:
			label.text = "Legs"
		ItemData.ItemType.PAULDRONS:
			label.text = "Pauldrons"
		ItemData.ItemType.GLOVES:
			label.text = "Gloves"
		ItemData.ItemType.RING:
			label.text = "Ring"
		ItemData.ItemType.ACCESSORY:
			label.text = "Accessory"
		_:
			label.text = "Slot"

func _set_background_color(color: Color) -> void:
	if not _background:
		return
	
	# Get existing stylebox to copy properties
	var existing_style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	if existing_style:
		# Create new stylebox with updated color
		var new_style: StyleBoxFlat = StyleBoxFlat.new()
		new_style.bg_color = color
		new_style.border_width_left = existing_style.border_width_left
		new_style.border_width_top = existing_style.border_width_top
		new_style.border_width_right = existing_style.border_width_right
		new_style.border_width_bottom = existing_style.border_width_bottom
		new_style.border_color = existing_style.border_color
		_background.add_theme_stylebox_override("panel", new_style)
		_current_stylebox = new_style
	else:
		# Fallback: create basic stylebox
		var new_style: StyleBoxFlat = StyleBoxFlat.new()
		new_style.bg_color = color
		new_style.border_width_left = 2
		new_style.border_width_top = 2
		new_style.border_width_right = 2
		new_style.border_width_bottom = 2
		new_style.border_color = Color(0.5, 0.5, 0.3, 1)
		_background.add_theme_stylebox_override("panel", new_style)
		_current_stylebox = new_style
	
	# Apply hover state if active
	if _is_hovered:
		_apply_hover_highlight()

func _update_display() -> void:
	if item and item.data:
		# Show icon if available, otherwise show placeholder with name
		if item.data.icon:
			_item_icon.texture = item.data.icon
			_item_icon.visible = true
			_item_name_label.visible = false
			_slot_label.visible = false
			# Set background to normal color
			_set_background_color(Color(0.15, 0.15, 0.15, 0.9))
		else:
			# No icon - show placeholder: white background with item name
			_item_icon.visible = false
			_item_name_label.text = item.data.item_name
			_item_name_label.visible = true
			_slot_label.visible = false
			# Set text color to black for visibility on white background
			_item_name_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
			# Set background to white
			_set_background_color(Color(1.0, 1.0, 1.0, 1.0))
	else:
		_item_icon.visible = false
		_item_name_label.visible = false
		_slot_label.visible = true
		# Reset background to normal color
		_set_background_color(Color(0.15, 0.15, 0.15, 0.9))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				slot_clicked.emit(self, MOUSE_BUTTON_LEFT)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				slot_clicked.emit(self, MOUSE_BUTTON_RIGHT)

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	# Handle Dictionary drag data from inventory slots
	if data is Dictionary:
		var drag_data: Dictionary = data as Dictionary
		var dropped_item: ItemInstance = drag_data.get("item") as ItemInstance
		if dropped_item and dropped_item.data:
			var can_drop: bool = dropped_item.data.item_type == slot_type
			return can_drop
		return false
	
	# Handle direct ItemInstance (fallback)
	if data is ItemInstance:
		var dropped_item: ItemInstance = data as ItemInstance
		if dropped_item and dropped_item.data:
			var can_drop: bool = dropped_item.data.item_type == slot_type
			return can_drop
	return false

func _drop_data(position: Vector2, data: Variant) -> void:
	var dropped_item: ItemInstance = null
	
	# Handle Dictionary drag data from inventory slots
	if data is Dictionary:
		var drag_data: Dictionary = data as Dictionary
		dropped_item = drag_data.get("item") as ItemInstance
	elif data is ItemInstance:
		dropped_item = data as ItemInstance
	
	if dropped_item and dropped_item.data:
		# Equip the item
		if GameManager.equip_item(dropped_item, slot_type):
			# Refresh inventory display
			var inventory_menu: Node = get_tree().current_scene.get_node_or_null("UI/InventoryMenu")
			if inventory_menu and inventory_menu.has_method("_refresh_inventory_display"):
				inventory_menu._refresh_inventory_display()
			else:
				EventBus.stats_changed.emit()

func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_hover_highlight()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_remove_hover_highlight()

func _apply_hover_highlight() -> void:
	if not _background:
		return
	
	# Get the actual stylebox from theme override (not stored reference)
	var style: StyleBoxFlat = _background.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	
	# Apply highlight: brighter border
	style.border_color = Color(0.8, 0.8, 0.2, 1.0)  # Yellow highlight
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3

func _remove_hover_highlight() -> void:
	if not _background:
		return
	
	# Get the actual stylebox from theme override
	var style: StyleBoxFlat = _background.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return
	
	# Reset to normal border
	style.border_color = Color(0.5, 0.5, 0.3, 1)  # Original border color from scene
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
