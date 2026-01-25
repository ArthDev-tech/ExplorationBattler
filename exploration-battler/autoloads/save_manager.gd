extends Node

## =============================================================================
## SaveManager - Save/Load System (Autoload Singleton)
## =============================================================================
## Handles save and load functionality for persistent game state.
## Currently a partial implementation - will be fully completed in Phase 5.
##
## Save data includes:
## - Player deck composition
## - Player max life and current currency
## - Current zone/progress
##
## HARDCODED: Save directory and file naming scheme defined below.
##
## Access via: SaveManager (autoload name in Project Settings)
## =============================================================================

# -----------------------------------------------------------------------------
# CONSTANTS
# -----------------------------------------------------------------------------

## HARDCODED: Save directory location in user:// (change for different save locations)
const SAVE_DIR: String = "user://saves/"

## HARDCODED: Save file naming prefix
const SAVE_FILE_PREFIX: String = "save_"

## HARDCODED: Save file extension
const SAVE_FILE_EXTENSION: String = ".save"

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

func _ready() -> void:
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.load_requested.connect(_on_load_requested)
	
	# Ensure save directory exists
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

# -----------------------------------------------------------------------------
# SIGNAL HANDLERS
# -----------------------------------------------------------------------------

func _on_save_requested() -> void:
	# HARDCODED: Default save slot - change to support multiple slots
	save_game(0)

func _on_load_requested(save_slot: int) -> void:
	load_game(save_slot)

# -----------------------------------------------------------------------------
# SAVE FUNCTIONS
# -----------------------------------------------------------------------------

## Saves the current game state to the specified slot.
## @param slot: Save slot index (0-based)
func save_game(slot: int) -> void:
	var save_data: Dictionary = {
		"player_deck": _serialize_deck(GameManager.player_deck),
		"player_max_life": GameManager.player_max_life,
		"player_currency": GameManager.player_currency,
		"current_zone": GameManager.current_zone,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var file_path: String = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXTENSION
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
	else:
		push_error("Failed to save game to slot " + str(slot))

# -----------------------------------------------------------------------------
# LOAD FUNCTIONS
# -----------------------------------------------------------------------------

## Loads game state from the specified save slot.
## @param slot: Save slot index (0-based)
func load_game(slot: int) -> void:
	var file_path: String = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXTENSION
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		push_error("Save file not found for slot " + str(slot))
		return
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse save file: " + json.get_error_message())
		return
	
	var save_data: Dictionary = json.data
	
	# HARDCODED: Default max_life fallback value
	GameManager.player_max_life = save_data.get("player_max_life", 20)
	GameManager.player_currency = int(save_data.get("player_currency", 0))
	GameManager.current_zone = save_data.get("current_zone", &"")
	EventBus.currency_changed.emit(GameManager.player_currency)
	
	# TODO: Deck deserialization will be implemented when Deck class is complete

# -----------------------------------------------------------------------------
# SERIALIZATION HELPERS
# -----------------------------------------------------------------------------

## Serializes a deck to a dictionary for JSON storage.
## @param deck: Deck instance to serialize
## @return: Dictionary with card IDs and counts
## TODO: Implement full serialization
func _serialize_deck(deck: RefCounted) -> Dictionary:
	# Stub - will serialize deck card IDs
	return {}

## Deserializes a deck from saved dictionary data.
## @param data: Dictionary with card IDs and counts
## @return: Reconstructed Deck instance
## TODO: Implement full deserialization
func _deserialize_deck(data: Dictionary) -> RefCounted:
	# Stub - will reconstruct deck from card IDs
	return null

# -----------------------------------------------------------------------------
# CLEANUP
# -----------------------------------------------------------------------------

func _exit_tree() -> void:
	if EventBus.save_requested.is_connected(_on_save_requested):
		EventBus.save_requested.disconnect(_on_save_requested)
	if EventBus.load_requested.is_connected(_on_load_requested):
		EventBus.load_requested.disconnect(_on_load_requested)
