class_name ItemData
extends Resource

## =============================================================================
## ItemData - Static Item Definition (Resource)
## =============================================================================
## Defines an item type: stats, equipment slot, inventory size, etc.
## This is a Resource saved to .tres files - one per item type.
##
## Item Types:
## - WEAPON: Equipped in weapon slot, provides attack bonus
## - ARMOR: Equipped in armor slot, provides defense/health
## - ACCESSORY: Equipped in accessory slot, various bonuses
##
## Inventory Size:
## Items occupy grid cells based on their size. A 2x3 item needs 6 cells.
## =============================================================================

# -----------------------------------------------------------------------------
# ENUMS
# -----------------------------------------------------------------------------

## Equipment slot this item occupies when equipped.
enum ItemType {
	WEAPON,    # Attack-focused equipment
	ARMOR,     # Defense/health equipment
	ACCESSORY  # Utility equipment (rings, amulets, etc.)
}

# -----------------------------------------------------------------------------
# CORE PROPERTIES
# -----------------------------------------------------------------------------

## Display name shown in UI.
@export var item_name: String = ""

## Description/flavor text.
@export var description: String = ""

## Item icon texture for inventory display.
@export var icon: Texture2D = null

## Equipment slot type.
@export var item_type: ItemType = ItemType.WEAPON

## Inventory grid size (width x height in cells).
## HARDCODED: Default 1x1 - larger items take more inventory space
@export var size: Vector2i = Vector2i(1, 1)

# -----------------------------------------------------------------------------
# STAT BONUSES
# -----------------------------------------------------------------------------

## Attack power bonus when equipped.
## HARDCODED: Default 0 - set per item
@export var attack_bonus: int = 0

## Defense bonus when equipped.
## HARDCODED: Default 0 - not yet used in combat
@export var defense_bonus: int = 0

## Maximum health bonus when equipped.
## HARDCODED: Default 0 - affects player_max_life
@export var health_bonus: int = 0
