extends Node

## =============================================================================
## CardRegistry - Card Database (Autoload Singleton)
## =============================================================================
## Global registry for CardData resources indexed by card_id.
## Builds an index at startup by scanning configured directories for .tres files.
## Allows decks and other systems to reference cards by ID (e.g., from JSON).
##
## Usage:
##   var card: CardData = CardRegistry.get_card(&"wandering_soul")
##   if CardRegistry.has_card(&"some_id"): ...
##
## HARDCODED: Card directory paths defined in _build_index().
##
## Access via: CardRegistry (autoload name in Project Settings)
## =============================================================================

# -----------------------------------------------------------------------------
# STATE
# -----------------------------------------------------------------------------

## Index of all cards by their card_id StringName.
var _cards_by_id: Dictionary = {} # {StringName: CardData}

## Flag to prevent re-indexing after initial build.
var _initialized: bool = false

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

func _ready() -> void:
	_build_index()

## Scans all card directories and builds the card_id -> CardData index.
## Only runs once; subsequent calls are no-ops.
func _build_index() -> void:
	if _initialized:
		return
	_initialized = true
	_cards_by_id.clear()
	
	# HARDCODED: Card directory paths - add new directories here when creating new card categories
	var dirs: Array[String] = [
		"res://resources/cards/starter",    # Starting/basic cards
		"res://resources/cards/common",     # Common rarity cards
		"res://resources/cards/uncommon",   # Uncommon rarity cards
		"res://resources/cards/rare",       # Rare rarity cards
		"res://resources/cards/legendary",  # Legendary rarity cards
		"res://resources/cards/tokens",     # Token creatures (summoned, not in deck)
		"res://resources/cards/avatars"     # Player/enemy avatar cards
	]
	
	for dir_path in dirs:
		_index_cards_in_dir(dir_path)

## Indexes all .tres files in a directory as CardData.
## @param dir_path: Resource path to scan
func _index_cards_in_dir(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		# Directory may not exist yet (e.g., uncommon cards not added yet)
		push_warning("CardRegistry: could not open dir: " + dir_path)
		return
	
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		# Skip subdirectories
		if dir.current_is_dir():
			continue
		# Only process .tres resource files
		if not file_name.ends_with(".tres"):
			continue
		
		var res_path: String = dir_path.path_join(file_name)
		var cd: CardData = load(res_path) as CardData
		if not cd:
			continue
		
		var cid: StringName = cd.card_id
		# Validate card has an ID set
		if cid == &"":
			push_warning("CardRegistry: card has empty card_id: " + res_path)
			continue
		
		# Check for duplicate IDs (indicates misconfiguration)
		if _cards_by_id.has(cid):
			var existing: CardData = _cards_by_id.get(cid, null) as CardData
			var existing_path: String = existing.resource_path if existing else ""
			push_warning("CardRegistry: duplicate card_id '" + String(cid) + "' at " + res_path + " (already indexed: " + existing_path + ")")
			continue
		
		_cards_by_id[cid] = cd
	
	dir.list_dir_end()

# -----------------------------------------------------------------------------
# PUBLIC API
# -----------------------------------------------------------------------------

## Retrieves a card by its unique ID.
## @param card_id: The card's StringName identifier
## @return: CardData if found, null otherwise
func get_card(card_id: StringName) -> CardData:
	if not _initialized:
		_build_index()
	return _cards_by_id.get(card_id, null) as CardData

## Checks if a card with the given ID exists.
## @param card_id: The card's StringName identifier
## @return: true if card exists in registry
func has_card(card_id: StringName) -> bool:
	if not _initialized:
		_build_index()
	return _cards_by_id.has(card_id)
