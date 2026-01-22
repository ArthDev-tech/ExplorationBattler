extends Control

## Inventory slot UI component that displays an item and handles interactions.

signal slot_clicked(slot: Control, button_index: int)
signal slot_drag_started(slot: Control, item: ItemInstance)

var item: ItemInstance = null
var slot_position: Vector2i = Vector2i.ZERO  # Grid position

var _is_hovered: bool = false
var _current_stylebox: StyleBoxFlat = null

@onready var _background: Panel = $Background
@onready var _item_icon: TextureRect = $ItemIcon
@onready var _quantity_label: Label = $QuantityLabel
@onready var _item_name_label: Label = $ItemNameLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# Ensure child nodes don't block mouse events
	if _item_icon:
		_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _item_name_label:
		_item_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _quantity_label:
		_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _background:
		_background.mouse_filter = Control.MOUSE_FILTER_PASS
	_update_display()

func set_item(new_item: ItemInstance) -> void:
	item = new_item
	_update_display()

func clear_item() -> void:
	item = null
	_update_display()

func _update_display() -> void:
	if item and item.data:
		# Show icon if available, otherwise show placeholder with name
		if item.data.icon:
			_item_icon.texture = item.data.icon
			_item_icon.visible = true
			_item_name_label.visible = false
			# Set background to normal color
			_set_background_color(Color(0.2, 0.2, 0.2, 0.8))
		else:
			# No icon - show placeholder: white background with item name
			_item_icon.visible = false
			_item_name_label.text = item.data.item_name
			_item_name_label.visible = true
			# Set text color to black for visibility on white background
			_item_name_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
			# Set background to white
			_set_background_color(Color(1.0, 1.0, 1.0, 1.0))
		
		# Show quantity if > 1
		if item.quantity > 1:
			_quantity_label.text = str(item.quantity)
			_quantity_label.visible = true
		else:
			_quantity_label.visible = false
	else:
		_item_icon.visible = false
		_item_name_label.visible = false
		_quantity_label.visible = false
		# Reset background to normal color
		_set_background_color(Color(0.2, 0.2, 0.2, 0.8))

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
		new_style.border_color = Color(0.4, 0.4, 0.4, 1)
		_background.add_theme_stylebox_override("panel", new_style)
		_current_stylebox = new_style
	
	# Apply hover state if active
	if _is_hovered:
		_apply_hover_highlight()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				slot_clicked.emit(self, MOUSE_BUTTON_LEFT)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				accept_event()  # Prevent event from being consumed
				slot_clicked.emit(self, MOUSE_BUTTON_RIGHT)
			elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
				# Start drag
				if item:
					slot_drag_started.emit(self, item)

func _get_drag_data(position: Vector2) -> Variant:
	# Only allow drag if slot has an item
	if not item:
		return null
	
	# Create drag preview
	var preview: Control = duplicate()
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	
	# Emit signal for tracking
	slot_drag_started.emit(self, item)
	
	# Return item data for dragging
	return {
		"item": item,
		"source_slot": self,
		"source_position": slot_position
	}

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	# Allow dropping items
	var can_drop: bool = false
	
	if data is Dictionary:
		var drag_data: Dictionary = data as Dictionary
		can_drop = drag_data.has("item") and drag_data.get("item") is ItemInstance
	elif data is ItemInstance:
		can_drop = true
	
	return can_drop

func _drop_data(position: Vector2, data: Variant) -> void:
	# Handle item drop - swap items between slots or move to empty slot
	if data is Dictionary:
		var drag_data: Dictionary = data as Dictionary
		var dragged_item: ItemInstance = drag_data.get("item") as ItemInstance
		var source_slot: Control = drag_data.get("source_slot") as Control
		
		if not dragged_item:
			return
		
		if not source_slot or source_slot == self:
			return
		
		# Get target slot's current item (may be null if empty)
		var target_item: ItemInstance = item
		
		# Remove items from inventory grid
		if GameManager.player_inventory:
			if dragged_item:
				GameManager.player_inventory.remove_item(dragged_item)
			if target_item:
				GameManager.player_inventory.remove_item(target_item)
		
		# Place items at new positions
		if GameManager.player_inventory:
			if dragged_item:
				GameManager.player_inventory.add_item(dragged_item, slot_position)
			if target_item:
				var source_pos: Vector2i = source_slot.get("slot_position")
				GameManager.player_inventory.add_item(target_item, source_pos)
		
		# Update slot displays
		if source_slot.has_method("set_item"):
			source_slot.set_item(target_item)
		set_item(dragged_item)
		
		# Refresh inventory display - find inventory menu by traversing up the tree
		var inventory_menu: Node = _find_inventory_menu()
		if inventory_menu and inventory_menu.has_method("_refresh_inventory_display"):
			inventory_menu._refresh_inventory_display()
		else:
			# Fallback: emit signal to refresh
			EventBus.stats_changed.emit()
	elif data is ItemInstance:
		# Fallback for direct ItemInstance drops
		var dragged_item: ItemInstance = data as ItemInstance
		if dragged_item and GameManager.player_inventory:
			GameManager.player_inventory.remove_item(dragged_item)
			GameManager.player_inventory.add_item(dragged_item, slot_position)
			set_item(dragged_item)
			
			var inventory_menu: Node = _find_inventory_menu()
			if inventory_menu and inventory_menu.has_method("_refresh_inventory_display"):
				inventory_menu._refresh_inventory_display()
			else:
				EventBus.stats_changed.emit()

func _find_inventory_menu() -> Node:
	# Try multiple paths to find inventory menu
	var paths: Array[String] = [
		"UI/InventoryMenu",
		"../InventoryMenu",
		"../../InventoryMenu"
	]
	
	for path in paths:
		var node: Node = get_tree().current_scene.get_node_or_null(path)
		if node and node.has_method("_refresh_inventory_display"):
			return node
	
	# Try traversing up the tree
	var parent: Node = get_parent()
	while parent:
		if parent.has_method("_refresh_inventory_display"):
			return parent
		parent = parent.get_parent()
	
	return null

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
	style.border_color = Color(0.4, 0.4, 0.4, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
