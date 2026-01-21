extends Control

## Inventory slot UI component that displays an item and handles interactions.

signal slot_clicked(slot: Control, button_index: int)
signal slot_drag_started(slot: Control, item: ItemInstance)

var item: ItemInstance = null
var slot_position: Vector2i = Vector2i.ZERO  # Grid position

@onready var _background: Panel = $Background
@onready var _item_icon: TextureRect = $ItemIcon
@onready var _quantity_label: Label = $QuantityLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_display()

func set_item(new_item: ItemInstance) -> void:
	item = new_item
	_update_display()

func clear_item() -> void:
	item = null
	_update_display()

func _update_display() -> void:
	if item and item.data:
		_item_icon.texture = item.data.icon
		_item_icon.visible = true
		if item.quantity > 1:
			_quantity_label.text = str(item.quantity)
			_quantity_label.visible = true
		else:
			_quantity_label.visible = false
	else:
		_item_icon.visible = false
		_quantity_label.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				slot_clicked.emit(self, MOUSE_BUTTON_LEFT)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				slot_clicked.emit(self, MOUSE_BUTTON_RIGHT)
			elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
				# Start drag
				if item:
					slot_drag_started.emit(self, item)

func can_drop_data(position: Vector2, data: Variant) -> bool:
	# Allow dropping items
	return data is ItemInstance

func drop_data(position: Vector2, data: Variant) -> void:
	# Handle item drop
	if data is ItemInstance:
		slot_clicked.emit(self, MOUSE_BUTTON_LEFT)
