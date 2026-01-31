extends Node

## =============================================================================
## GameManager - Central Game State Controller (Autoload Singleton)
## =============================================================================
## Manages global game state, scene transitions, and high-level game flow.
## This autoload is the single source of truth for:
## - Player deck and card collection
## - Player stats, inventory, and equipment
## - Currency and persistent health
## - Scene transitions and zone tracking
##
## Access via: GameManager (autoload name in Project Settings)
## =============================================================================

# -----------------------------------------------------------------------------
# PRELOADED SCRIPTS
# -----------------------------------------------------------------------------
# Preload core resource classes to ensure they're registered before resources load.
# These const declarations execute when the script loads (before _ready).
const CardDataScript = preload("res://scripts/core/card_data.gd")
const EnemyDataScript = preload("res://scripts/core/enemy_data.gd")
const ItemDataScript = preload("res://scripts/core/item_data.gd")
const PlayerDataScript = preload("res://scripts/core/player_data.gd")
const PlayerStatsScript = preload("res://scripts/core/player_stats.gd")
const InventoryScript = preload("res://scripts/core/inventory.gd")
const DeckScript = preload("res://scripts/core/deck.gd")

# -----------------------------------------------------------------------------
# STATE VARIABLES
# -----------------------------------------------------------------------------

## Player data resource - loaded dynamically to ensure class is registered first.
## Contains base stats defined in player_data.tres.
var _player_data: Resource = null

## Reference to the currently active scene node.
var current_scene: Node = null

## The player's current deck (Deck class instance).
## Initialized from starting_deck.json on game start.
var player_deck: RefCounted = null

## Current exploration zone identifier (e.g., &"forest", &"dungeon").
## Used for save/load and zone-specific logic.
var current_zone: StringName = &""

## Computed max life including equipment bonuses.
## Dynamically calculated from player_stats when accessed.
var player_max_life: int:
	get:
		if player_stats:
			return player_stats.get_total_health()
		# Fallback if player_stats not initialized yet
		var value = _player_data.get("max_life") if _player_data else null
		# HARDCODED: Default fallback max life if data not loaded
		return value if value != null else 20

## Player stats manager - handles base stats and equipment bonuses.
var player_stats: PlayerStats = null

## Player inventory - holds unequipped items.
var player_inventory: Inventory = null

## All cards the player has unlocked/collected (unique CardData references).
var player_card_collection: Array[CardData] = []

## Persistent collection quantities keyed by CardData.card_id.
## This drives deckbuilding availability (how many copies of each card you own).
var player_card_quantities: Dictionary = {}  # {StringName: int}

## Currently equipped items by slot type.
## Keys are ItemData.ItemType enum values (WEAPON, ARMOR, ACCESSORY).
var equipped_items: Dictionary = {}  # {ItemData.ItemType: ItemInstance}

## Player's currency (gold/coins).
var player_currency: int = 0

## Persistent player health between battles.
## -1 indicates uninitialized (will use max_life on first battle).
var player_current_life: int = -1

## Shop inventory for the NPC currently in dialogue (set when dialogue opens, cleared when shop closes).
var current_shop_inventory: Resource = null

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

func _ready() -> void:
	current_scene = get_tree().current_scene
	EventBus.scene_transition_requested.connect(_on_scene_transition_requested)
	
	# Load player data resource - must happen in _ready() to ensure class is registered
	# HARDCODED: Path to player base data resource
	_player_data = load("res://resources/player/player_data.tres")
	
	# Initialize player systems
	player_stats = PlayerStats.new()
	player_stats.initialize(_player_data)
	player_inventory = Inventory.new()
	
	# Initialize equipment slots (all empty at start)
	equipped_items = {
		ItemData.ItemType.WEAPON: null,
		ItemData.ItemType.ARMOR: null,
		ItemData.ItemType.HELM: null,
		ItemData.ItemType.BOOTS: null,
		ItemData.ItemType.BELT: null,
		ItemData.ItemType.LEGS: null,
		ItemData.ItemType.PAULDRONS: null,
		ItemData.ItemType.GLOVES: null,
		ItemData.ItemType.RING: null,
		ItemData.ItemType.ACCESSORY: null
	}
	
	# Initialize starter deck and card collection
	_initialize_starter_deck()
	_initialize_card_collection()
	_rebuild_collection_quantities_from_deck()
	
	# Initialize player health if not already set
	if player_current_life < 0:
		player_current_life = player_max_life

# -----------------------------------------------------------------------------
# SCENE TRANSITIONS
# -----------------------------------------------------------------------------

func _on_scene_transition_requested(scene_path: String) -> void:
	transition_to_scene(scene_path)

## Transitions to a new scene. Uses call_deferred to avoid issues during physics.
## @param scene_path: Full resource path to the scene (e.g., "res://scenes/...")
func transition_to_scene(scene_path: String) -> void:
	# Use call_deferred to avoid removing nodes during physics callbacks
	call_deferred("_do_transition", scene_path)

func _do_transition(scene_path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to transition to scene: " + scene_path + " Error: " + str(error))
		return
	current_scene = get_tree().current_scene

# -----------------------------------------------------------------------------
# BATTLE MANAGEMENT
# -----------------------------------------------------------------------------

## Initiates a battle with the specified enemy.
## @param enemy_data: EnemyData resource defining the enemy
## @param triggering_enemy: Optional reference to the 3D enemy node that started combat
func start_battle(enemy_data: Resource, triggering_enemy: Node3D = null) -> void:
	if BattleOverlayManager:
		BattleOverlayManager.show_battle_overlay(enemy_data as EnemyData, triggering_enemy)
	else:
		push_error("BattleOverlayManager not found - battle overlay system not available")

## Returns player to the exploration test room after battle.
## HARDCODED: Scene path - change this when implementing zone-based return
func return_to_exploration() -> void:
	transition_to_scene("res://scenes/exploration/levels/test_room.tscn")

# -----------------------------------------------------------------------------
# CURRENCY MANAGEMENT
# -----------------------------------------------------------------------------

## Adds or removes currency from player.
## @param amount: Positive to add, negative to remove (clamped to 0 minimum)
func add_currency(amount: int) -> void:
	if amount == 0:
		return
	player_currency = maxi(0, player_currency + amount)
	EventBus.currency_changed.emit(player_currency)

# -----------------------------------------------------------------------------
# CARD COLLECTION MANAGEMENT
# -----------------------------------------------------------------------------

## Adds copies of a card to the player's collection.
## @param card: The CardData to add
## @param amount: Number of copies to add (default 1)
func add_card_to_collection(card: CardData, amount: int = 1) -> void:
	var add_amount: int = maxi(0, amount)
	if add_amount <= 0:
		return
	if not card:
		return
	
	# Ensure the card is in the visible collection list
	var cid: StringName = card.card_id
	var has_card: bool = false
	for existing in player_card_collection:
		if existing and existing.card_id == cid:
			has_card = true
			break
	if not has_card:
		player_card_collection.append(card)
	
	# Increase owned quantity
	var current: int = int(player_card_quantities.get(cid, 0))
	player_card_quantities[cid] = current + add_amount

## Rebuilds card quantity tracking from the current deck.
## Called on initialization to sync quantities with starter deck.
func _rebuild_collection_quantities_from_deck() -> void:
	player_card_quantities.clear()
	var deck: Deck = player_deck as Deck
	if deck:
		for inst in deck.cards:
			if inst and inst.data:
				var cid: StringName = inst.data.card_id
				player_card_quantities[cid] = int(player_card_quantities.get(cid, 0)) + 1
	
	# Ensure every unlocked collection card has at least 1 quantity entry (even if not in deck)
	for cd in player_card_collection:
		if not cd:
			continue
		if not player_card_quantities.has(cd.card_id):
			player_card_quantities[cd.card_id] = 1

## Sets the player deck (used when loading saves or changing decks).
func initialize_player_deck(deck: RefCounted) -> void:
	player_deck = deck

## Loads the starter deck from JSON configuration.
## HARDCODED: Path to starter deck JSON file
func _initialize_starter_deck() -> void:
	# HARDCODED: Starter deck configuration path - change for different starter decks
	var path: String = "res://resources/player/decks/starting_deck.json"
	var card_registry: Node = get_node_or_null("/root/CardRegistry")
	
	if not card_registry or not card_registry.has_method("get_card"):
		push_error("GameManager: CardRegistry not available for starter deck")
		return
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("GameManager: could not open starter deck json: " + path)
		return
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameManager: invalid starter deck json")
		return
	
	var starter_cards: Array[CardData] = []
	var counts: Dictionary = parsed as Dictionary
	for key in counts.keys():
		var cid_str: String = String(key)
		var card_id: StringName = StringName(cid_str)
		# Parse count from various JSON number formats
		var count_raw: Variant = counts.get(key, 0)
		var count: int = 0
		if typeof(count_raw) == TYPE_INT:
			count = int(count_raw)
		elif typeof(count_raw) == TYPE_FLOAT:
			count = int(count_raw)
		elif typeof(count_raw) == TYPE_STRING:
			count = int(String(count_raw).to_int())
		
		if count <= 0:
			continue
		
		var card_data: CardData = card_registry.call("get_card", card_id) as CardData
		if card_data:
			for i in range(count):
				starter_cards.append(card_data)
		else:
			push_warning("GameManager: starter deck json references unknown card_id '" + cid_str + "'")
	
	# Create deck from loaded cards
	if not starter_cards.is_empty():
		player_deck = Deck.new(starter_cards)
	else:
		push_error("Failed to initialize starter deck from JSON - no cards loaded")

## Initializes the card collection with all starter cards.
## HARDCODED: List of starter card resource paths - expand this list to add more cards
func _initialize_card_collection() -> void:
	# HARDCODED: Starter card paths - add new cards here as they're created
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

# -----------------------------------------------------------------------------
# EQUIPMENT MANAGEMENT
# -----------------------------------------------------------------------------

## Equips an item to the specified slot.
## @param item: ItemInstance to equip
## @param slot_type: ItemData.ItemType enum value
## @return: true if equipped successfully, false otherwise
func equip_item(item: ItemInstance, slot_type: ItemData.ItemType) -> bool:
	if not item or item.data.item_type != slot_type:
		return false
	
	# Unequip current item if any
	var current_item: ItemInstance = equipped_items.get(slot_type)
	if current_item:
		unequip_item(slot_type)
	
	# Get HP bonus from item before equipping
	var hp_bonus: int = item.get_total_health_bonus()
	
	# Equip new item
	equipped_items[slot_type] = item
	player_inventory.remove_item(item)
	player_stats.update_equipment_bonuses(equipped_items)
	
	# Add HP bonus directly to current health (symmetric with unequip)
	if hp_bonus > 0 and player_current_life >= 0:
		player_current_life += hp_bonus
		# Cap at new max life (can't exceed maximum)
		player_current_life = mini(player_current_life, player_max_life)
	
	EventBus.item_equipped.emit(item, slot_type)
	EventBus.stats_changed.emit()
	return true

## Unequips an item from the specified slot and returns it to inventory.
## @param slot_type: ItemData.ItemType enum value
## @return: true if unequipped successfully, false if slot empty or inventory full
func unequip_item(slot_type: ItemData.ItemType) -> bool:
	var item: ItemInstance = equipped_items.get(slot_type)
	if not item:
		return false
	
	# Get HP bonus from item before unequipping
	var hp_bonus: int = item.get_total_health_bonus()
	
	# Try to add back to inventory
	if player_inventory.add_item(item):
		equipped_items[slot_type] = null
		player_stats.update_equipment_bonuses(equipped_items)
		
		# Reduce current health by the HP bonus amount
		if hp_bonus > 0 and player_current_life >= 0:
			player_current_life -= hp_bonus
			# Ensure health never goes below 1 HP
			player_current_life = maxi(1, player_current_life)
		
		EventBus.item_unequipped.emit(item, slot_type)
		EventBus.stats_changed.emit()
		return true
	else:
		# Inventory full, can't unequip
		return false

## Updates player_current_life when max_life changes due to equipment.
## If max increases: scales current health proportionally.
## If max decreases: caps current health at new max.
func _update_health_on_max_change(old_max: int, new_max: int) -> void:
	if player_current_life < 0:
		# Not initialized yet, set to new max
		player_current_life = new_max
		return
	
	if new_max > old_max:
		# Max increased: scale proportionally
		if old_max > 0:
			var ratio: float = float(player_current_life) / float(old_max)
			player_current_life = int(round(ratio * float(new_max)))
		else:
			player_current_life = new_max
	else:
		# Max decreased: cap at new max
		player_current_life = mini(player_current_life, new_max)
	
	# Ensure health is never negative
	player_current_life = maxi(0, player_current_life)

# -----------------------------------------------------------------------------
# INVENTORY MANAGEMENT
# -----------------------------------------------------------------------------

## Adds an item to the player's inventory.
## @param item_data: ItemData resource to create an instance from
## @return: true if added successfully, false if inventory full or invalid
func add_item_to_inventory(item_data: ItemData) -> bool:
	if not item_data or not player_inventory:
		push_warning("add_item_to_inventory: item_data or player_inventory is null")
		return false
	
	if player_inventory.is_full():
		push_warning("Inventory is full, cannot add item: " + item_data.item_name)
		return false
	
	var item_instance: ItemInstance = ItemInstance.new(item_data, 1)
	if player_inventory.add_item(item_instance):
		EventBus.item_collected.emit(StringName(item_data.item_name))
		EventBus.stats_changed.emit()  # Trigger UI refresh
		return true
	else:
		push_warning("Failed to add item to inventory: " + item_data.item_name)
		return false

# -----------------------------------------------------------------------------
# CLEANUP
# -----------------------------------------------------------------------------

func _exit_tree() -> void:
	if EventBus.scene_transition_requested.is_connected(_on_scene_transition_requested):
		EventBus.scene_transition_requested.disconnect(_on_scene_transition_requested)
