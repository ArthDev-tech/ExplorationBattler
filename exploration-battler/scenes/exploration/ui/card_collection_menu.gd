extends CanvasLayer

## Card collection and deck management menu with Hearthstone-style layout.

var _collection_cards: Array[CardData] = []
var _filtered_collection_cards: Array[CardData] = []
var _active_mana_filters: Array[int] = []
var _search_text: String = ""
var _current_page: int = 1
var _cards_per_page: int = 16  # 4 columns x 4 rows
var _deck_name: String = "My Deck"

func _init() -> void:
	# Ensure this node processes even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

@onready var _background_overlay: ColorRect = $BackgroundOverlay
@onready var _menu_panel: Control = $MenuPanel
@onready var _collection_grid: GridContainer = $MenuPanel/MainContainer/LeftPanel/CollectionScroll/CollectionGrid
@onready var _deck_list: VBoxContainer = $MenuPanel/MainContainer/RightPanel/DeckScroll/DeckList
@onready var _deck_size_label: Label = $MenuPanel/MainContainer/RightPanel/DeckSizeBar/DeckSizeLabel
@onready var _close_button: Button = $MenuPanel/TopBar/CloseButton
@onready var _back_button: Button = $MenuPanel/TopBar/BackButton
@onready var _deck_name_edit: LineEdit = $MenuPanel/TopBar/DeckNameEdit
@onready var _page_label: Label = $MenuPanel/MainContainer/LeftPanel/PageIndicator/PageLabel
@onready var _prev_page_button: Button = $MenuPanel/MainContainer/LeftPanel/PageIndicator/PrevPageButton
@onready var _next_page_button: Button = $MenuPanel/MainContainer/LeftPanel/PageIndicator/NextPageButton
@onready var _done_button: Button = $MenuPanel/MainContainer/RightPanel/DoneButton
@onready var _search_line_edit: LineEdit = $MenuPanel/BottomBar/SearchContainer/SearchLineEdit
@onready var _filter_all_button: Button = $MenuPanel/BottomBar/ManaFilters/FilterAll

# Mana filter buttons
@onready var _filter_buttons: Array[Button] = [
	$MenuPanel/BottomBar/ManaFilters/Filter0,
	$MenuPanel/BottomBar/ManaFilters/Filter1,
	$MenuPanel/BottomBar/ManaFilters/Filter2,
	$MenuPanel/BottomBar/ManaFilters/Filter3,
	$MenuPanel/BottomBar/ManaFilters/Filter4,
	$MenuPanel/BottomBar/ManaFilters/Filter5,
	$MenuPanel/BottomBar/ManaFilters/Filter6,
	$MenuPanel/BottomBar/ManaFilters/Filter7Plus
]

var _dragging_card: Dictionary = {}  # Track current drag operation (reserved)

func _ready() -> void:
	_menu_panel.visible = false
	if _background_overlay:
		_background_overlay.visible = false
	_dragging_card.clear()
	
	_setup_collection()
	_setup_mana_filters()
	_setup_search()
	_setup_deck_name()
	_setup_pagination()
	
	if _close_button:
		_close_button.pressed.connect(_on_close_button_pressed)
		_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _back_button:
		_back_button.pressed.connect(_on_back_button_pressed)
		_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _done_button:
		_done_button.pressed.connect(_on_done_button_pressed)
	
	# Set up deck list as drop zone
	if _deck_list:
		_deck_list.mouse_filter = Control.MOUSE_FILTER_STOP

func open_menu() -> void:
	# Ensure game remains paused and mouse is visible
	if not get_tree().paused:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if _background_overlay:
		_background_overlay.visible = true
	_menu_panel.visible = true
	
	# Update deck name display
	if _deck_name_edit:
		_deck_name_edit.text = _deck_name
	
	# Set "All" filter as default
	if _filter_all_button:
		_filter_all_button.button_pressed = true
		_on_all_filter_toggled(true)
	
	_refresh_collection_display()
	_refresh_deck_display()

func _input(event: InputEvent) -> void:
	if not _menu_panel.visible:
		return
	
	# Consume inventory input events when menu is open
	if event.is_action_pressed("inventory"):
		# Block inventory toggle when card collection menu is open
		get_viewport().set_input_as_handled()
		return
	
	# Close with Escape when menu is open
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()

func close_menu() -> void:
	_menu_panel.visible = false
	# IMPORTANT: Always hide our overlay when closing this menu.
	# Inventory menu has its own overlay and will manage dimming.
	if _background_overlay:
		_background_overlay.visible = false
	
	# Return to inventory menu (keep game paused).
	var inventory_menu: Node = get_tree().current_scene.get_node_or_null("UI/InventoryMenu")
	if inventory_menu:
		var inv_panel: CanvasItem = inventory_menu.get_node_or_null("MenuPanel")
		if inv_panel:
			inv_panel.visible = true
		
		# Ensure inventory overlay is visible while inventory is open.
		var inv_overlay: CanvasItem = inventory_menu.get_node_or_null("BackgroundOverlay")
		if inv_overlay:
			inv_overlay.visible = true
	else:
		# Fallback: if inventory isn't present, ensure we don't leave the game stuck paused.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false

func _setup_collection() -> void:
	# Collection will be populated from GameManager.player_card_collection
	pass

func _setup_mana_filters() -> void:
	# Connect "All" button
	if _filter_all_button:
		_filter_all_button.toggled.connect(_on_all_filter_toggled)
	
	# Connect mana cost filter buttons
	for i in range(_filter_buttons.size()):
		var button: Button = _filter_buttons[i]
		if button:
			var mana_cost: int = i if i < 7 else 7  # 7+ for last button
			button.toggled.connect(func(pressed: bool): _on_mana_filter_toggled(mana_cost, pressed))

func _setup_search() -> void:
	if _search_line_edit:
		_search_line_edit.text_changed.connect(_on_search_text_changed)

func _setup_deck_name() -> void:
	if _deck_name_edit:
		_deck_name_edit.text = _deck_name
		_deck_name_edit.text_submitted.connect(_on_deck_name_submitted)
		_deck_name_edit.focus_exited.connect(_on_deck_name_focus_exited)

func _setup_pagination() -> void:
	if _prev_page_button:
		_prev_page_button.pressed.connect(_on_prev_page_pressed)
	if _next_page_button:
		_next_page_button.pressed.connect(_on_next_page_pressed)

func _on_mana_filter_toggled(mana_cost: int, pressed: bool) -> void:
	# When a specific filter is toggled on, deselect the "All" button
	if pressed and _filter_all_button:
		_filter_all_button.button_pressed = false
	
	if pressed:
		if not _active_mana_filters.has(mana_cost):
			_active_mana_filters.append(mana_cost)
	else:
		_active_mana_filters.erase(mana_cost)
	
	_apply_filters()
	_refresh_collection_display()

func _on_all_filter_toggled(pressed: bool) -> void:
	if pressed:
		# Clear all active mana filters
		_active_mana_filters.clear()
		
		# Deselect all other filter buttons
		for button in _filter_buttons:
			if button:
				button.button_pressed = false
		
		_apply_filters()
		_refresh_collection_display()
	else:
		pass

func _on_search_text_changed(new_text: String) -> void:
	_search_text = new_text.to_lower()
	_apply_filters()
	_refresh_collection_display()

func _apply_filters() -> void:
	_filtered_collection_cards.clear()
	
	if not GameManager or not GameManager.player_card_collection:
		return
	
	# Start with all cards
	_filtered_collection_cards = GameManager.player_card_collection.duplicate()
	
	# Apply mana cost filters
	if not _active_mana_filters.is_empty():
		var mana_filtered: Array[CardData] = []
		for card_data in _filtered_collection_cards:
			var card_cost: int = card_data.cost
			var cost_match: bool = false
			
			# Check if cost matches any active filter
			for filter_cost in _active_mana_filters:
				if filter_cost == 7:  # 7+ filter
					if card_cost >= 7:
						cost_match = true
						break
				else:
					if card_cost == filter_cost:
						cost_match = true
						break
			
			if cost_match:
				mana_filtered.append(card_data)
		
		_filtered_collection_cards = mana_filtered
	
	# Apply search filter
	if _search_text != "":
		var search_filtered: Array[CardData] = []
		for card_data in _filtered_collection_cards:
			var name_match: bool = card_data.display_name.to_lower().contains(_search_text)
			var desc_match: bool = card_data.description.to_lower().contains(_search_text)
			if name_match or desc_match:
				search_filtered.append(card_data)
		
		_filtered_collection_cards = search_filtered
	
	# Reset to first page when filters change
	_current_page = 1

func _get_collection_count(card_data: CardData) -> int:
	# Get the quantity of this card in the persistent collection.
	if not card_data:
		return 0
	if not GameManager:
		return 0
	
	# Prefer the persistent quantity map in GameManager (by card_id).
	var cid: StringName = card_data.card_id
	if GameManager.player_card_quantities.has(cid):
		return int(GameManager.player_card_quantities.get(cid, 0))
	
	return 0

func _get_deck_count(card_data: CardData) -> int:
	# Count how many CardInstances of this CardData exist in player_deck
	if not GameManager.player_deck:
		return 0
	
	var deck: Deck = GameManager.player_deck as Deck
	if not deck:
		return 0
	
	var count: int = 0
	var target_id: StringName = card_data.card_id if card_data else &""
	for card_instance in deck.cards:
		if card_instance and card_instance.data and card_instance.data.card_id == target_id:
			count += 1
	
	return count

func _get_available_count(card_data: CardData) -> int:
	return _get_collection_count(card_data) - _get_deck_count(card_data)

func _refresh_collection_display() -> void:
	# Check GridContainer
	if not _collection_grid:
		push_error("Collection grid is null")
		return
	
	# Clear existing cards
	for child in _collection_grid.get_children():
		child.queue_free()
	
	# Check if collection exists
	if not GameManager:
		push_warning("GameManager is null")
		return
	
	if not GameManager.player_card_collection:
		push_warning("Card collection is null in GameManager")
		return
	
	# Use filtered cards
	_collection_cards = _filtered_collection_cards.duplicate()
	
	if _collection_cards.is_empty():
		_update_page_indicator()
		return
	
	# Calculate pagination
	var total_pages: int = ceil(float(_collection_cards.size()) / float(_cards_per_page))
	if _current_page > total_pages:
		_current_page = max(1, total_pages)
	
	var start_index: int = (_current_page - 1) * _cards_per_page
	var end_index: int = min(start_index + _cards_per_page, _collection_cards.size())
	
	# Load card visual scene
	var card_scene: PackedScene = load("res://scenes/battle/card_ui/card_visual.tscn")
	if not card_scene:
		push_error("Failed to load card_visual.tscn scene")
		return
	
	# Set up collection grid as drop zone for removing cards from deck
	if _collection_grid:
		_collection_grid.mouse_filter = Control.MOUSE_FILTER_STOP
		# Add drop zone script to collection grid
		var drop_zone_script: GDScript = load("res://scenes/exploration/ui/components/collection_drop_zone.gd")
		if drop_zone_script and not _collection_grid.get_script():
			_collection_grid.set_script(drop_zone_script)
	
	# Display cards for current page
	var _displayed_count: int = 0
	for i in range(start_index, end_index):
		var card_data: CardData = _collection_cards[i]
		if not card_data:
			continue
		
		var card_instance: CardInstance = CardInstance.new(card_data)
		if not card_instance:
			continue
		
		var card_visual: Control = card_scene.instantiate()
		if not card_visual:
			continue
		
		# Get quantities
		var collection_count: int = _get_collection_count(card_data)
		var deck_count: int = _get_deck_count(card_data)
		var available_count: int = _get_available_count(card_data)
		
		# Create wrapper with quantity indicator and drag support
		var card_wrapper: Control = _create_card_with_quantity(card_visual, card_instance, collection_count, deck_count, available_count)
		
		# Add drag support for collection cards
		if available_count > 0:
			card_wrapper.set_meta("can_drag", true)
		
		# Set size flags for GridContainer
		card_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Add to scene tree
		_collection_grid.add_child(card_wrapper)
		_displayed_count += 1
	
	_update_page_indicator()

func _update_page_indicator() -> void:
	if not _page_label:
		return
	
	var total_cards: int = _filtered_collection_cards.size()
	var total_pages: int = ceil(float(total_cards) / float(_cards_per_page)) if total_cards > 0 else 1
	
	if total_pages > 1:
		_page_label.text = "Page " + str(_current_page) + " / " + str(total_pages)
	else:
		_page_label.text = "Page 1"
	
	# Update button states
	if _prev_page_button:
		_prev_page_button.disabled = (_current_page <= 1)
	if _next_page_button:
		_next_page_button.disabled = (_current_page >= total_pages)

func _on_prev_page_pressed() -> void:
	if _current_page > 1:
		_current_page -= 1
		_refresh_collection_display()

func _on_next_page_pressed() -> void:
	var total_cards: int = _filtered_collection_cards.size()
	var total_pages: int = ceil(float(total_cards) / float(_cards_per_page)) if total_cards > 0 else 1
	if _current_page < total_pages:
		_current_page += 1
		_refresh_collection_display()

func _create_card_with_quantity(card_visual: Control, card_instance: CardInstance, _collection_count: int, _deck_count: int, available_count: int) -> Control:
	# Create a wrapper Control that contains the card visual and quantity indicator
	# Load draggable wrapper script
	var wrapper_script: GDScript = load("res://scenes/exploration/ui/components/draggable_card_wrapper.gd")
	var wrapper: Control = Control.new()
	if wrapper_script:
		wrapper.set_script(wrapper_script)
	
	# Set wrapper size to match card visual
	wrapper.custom_minimum_size = card_visual.custom_minimum_size
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP  # Allow drag detection
	
	# Add card visual as child
	card_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let wrapper handle input
	wrapper.add_child(card_visual)
	
	# Ensure wrapper expands to fill available space
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Set card data
	if card_visual.has_method("set_card"):
		card_visual.call_deferred("set_card", card_instance)
	
	# Store card data in wrapper for drag operations
	if wrapper.get_script():
		wrapper.card_data = card_instance.data if card_instance else null
		wrapper.card_instance = card_instance
		wrapper.available_count = available_count
		wrapper.source_location = "collection"
	else:
		# Fallback if script not loaded - set metadata
		wrapper.set_meta("card_instance", card_instance)
		wrapper.set_meta("card_data", card_instance.data if card_instance else null)
		wrapper.set_meta("available_count", available_count)
		wrapper.set_meta("source_location", "collection")
	
	# Create quantity label - show copy count (x2, x3, etc.)
	var quantity_label: Label = Label.new()
	if available_count <= 0:
		quantity_label.text = "x0"
		# Grey out the card
		card_visual.modulate = Color(0.4, 0.4, 0.4, 1.0)
		quantity_label.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Red for unavailable
	else:
		# Show how many copies available
		quantity_label.text = "x" + str(available_count)
		quantity_label.modulate = Color(0.9, 0.8, 0.3, 1.0)  # Gold color
	
	quantity_label.add_theme_font_size_override("font_size", 14)
	quantity_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	quantity_label.add_theme_constant_override("outline_size", 2)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	# Position label at top center of card
	quantity_label.anchors_preset = Control.PRESET_TOP_WIDE
	quantity_label.offset_top = 5
	quantity_label.offset_bottom = 25
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_label.visible = true
	wrapper.add_child(quantity_label)
	
	# Move label to front to ensure it's visible above card visual
	wrapper.move_child(quantity_label, -1)
	
	# Add click-to-add button for collection cards (if available)
	if available_count > 0:
		var add_button: Button = Button.new()
		add_button.text = "+"
		add_button.custom_minimum_size = Vector2(30, 30)
		add_button.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		add_button.offset_left = -35
		add_button.offset_top = -35
		add_button.offset_right = -5
		add_button.offset_bottom = -5
		add_button.mouse_filter = Control.MOUSE_FILTER_STOP
		add_button.pressed.connect(_on_add_card_to_deck_button.bind(card_instance.data))
		wrapper.add_child(add_button)
	
	return wrapper

func _on_add_card_to_deck_button(card_data: CardData) -> void:
	_add_card_to_deck(card_data)

func _add_card_to_deck(card_data: CardData) -> bool:
	# Add card to deck if available
	if not GameManager.player_deck:
		return false
	
	var available: int = _get_available_count(card_data)
	if available <= 0:
		return false
	
	var deck: Deck = GameManager.player_deck as Deck
	var new_instance: CardInstance = CardInstance.new(card_data)
	deck.add_card(new_instance)
	
	# Refresh displays
	_refresh_collection_display()
	_refresh_deck_display()
	return true

func _remove_card_from_deck(card_data: CardData) -> bool:
	# Remove one instance of card from deck
	if not GameManager.player_deck:
		return false
	
	var deck: Deck = GameManager.player_deck as Deck
	# Find first matching card instance
	var target_id: StringName = card_data.card_id if card_data else &""
	for card_instance in deck.cards:
		if card_instance and card_instance.data and card_instance.data.card_id == target_id:
			deck.remove_card(card_instance)
			_refresh_collection_display()
			_refresh_deck_display()
			return true
	
	return false

func _refresh_deck_display() -> void:
	# Clear existing deck cards
	for child in _deck_list.get_children():
		child.queue_free()
	
	# Check if deck exists
	if not GameManager.player_deck:
		if _deck_size_label:
			_deck_size_label.text = "0/30 Cards"
		return
	
	var deck: Deck = GameManager.player_deck as Deck
	if not deck:
		if _deck_size_label:
			_deck_size_label.text = "0/30 Cards"
		return
	
	# Count cards by card_id (group duplicates robustly)
	var deck_card_counts: Dictionary = {}  # {StringName: count}
	var deck_card_data_by_id: Dictionary = {}  # {StringName: CardData}
	for card_instance in deck.cards:
		if card_instance and card_instance.data:
			var card_data: CardData = card_instance.data
			var cid: StringName = card_data.card_id
			if deck_card_counts.has(cid):
				deck_card_counts[cid] += 1
			else:
				deck_card_counts[cid] = 1
				deck_card_data_by_id[cid] = card_data
	
	# Load compact card visual scene
	var compact_card_scene: PackedScene = load("res://scenes/exploration/ui/components/compact_card_visual.tscn")
	if not compact_card_scene:
		push_error("Failed to load compact_card_visual.tscn for deck display")
		return
	
	# Sort cards by mana cost
	var sorted_cards: Array[CardData] = []
	for cid in deck_card_counts:
		var cd: CardData = deck_card_data_by_id.get(cid, null)
		if cd:
			sorted_cards.append(cd)
	
	# Sort by mana cost, then by name
	sorted_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.display_name < b.display_name
	)
	
	# Display each unique card in deck with count
	var _displayed_count: int = 0
	for card_data in sorted_cards:
		var count: int = int(deck_card_counts.get(card_data.card_id, 1))
		var card_instance: CardInstance = CardInstance.new(card_data)
		var compact_card: Control = compact_card_scene.instantiate()
		
		# Set size flags before adding to tree
		compact_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Add to scene tree first so _ready() is called and @onready vars are initialized
		_deck_list.add_child(compact_card)
		
		# Now call set_card after node is ready
		if compact_card.has_method("set_card"):
			compact_card.set_card(card_instance, count)
		
		# Connect remove signal
		if compact_card.has_signal("card_removed"):
			compact_card.card_removed.connect(_on_compact_card_removed)
		
		_displayed_count += 1
	
	# Update deck size label
	if _deck_size_label:
		_deck_size_label.text = str(deck.cards.size()) + "/30 Cards"
	
	# Set up deck list as drop zone for collection cards
	if _deck_list:
		_deck_list.mouse_filter = Control.MOUSE_FILTER_STOP
		# Add drop zone script to deck list
		var drop_zone_script: GDScript = load("res://scenes/exploration/ui/components/deck_drop_zone.gd")
		if drop_zone_script and not _deck_list.get_script():
			_deck_list.set_script(drop_zone_script)

func _on_compact_card_removed(card_instance: CardInstance) -> void:
	if card_instance and card_instance.data:
		_remove_card_from_deck(card_instance.data)

func _handle_card_drop(card_data: CardData, source_location: String, target_location: String) -> void:
	# Handle card drop from drag-and-drop
	if source_location == "collection" and target_location == "deck":
		# Adding card from collection to deck
		_add_card_to_deck(card_data)
	elif source_location == "deck" and target_location == "collection":
		# Removing card from deck (dropping back to collection)
		_remove_card_from_deck(card_data)

func _on_deck_name_submitted(new_text: String) -> void:
	_deck_name = new_text
	_save_deck_name()

func _on_deck_name_focus_exited() -> void:
	if _deck_name_edit:
		_deck_name = _deck_name_edit.text
		_save_deck_name()

func _save_deck_name() -> void:
	# Save deck name - for now just store locally
	# In the future, this could be saved to a save file or GameManager property
	# For now, we'll just keep it in memory during the session
	pass  # Deck name is stored in _deck_name variable

func _on_done_button_pressed() -> void:
	# Save deck name
	_save_deck_name()
	# Close menu
	_on_back_button_pressed()

func _on_close_button_pressed() -> void:
	# Close card collection menu
	_menu_panel.visible = false
	if _background_overlay:
		_background_overlay.visible = false
	
	# Also close inventory and unpause
	var inventory_menu: CanvasLayer = get_tree().current_scene.get_node_or_null("UI/InventoryMenu")
	if inventory_menu and inventory_menu.has_method("close_inventory"):
		inventory_menu.close_inventory()

func _on_back_button_pressed() -> void:
	close_menu()

func _exit_tree() -> void:
	# Safety: never leave the screen dimmed if this node exits unexpectedly.
	if _background_overlay:
		_background_overlay.visible = false
