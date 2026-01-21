extends Control

## Equipment slot UI component for weapon, armor, and accessories.

signal slot_clicked(slot: Control, button_index: int)
signal slot_drag_started(slot: Control, item: ItemInstance)

var slot_type: ItemData.ItemType = ItemData.ItemType.WEAPON
var item: ItemInstance = null

@onready var _background: Panel = $Background
@onready var _item_icon: TextureRect = $ItemIcon
@onready var _slot_label: Label = $SlotLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_display()
	_update_label()

func set_item(new_item: ItemInstance) -> void:
	item = new_item
	_update_display()

func clear_item() -> void:
	item = null
	_update_display()

func set_slot_type(new_type: ItemData.ItemType) -> void:
	slot_type = new_type
	_update_label()

func _update_label() -> void:
	match slot_type:
		ItemData.ItemType.WEAPON:
			_slot_label.text = "Weapon"
		ItemData.ItemType.ARMOR:
			_slot_label.text = "Armor"
		ItemData.ItemType.ACCESSORY:
			_slot_label.text = "Accessory"
		_:
			_slot_label.text = "Slot"

func _update_display() -> void:
	if item and item.data:
		_item_icon.texture = item.data.icon
		_item_icon.visible = true
		_slot_label.visible = false
	else:
		_item_icon.visible = false
		_slot_label.visible = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				slot_clicked.emit(self, MOUSE_BUTTON_LEFT)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				slot_clicked.emit(self, MOUSE_BUTTON_RIGHT)

func can_drop_data(position: Vector2, data: Variant) -> bool:
	# Allow dropping items of matching type
	if data is ItemInstance:
		var dropped_item: ItemInstance = data as ItemInstance
		return dropped_item.data.item_type == slot_type
	return false

func drop_data(position: Vector2, data: Variant) -> void:
	if data is ItemInstance:
		slot_clicked.emit(self, MOUSE_BUTTON_LEFT)
