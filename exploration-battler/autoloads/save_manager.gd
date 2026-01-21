extends Node

## Handles save and load functionality for game state.
## Currently a stub - will be fully implemented in Phase 5.

const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_"
const SAVE_FILE_EXTENSION: String = ".save"

func _ready() -> void:
	EventBus.save_requested.connect(_on_save_requested)
	EventBus.load_requested.connect(_on_load_requested)
	
	# Ensure save directory exists
	var dir: DirAccess = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

func _on_save_requested() -> void:
	save_game(0)  # Default to slot 0

func _on_load_requested(save_slot: int) -> void:
	load_game(save_slot)

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
	GameManager.player_max_life = save_data.get("player_max_life", 20)
	GameManager.player_currency = int(save_data.get("player_currency", 0))
	GameManager.current_zone = save_data.get("current_zone", &"")
	EventBus.currency_changed.emit(GameManager.player_currency)
	# Deck deserialization will be implemented when Deck class is complete

func _serialize_deck(deck: RefCounted) -> Dictionary:
	# Stub - will serialize deck card IDs
	return {}

func _deserialize_deck(data: Dictionary) -> RefCounted:
	# Stub - will reconstruct deck from card IDs
	return null

func _exit_tree() -> void:
	if EventBus.save_requested.is_connected(_on_save_requested):
		EventBus.save_requested.disconnect(_on_save_requested)
	if EventBus.load_requested.is_connected(_on_load_requested):
		EventBus.load_requested.disconnect(_on_load_requested)
