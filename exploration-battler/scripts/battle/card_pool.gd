class_name CardPool
extends Node

## Object pooling system for card visuals to improve performance.

var CARD_SCENE: PackedScene = null

var _pool: Array[Control] = []
var _active_cards: Array[Control] = []
var _pool_size: int = 20

func _ready() -> void:
	CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene
	# Pre-instantiate pool
	if CARD_SCENE:
		for i in range(_pool_size):
			var card: Control = CARD_SCENE.instantiate()
			card.set_process(false)
			card.visible = false
			_pool.append(card)

func get_card_visual() -> Control:
	var card: Control = null
	
	if not CARD_SCENE:
		CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene
	
	if _pool.is_empty():
		# Pool exhausted, create new one
		if CARD_SCENE:
			card = CARD_SCENE.instantiate()
	else:
		card = _pool.pop_back()
	
	card.set_process(true)
	card.visible = true
	_active_cards.append(card)
	return card

func return_card_visual(card: Control) -> void:
	if not card:
		return
	
	var index: int = _active_cards.find(card)
	if index >= 0:
		_active_cards.remove_at(index)
	
	# Remove from parent
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	# Reset state
	card.set_process(false)
	card.visible = false
	if card.has_method("set_card"):
		card.set_card(null)
	
	# Return to pool
	if _pool.size() < _pool_size:
		_pool.append(card)
	else:
		# Pool full, just queue free
		card.queue_free()

func clear_all() -> void:
	# Return all active cards to pool
	for card in _active_cards.duplicate():
		return_card_visual(card)
