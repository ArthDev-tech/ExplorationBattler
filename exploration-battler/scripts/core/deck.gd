class_name Deck
extends RefCounted

## =============================================================================
## Deck - Card Collection Manager
## =============================================================================
## Manages a collection of CardInstances for battle: shuffling, drawing,
## discarding, and deck manipulation.
##
## Two piles:
## - cards: The draw pile (cards that can be drawn)
## - discard_pile: Cards that have been played/discarded
##
## When the draw pile is empty and a draw is attempted, the discard pile
## is shuffled back into the draw pile automatically.
##
## Created from an Array[CardData] at battle start. Each CardData becomes
## a unique CardInstance.
## =============================================================================

# -----------------------------------------------------------------------------
# STATE
# -----------------------------------------------------------------------------

## The draw pile - cards that can be drawn.
var cards: Array[CardInstance] = []

## The discard pile - cards that have been played or discarded.
var discard_pile: Array[CardInstance] = []

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

## Creates a new deck from an array of CardData.
## Each CardData is converted to a CardInstance. Deck is shuffled.
## @param card_data_list: Array of CardData to create instances from
func _init(card_data_list: Array[CardData] = []) -> void:
	for card_data in card_data_list:
		var instance: CardInstance = CardInstance.new(card_data)
		cards.append(instance)
	shuffle()

# -----------------------------------------------------------------------------
# CORE OPERATIONS
# -----------------------------------------------------------------------------

## Randomizes the order of cards in the draw pile.
func shuffle() -> void:
	cards.shuffle()

## Draws cards from the top of the deck.
## If draw pile is empty, discard pile is shuffled into draw pile first.
## @param count: Number of cards to draw (default 1)
## @return: Array of drawn CardInstances (may be fewer than count if deck empty)
func draw(count: int = 1) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in range(count):
		if cards.is_empty():
			# Deck empty - shuffle discard into deck
			if discard_pile.is_empty():
				break  # No more cards available at all
			cards = discard_pile.duplicate()
			discard_pile.clear()
			shuffle()
		
		if not cards.is_empty():
			# Draw from front (top of deck)
			var card: CardInstance = cards.pop_front()
			drawn.append(card)
	return drawn

## Adds a card to the bottom of the draw pile.
## Used for effects that put cards into the deck.
## @param card_instance: The CardInstance to add
func add_card(card_instance: CardInstance) -> void:
	cards.append(card_instance)

## Removes a specific card from the draw pile.
## Used for search effects that find specific cards.
## @param card_instance: The CardInstance to remove
## @return: True if found and removed, false otherwise
func remove_card(card_instance: CardInstance) -> bool:
	var index: int = cards.find(card_instance)
	if index >= 0:
		cards.remove_at(index)
		return true
	return false

## Moves a card to the discard pile.
## Called when cards are played or destroyed.
## @param card_instance: The CardInstance to discard
func discard(card_instance: CardInstance) -> void:
	discard_pile.append(card_instance)

# -----------------------------------------------------------------------------
# QUERIES
# -----------------------------------------------------------------------------

## Returns number of cards in draw pile.
func get_size() -> int:
	return cards.size()

## Returns number of cards in discard pile.
func get_discard_size() -> int:
	return discard_pile.size()

## Returns total cards in deck (draw + discard).
func get_total_size() -> int:
	return cards.size() + discard_pile.size()

# -----------------------------------------------------------------------------
# UTILITY
# -----------------------------------------------------------------------------

## Removes all cards from both draw and discard piles.
func clear() -> void:
	cards.clear()
	discard_pile.clear()
