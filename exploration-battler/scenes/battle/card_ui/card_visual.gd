extends Control

## =============================================================================
## CardVisual - Card UI Representation
## =============================================================================
## UI representation of a card. Displays card data and handles interactions.
## Used in hand, lanes, and backrow for consistent card appearance.
##
## Visual Features:
## - Cost display with colored pips (R/B/G)
## - Background color based on dominant energy type
## - Rarity border color (Common/Uncommon/Rare/Legendary)
## - Tribe-based artwork placeholder colors
## - Summoning sickness swirl overlay
##
## Interactions:
## - Hover: Scale up, glow effect, raise z-index
## - Drag: Create preview, return CardInstance as data
## - Click: Select creature or play spell
##
## Context-Aware Behavior:
## - In Hand: Full interaction (drag, click, hover scale)
## - In Lane: Reduced interaction (pass events to lane)
## - In Backrow: No drag, hover scale preserved at 0.7x
##
## HARDCODED: Color constants for energy types defined below.
## =============================================================================

signal card_clicked(card: CardInstance)

var card_instance: CardInstance = null
var _is_selected: bool = false
var _is_playable: bool = false
var _drag_started: bool = false
var _click_timer: float = 0.0
var _mouse_press_pos: Vector2 = Vector2.ZERO
var _original_scale: Vector2 = Vector2(1.0, 1.0)

@onready var _background: Panel = $Background
@onready var _cost_label: Label = $VBox/Header/CostLabel
@onready var _type_label: Label = $VBox/Header/TypeLabel
@onready var _artwork: ColorRect = $VBox/ArtworkPlaceholder
@onready var _name_label: Label = $VBox/NameLabel
@onready var _tribe_label: Label = $VBox/TribeLabel
@onready var _keywords_label: Label = $VBox/KeywordsLabel
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
var _background_style: StyleBoxFlat = null
var _original_position: Vector2 = Vector2.ZERO

const _COLOR_GREY: Color = Color(0.5, 0.5, 0.5, 1.0)      # Medium grey (colorless)
const _COLOR_RED: Color = Color(0.5, 0.15, 0.15, 1.0)     # Dark red
const _COLOR_BLUE: Color = Color(0.15, 0.25, 0.5, 1.0)    # Dark blue
const _COLOR_GREEN: Color = Color(0.15, 0.4, 0.2, 1.0)    # Dark green

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure cards receive mouse input
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_click_timer = 0.0
	_mouse_press_pos = Vector2.ZERO
	# REMOVED: gui_input connection - it was preventing drag-and-drop from working
	# Use _unhandled_input for click-to-select instead
	# Cache battle manager reference - try multiple paths
	_battle_manager = _get_battle_manager()
	# Store original position for animations (will be updated when card is placed)
	call_deferred("_store_original_position")
	# Allow lanes to receive clicks during targeting
	EventBus.targeting_started.connect(_on_targeting_started)
	EventBus.targeting_cancelled.connect(_on_targeting_cancelled)
	_update_mouse_filter_for_targeting()
	# Listen for card selection
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_deselected.connect(_on_card_deselected)
	# Listen for card stats changes (e.g., summoning sickness cleared)
	EventBus.card_stats_changed.connect(_on_card_stats_changed)

func _store_original_position() -> void:
	# Store original position for animations (called deferred to ensure position is set)
	if _original_position == Vector2.ZERO:
		_original_position = global_position

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

	_ensure_unique_background_style()
	
	# Cost
	_cost_label.text = _format_cost_text(data)
	_apply_cost_color_theme(data)
	
	# Type icon
	_type_label.text = _type_icons.get(data.card_type, "?")
	
	# Name
	_name_label.text = data.display_name
	
	# Tribe
	if data.is_creature() and data.tribe != CardData.Tribe.NONE:
		_tribe_label.text = _tribe_names[data.tribe]
	else:
		_tribe_label.text = ""
	
	# Keywords
	if _keywords_label:
		var keyword_list: Array[String] = []
		for kw in data.keywords:
			if kw != &"":
				keyword_list.append(String(kw))
		if keyword_list.size() > 0:
			_keywords_label.text = " | ".join(keyword_list)
			_keywords_label.visible = true
		else:
			_keywords_label.text = ""
			_keywords_label.visible = false
	
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
		if _background_style:
			_background_style.border_color = _rarity_colors.get(data.rarity, Color(0.2, 0.2, 0.2, 1))
	
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
	var battle_state: BattleState = _get_battle_state()
	if battle_state:
		_is_playable = battle_state.can_afford_player_cost(card_instance.data)
	else:
		var current_energy: int = _get_current_energy()
		_is_playable = card_instance.data.cost <= current_energy
	
	# Apply visual state
	_apply_visual_state()
	# Update summoning sickness overlay
	_update_summoning_sickness_visual()

func _ensure_unique_background_style() -> void:
	if not _background:
		return
	if _background_style:
		return
	var style: StyleBox = _background.get_theme_stylebox("panel", "Panel")
	if style and style is StyleBoxFlat:
		_background_style = (style as StyleBoxFlat).duplicate() as StyleBoxFlat
		_background.add_theme_stylebox_override("panel", _background_style)

func _format_cost_text(data: CardData) -> String:
	var generic: int = maxi(0, data.cost)
	var r: int = maxi(0, data.cost_red)
	var b: int = maxi(0, data.cost_blue)
	var g: int = maxi(0, data.cost_green)
	var text: String = ""
	if generic > 0:
		text += str(generic)
	if r > 0:
		text += "R".repeat(r)
	if b > 0:
		text += "B".repeat(b)
	if g > 0:
		text += "G".repeat(g)
	if text.is_empty():
		return "0"
	return text

func _get_dominant_pip_color(data: CardData) -> int:
	var r: int = maxi(0, data.cost_red)
	var b: int = maxi(0, data.cost_blue)
	var g: int = maxi(0, data.cost_green)
	var max_pips: int = maxi(r, maxi(b, g))
	if max_pips <= 0:
		return -1
	var winners: int = 0
	if r == max_pips:
		winners += 1
	if b == max_pips:
		winners += 1
	if g == max_pips:
		winners += 1
	if winners != 1:
		return -1
	if r == max_pips:
		return 0
	if b == max_pips:
		return 1
	return 2

func _apply_cost_color_theme(data: CardData) -> void:
	# Grey for no pips or ties. Otherwise tint by dominant pip color.
	if not _background_style:
		return
	var dominant: int = _get_dominant_pip_color(data)
	match dominant:
		0:
			_background_style.bg_color = _COLOR_RED
		1:
			_background_style.bg_color = _COLOR_BLUE
		2:
			_background_style.bg_color = _COLOR_GREEN
		_:
			_background_style.bg_color = _COLOR_GREY

func _get_current_energy() -> int:
	var battle_state: BattleState = _get_battle_state()
	if battle_state:
		return battle_state.get_player_energy_total()
	return 0

func _get_battle_state() -> BattleState:
	# Query battle state via BattleManager
	if not _battle_manager:
		_battle_manager = _get_battle_manager()
	if not _battle_manager:
		return null
	var state_variant: Variant = _battle_manager.get("battle_state")
	if state_variant and state_variant is BattleState:
		return state_variant as BattleState
	return null

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
		# Only apply scale/z_index for cards not in hand (hand_area handles those)
		if not _is_in_hand():
			_original_scale = scale  # Store current scale before modifying
			scale = _original_scale * 1.15  # Scale up from current (preserves 0.7x for backrow)
			z_index = 20
		# Always add glow effect
		if _background:
			var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
			if style:
				style.shadow_size = 8
				style.shadow_color = Color(0.5, 0.5, 1.0, 0.5)

func _on_mouse_exited() -> void:
	# Only reset scale/z_index for cards not in hand
	if not _is_in_hand():
		scale = _original_scale  # Restore to original scale (preserves 0.7x for backrow)
		z_index = 0
	# Always remove glow effect
	if _background:
		var style: StyleBoxFlat = _background.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if style:
			style.shadow_size = 4
			style.shadow_color = Color(0, 0, 0, 0.3)
	_apply_visual_state()

func _is_in_hand() -> bool:
	# Cards in hand are children of CardContainer in HandArea
	var parent_node: Node = get_parent()
	if not parent_node:
		return false
	if parent_node.name == "CardContainer":
		var grandparent = parent_node.get_parent()
		if grandparent and grandparent.name == "HandArea":
			return true
	return false

func _is_in_lane() -> bool:
	# Cards in hand are in hand_area; cards in lanes are in lane's CardSlot.
	var parent_node: Node = get_parent()
	if not parent_node:
		return false
	if parent_node.name == "CardSlot":
		return true
	if parent_node.get_parent() and parent_node.get_parent().has_method("place_card"):
		return true
	return false

func _is_in_backrow() -> bool:
	# Cards in backrow are in backrow_zone's SlotsContainer -> Slot1/Slot2/Slot3
	var parent_node: Node = get_parent()
	if not parent_node:
		return false
	if parent_node.name.begins_with("Slot"):
		var grandparent: Node = parent_node.get_parent()
		if grandparent and grandparent.name == "SlotsContainer":
			return true
	return false

func _is_targeting_mode() -> bool:
	if not _battle_manager:
		_battle_manager = _get_battle_manager()
	if not _battle_manager:
		return false
	return _battle_manager.get("_targeting_mode") == true

func _update_mouse_filter_for_targeting() -> void:
	# Lane cards should not block lane input (click targeting + drag-drop targeting).
	# Hand cards should still consume input for selection/drag.
	if _is_in_lane():
		mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP

func _on_targeting_started(_card: CardInstance) -> void:
	_update_mouse_filter_for_targeting()

func _on_targeting_cancelled() -> void:
	_update_mouse_filter_for_targeting()

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
	# Prevent dragging cards that are already in lanes or backrow - only cards in hand should be draggable
	if _is_in_lane() or _is_in_backrow():
		return null
	
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
	preview.z_index = 100  # High z_index to ensure drag preview appears above all cards
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)  # Slightly transparent
	# Use custom_minimum_size (base size) not current size (which may be scaled)
	preview.custom_minimum_size = Vector2(200, 280)
	preview.size = Vector2(200, 280)  # Explicit size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE  # preview should not receive mouse input
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

func play_attack_animation(target_position: Vector2) -> void:
	## Play bump animation when card attacks a target.
	## target_position: The global position of the attack target
	# Store current position if not set
	if _original_position == Vector2.ZERO:
		_original_position = global_position
	
	var original_pos: Vector2 = _original_position
	# If original position is still zero, use current position
	if original_pos == Vector2.ZERO:
		original_pos = global_position
		_original_position = original_pos
	
	# Store original z_index and set high z_index for animation
	var original_z_index: int = z_index
	z_index = 50  # High z_index so card appears above others during animation
	
	# Calculate bump position (move 30% toward target)
	var bump_pos: Vector2 = original_pos.lerp(target_position, 0.3)
	
	# Create tween animation
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	# Move toward target
	tween.tween_property(self, "global_position", bump_pos, 0.15)
	
	# Brief pause at bump position
	tween.tween_interval(0.05)
	
	# Return to original position
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", original_pos, 0.15)
	
	await tween.finished
	# Update stored original position in case it changed
	_original_position = global_position
	# Restore original z_index
	z_index = original_z_index

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
	if EventBus.targeting_started.is_connected(_on_targeting_started):
		EventBus.targeting_started.disconnect(_on_targeting_started)
	if EventBus.targeting_cancelled.is_connected(_on_targeting_cancelled):
		EventBus.targeting_cancelled.disconnect(_on_targeting_cancelled)
