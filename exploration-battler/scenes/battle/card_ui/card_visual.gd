extends Control

## UI representation of a card. Displays card data and handles interactions.

signal card_clicked(card: CardInstance)

var card_instance: CardInstance = null
var _is_selected: bool = false
var _is_playable: bool = false
var _drag_started: bool = false
var _click_timer: float = 0.0
var _mouse_press_pos: Vector2 = Vector2.ZERO

@onready var _background: Panel = $Background
@onready var _cost_label: Label = $VBox/Header/CostLabel
@onready var _type_label: Label = $VBox/Header/TypeLabel
@onready var _artwork: ColorRect = $VBox/ArtworkPlaceholder
@onready var _name_label: Label = $VBox/NameLabel
@onready var _tribe_label: Label = $VBox/TribeLabel
@onready var _description_label: Label = $VBox/DescriptionLabel
@onready var _stats_label: Label = $VBox/Footer/StatsLabel
@onready var _swirl_overlay: ColorRect = $SwirlOverlay

var _rarity_colors: Dictionary = {
	CardData.Rarity.COMMON: Color(0.7, 0.7, 0.7, 1),
	CardData.Rarity.UNCOMMON: Color(0.2, 0.8, 0.2, 1),
	CardData.Rarity.RARE: Color(0.2, 0.4, 0.8, 1),
	CardData.Rarity.LEGENDARY: Color(0.8, 0.6, 0.2, 1)
}

var _type_icons: Dictionary = {
	CardData.CardType.CREATURE: "⚔️",
	CardData.CardType.SPELL: "✨",
	CardData.CardType.TRAP: "🪤",
	CardData.CardType.RELIC: "🔮",
	CardData.CardType.TOKEN: "👤"
}

var _tribe_names: Array[String] = ["None", "Phantom", "Beast", "Construct", "Cultist", "Nature"]

var _battle_manager: Node = null

func _ready() -> void:
	mouse_filter = 2  # MOUSE_FILTER_STOP - Ensure cards receive mouse input
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# REMOVED: gui_input connection - it was preventing drag-and-drop from working
	# Use _unhandled_input for click-to-select instead
	# Cache battle manager reference - try multiple paths
	_battle_manager = _get_battle_manager()
	# Listen for card selection
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_deselected.connect(_on_card_deselected)
	# Listen for card stats changes (e.g., summoning sickness cleared)
	EventBus.card_stats_changed.connect(_on_card_stats_changed)

func _get_battle_manager() -> Node:
	# Try multiple paths to find battle manager
	var paths = [
		"/root/BattleArena",
		"../../BattleArena",
		"../../../BattleArena"
	]
	for path in paths:
		var manager = get_node_or_null(path)
		if manager and manager.has_method("play_card"):
			return manager
	return null

func set_card(instance: CardInstance) -> void:
	card_instance = instance
	if not card_instance:
		return
	
	var data: CardData = card_instance.data
	if not data:
		return
	
	# Cost
	_cost_label.text = str(data.cost)
	
	# Type icon
	_type_label.text = _type_icons.get(data.card_type, "?")
	
	# Name
	_name_label.text = data.display_name
	
	# Tribe
	if data.is_creature() and data.tribe != CardData.Tribe.NONE:
		_tribe_label.text = _tribe_names[data.tribe]
	else:
		_tribe_label.text = ""
	
	# Description
	_description_label.text = data.description
	
	# Stats (for creatures)
	if data.is_creature():
		_stats_label.text = str(card_instance.current_attack) + "/" + str(card_instance.current_health)
		_stats_label.visible = true
	else:
		_stats_label.visible = false
	
	# Rarity border color
	if _background:
		var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if style:
			style.border_color = _rarity_colors.get(data.rarity, Color(0.2, 0.2, 0.2, 1))
	
	# Artwork placeholder color (based on tribe)
	if data.is_creature():
		var tribe_colors: Array[Color] = [
			Color(0.5, 0.5, 0.5, 1),  # None
			Color(0.6, 0.5, 0.8, 1),  # Phantom
			Color(0.5, 0.7, 0.4, 1),  # Beast
			Color(0.6, 0.6, 0.5, 1),  # Construct
			Color(0.7, 0.4, 0.4, 1),  # Cultist
			Color(0.4, 0.7, 0.5, 1)   # Nature
		]
		_artwork.color = tribe_colors[data.tribe] if data.tribe < tribe_colors.size() else Color(0.5, 0.5, 0.5, 1)
	
	# Update visual state
	update_visual_state()
	# Update summoning sickness overlay
	_update_summoning_sickness_visual()

func update_visual_state() -> void:
	if not card_instance:
		return
	
	# Update stats if changed
	if card_instance.data.is_creature():
		_stats_label.text = str(card_instance.current_attack) + "/" + str(card_instance.current_health)
	
	# Update playable state
	var current_energy: int = _get_current_energy()
	_is_playable = card_instance.data.cost <= current_energy
	
	# Apply visual state
	_apply_visual_state()
	# Update summoning sickness overlay
	_update_summoning_sickness_visual()

func _get_current_energy() -> int:
	# Query battle state via BattleManager
	if not _battle_manager:
		_battle_manager = _get_battle_manager()
	if _battle_manager:
		# Access battle_state property directly (it's a public var in BattleManager)
		# Use get() to safely access property, returns null if doesn't exist
		var battle_state = _battle_manager.get("battle_state")
		if battle_state:
			# BattleState is a RefCounted, access player_energy directly
			return battle_state.player_energy
	return 0

func _apply_visual_state() -> void:
	if not card_instance:
		return
	
	# Base modulation based on playable state
	if _is_playable:
		modulate = Color.WHITE
	else:
		modulate = Color(0.6, 0.6, 0.6, 1.0)  # Grayed out but still visible
	
	# Selected state overlay
	if _is_selected:
		modulate = modulate * Color(1.2, 1.2, 1.0, 1.0)  # Yellow tint when selected
		if _background:
			var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
			if style:
				style.border_color = Color(1.0, 0.8, 0.0, 1.0)  # Gold border when selected
	else:
		if _background:
			var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
			if style and card_instance:
				style.border_color = _rarity_colors.get(card_instance.data.rarity, Color(0.2, 0.2, 0.2, 1))

func _on_mouse_entered() -> void:
	if card_instance:
		scale = Vector2(1.15, 1.15)
		z_index = 20
		# Add glow effect
		if _background:
			var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
			if style:
				style.shadow_size = 8
				style.shadow_color = Color(0.5, 0.5, 1.0, 0.5)

func _on_mouse_exited() -> void:
	scale = Vector2(1.0, 1.0)
	z_index = 0
	# Remove glow effect
	if _background:
		var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if style:
			style.shadow_size = 4
			style.shadow_color = Color(0, 0, 0, 0.3)
	_apply_visual_state()

func _unhandled_input(event: InputEvent) -> void:
	# Handle click-to-play for spells/relics, click-to-select for creatures
	# Use _unhandled_input so we don't interfere with drag-and-drop
	# Only handle if mouse is over this card
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if card_instance and not _drag_started:
			# Check if mouse is over this card
			var mouse_pos = get_global_mouse_position()
			var card_rect = Rect2(global_position, size)
			if card_rect.has_point(mouse_pos):
				# Check if this is a non-creature card (spell/relic)
				if not card_instance.data.is_creature():
					# Click-to-play for spells/relics
					update_visual_state()
					if _is_playable and _battle_manager:
						# Check if spell needs targeting
						if _battle_manager.has_method("spell_needs_target") and _battle_manager.spell_needs_target(card_instance):
							# Enter targeting mode
							print("[CardVisual] Spell needs target, entering targeting mode: ", card_instance.data.display_name)
							if _battle_manager.has_method("enter_targeting_mode"):
								_battle_manager.enter_targeting_mode(card_instance)
						else:
							# No target needed, play immediately
							print("[CardVisual] Playing spell/relic: ", card_instance.data.display_name)
							if _battle_manager.has_method("play_card"):
								_battle_manager.play_card(card_instance, -1, true)
					else:
						var current_energy: int = _get_current_energy()
						print("[CardVisual] ❌ Cannot play spell (not enough energy: ", current_energy, " < ", card_instance.data.cost, ")")
				else:
					# This was a click on a creature - emit click signal for selection
					card_clicked.emit(card_instance)
		# Reset drag flag
		_drag_started = false

func _get_drag_data(_position: Vector2) -> Variant:
	# Allow drag for both creatures and spells if playable
	if not card_instance:
		return null
	
	# Mark that drag has started (prevents click from firing)
	_drag_started = true
	
	# Check if card is playable (enough energy)
	update_visual_state()
	if not _is_playable:
		_drag_started = false
		return null
	
	# Allow dragging both creatures and spells
	# Creatures go to lanes, spells can target creatures or be cast on field
	
	# Create drag preview - duplicate this card visual
	var preview: Control = duplicate()
	# Remove from parent immediately to avoid container constraints
	if preview.get_parent():
		preview.get_parent().remove_child(preview)
	
	# Reset all transform properties that might have been modified by hover effects
	preview.scale = Vector2(1.0, 1.0)
	preview.z_index = 0
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)  # Slightly transparent
	# Use custom_minimum_size (base size) not current size (which may be scaled)
	preview.custom_minimum_size = Vector2(200, 280)
	preview.size = Vector2(200, 280)  # Explicit size
	preview.mouse_filter = 0  # MOUSE_FILTER_IGNORE - preview should not receive mouse input
	set_drag_preview(preview)
	
	# Return card instance as drag data
	return card_instance

func _on_card_selected(card: CardInstance) -> void:
	_is_selected = (card == card_instance)
	_apply_visual_state()

func _on_card_deselected() -> void:
	_is_selected = false
	_apply_visual_state()

func _on_card_stats_changed(changed_card: CardInstance) -> void:
	# Update visual if this card's stats changed
	if changed_card == card_instance:
		_update_summoning_sickness_visual()

func _update_summoning_sickness_visual() -> void:
	# Show/hide swirl overlay based on summoning sickness
	# Only show on cards in lanes (not in hand), and only if they have summoning sickness
	if not _swirl_overlay or not card_instance:
		return
	
	# Check if this card is in a lane (has a parent that might be a lane)
	# Cards in hand are in hand_area, cards in lanes are in lane's card_slot
	var parent_node: Node = get_parent()
	var is_in_lane: bool = false
	if parent_node:
		# Check if parent is CardSlot (lane) or if we're in a lane structure
		if parent_node.name == "CardSlot" or parent_node.get_parent() and parent_node.get_parent().has_method("place_card"):
			is_in_lane = true
	
	# Show overlay if card is in lane and has summoning sickness
	if is_in_lane and card_instance.has_summoning_sickness:
		_swirl_overlay.visible = true
	else:
		_swirl_overlay.visible = false

func _exit_tree() -> void:
	if mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.disconnect(_on_mouse_entered)
	if mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.disconnect(_on_mouse_exited)
	# gui_input connection was removed - no need to disconnect
	if EventBus.card_selected.is_connected(_on_card_selected):
		EventBus.card_selected.disconnect(_on_card_selected)
	if EventBus.card_deselected.is_connected(_on_card_deselected):
		EventBus.card_deselected.disconnect(_on_card_deselected)
	if EventBus.card_stats_changed.is_connected(_on_card_stats_changed):
		EventBus.card_stats_changed.disconnect(_on_card_stats_changed)
