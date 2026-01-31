extends Control

## =============================================================================
## DialoguePanel - Dialogue tree UI
## =============================================================================
## Subscribes to EventBus.dialogue_requested. Shows speaker and text for the
## current node; either one "Continue" button (linear) or choice buttons.
## Pauses game while open; emits dialogue_ended and unpauses when finished.
## =============================================================================

var _dialogue_tree: DialogueTreeData = null
var _current_node_id: StringName = &""

@onready var _speaker_label: Label = $PanelContainer/MarginContainer/VBox/SpeakerLabel
@onready var _text_label: Label = $PanelContainer/MarginContainer/VBox/TextLabel
@onready var _choices_container: VBoxContainer = $PanelContainer/MarginContainer/VBox/ChoicesContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not EventBus.dialogue_requested.is_connected(_on_dialogue_requested):
		EventBus.dialogue_requested.connect(_on_dialogue_requested)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close_dialogue(true)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if EventBus.dialogue_requested.is_connected(_on_dialogue_requested):
		EventBus.dialogue_requested.disconnect(_on_dialogue_requested)


func _on_dialogue_requested(dialogue_tree: Resource) -> void:
	var tree: DialogueTreeData = dialogue_tree as DialogueTreeData
	if not tree or tree.nodes.is_empty():
		return
	_dialogue_tree = tree
	_current_node_id = tree.entry_id
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_show_node(_current_node_id)


func _show_node(node_id: StringName) -> void:
	if not _dialogue_tree:
		return
	var node: DialogueNode = _dialogue_tree.get_node_by_id(node_id)
	if not node:
		_close_dialogue(true)
		return

	if _speaker_label:
		_speaker_label.text = node.speaker
		_speaker_label.visible = node.speaker.length() > 0
	if _text_label:
		_text_label.text = node.text

	_clear_choices()

	if node.choices.size() > 0:
		for choice: DialogueChoice in node.choices:
			if not choice:
				continue
			var btn: Button = Button.new()
			btn.text = choice.label
			btn.pressed.connect(_on_choice_pressed.bind(choice.next_id))
			_choices_container.add_child(btn)
	else:
		var continue_btn: Button = Button.new()
		continue_btn.text = "Continue"
		continue_btn.pressed.connect(_on_continue_pressed.bind(node.next_id))
		_choices_container.add_child(continue_btn)


func _clear_choices() -> void:
	if not _choices_container:
		return
	for child: Node in _choices_container.get_children():
		child.queue_free()


func _on_choice_pressed(next_id: StringName) -> void:
	_go_to(next_id)


func _on_continue_pressed(next_id: StringName) -> void:
	_go_to(next_id)


const OPEN_SHOP_NEXT_ID: StringName = &"__open_shop__"


func _go_to(next_id: StringName) -> void:
	if next_id == OPEN_SHOP_NEXT_ID:
		_open_shop()
		return
	if next_id == &"" or not _dialogue_tree or _dialogue_tree.get_node_by_id(next_id) == null:
		_close_dialogue(true)
		return
	_current_node_id = next_id
	_show_node(_current_node_id)


func _open_shop() -> void:
	_close_dialogue(false)
	EventBus.shop_requested.emit(GameManager.current_shop_inventory)


func _close_dialogue(restore_game: bool = true) -> void:
	_dialogue_tree = null
	_current_node_id = &""
	visible = false
	if restore_game:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		EventBus.dialogue_ended.emit()
