extends CanvasLayer

## Reusable UI container for exploration levels.
## Contains all UI elements needed for exploration gameplay:
## - AbilityIndicators: Shows player abilities/cooldowns
## - InventoryMenu: Player inventory and equipment
## - CardCollectionMenu: Deck management

@onready var _ability_indicators: Control = $AbilityIndicators
@onready var _inventory_menu: CanvasLayer = $InventoryMenu
@onready var _card_collection_menu: CanvasLayer = $CardCollectionMenu

func _ready() -> void:
	# Ensure UI processes even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Verify all UI components are loaded
	if not _ability_indicators:
		push_warning("ExplorationUI: AbilityIndicators not found")
	if not _inventory_menu:
		push_warning("ExplorationUI: InventoryMenu not found")
	if not _card_collection_menu:
		push_warning("ExplorationUI: CardCollectionMenu not found")
