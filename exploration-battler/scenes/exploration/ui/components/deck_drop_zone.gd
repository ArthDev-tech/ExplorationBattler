extends VBoxContainer

## Drop zone for deck list - accepts cards from collection.

func can_drop_data(position: Vector2, data: Variant) -> bool:
	# Allow dropping collection cards into deck
	if data is Dictionary:
		var drag_data: Dictionary = data as Dictionary
		var source: String = drag_data.get("source", "")
		return source == "collection"
	return false

func drop_data(position: Vector2, data: Variant) -> void:
	# Handle card drop into deck
	if data is Dictionary:
		var drag_data: Dictionary = data as Dictionary
		var card_data: CardData = drag_data.get("card_data", null)
		if card_data:
			# Find card collection menu to handle the drop
			var menu: Node = _find_card_collection_menu()
			if menu and menu.has_method("_handle_card_drop"):
				menu.call_deferred("_handle_card_drop", card_data, "collection", "deck")

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
		if node and node.has_method("_handle_card_drop"):
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
