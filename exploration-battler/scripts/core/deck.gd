class_name Deck
extends RefCounted

## Manages a collection of CardInstances: shuffle, draw, add/remove cards.

var cards: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []

func _init(card_data_list: Array[CardData] = []) -> void:
	for card_data in card_data_list:
		var instance: CardInstance = CardInstance.new(card_data)
		cards.append(instance)
	shuffle()

func shuffle() -> void:
	cards.shuffle()

func draw(count: int = 1) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in range(count):
		if cards.is_empty():
			# Deck empty - shuffle discard into deck
			if discard_pile.is_empty():
				break  # No more cards
			cards = discard_pile.duplicate()
			discard_pile.clear()
			shuffle()
		
		if not cards.is_empty():
			var card: CardInstance = cards.pop_front()
			drawn.append(card)
	return drawn

func add_card(card_instance: CardInstance) -> void:
	cards.append(card_instance)

func remove_card(card_instance: CardInstance) -> bool:
	var index: int = cards.find(card_instance)
	if index >= 0:
		cards.remove_at(index)
		return true
	return false

func discard(card_instance: CardInstance) -> void:
	discard_pile.append(card_instance)

func get_size() -> int:
	return cards.size()

func get_discard_size() -> int:
	return discard_pile.size()

func get_total_size() -> int:
	return cards.size() + discard_pile.size()

func clear() -> void:
	cards.clear()
	discard_pile.clear()
