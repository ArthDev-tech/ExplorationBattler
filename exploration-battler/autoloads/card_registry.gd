extends Node

## Global registry for CardData resources.
## Builds an index of CardData by `card_id` so decks can be authored using IDs (e.g. JSON).

var _cards_by_id: Dictionary = {} # {StringName: CardData}
var _initialized: bool = false

func _ready() -> void:
	_build_index()

func _build_index() -> void:
	if _initialized:
		return
	_initialized = true
	_cards_by_id.clear()
	
	var dirs: Array[String] = [
		"res://resources/cards/starter",
		"res://resources/cards/common",
		"res://resources/cards/uncommon",
		"res://resources/cards/rare",
		"res://resources/cards/legendary",
		"res://resources/cards/tokens",
		"res://resources/cards/avatars"
	]
	
	for dir_path in dirs:
		_index_cards_in_dir(dir_path)

func _index_cards_in_dir(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		push_warning("CardRegistry: could not open dir: " + dir_path)
		return
	
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(".tres"):
			continue
		
		var res_path: String = dir_path.path_join(file_name)
		var cd: CardData = load(res_path) as CardData
		if not cd:
			continue
		var cid: StringName = cd.card_id
		if cid == &"":
			push_warning("CardRegistry: card has empty card_id: " + res_path)
			continue
		if _cards_by_id.has(cid):
			var existing: CardData = _cards_by_id.get(cid, null) as CardData
			var existing_path: String = existing.resource_path if existing else ""
			push_warning("CardRegistry: duplicate card_id '" + String(cid) + "' at " + res_path + " (already indexed: " + existing_path + ")")
			continue
		
		_cards_by_id[cid] = cd
	
	dir.list_dir_end()

func get_card(card_id: StringName) -> CardData:
	if not _initialized:
		_build_index()
	return _cards_by_id.get(card_id, null) as CardData

func has_card(card_id: StringName) -> bool:
	if not _initialized:
		_build_index()
	return _cards_by_id.has(card_id)
