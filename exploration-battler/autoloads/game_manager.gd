extends Node

## Manages global game state, scene transitions, and high-level game flow.

# Preload core resource classes to ensure they're registered before resources load
# These const declarations execute when the script loads (before _ready)
const CardDataScript = preload("res://scripts/core/card_data.gd")
const EnemyDataScript = preload("res://scripts/core/enemy_data.gd")
const ItemDataScript = preload("res://scripts/core/item_data.gd")
const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const PlayerStatsScript = preload("res://scripts/core/player_stats.gd")
const InventoryScript = preload("res://scripts/core/inventory.gd")
const DeckScript = preload("res://scripts/core/deck.gd")

# Player data resource - loaded dynamically to ensure class is registered first
var _player_data: Resource = null

var current_scene: Node = null
var player_deck: RefCounted = null
var current_zone: StringName = &""

# Computed from _player_data for easy access
var player_max_life: int:
	get:
		var value = _player_data.get("max_life") if _player_data else null
		return value if value != null else 20

var player_stats: PlayerStats = null
var player_inventory: Inventory = null
var player_card_collection: Array[CardData] = []
## Persistent collection quantities keyed by `CardData.card_id`.
## This drives deckbuilding availability (how many copies you own).
var player_card_quantities: Dictionary = {}  # {StringName: int}
var equipped_items: Dictionary = {}  # {ItemData.ItemType: ItemInstance}
var player_currency: int = 0

func _ready() -> void:
	current_scene = get_tree().current_scene
	EventBus.scene_transition_requested.connect(_on_scene_transition_requested)
	
	# Load player data resource - must happen in _ready() to ensure class is registered
	_player_data = load("res://resources/player/player_data.tres")
	
	# Initialize player systems
	player_stats = PlayerStats.new()
	player_stats.initialize(_player_data)
	player_inventory = Inventory.new()
	equipped_items = {
		ItemData.ItemType.WEAPON: null,
		ItemData.ItemType.ARMOR: null,
		ItemData.ItemType.ACCESSORY: null
	}
	
	# Initialize starter deck and card collection
	_initialize_starter_deck()
	_initialize_card_collection()
	_rebuild_collection_quantities_from_deck()

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
	if enemy_data:
		var ed = enemy_data as EnemyData
		if ed:
			print("DEBUG [GameManager]: enemy_data.display_name = ", ed.display_name)
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

func add_card_to_collection(card: CardData, amount: int = 1) -> void:
	var add_amount: int = maxi(0, amount)
	if add_amount <= 0:
		return
	if not card:
		return
	
	# Ensure the card is in the visible collection list.
	var cid: StringName = card.card_id
	var has_card: bool = false
	for existing in player_card_collection:
		if existing and existing.card_id == cid:
			has_card = true
			break
	if not has_card:
		player_card_collection.append(card)
	
	# Increase owned quantity.
	var current: int = int(player_card_quantities.get(cid, 0))
	player_card_quantities[cid] = current + add_amount

func _rebuild_collection_quantities_from_deck() -> void:
	player_card_quantities.clear()
	var deck: Deck = player_deck as Deck
	if deck:
		for inst in deck.cards:
			if inst and inst.data:
				var cid: StringName = inst.data.card_id
				player_card_quantities[cid] = int(player_card_quantities.get(cid, 0)) + 1
	
	# Ensure every unlocked collection card has at least 1 quantity entry (even if not in deck).
	for cd in player_card_collection:
		if not cd:
			continue
		if not player_card_quantities.has(cd.card_id):
			player_card_quantities[cd.card_id] = 1

func initialize_player_deck(deck: RefCounted) -> void:
	player_deck = deck

func _initialize_starter_deck() -> void:
	# Create starter deck with one of each starter card
	var starter_card_paths: Array[String] = [
		# Original starter cards
		"res://resources/cards/starter/wandering_soul.tres",
		"res://resources/cards/starter/forest_whelp.tres",
		"res://resources/cards/starter/stone_sentry.tres",
		"res://resources/cards/starter/soul_strike.tres",
		"res://resources/cards/starter/vengeful_spirit.tres",
		"res://resources/cards/starter/thornback_wolf.tres",
		"res://resources/cards/starter/hollow_knight.tres",
		"res://resources/cards/starter/mend.tres",
		"res://resources/cards/starter/spectral_surge.tres",
		"res://resources/cards/starter/cracked_lantern.tres",
		# Green energy cards
		"res://resources/cards/starter/green_breath.tres",
		"res://resources/cards/starter/green_bloom_guardian.tres",
		"res://resources/cards/starter/green_restore.tres",
		"res://resources/cards/starter/green_rejuvenate.tres",
		# Blue energy cards
		"res://resources/cards/starter/blue_ponder.tres",
		"res://resources/cards/starter/blue_study.tres",
		"res://resources/cards/starter/blue_skim.tres",
		"res://resources/cards/starter/blue_insight.tres",
		# Red energy cards
		"res://resources/cards/starter/red_uppercut.tres",
		"res://resources/cards/starter/red_rampage.tres",
		"res://resources/cards/starter/red_bash.tres",
		"res://resources/cards/starter/red_strike.tres",
		# Grey energy cards
		"res://resources/cards/starter/grey_scout.tres",
		"res://resources/cards/starter/grey_shieldbearer.tres",
		"res://resources/cards/starter/grey_strike.tres"
	]
	
	var starter_cards: Array[CardData] = []
	for card_path in starter_card_paths:
		var card: CardData = load(card_path) as CardData
		if card:
			starter_cards.append(card)
		else:
			push_error("Failed to load card from path: " + card_path)
	
	# Create deck
	if not starter_cards.is_empty():
		player_deck = Deck.new(starter_cards)
	else:
		push_error("Failed to initialize starter deck - no cards loaded")

func _initialize_card_collection() -> void:
	# Add starter cards to collection (one of each unique card)
	var starter_cards: Array[String] = [
		# Original starter cards
		"res://resources/cards/starter/wandering_soul.tres",
		"res://resources/cards/starter/forest_whelp.tres",
		"res://resources/cards/starter/stone_sentry.tres",
		"res://resources/cards/starter/soul_strike.tres",
		"res://resources/cards/starter/vengeful_spirit.tres",
		"res://resources/cards/starter/thornback_wolf.tres",
		"res://resources/cards/starter/hollow_knight.tres",
		"res://resources/cards/starter/mend.tres",
		"res://resources/cards/starter/spectral_surge.tres",
		"res://resources/cards/starter/cracked_lantern.tres",
		# Green energy cards
		"res://resources/cards/starter/green_breath.tres",
		"res://resources/cards/starter/green_bloom_guardian.tres",
		"res://resources/cards/starter/green_restore.tres",
		"res://resources/cards/starter/green_rejuvenate.tres",
		# Blue energy cards
		"res://resources/cards/starter/blue_ponder.tres",
		"res://resources/cards/starter/blue_study.tres",
		"res://resources/cards/starter/blue_skim.tres",
		"res://resources/cards/starter/blue_insight.tres",
		# Red energy cards
		"res://resources/cards/starter/red_uppercut.tres",
		"res://resources/cards/starter/red_rampage.tres",
		"res://resources/cards/starter/red_bash.tres",
		"res://resources/cards/starter/red_strike.tres",
		# Grey energy cards
		"res://resources/cards/starter/grey_scout.tres",
		"res://resources/cards/starter/grey_shieldbearer.tres",
		"res://resources/cards/starter/grey_strike.tres"
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

func add_item_to_inventory(item_data: ItemData) -> bool:
	if not item_data or not player_inventory:
		push_warning("add_item_to_inventory: item_data or player_inventory is null")
		return false
	
	if player_inventory.is_full():
		push_warning("Inventory is full, cannot add item: " + item_data.item_name)
		return false
	
	var item_instance: ItemInstance = ItemInstance.new(item_data, 1)
	if player_inventory.add_item(item_instance):
		print("DEBUG: Added item to inventory: ", item_data.item_name, " (total items: ", player_inventory.get_item_count(), ")")
		EventBus.item_collected.emit(StringName(item_data.item_name))
		EventBus.stats_changed.emit()  # Trigger UI refresh
		return true
	else:
		push_warning("Failed to add item to inventory: " + item_data.item_name)
		return false

func _exit_tree() -> void:
	if EventBus.scene_transition_requested.is_connected(_on_scene_transition_requested):
		EventBus.scene_transition_requested.disconnect(_on_scene_transition_requested)
