extends CanvasLayer

## Inventory menu overlay that pauses the game and displays player stats, equipment, and inventory.

var _is_open: bool = false
var _inventory_slots: Array[Control] = []
var _equipment_slots: Dictionary = {}  # {ItemData.ItemType: EquipmentSlot}

func _init() -> void:
	# Ensure this node processes even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

@onready var _background_overlay: ColorRect = $BackgroundOverlay
@onready var _menu_panel: Control = $MenuPanel
@onready var _stats_panel: VBoxContainer = $MenuPanel/MainContainer/LeftPanel/StatsPanel
@onready var _equipment_container: VBoxContainer = $MenuPanel/MainContainer/RightPanel/EquipmentContainer
@onready var _inventory_grid: GridContainer = $MenuPanel/MainContainer/RightPanel/InventoryGrid
@onready var _close_button: Button = $MenuPanel/Header/CloseButton
@onready var _cards_button: Button = $MenuPanel/MainContainer/RightPanel/CardsButton
@onready var _health_label: Label = $MenuPanel/MainContainer/LeftPanel/StatsPanel/HealthLabel
@onready var _level_label: Label = $MenuPanel/MainContainer/LeftPanel/StatsPanel/LevelLabel
@onready var _xp_label: Label = $MenuPanel/MainContainer/LeftPanel/StatsPanel/XPLabel
@onready var _attack_label: Label = $MenuPanel/MainContainer/LeftPanel/StatsPanel/AttackLabel
@onready var _defense_label: Label = $MenuPanel/MainContainer/LeftPanel/StatsPanel/DefenseLabel
@onready var _currency_label: Label = $MenuPanel/MainContainer/LeftPanel/StatsPanel/CurrencyLabel
@onready var _equipment_slots_container: HBoxContainer = $MenuPanel/MainContainer/RightPanel/EquipmentContainer/EquipmentSlots

func _ready() -> void:
	_menu_panel.visible = false
	if _background_overlay:
		_background_overlay.visible = false
	_setup_equipment_slots()
	_setup_inventory_grid()
	
	if _close_button:
		_close_button.pressed.connect(_on_close_button_pressed)
	if _cards_button:
		_cards_button.pressed.connect(_on_cards_button_pressed)
	
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.item_collected.connect(_on_item_collected)
	_update_stats_display()

func _input(event: InputEvent) -> void:
	# Check if card collection menu is open - if so, don't process inventory input
	var card_menu: CanvasLayer = get_tree().current_scene.get_node_or_null("UI/CardCollectionMenu")
	if card_menu and card_menu.get_node("MenuPanel").visible:
		# Card collection menu is open, don't process inventory input
		return
	
	# Handle Tab key directly to prevent UI focus navigation from consuming it
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_TAB:  # KEY_TAB = 4194305
			toggle_inventory()
			get_viewport().set_input_as_handled()
			return
		# Block Esc key from opening inventory (but allow it to propagate for mouse mode toggle)
		if event.physical_keycode == KEY_ESCAPE:  # KEY_ESCAPE = 4194306
			return
	
	if event.is_action_pressed("inventory"):
		toggle_inventory()

func toggle_inventory() -> void:
	if _is_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	if _is_open:
		return
	
	_is_open = true
	if _background_overlay:
		_background_overlay.visible = true
	_menu_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	EventBus.inventory_opened.emit()
	EventBus.game_paused.emit()
	_refresh_inventory_display()
	_update_stats_display()
	_setup_equipment_slots()  # Ensure equipment slots are set up

func close_inventory() -> void:
	if not _is_open:
		return
	
	_is_open = false
	_menu_panel.visible = false
	if _background_overlay:
		_background_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	EventBus.inventory_closed.emit()
	EventBus.game_resumed.emit()

func _setup_equipment_slots() -> void:
	# Equipment slots are in EquipmentSlots container
	if not _equipment_slots_container:
		return
	
	var weapon_slot: Control = _equipment_slots_container.get_node_or_null("WeaponSlot")
	var armor_slot: Control = _equipment_slots_container.get_node_or_null("ArmorSlot")
	var acc1_slot: Control = _equipment_slots_container.get_node_or_null("Accessory1Slot")
	
	if weapon_slot and weapon_slot.has_method("set_slot_type"):
		weapon_slot.set_slot_type(ItemData.ItemType.WEAPON)
		if not weapon_slot.slot_clicked.is_connected(_on_equipment_slot_clicked):
			weapon_slot.slot_clicked.connect(_on_equipment_slot_clicked)
		_equipment_slots[ItemData.ItemType.WEAPON] = weapon_slot
	
	if armor_slot and armor_slot.has_method("set_slot_type"):
		armor_slot.set_slot_type(ItemData.ItemType.ARMOR)
		if not armor_slot.slot_clicked.is_connected(_on_equipment_slot_clicked):
			armor_slot.slot_clicked.connect(_on_equipment_slot_clicked)
		_equipment_slots[ItemData.ItemType.ARMOR] = armor_slot
	
	if acc1_slot and acc1_slot.has_method("set_slot_type"):
		acc1_slot.set_slot_type(ItemData.ItemType.ACCESSORY)
		if not acc1_slot.slot_clicked.is_connected(_on_equipment_slot_clicked):
			acc1_slot.slot_clicked.connect(_on_equipment_slot_clicked)
		_equipment_slots[ItemData.ItemType.ACCESSORY] = acc1_slot
	
	# For now, use first accessory slot for all accessories
	# In full implementation, would have separate accessory slots

func _setup_inventory_grid() -> void:
	# Create inventory slots (6x8 = 48 slots)
	_inventory_slots.clear()
	
	for row in range(8):
		for col in range(6):
			var slot_scene: PackedScene = load("res://scenes/exploration/ui/components/inventory_slot.tscn")
			if slot_scene:
				var slot: Control = slot_scene.instantiate()
				slot.slot_position = Vector2i(col, row)
				slot.slot_clicked.connect(_on_inventory_slot_clicked)
				if slot.has_signal("slot_drag_started"):
					slot.slot_drag_started.connect(_on_slot_drag_started)
				_inventory_grid.add_child(slot)
				_inventory_slots.append(slot)

func _refresh_inventory_display() -> void:
	if not GameManager.player_inventory:
		return
	
	# Clear all slots
	for slot in _inventory_slots:
		if slot and slot.has_method("clear_item"):
			slot.clear_item()
	
	# Display items from inventory using grid positions
	var inventory: Inventory = GameManager.player_inventory
	
	# Map items to their grid positions
	for row in range(8):
		for col in range(6):
			var grid_pos: Vector2i = Vector2i(col, row)
			var item_at_pos: ItemInstance = inventory.get_item_at(grid_pos)
			
			# Find the slot at this position
			for slot in _inventory_slots:
				if slot and slot.slot_position == grid_pos:
					if item_at_pos:
						if slot.has_method("set_item"):
							slot.set_item(item_at_pos)
					else:
						if slot.has_method("clear_item"):
							slot.clear_item()
					break
	
	# Update equipment slots
	for slot_type in _equipment_slots:
		var slot: Control = _equipment_slots[slot_type]
		var equipped_item: ItemInstance = GameManager.equipped_items.get(slot_type)
		if slot and slot.has_method("set_item"):
			slot.set_item(equipped_item)

func _on_slot_drag_started(slot: Control, item: ItemInstance) -> void:
	# Store source slot for drag operation tracking
	# This is mainly for debugging/logging - the actual swap is handled in drop_data()
	pass

func _swap_items(source_slot: Control, target_slot: Control) -> void:
	# Helper method for swapping items between slots
	if not source_slot or not target_slot:
		return
	
	var source_item: ItemInstance = source_slot.get("item")
	var target_item: ItemInstance = target_slot.get("item")
	
	if not source_item:
		return
	
	# Remove items from inventory grid
	if GameManager.player_inventory:
		if source_item:
			GameManager.player_inventory.remove_item(source_item)
		if target_item:
			GameManager.player_inventory.remove_item(target_item)
	
	# Place items at new positions
	if GameManager.player_inventory:
		if source_item:
			GameManager.player_inventory.add_item(source_item, target_slot.slot_position)
		if target_item:
			GameManager.player_inventory.add_item(target_item, source_slot.slot_position)
	
	# Update slot displays
	if source_slot.has_method("set_item"):
		source_slot.set_item(target_item)
	if target_slot.has_method("set_item"):
		target_slot.set_item(source_item)
	
	# Refresh display
	_refresh_inventory_display()

func _update_stats_display() -> void:
	if not GameManager.player_stats:
		return
	
	var stats: PlayerStats = GameManager.player_stats
	
	if _health_label:
		_health_label.text = "Health: " + str(GameManager.player_max_life) + "/" + str(GameManager.player_max_life)
	if _level_label:
		_level_label.text = "Level: " + str(stats.level)
	if _xp_label:
		_xp_label.text = "XP: " + str(stats.experience) + "/" + str(stats.experience_to_next)
	if _attack_label:
		_attack_label.text = "Attack: " + str(stats.get_total_attack())
	if _defense_label:
		_defense_label.text = "Defense: " + str(stats.get_total_defense())
	if _currency_label:
		_currency_label.text = "Currency: " + str(GameManager.player_currency)

func _on_inventory_slot_clicked(slot: Control, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_RIGHT:
		# Right-click to use/equip item
		if not slot:
			return
		
		# Access item property directly
		var item: ItemInstance = slot.get("item")
		if item and item.data:
			# Try to equip if it's equipment
			var slot_type: ItemData.ItemType = item.data.item_type
			GameManager.equip_item(item, slot_type)

func _on_equipment_slot_clicked(slot: Control, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_RIGHT:
		# Right-click to unequip
		for slot_type in _equipment_slots:
			if _equipment_slots[slot_type] == slot:
				GameManager.unequip_item(slot_type)
				break

func _on_close_button_pressed() -> void:
	close_inventory()

func _on_cards_button_pressed() -> void:
	# Open card collection menu
	var card_menu: CanvasLayer = get_tree().current_scene.get_node_or_null("UI/CardCollectionMenu")
	if card_menu and card_menu.has_method("open_menu"):
		card_menu.open_menu()
		_menu_panel.visible = false

func _on_stats_changed() -> void:
	_update_stats_display()
	_refresh_inventory_display()

func _on_currency_changed(_current: int) -> void:
	_update_stats_display()

func _on_item_collected(item_name: StringName) -> void:
	# Refresh inventory display when item is collected
	if _is_open:
		_refresh_inventory_display()

func _exit_tree() -> void:
	if EventBus.stats_changed.is_connected(_on_stats_changed):
		EventBus.stats_changed.disconnect(_on_stats_changed)
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if EventBus.item_collected.is_connected(_on_item_collected):
		EventBus.item_collected.disconnect(_on_item_collected)
		EventBus.stats_changed.disconnect(_on_stats_changed)
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
