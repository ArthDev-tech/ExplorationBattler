@tool
extends CanvasLayer

## =============================================================================
## InventoryMenu - Player Inventory and Equipment Screen
## =============================================================================
## Inventory menu overlay that pauses the game and displays player stats,
## equipment, and inventory.
##
## Features:
## - Stats panel: Health, level, XP, attack, defense, currency
## - Equipment slots: Weapon, armor, accessory (right-click to unequip)
## - Inventory grid: Configurable grid-based item storage (see INVENTORY_GRID_COLUMNS and INVENTORY_GRID_ROWS constants)
## - Drag-and-drop item management
## - Cards button to open deck builder
##
## Input:
## - Tab key or "inventory" action to toggle
## - Right-click on inventory item to equip
## - Right-click on equipment slot to unequip
##
## Pause Behavior:
## - Opens: pauses game, shows mouse cursor
## - Closes: unpauses game, captures mouse
## =============================================================================

var _is_open: bool = false
var _inventory_slots: Array[Control] = []
var _equipment_slots: Dictionary = {}  # {ItemData.ItemType: EquipmentSlot}

# Inventory grid configuration
const INVENTORY_GRID_COLUMNS: int = 12
const INVENTORY_GRID_ROWS: int = 8
const INVENTORY_GRID_TOTAL_SLOTS: int = INVENTORY_GRID_COLUMNS * INVENTORY_GRID_ROWS

func _init() -> void:
	# Ensure this node processes even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

@onready var _background_overlay: ColorRect = $BackgroundOverlay
@onready var _inventory_grid: GridContainer = $RightPanel/InventoryGrid
@onready var _close_button: Button = $Header/CloseButton
@onready var _cards_button: Button = $RightPanel/CardsButton
@onready var _health_label: Label = $StatsPanel/HealthLabel
@onready var _level_label: Label = $StatsPanel/LevelLabel
@onready var _xp_label: Label = $StatsPanel/XPLabel
@onready var _attack_label: Label = $StatsPanel/AttackLabel
@onready var _defense_label: Label = $StatsPanel/DefenseLabel
@onready var _currency_label: Label = $StatsPanel/CurrencyLabel
@onready var _equipment_slots_container: Control = $EquipmentTitle/EquipmentSlots
@onready var _profile_sprite: Sprite2D = $Profile
@onready var _stats_panel_container: VBoxContainer = $StatsPanel
@onready var _right_panel_container: VBoxContainer = $RightPanel
@onready var _header_container: HBoxContainer = $Header
@onready var _equipment_title_label: Label = $EquipmentTitle

func _ready() -> void:
	# Hide all UI elements by default
	if _background_overlay:
		_background_overlay.visible = false
	if _stats_panel_container:
		_stats_panel_container.visible = false
	if _right_panel_container:
		_right_panel_container.visible = false
	if _header_container:
		_header_container.visible = false
	if _equipment_title_label:
		_equipment_title_label.visible = false
	if _profile_sprite:
		_profile_sprite.visible = false
	_setup_equipment_slots()
	_setup_inventory_grid()
	
	if _close_button:
		_close_button.pressed.connect(_on_close_button_pressed)
	if _cards_button:
		_cards_button.pressed.connect(_on_cards_button_pressed)
	
	# Only connect signals at runtime, not in editor
	if not Engine.is_editor_hint():
		EventBus.stats_changed.connect(_on_stats_changed)
		EventBus.currency_changed.connect(_on_currency_changed)
		EventBus.item_collected.connect(_on_item_collected)
		EventBus.player_health_changed.connect(_on_player_health_changed)
	_update_stats_display()

func _is_battle_active() -> bool:
	# Check if BattleArena exists in the scene tree (battle is active)
	# Battle scenes are added to root when active
	var battle_arena: Node = get_tree().root.get_node_or_null("BattleArena")
	if battle_arena:
		return true
	
	# Alternative: Check for BattleManager specifically
	# BattleManager extends Node2D, GameManager extends Node
	# Only check Node2D nodes with start_battle method
	for child in get_tree().root.get_children():
		# Skip known autoloads (GameManager, EventBus, etc.)
		if child == GameManager or child.name == "EventBus" or child.name == "CardRegistry" or child.name == "SaveManager":
			continue
		
		# BattleManager is Node2D, GameManager is Node
		if child is Node2D and child.has_method("start_battle"):
			return true
	
	return false

func _input(event: InputEvent) -> void:
	# Don't open inventory during battle
	var battle_active: bool = _is_battle_active()
	if battle_active:
		return
	
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
	# Don't allow opening inventory during battle
	var battle_active: bool = _is_battle_active()
	if not _is_open and battle_active:
		return
	
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
	if _stats_panel_container:
		_stats_panel_container.visible = true
	if _right_panel_container:
		_right_panel_container.visible = true
	if _header_container:
		_header_container.visible = true
	if _equipment_title_label:
		_equipment_title_label.visible = true
	if _profile_sprite:
		_profile_sprite.visible = true
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
	if _background_overlay:
		_background_overlay.visible = false
	if _stats_panel_container:
		_stats_panel_container.visible = false
	if _right_panel_container:
		_right_panel_container.visible = false
	if _header_container:
		_header_container.visible = false
	if _equipment_title_label:
		_equipment_title_label.visible = false
	if _profile_sprite:
		_profile_sprite.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	EventBus.inventory_closed.emit()
	EventBus.game_resumed.emit()

func _setup_equipment_slots() -> void:
	# Equipment slots are in EquipmentSlots container
	if not _equipment_slots_container:
		return
	
	# Setup function to configure a slot
	var setup_slot = func(slot_name: String, slot_type: ItemData.ItemType) -> void:
		var slot: Control = _equipment_slots_container.get_node_or_null(slot_name)
		if slot and slot.has_method("set_slot_type"):
			slot.set_slot_type(slot_type)
			if not slot.slot_clicked.is_connected(_on_equipment_slot_clicked):
				slot.slot_clicked.connect(_on_equipment_slot_clicked)
			_equipment_slots[slot_type] = slot
	
	# Setup all equipment slots
	setup_slot.call("WeaponSlot", ItemData.ItemType.WEAPON)
	setup_slot.call("ArmorSlot", ItemData.ItemType.ARMOR)
	setup_slot.call("HelmSlot", ItemData.ItemType.HELM)
	setup_slot.call("BootsSlot", ItemData.ItemType.BOOTS)
	setup_slot.call("BeltSlot", ItemData.ItemType.BELT)
	setup_slot.call("LegsSlot", ItemData.ItemType.LEGS)
	setup_slot.call("PauldronsSlot", ItemData.ItemType.PAULDRONS)
	setup_slot.call("GlovesSlot", ItemData.ItemType.GLOVES)
	setup_slot.call("Ring1Slot", ItemData.ItemType.RING)
	setup_slot.call("Ring2Slot", ItemData.ItemType.RING)
	setup_slot.call("Accessory1Slot", ItemData.ItemType.ACCESSORY)

func _setup_inventory_grid() -> void:
	if not _inventory_grid:
		return
	
	# Check if slots already exist (editor scenario)
	var existing_slots: int = _inventory_grid.get_child_count()
	var expected_slots: int = INVENTORY_GRID_TOTAL_SLOTS
	
	# Only create slots if they don't exist or count doesn't match
	if existing_slots != expected_slots:
		# Clear existing slots if count doesn't match
		if existing_slots > 0:
			for child in _inventory_grid.get_children():
				child.queue_free()
		
		_inventory_slots.clear()
		
		# Create inventory slots
		for row in range(INVENTORY_GRID_ROWS):
			for col in range(INVENTORY_GRID_COLUMNS):
				var slot_scene: PackedScene = load("res://scenes/exploration/ui/widgets/inventory_slot.tscn")
				if slot_scene:
					var slot: Control = slot_scene.instantiate()
					_inventory_grid.add_child(slot)
					# Set position after adding to tree (ensures script is loaded)
					# Use set() method which works even if property isn't directly accessible in @tool mode
					slot.set("slot_position", Vector2i(col, row))
					
					# Only connect signals at runtime, not in editor
					if not Engine.is_editor_hint():
						slot.slot_clicked.connect(_on_inventory_slot_clicked)
						if slot.has_signal("slot_drag_started"):
							slot.slot_drag_started.connect(_on_slot_drag_started)
					
					_inventory_slots.append(slot)
	else:
		# Slots already exist, just populate the array
		_inventory_slots.clear()
		for child in _inventory_grid.get_children():
			if child is Control:
				_inventory_slots.append(child)

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
	for row in range(INVENTORY_GRID_ROWS):
		for col in range(INVENTORY_GRID_COLUMNS):
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
	# Don't access GameManager in editor mode
	if Engine.is_editor_hint():
		return
	
	if not GameManager.player_stats:
		return
	
	var stats: PlayerStats = GameManager.player_stats
	
	if _health_label:
		# Use current_life if initialized, otherwise fall back to max_life
		var current_life: int = GameManager.player_current_life
		if current_life < 0:
			current_life = GameManager.player_max_life
		_health_label.text = "Health: " + str(current_life) + "/" + str(GameManager.player_max_life)
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
		# Hide all inventory menu elements
		if _background_overlay:
			_background_overlay.visible = false
		if _stats_panel_container:
			_stats_panel_container.visible = false
		if _right_panel_container:
			_right_panel_container.visible = false
		if _header_container:
			_header_container.visible = false
		if _equipment_title_label:
			_equipment_title_label.visible = false
		if _profile_sprite:
			_profile_sprite.visible = false

func _on_stats_changed() -> void:
	_update_stats_display()
	_refresh_inventory_display()

func _on_currency_changed(_current: int) -> void:
	_update_stats_display()

func _on_item_collected(item_name: StringName) -> void:
	# Refresh inventory display when item is collected
	if _is_open:
		_refresh_inventory_display()

func _on_player_health_changed(current: int, maximum: int) -> void:
	# Update stats display when health changes (e.g., after battle)
	_update_stats_display()

func _exit_tree() -> void:
	# Only disconnect signals at runtime, not in editor
	if not Engine.is_editor_hint():
		if EventBus.stats_changed.is_connected(_on_stats_changed):
			EventBus.stats_changed.disconnect(_on_stats_changed)
		if EventBus.currency_changed.is_connected(_on_currency_changed):
			EventBus.currency_changed.disconnect(_on_currency_changed)
		if EventBus.item_collected.is_connected(_on_item_collected):
			EventBus.item_collected.disconnect(_on_item_collected)
		if EventBus.player_health_changed.is_connected(_on_player_health_changed):
			EventBus.player_health_changed.disconnect(_on_player_health_changed)
