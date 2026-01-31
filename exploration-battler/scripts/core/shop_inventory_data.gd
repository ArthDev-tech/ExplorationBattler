class_name ShopInventoryData
extends Resource

## =============================================================================
## ShopInventoryData - Fixed list of cards a shop sells (Resource)
## =============================================================================
## Used by NPCs and the card shop UI. Prices come from each card's
## currency_cost (CardData). Assign to InteractableNPC.shop_inventory.
## =============================================================================

@export var cards: Array[CardData] = []
