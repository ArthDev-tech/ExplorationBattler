extends CanvasLayer

## =============================================================================
## ExplorationUI - Main Exploration UI Container
## =============================================================================
## Reusable UI container for exploration levels.
## Contains all UI elements needed for exploration gameplay.
##
## Child Components:
## - AbilityIndicators: Shows player abilities/cooldowns (dash, jumps)
## - InventoryMenu: Player inventory and equipment management
## - CardCollectionMenu: Deck building and card collection view
##
## Note: Processes even when game is paused (PROCESS_MODE_ALWAYS)
## to allow menu interactions during pause.
## =============================================================================
## Contains all UI elements needed for exploration gameplay:
## - AbilityIndicators: Shows player abilities/cooldowns
## - InventoryMenu: Player inventory and equipment
## - CardCollectionMenu: Deck management

@onready var _ability_indicators: Control = $AbilityIndicators
@onready var _inventory_menu: CanvasLayer = $InventoryMenu
@onready var _card_collection_menu: CanvasLayer = $CardCollectionMenu
@onready var _interact_prompt_label: Label = $InteractPrompt

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
	
	if _interact_prompt_label:
		EventBus.interact_prompt_shown.connect(_on_interact_prompt_shown)
		EventBus.interact_prompt_hidden.connect(_on_interact_prompt_hidden)

func _on_interact_prompt_shown(prompt_text: String) -> void:
	if _interact_prompt_label:
		_interact_prompt_label.text = prompt_text
		_interact_prompt_label.visible = true

func _on_interact_prompt_hidden() -> void:
	if _interact_prompt_label:
		_interact_prompt_label.visible = false

func _exit_tree() -> void:
	if _interact_prompt_label:
		if EventBus.interact_prompt_shown.is_connected(_on_interact_prompt_shown):
			EventBus.interact_prompt_shown.disconnect(_on_interact_prompt_shown)
		if EventBus.interact_prompt_hidden.is_connected(_on_interact_prompt_hidden):
			EventBus.interact_prompt_hidden.disconnect(_on_interact_prompt_hidden)
