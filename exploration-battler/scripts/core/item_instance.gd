class_name ItemInstance
extends RefCounted

## =============================================================================
## ItemInstance - Runtime Item State
## =============================================================================
## Represents a single item instance with mutable state.
## Created from ItemData when an item is picked up.
##
## Unlike ItemData (shared resource), ItemInstance tracks:
## - Quantity (for stackable items - not yet fully implemented)
## - Durability (for degradable items - reserved for future use)
##
## Each item in inventory is a unique ItemInstance, even if they share
## the same ItemData.
## =============================================================================

# -----------------------------------------------------------------------------
# STATE
# -----------------------------------------------------------------------------

## Reference to the base ItemData resource (read-only properties).
var data: ItemData

## Stack quantity for stackable items.
## HARDCODED: Currently all items have quantity 1 - stacking not implemented
var quantity: int = 1

## Current durability (for degradable equipment).
## HARDCODED: Default 100 - durability system not yet implemented
var durability: int = 100

## Maximum durability value.
## HARDCODED: Default 100 - reserved for future durability system
var max_durability: int = 100

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

## Creates a new ItemInstance from ItemData.
## @param item_data: The base item definition
## @param item_quantity: Initial stack quantity (default 1)
func _init(item_data: ItemData, item_quantity: int = 1) -> void:
	data = item_data
	quantity = item_quantity
	if data:
		# HARDCODED: Default durability - could be customized per ItemData
		max_durability = 100

# -----------------------------------------------------------------------------
# STAT ACCESSORS
# -----------------------------------------------------------------------------

## Returns total attack bonus from this item.
## Multiplied by quantity for stackable items (future feature).
func get_total_attack_bonus() -> int:
	if not data:
		return 0
	return data.attack_bonus

## Returns total defense bonus from this item.
func get_total_defense_bonus() -> int:
	if not data:
		return 0
	return data.defense_bonus

## Returns total health bonus from this item.
func get_total_health_bonus() -> int:
	if not data:
		return 0
	return data.health_bonus
