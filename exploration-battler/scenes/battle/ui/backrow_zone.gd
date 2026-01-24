extends Control

## Manages a backrow zone with 3 slots for traps and relics.

signal backrow_slot_clicked(slot_index: int)
signal card_placed(card: CardInstance, slot: int)
signal card_removed(card: CardInstance, slot: int)

const MAX_SLOTS: int = 3

var is_player_zone: bool = true
var _cards: Array[CardInstance] = [null, null, null]
var _card_visuals: Array[Control] = [null, null, null]
var _slots: Array[Control] = []

var CARD_SCENE: PackedScene = null

@onready var _background: Panel = $Background
@onready var _label: Label = $Label
@onready var _slots_container: HBoxContainer = $SlotsContainer

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_setup_slots()

func _setup_slots() -> void:
	_slots.clear()
	if not _slots_container:
		return
	
	for i in range(_slots_container.get_child_count()):
		var slot: Control = _slots_container.get_child(i) as Control
		if slot:
			_slots.append(slot)
			# Connect click handling for each slot
			slot.gui_input.connect(_on_slot_gui_input.bind(i))
			slot.mouse_filter = MOUSE_FILTER_STOP

func set_player_zone(is_player: bool) -> void:
	is_player_zone = is_player
	if _label:
		_label.text = "Backrow" if is_player else "Enemy Backrow"

func place_card(card: CardInstance, slot: int = -1) -> bool:
	## Place a card in the backrow. If slot is -1, finds the first empty slot.
	if not card:
		return false
	
	# Find slot if not specified
	var target_slot: int = slot
	if target_slot < 0:
		target_slot = _find_empty_slot()
	
	if target_slot < 0 or target_slot >= MAX_SLOTS:
		return false
	
	if _cards[target_slot] != null:
		return false  # Slot occupied
	
	_cards[target_slot] = card
	
	# Create visual representation
	if not CARD_SCENE:
		CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene
	
	if CARD_SCENE and target_slot < _slots.size():
		var slot_node: Control = _slots[target_slot]
		var card_visual: Control = CARD_SCENE.instantiate()
		slot_node.add_child(card_visual)
		
		# Scale down for backrow display
		card_visual.scale = Vector2(0.7, 0.7)
		card_visual.anchors_preset = Control.PRESET_CENTER
		card_visual.position = slot_node.size / 2 - (card_visual.custom_minimum_size * 0.7) / 2
		
		if card_visual.has_method("set_card"):
			card_visual.set_card(card)
		
		_card_visuals[target_slot] = card_visual
	
	card_placed.emit(card, target_slot)
	return true

func remove_card(slot: int) -> CardInstance:
	## Remove and return the card from the specified slot.
	if slot < 0 or slot >= MAX_SLOTS:
		return null
	
	var card: CardInstance = _cards[slot]
	if not card:
		return null
	
	_cards[slot] = null
	
	# Remove visual
	if _card_visuals[slot]:
		_card_visuals[slot].queue_free()
		_card_visuals[slot] = null
	
	card_removed.emit(card, slot)
	return card

func get_card(slot: int) -> CardInstance:
	## Get the card at the specified slot.
	if slot < 0 or slot >= MAX_SLOTS:
		return null
	return _cards[slot]

func get_all_cards() -> Array[CardInstance]:
	## Get all non-null cards in the backrow.
	var result: Array[CardInstance] = []
	for card in _cards:
		if card:
			result.append(card)
	return result

func get_card_count() -> int:
	## Get the number of cards currently in the backrow.
	var count: int = 0
	for card in _cards:
		if card:
			count += 1
	return count

func is_full() -> bool:
	## Check if the backrow is full.
	return get_card_count() >= MAX_SLOTS

func _find_empty_slot() -> int:
	## Find the first empty slot, or -1 if full.
	for i in range(MAX_SLOTS):
		if _cards[i] == null:
			return i
	return -1

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.is_echo():
			backrow_slot_clicked.emit(slot_index)

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	# Check if data is a CardInstance
	if data == null or not data is CardInstance:
		return false
	
	var card: CardInstance = data as CardInstance
	if not card or not card.data:
		return false
	
	# Only accept non-creature cards (spells, traps, relics)
	if card.data.is_creature():
		return false
	
	# Check if there's room
	if is_full():
		return false
	
	# Check affordability
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		return false
	
	var battle_state = battle_manager.get("battle_state")
	if not battle_state:
		return false
	
	# Block plays until player picks start-of-turn energy color
	if battle_manager.get("_awaiting_energy_pick") == true:
		return false
	
	# Check if player can afford this card
	if is_player_zone and not battle_state.can_afford_player_cost(card.data):
		return false
	
	return true

func _drop_data(_position: Vector2, data: Variant) -> void:
	if data == null or not data is CardInstance:
		return
	
	var card: CardInstance = data as CardInstance
	if not card:
		return
	
	var battle_manager = _get_battle_manager()
	if battle_manager and battle_manager.has_method("play_card"):
		# Use -1 for lane to indicate backrow placement
		# The battle manager will handle backrow logic
		battle_manager.play_card(card, -1, is_player_zone)

func _get_battle_manager() -> Node:
	var paths: Array[String] = [
		"/root/BattleArena",
		"../../..",
		"../../../BattleArena"
	]
	for path in paths:
		var manager = get_node_or_null(path)
		if manager and manager.has_method("play_card"):
			return manager
	return null

func clear_all() -> void:
	## Remove all cards from the backrow.
	for i in range(MAX_SLOTS):
		remove_card(i)
