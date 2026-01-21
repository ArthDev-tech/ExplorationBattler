extends Control

## Shows small "+<amount> C" popups near screen center on currency pickup.

@export var popup_rise_px: float = 30.0
@export var popup_duration: float = 0.6
@export var popup_offset: Vector2 = Vector2(0.0, 60.0) # below center (crosshair)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not EventBus.currency_gained.is_connected(_on_currency_gained):
		EventBus.currency_gained.connect(_on_currency_gained)

func _exit_tree() -> void:
	if EventBus.currency_gained.is_connected(_on_currency_gained):
		EventBus.currency_gained.disconnect(_on_currency_gained)

func _on_currency_gained(amount: int) -> void:
	if amount == 0:
		return
	
	var popup: Control = Control.new()
	popup.name = "CurrencyPopup"
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.size = Vector2(120.0, 40.0)
	add_child(popup)
	
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "+%d C" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup.add_child(label)
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	
	# Position near screen center.
	var viewport_size: Vector2 = get_viewport_rect().size
	var start_pos: Vector2 = (viewport_size * 0.5) - (popup.size * 0.5) + popup_offset
	popup.position = start_pos
	popup.modulate = Color(1, 1, 1, 1)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position", start_pos + Vector2(0.0, -popup_rise_px), popup_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, popup_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(popup.queue_free)

