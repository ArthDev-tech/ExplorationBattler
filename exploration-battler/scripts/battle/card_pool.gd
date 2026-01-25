class_name CardPool
extends Node

## =============================================================================
## CardPool - Card Visual Object Pool
## =============================================================================
## Object pooling system for card visual nodes to improve performance.
## Pre-instantiates card visuals and recycles them instead of creating/destroying.
##
## Why Pooling:
## - Instantiating scenes is expensive
## - Cards are frequently created/destroyed (draw, play, discard)
## - Pooling reduces GC pressure and improves frame times
##
## Usage:
##   var card_visual = card_pool.get_card_visual()
##   card_visual.set_card(card_instance)
##   # ... use card ...
##   card_pool.return_card_visual(card_visual)
##
## HARDCODED: Pool size and card scene path defined below.
## =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

## The card visual scene to pool.
## HARDCODED: Path to card visual scene
var CARD_SCENE: PackedScene = null

## Pool of inactive card visuals ready for reuse.
var _pool: Array[Control] = []

## Currently active (in-use) card visuals.
var _active_cards: Array[Control] = []

## HARDCODED: Maximum pool size - increase for more simultaneous cards
var _pool_size: int = 20

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

func _ready() -> void:
	# HARDCODED: Card visual scene path
	CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene
	
	# Pre-instantiate pool for better performance at battle start
	if CARD_SCENE:
		for i in range(_pool_size):
			var card: Control = CARD_SCENE.instantiate()
			card.set_process(false)  # Disable processing while pooled
			card.visible = false
			_pool.append(card)

# -----------------------------------------------------------------------------
# PUBLIC API
# -----------------------------------------------------------------------------

## Gets a card visual from the pool (or creates new if pool empty).
## @return: Ready-to-use Control node for card display
func get_card_visual() -> Control:
	var card: Control = null
	
	# Lazy load scene if needed
	if not CARD_SCENE:
		CARD_SCENE = load("res://scenes/battle/card_ui/card_visual.tscn") as PackedScene
	
	if _pool.is_empty():
		# Pool exhausted - create new instance
		# This is slower but handles edge cases
		if CARD_SCENE:
			card = CARD_SCENE.instantiate()
	else:
		# Reuse pooled card (fast path)
		card = _pool.pop_back()
	
	# Activate the card
	card.set_process(true)
	card.visible = true
	_active_cards.append(card)
	return card

## Returns a card visual to the pool for reuse.
## @param card: The Control node to return
func return_card_visual(card: Control) -> void:
	if not card:
		return
	
	# Remove from active tracking
	var index: int = _active_cards.find(card)
	if index >= 0:
		_active_cards.remove_at(index)
	
	# Remove from scene tree
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	# Reset card state
	card.set_process(false)
	card.visible = false
	if card.has_method("set_card"):
		card.set_card(null)  # Clear card data reference
	
	# Return to pool or free if pool is full
	if _pool.size() < _pool_size:
		_pool.append(card)
	else:
		# Pool at capacity - free excess cards
		card.queue_free()

## Returns all active cards to the pool.
## Call when battle ends to reset pool state.
func clear_all() -> void:
	# Use duplicate() to avoid modifying array while iterating
	for card in _active_cards.duplicate():
		return_card_visual(card)
