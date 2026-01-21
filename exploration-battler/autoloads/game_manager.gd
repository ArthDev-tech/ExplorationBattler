extends Node

## Manages global game state, scene transitions, and high-level game flow.

# Preload core resource classes to ensure they're registered before resources load
# These const declarations execute when the script loads (before _ready)
const CardDataScript = preload("res://scripts/core/card_data.gd")
const EnemyDataScript = preload("res://scripts/core/enemy_data.gd")
const ItemDataScript = preload("res://scripts/core/item_data.gd")
const PlayerStatsScript = preload("res://scripts/core/player_stats.gd")
const InventoryScript = preload("res://scripts/core/inventory.gd")
const DeckScript = preload("res://scripts/core/deck.gd")

var current_scene: Node = null
var player_deck: RefCounted = null
var player_max_life: int = 20
var current_zone: StringName = &""

var player_stats: PlayerStats = null
var player_inventory: Inventory = null
var player_card_collection: Array[CardData] = []
var equipped_items: Dictionary = {}  # {ItemData.ItemType: ItemInstance}
var player_currency: int = 0

func _ready() -> void:
	current_scene = get_tree().current_scene
	EventBus.scene_transition_requested.connect(_on_scene_transition_requested)
	
	# Initialize player systems
	player_stats = PlayerStats.new()
	player_inventory = Inventory.new()
	equipped_items = {
		ItemData.ItemType.WEAPON: null,
		ItemData.ItemType.ARMOR: null,
		ItemData.ItemType.ACCESSORY: null
	}
	
	# Initialize starter deck and card collection
	_initialize_starter_deck()
	_initialize_card_collection()

func _on_scene_transition_requested(scene_path: String) -> void:
	transition_to_scene(scene_path)

func transition_to_scene(scene_path: String) -> void:
	# Use call_deferred to avoid removing nodes during physics callbacks
	call_deferred("_do_transition", scene_path)

func _do_transition(scene_path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to transition to scene: " + scene_path + " Error: " + str(error))
		return
	current_scene = get_tree().current_scene

func start_battle(enemy_data: Resource, triggering_enemy: Node3D = null) -> void:
	if BattleOverlayManager:
		BattleOverlayManager.show_battle_overlay(enemy_data as EnemyData, triggering_enemy)
	else:
		push_error("BattleOverlayManager not found - battle overlay system not available")

func return_to_exploration() -> void:
	transition_to_scene("res://scenes/exploration/levels/test_room.tscn")

func add_currency(amount: int) -> void:
	if amount == 0:
		return
	player_currency = maxi(0, player_currency + amount)
	EventBus.currency_changed.emit(player_currency)

func initialize_player_deck(deck: RefCounted) -> void:
	player_deck = deck

func _initialize_starter_deck() -> void:
	# Create starter deck with the same structure as battle_manager.gd
	var starter_cards: Array[CardData] = []
	
	# Load card resources
	var wandering_soul: CardData = load("res://resources/cards/starter/wandering_soul.tres") as CardData
	if not wandering_soul:
		push_error("Failed to load wandering_soul card")
	
	var forest_whelp: CardData = load("res://resources/cards/starter/forest_whelp.tres") as CardData
	if not forest_whelp:
		push_error("Failed to load forest_whelp card")
	
	var stone_sentry: CardData = load("res://resources/cards/starter/stone_sentry.tres") as CardData
	if not stone_sentry:
		push_error("Failed to load stone_sentry card")
	
	var soul_strike: CardData = load("res://resources/cards/starter/soul_strike.tres") as CardData
	if not soul_strike:
		push_error("Failed to load soul_strike card")
	
	# Add cards with proper quantities
	if wandering_soul:
		for i in range(3):
			starter_cards.append(wandering_soul)
	if forest_whelp:
		for i in range(2):
			starter_cards.append(forest_whelp)
	if stone_sentry:
		for i in range(2):
			starter_cards.append(stone_sentry)
	
	# Add single copies
	var vengeful_spirit: CardData = load("res://resources/cards/starter/vengeful_spirit.tres") as CardData
	if vengeful_spirit:
		starter_cards.append(vengeful_spirit)
	else:
		push_error("Failed to load vengeful_spirit card")
	
	var thornback_wolf: CardData = load("res://resources/cards/starter/thornback_wolf.tres") as CardData
	if thornback_wolf:
		starter_cards.append(thornback_wolf)
	else:
		push_error("Failed to load thornback_wolf card")
	
	var hollow_knight: CardData = load("res://resources/cards/starter/hollow_knight.tres") as CardData
	if hollow_knight:
		starter_cards.append(hollow_knight)
	else:
		push_error("Failed to load hollow_knight card")
	
	if soul_strike:
		for i in range(2):
			starter_cards.append(soul_strike)
	
	var mend: CardData = load("res://resources/cards/starter/mend.tres") as CardData
	if mend:
		starter_cards.append(mend)
	else:
		push_error("Failed to load mend card")
	
	var spectral_surge: CardData = load("res://resources/cards/starter/spectral_surge.tres") as CardData
	if spectral_surge:
		starter_cards.append(spectral_surge)
	else:
		push_error("Failed to load spectral_surge card")
	
	var cracked_lantern: CardData = load("res://resources/cards/starter/cracked_lantern.tres") as CardData
	if cracked_lantern:
		starter_cards.append(cracked_lantern)
	else:
		push_error("Failed to load cracked_lantern card")
	
	# Create deck
	if not starter_cards.is_empty():
		player_deck = Deck.new(starter_cards)
	else:
		push_error("Failed to initialize starter deck - no cards loaded")

func _initialize_card_collection() -> void:
	# Add starter cards to collection (one of each unique card)
	var starter_cards: Array[String] = [
		"res://resources/cards/starter/wandering_soul.tres",
		"res://resources/cards/starter/forest_whelp.tres",
		"res://resources/cards/starter/stone_sentry.tres",
		"res://resources/cards/starter/soul_strike.tres",
		"res://resources/cards/starter/vengeful_spirit.tres",
		"res://resources/cards/starter/thornback_wolf.tres",
		"res://resources/cards/starter/hollow_knight.tres",
		"res://resources/cards/starter/mend.tres",
		"res://resources/cards/starter/spectral_surge.tres",
		"res://resources/cards/starter/cracked_lantern.tres"
	]
	
	player_card_collection.clear()
	for card_path in starter_cards:
		var card: CardData = load(card_path) as CardData
		if card:
			player_card_collection.append(card)
		else:
			push_error("Failed to load card from path: " + card_path)
	
	if player_card_collection.is_empty():
		push_error("Card collection is empty - no cards loaded successfully!")

func equip_item(item: ItemInstance, slot_type: ItemData.ItemType) -> bool:
	if not item or item.data.item_type != slot_type:
		return false
	
	# Unequip current item if any
	var current_item: ItemInstance = equipped_items.get(slot_type)
	if current_item:
		unequip_item(slot_type)
	
	# Equip new item
	equipped_items[slot_type] = item
	player_inventory.remove_item(item)
	player_stats.update_equipment_bonuses(equipped_items)
	EventBus.item_equipped.emit(item, slot_type)
	EventBus.stats_changed.emit()
	return true

func unequip_item(slot_type: ItemData.ItemType) -> bool:
	var item: ItemInstance = equipped_items.get(slot_type)
	if not item:
		return false
	
	# Try to add back to inventory
	if player_inventory.add_item(item):
		equipped_items[slot_type] = null
		player_stats.update_equipment_bonuses(equipped_items)
		EventBus.item_unequipped.emit(item, slot_type)
		EventBus.stats_changed.emit()
		return true
	else:
		# Inventory full, can't unequip
		return false

func _exit_tree() -> void:
	if EventBus.scene_transition_requested.is_connected(_on_scene_transition_requested):
		EventBus.scene_transition_requested.disconnect(_on_scene_transition_requested)
