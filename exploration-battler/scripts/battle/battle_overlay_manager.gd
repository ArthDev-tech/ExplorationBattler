extends Node

## Manages battle overlay lifecycle, world pause/unpause, and enemy defeat handling.

var _current_battle_overlay: Node = null
var _current_enemy_data: EnemyData = null
var _triggering_enemy: Node3D = null
var _battle_scene: PackedScene = null
var _victory_scene: PackedScene = null
var _current_victory_screen: CanvasLayer = null
var _hide_timer: float = 0.0
var _waiting_to_hide: bool = false

var _global_card_pool: Array[CardData] = []
var _card_registry: Node = null

func _ready() -> void:
	_card_registry = get_node_or_null("/root/CardRegistry")
	# Ensure overlay manager processes even when world is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load battle scene
	_battle_scene = load("res://scenes/battle/battle_arena.tscn") as PackedScene
	if not _battle_scene:
		push_error("Failed to load battle arena scene")
	_victory_scene = load("res://scenes/battle/ui/victory_screen.tscn") as PackedScene
	if not _victory_scene:
		push_error("Failed to load victory screen scene")
	
	# Connect to battle end signal
	EventBus.battle_ended.connect(_on_battle_ended)

func show_battle_overlay(enemy_data: EnemyData, triggering_enemy: Node3D = null) -> void:
	if enemy_data:
		print("DEBUG [BattleOverlayManager]: enemy_data.display_name = ", enemy_data.display_name)
	if _current_battle_overlay:
		push_warning("Battle overlay already active, hiding previous one")
		hide_battle_overlay()
	
	if not _battle_scene:
		push_error("Battle scene not loaded, cannot show overlay")
		return
	
	# Store reference to triggering enemy
	_triggering_enemy = triggering_enemy
	_current_enemy_data = enemy_data
	
	# Instantiate battle scene
	_current_battle_overlay = _battle_scene.instantiate()
	if not _current_battle_overlay:
		push_error("Failed to instantiate battle overlay")
		return
	
	# Add to scene tree (as child of root, so it's on top)
	var root: Node = get_tree().root
	root.add_child(_current_battle_overlay)
	
	# Ensure battle processes even when world is paused
	_current_battle_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Pause the world (except nodes with PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	
	# Emit battle started signal (battle manager will handle initialization)
	EventBus.battle_started.emit(enemy_data)

func hide_battle_overlay() -> void:
	if _current_victory_screen:
		_current_victory_screen.queue_free()
		_current_victory_screen = null
	if _current_battle_overlay:
		_current_battle_overlay.queue_free()
		_current_battle_overlay = null
	
	# Unpause the world
	get_tree().paused = false
	
	# Recapture mouse for 3D exploration
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Clear enemy reference
	_triggering_enemy = null
	_current_enemy_data = null
	_waiting_to_hide = false
	_hide_timer = 0.0

func _on_battle_ended(result: int) -> void:
	# result: 0 = player win, 1 = player loss
	if result == 0 and _triggering_enemy:
		# Player won - mark enemy as defeated
		if _triggering_enemy.has_method("defeated_enemy"):
			_triggering_enemy.defeated_enemy()
		else:
			push_warning("Triggering enemy does not have defeated_enemy() method")

	if result == 0:
		_show_victory_rewards()
		return
	
	# Loss: Start timer to hide overlay after delay (for defeat display)
	_waiting_to_hide = true
	_hide_timer = 2.0

func _show_victory_rewards() -> void:
	if not _victory_scene:
		# Fallback: no UI, just close battle.
		hide_battle_overlay()
		return
	
	var enemy: EnemyData = _current_enemy_data
	var gold_amount: int = enemy.gold_reward if enemy else 0
	var card_options: Array[CardData] = _pick_reward_cards(enemy, 3)
	
	var screen: CanvasLayer = _victory_scene.instantiate() as CanvasLayer
	if not screen:
		hide_battle_overlay()
		return
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_current_victory_screen = screen
	
	var root: Node = get_tree().root
	root.add_child(screen)
	if screen.has_method("setup"):
		screen.call("setup", gold_amount, card_options)
	if screen.has_signal("rewards_claimed"):
		screen.connect("rewards_claimed", Callable(self, "_on_victory_rewards_claimed"))

func _on_victory_rewards_claimed(gold_amount: int, selected_card: CardData) -> void:
	if gold_amount > 0:
		GameManager.add_currency(gold_amount)
	if selected_card:
		GameManager.add_card_to_collection(selected_card, 1)
	hide_battle_overlay()

func _get_rarity_weight(card: CardData) -> int:
	## Returns default weight for a card based on its rarity.
	## COMMON=8, UNCOMMON=4, RARE=2, LEGENDARY=1
	if not card:
		return 1
	
	match card.rarity:
		CardData.Rarity.COMMON:
			return 8
		CardData.Rarity.UNCOMMON:
			return 4
		CardData.Rarity.RARE:
			return 2
		CardData.Rarity.LEGENDARY:
			return 1
		_:
			return 1

func _pick_reward_cards(enemy: EnemyData, count: int) -> Array[CardData]:
	var desired: int = maxi(0, count)
	if desired <= 0:
		return []
	
	var weighted_pool: Array[Dictionary] = [] # Array of {"card": CardData, "weight": int}
	
	# Priority 1: Load from JSON if available
	if enemy and not enemy.reward_card_json_path.is_empty():
		weighted_pool = _load_reward_cards_from_json(enemy)
	
	# Priority 2: Use card_pool if JSON didn't provide cards
	if weighted_pool.is_empty() and enemy:
		for r in enemy.card_pool:
			if r is CardData:
				var cd: CardData = r as CardData
				weighted_pool.append({"card": cd, "weight": _get_rarity_weight(cd)})
	
	# Priority 3: Fall back to global pool
	if weighted_pool.is_empty():
		var global_pool: Array[CardData] = _get_global_card_pool()
		for cd in global_pool:
			weighted_pool.append({"card": cd, "weight": _get_rarity_weight(cd)})
	
	if weighted_pool.is_empty():
		return []
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var picked: Array[CardData] = []
	var used_ids: Dictionary = {} # {StringName: true}
	var safety: int = 200
	
	while picked.size() < desired and safety > 0:
		safety -= 1
		
		# Calculate total weight of available cards (excluding already picked)
		var total_weight: int = 0
		var available_entries: Array[Dictionary] = []
		for entry in weighted_pool:
			var cd: CardData = entry.get("card") as CardData
			if not cd:
				continue
			var cid: StringName = cd.card_id
			if used_ids.has(cid):
				continue
			var weight: int = entry.get("weight", 1) as int
			if weight <= 0:
				weight = 1
			total_weight += weight
			available_entries.append(entry)
		
		if available_entries.is_empty():
			break
		
		# Weighted random selection using cumulative weight method
		var random_value: int = rng.randi_range(1, total_weight)
		var cumulative_weight: int = 0
		var selected_entry: Dictionary = {}
		
		for entry in available_entries:
			var weight: int = entry.get("weight", 1) as int
			if weight <= 0:
				weight = 1
			cumulative_weight += weight
			if random_value <= cumulative_weight:
				selected_entry = entry
				break
		
		if selected_entry.is_empty():
			# Fallback: pick first available
			selected_entry = available_entries[0]
		
		var selected_card: CardData = selected_entry.get("card") as CardData
		if not selected_card:
			continue
		
		var cid: StringName = selected_card.card_id
		if used_ids.has(cid):
			continue
		
		used_ids[cid] = true
		picked.append(selected_card)
	
	return picked

func _load_reward_cards_from_json(enemy: EnemyData) -> Array[Dictionary]:
	## Loads reward cards from JSON file.
	## Returns Array[Dictionary] where each dict is {"card": CardData, "weight": int}
	## Supports two JSON formats:
	## - Simple array: ["card_id1", "card_id2"] - uses card's built-in rarity
	## - Object array: [{"id": "card_id1", "weight": 5}, {"id": "card_id2"}] - explicit weight or card rarity
	var result: Array[Dictionary] = []
	if not enemy:
		return result
	if enemy.reward_card_json_path.is_empty():
		return result
	if not _card_registry or not _card_registry.has_method("get_card"):
		push_warning("BattleOverlayManager: CardRegistry autoload missing; cannot load reward cards json: " + enemy.reward_card_json_path)
		return result
	
	var file: FileAccess = FileAccess.open(enemy.reward_card_json_path, FileAccess.READ)
	if not file:
		push_warning("BattleOverlayManager: could not open reward cards json: " + enemy.reward_card_json_path)
		return result
	
	var text: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		push_warning("BattleOverlayManager: invalid reward cards json (expected Array): " + enemy.reward_card_json_path)
		return result
	
	var entries: Array = parsed as Array
	for entry_raw in entries:
		var card_id_str: String = ""
		var explicit_weight: int = -1 # -1 means use card rarity
		
		# Detect format: string (simple) vs object (weighted)
		if typeof(entry_raw) == TYPE_STRING:
			# Simple format: just a card ID string
			card_id_str = String(entry_raw)
		elif typeof(entry_raw) == TYPE_DICTIONARY:
			# Weighted format: object with "id" and optional "weight"
			var entry_dict: Dictionary = entry_raw as Dictionary
			if entry_dict.has("id"):
				card_id_str = String(entry_dict.get("id", ""))
			elif entry_dict.has("card_id"):
				# Support both "id" and "card_id" keys
				card_id_str = String(entry_dict.get("card_id", ""))
			else:
				push_warning("BattleOverlayManager: reward card entry missing 'id' or 'card_id' field: " + str(entry_raw))
				continue
			
			if entry_dict.has("weight"):
				var weight_val = entry_dict.get("weight")
				if typeof(weight_val) == TYPE_INT or typeof(weight_val) == TYPE_FLOAT:
					explicit_weight = int(weight_val)
		else:
			push_warning("BattleOverlayManager: invalid reward card entry type (expected String or Dictionary): " + str(entry_raw))
			continue
		
		if card_id_str.is_empty():
			continue
		
		var cid: StringName = StringName(card_id_str)
		var cd: CardData = _card_registry.call("get_card", cid) as CardData
		if not cd:
			push_warning("BattleOverlayManager: reward cards json references unknown card_id '" + card_id_str + "' (" + enemy.reward_card_json_path + ")")
			continue
		
		# Determine weight: use explicit weight if provided, otherwise use card rarity
		var final_weight: int
		if explicit_weight >= 0:
			final_weight = explicit_weight
		else:
			final_weight = _get_rarity_weight(cd)
		
		result.append({"card": cd, "weight": final_weight})
	
	return result

func _get_global_card_pool() -> Array[CardData]:
	if not _global_card_pool.is_empty():
		return _global_card_pool
	
	var dirs: Array[String] = [
		"res://resources/cards/common",
		"res://resources/cards/uncommon",
		"res://resources/cards/rare",
		"res://resources/cards/legendary"
	]
	
	for dir_path in dirs:
		var dir: DirAccess = DirAccess.open(dir_path)
		if not dir:
			continue
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
			if cd:
				_global_card_pool.append(cd)
		dir.list_dir_end()
	
	return _global_card_pool

func _process(delta: float) -> void:
	if _waiting_to_hide:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_waiting_to_hide = false
			hide_battle_overlay()

func _exit_tree() -> void:
	if EventBus.battle_ended.is_connected(_on_battle_ended):
		EventBus.battle_ended.disconnect(_on_battle_ended)
