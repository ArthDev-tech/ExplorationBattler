extends Control

## Central drop zone that routes cards to appropriate destinations with animations.
## Creatures -> nearest empty player lane (with animation)
## Spells -> animate to backrow area, flash, execute, discard
## Traps/Relics -> animate to backrow slot, stay there

const ANIMATION_DURATION: float = 0.25
const CARD_SCENE_PATH: String = "res://scenes/battle/card_ui/card_visual.tscn"

var _battle_manager: Node = null
var _player_lanes: Array[Node] = []
var _card_scene: PackedScene = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	# Get battle manager and lane references after scene is ready
	call_deferred("_setup_references")
	# Preload card scene
	_card_scene = load(CARD_SCENE_PATH) as PackedScene

func _setup_references() -> void:
	_battle_manager = _get_battle_manager()
	if _battle_manager:
		# Get lane references from battle manager
		var lanes = _battle_manager.get("_player_lanes")
		if lanes:
			_player_lanes.clear()
			for lane in lanes:
				_player_lanes.append(lane)

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

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	# Check if data is a CardInstance
	if data == null or not data is CardInstance:
		return false
	
	var card: CardInstance = data as CardInstance
	if not card or not card.data:
		return false
	
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
	if not battle_state.can_afford_player_cost(card.data):
		return false
	
	# For creatures, check if there's an empty lane
	if card.data.is_creature():
		var has_empty_lane: bool = false
		for i in range(battle_state.player_lanes.size()):
			if battle_state.player_lanes[i] == null:
				has_empty_lane = true
				break
		if not has_empty_lane:
			return false
	else:
		# For traps/relics, check if backrow has space
		# Spells don't need backrow space since they execute and discard
		var card_type: int = card.data.card_type
		if card_type == CardData.CardType.TRAP or card_type == CardData.CardType.RELIC:
			if battle_state.player_backrow.size() >= 3:
				return false
	
	return true

func _drop_data(drop_position: Vector2, data: Variant) -> void:
	if data == null or not data is CardInstance:
		return
	
	var card: CardInstance = data as CardInstance
	if not card or not card.data:
		return
	
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		return
	
	# Calculate global position from local drop position
	var global_drop_pos: Vector2 = global_position + drop_position
	
	if card.data.is_creature():
		# Find nearest empty lane based on drop position
		var lane_index: int = _find_nearest_empty_lane(drop_position)
		if lane_index >= 0:
			_animate_card_to_lane(card, global_drop_pos, lane_index)
	else:
		# Non-creature: use battle manager's animated backrow method
		if battle_manager.has_method("play_card_animated_to_backrow"):
			battle_manager.play_card_animated_to_backrow(card, global_drop_pos, true)
		else:
			_animate_card_to_backrow(card, global_drop_pos)

func _animate_card_to_lane(card: CardInstance, from_pos: Vector2, lane_index: int) -> void:
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		return
	
	# Get target position (lane center)
	var lanes = battle_manager.get("_player_lanes")
	if not lanes or lane_index >= lanes.size():
		# Fallback: just play the card
		battle_manager.play_card(card, lane_index, true)
		return
	
	var lane_node: Control = lanes[lane_index] as Control
	if not lane_node:
		battle_manager.play_card(card, lane_index, true)
		return
	
	var target_pos: Vector2 = lane_node.global_position + lane_node.size / 2
	
	# Create temporary card visual
	var temp_visual: Control = _create_temp_card_visual(card, from_pos)
	if not temp_visual:
		battle_manager.play_card(card, lane_index, true)
		return
	
	# Animate to lane
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Move and scale
	var target_visual_pos: Vector2 = target_pos - temp_visual.size / 2
	tween.tween_property(temp_visual, "global_position", target_visual_pos, ANIMATION_DURATION)
	
	# On complete: play the card and remove temp visual
	tween.tween_callback(func():
		if is_instance_valid(temp_visual):
			temp_visual.queue_free()
		if is_instance_valid(battle_manager) and battle_manager.has_method("play_card"):
			battle_manager.play_card(card, lane_index, true)
	)

func _animate_card_to_backrow(card: CardInstance, from_pos: Vector2) -> void:
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		return
	
	# Get backrow zone for target position
	var backrow_zone: Control = battle_manager.get("_player_backrow_zone") as Control
	var target_pos: Vector2 = from_pos  # Default fallback
	
	if backrow_zone:
		target_pos = backrow_zone.global_position + backrow_zone.size / 2
	
	# Create temporary card visual
	var temp_visual: Control = _create_temp_card_visual(card, from_pos)
	if not temp_visual:
		# Fallback: just execute the action
		_execute_non_creature_action(card, battle_manager)
		return
	
	# Animate to backrow area
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Move and scale down slightly
	var target_visual_pos: Vector2 = target_pos - temp_visual.size * 0.35
	tween.tween_property(temp_visual, "global_position", target_visual_pos, ANIMATION_DURATION)
	tween.parallel().tween_property(temp_visual, "scale", Vector2(0.7, 0.7), ANIMATION_DURATION)
	
	# On complete: handle based on card type
	tween.tween_callback(func():
		if is_instance_valid(temp_visual) and is_instance_valid(battle_manager):
			_on_backrow_animation_complete(card, temp_visual, battle_manager)
		elif is_instance_valid(temp_visual):
			temp_visual.queue_free()
	)

func _on_backrow_animation_complete(card: CardInstance, temp_visual: Control, battle_manager: Node) -> void:
	if not card or not card.data:
		if is_instance_valid(temp_visual):
			temp_visual.queue_free()
		return
	
	var card_type: int = card.data.card_type
	
	if card_type == CardData.CardType.SPELL:
		# Spell: flash screen, execute effect, remove visual
		if is_instance_valid(battle_manager) and battle_manager.has_method("play_spell_animated"):
			battle_manager.play_spell_animated(card, true)
		
		# Fade out and remove the visual
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(temp_visual, "modulate:a", 0.0, 0.2)
		fade_tween.tween_callback(func():
			if is_instance_valid(temp_visual):
				temp_visual.queue_free()
		)
	else:
		# Trap or Relic: place in backrow, remove temp visual
		if is_instance_valid(temp_visual):
			temp_visual.queue_free()
		if is_instance_valid(battle_manager) and battle_manager.has_method("play_card"):
			battle_manager.play_card(card, -1, true)

func _execute_non_creature_action(card: CardInstance, battle_manager: Node) -> void:
	## Fallback execution when animation can't be created
	var card_type: int = card.data.card_type
	
	if card_type == CardData.CardType.SPELL:
		if battle_manager.has_method("play_spell_animated"):
			battle_manager.play_spell_animated(card, true)
	else:
		if battle_manager.has_method("play_card"):
			battle_manager.play_card(card, -1, true)

func _create_temp_card_visual(card: CardInstance, start_pos: Vector2) -> Control:
	## Create a temporary card visual for animation purposes
	if not _card_scene:
		_card_scene = load(CARD_SCENE_PATH) as PackedScene
	
	if not _card_scene:
		return null
	
	var card_visual: Control = _card_scene.instantiate() as Control
	if not card_visual:
		return null
	
	# Add to UI layer so it's visible above everything
	var ui_layer: CanvasLayer = get_parent() as CanvasLayer
	if ui_layer:
		ui_layer.add_child(card_visual)
	else:
		add_child(card_visual)
	
	# Position at start
	card_visual.global_position = start_pos - card_visual.custom_minimum_size / 2
	card_visual.z_index = 50  # Above other UI elements
	
	# Set the card data
	if card_visual.has_method("set_card"):
		card_visual.set_card(card)
	
	# Disable mouse interaction on the temp visual
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	return card_visual

func _find_nearest_empty_lane(drop_position: Vector2) -> int:
	var battle_manager = _get_battle_manager()
	if not battle_manager:
		return -1
	
	var battle_state = battle_manager.get("battle_state")
	if not battle_state:
		return -1
	
	# Get lane visual nodes
	var lanes = battle_manager.get("_player_lanes")
	if not lanes or lanes.is_empty():
		return -1
	
	var nearest_lane: int = -1
	var nearest_distance: float = INF
	
	for i in range(mini(lanes.size(), battle_state.player_lanes.size())):
		# Skip occupied lanes
		if battle_state.player_lanes[i] != null:
			continue
		
		var lane_node: Control = lanes[i] as Control
		if not lane_node:
			continue
		
		# Calculate distance from drop position to lane center
		var lane_center: Vector2 = lane_node.global_position + lane_node.size / 2
		var distance: float = drop_position.distance_to(lane_center)
		
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_lane = i
	
	# If no empty lane found by distance, find first empty lane
	if nearest_lane < 0:
		for i in range(battle_state.player_lanes.size()):
			if battle_state.player_lanes[i] == null:
				nearest_lane = i
				break
	
	return nearest_lane
