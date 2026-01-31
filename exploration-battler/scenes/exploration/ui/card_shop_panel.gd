extends Control

## =============================================================================
## CardShopPanel - Card shop UI opened from dialogue (e.g. Mysterious Stranger)
## =============================================================================
## Subscribes to EventBus.shop_requested. Shows a grid of card visuals (same as
## collection menu) with cost and Buy button under each card. On close: unpauses,
## restores mouse, clears GameManager.current_shop_inventory, emits dialogue_ended.
## =============================================================================

const CARD_VISUAL_SCENE: String = "res://scenes/battle/card_ui/card_visual.tscn"

var _shop_inventory: ShopInventoryData = null

@onready var _flash_overlay: ColorRect = $FlashOverlay
@onready var _panel_container: PanelContainer = $PanelContainer
@onready var _title_label: Label = $PanelContainer/MarginContainer/VBox/TitleLabel
@onready var _currency_label: Label = $PanelContainer/MarginContainer/VBox/CurrencyLabel
@onready var _card_grid: GridContainer = $PanelContainer/MarginContainer/VBox/ScrollContainer/CardGrid
@onready var _close_button: Button = $PanelContainer/MarginContainer/VBox/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not EventBus.shop_requested.is_connected(_on_shop_requested):
		EventBus.shop_requested.connect(_on_shop_requested)
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)


func _exit_tree() -> void:
	if EventBus.shop_requested.is_connected(_on_shop_requested):
		EventBus.shop_requested.disconnect(_on_shop_requested)


func _on_shop_requested(shop_inventory: Resource) -> void:
	_shop_inventory = shop_inventory as ShopInventoryData
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_refresh_currency()
	_build_card_grid()


func _build_card_grid() -> void:
	for child: Node in _card_grid.get_children():
		child.queue_free()
	if not _shop_inventory or not _shop_inventory.cards:
		return
	var card_scene: PackedScene = load(CARD_VISUAL_SCENE) as PackedScene
	if not card_scene:
		push_error("CardShopPanel: failed to load card_visual.tscn")
		return
	for card_data: CardData in _shop_inventory.cards:
		if not card_data:
			continue
		var card_visual: Control = card_scene.instantiate()
		if not card_visual:
			continue
		var card_instance: CardInstance = CardInstance.new(card_data)
		card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot: VBoxContainer = VBoxContainer.new()
		slot.add_theme_constant_override("separation", 6)
		slot.custom_minimum_size.x = 200
		slot.add_child(card_visual)
		if card_visual.has_method("set_card"):
			card_visual.call_deferred("set_card", card_instance)
		var cost_row: HBoxContainer = HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 8)
		var cost_label: Label = Label.new()
		cost_label.text = str(card_data.currency_cost) + " G"
		cost_label.custom_minimum_size.x = 50
		var buy_btn: Button = Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_buy_pressed.bind(card_data, buy_btn))
		cost_row.add_child(cost_label)
		cost_row.add_child(buy_btn)
		slot.add_child(cost_row)
		_card_grid.add_child(slot)


func _on_buy_pressed(card_data: CardData, buy_btn: Button) -> void:
	if not card_data or not GameManager:
		return
	var cost: int = maxi(0, card_data.currency_cost)
	if GameManager.player_currency < cost:
		_play_cannot_afford_feedback()
		return
	var slot: Node = buy_btn.get_parent().get_parent()
	var card_visual: Control = slot.get_child(0) as Control if slot.get_child_count() > 0 else null
	_play_buy_success_animation(card_visual)
	_show_added_to_collection_popup(card_data.display_name)
	GameManager.add_currency(-cost)
	GameManager.add_card_to_collection(card_data, 1)
	_refresh_currency()
	buy_btn.disabled = true
	buy_btn.text = "Owned"


func _play_cannot_afford_feedback() -> void:
	if _flash_overlay:
		_flash_overlay.color = Color(1, 0, 0, 0.5)
		var tween: Tween = create_tween()
		tween.tween_property(_flash_overlay, "color:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	if _panel_container:
		var start_pos: Vector2 = _panel_container.position
		var shake_tween: Tween = create_tween()
		for i in range(5):
			var offset: Vector2 = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
			shake_tween.tween_property(_panel_container, "position", start_pos + offset, 0.03)
		shake_tween.tween_property(_panel_container, "position", start_pos, 0.05).set_ease(Tween.EASE_OUT)
	_show_not_enough_gold_popup()


func _show_not_enough_gold_popup() -> void:
	var popup: Label = Label.new()
	popup.name = "NotEnoughGoldPopup"
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.text = "Not enough gold!"
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 1.0))
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.size = Vector2(280, 50)
	add_child(popup)
	var viewport_size: Vector2 = get_viewport_rect().size
	popup.position = (viewport_size * 0.5) - (popup.size * 0.5)
	popup.modulate = Color(1, 1, 1, 1)
	var tween: Tween = create_tween()
	tween.tween_property(popup, "modulate:a", 0.0, 0.8).set_delay(0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(popup.queue_free)


func _play_buy_success_animation(card_visual: Control) -> void:
	if not card_visual:
		return
	var start_scale: Vector2 = card_visual.scale
	var tween: Tween = create_tween()
	tween.tween_property(card_visual, "scale", Vector2(1.15, 1.15), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_visual, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)


func _show_added_to_collection_popup(card_name: String) -> void:
	var popup: Control = Control.new()
	popup.name = "AddedToCollectionPopup"
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.size = Vector2(260, 50)
	add_child(popup)
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "Added to collection!"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	popup.add_child(label)
	var viewport_size: Vector2 = get_viewport_rect().size
	var start_pos: Vector2 = (viewport_size * 0.5) - (popup.size * 0.5) + Vector2(0, -20)
	popup.position = start_pos
	popup.modulate = Color(1, 1, 1, 1)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position", start_pos + Vector2(0, -30), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(popup.queue_free)


func _refresh_currency() -> void:
	if _currency_label and GameManager:
		_currency_label.text = "Gold: " + str(GameManager.player_currency)


func _on_close_pressed() -> void:
	_shop_inventory = null
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.current_shop_inventory = null
	EventBus.dialogue_ended.emit()
