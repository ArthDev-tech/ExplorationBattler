extends Control

## Wrapper Control for cards that supports drag-and-drop in deck builder.

var card_data: CardData = null
var card_instance: CardInstance = null
var available_count: int = 0
var source_location: String = "collection"  # "collection" or "deck"

func _get_drag_data(position: Vector2) -> Variant:
	# Only allow drag if card is available (for collection) or always for deck cards
	if source_location == "collection" and available_count <= 0:
		return null
	
	if not card_data:
		return null
	
	# Create drag preview
	var preview: Control = duplicate()
	preview.modulate = Color(1.0, 1.0, 1.0, 0.8)
	# Set drag preview
	set_drag_preview(preview)
	
	# Return drag data
	return {
		"card_data": card_data,
		"card_instance": card_instance,
		"source": source_location
	}

func _gui_input(event: InputEvent) -> void:
	# Handle double-click to add card to deck (for collection cards only)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click and source_location == "collection":
			if card_data and available_count > 0:
				var menu: Node = _find_card_collection_menu()
				if menu and menu.has_method("_add_card_to_deck"):
					menu.call_deferred("_add_card_to_deck", card_data)

func _find_card_collection_menu() -> Node:
	# Try multiple paths for compatibility
	var paths: Array[String] = [
		"UI/CardCollectionMenu",
		"UI/ExplorationUI/CardCollectionMenu",
		"../CardCollectionMenu",
		"../../CardCollectionMenu"
	]
	
	for path in paths:
		var node: Node = get_tree().current_scene.get_node_or_null(path)
		if node and (node.has_method("_handle_card_drop") or node.has_method("_add_card_to_deck")):
			return node
	
	# Fallback: search by script type
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		return _find_node_with_script(scene_root, "card_collection_menu.gd")
	
	return null

func _find_node_with_script(root: Node, script_name: String) -> Node:
	if root.get_script() and str(root.get_script().resource_path).ends_with(script_name):
		return root
	for child in root.get_children():
		var found: Node = _find_node_with_script(child, script_name)
		if found:
			return found
	return null
