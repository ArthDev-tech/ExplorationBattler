class_name DialogueTreeData
extends Resource

## =============================================================================
## DialogueTreeData - Reusable dialogue tree (Resource)
## =============================================================================
## Data-driven dialogue: entry_id plus an array of DialogueNode. Each node
## has id, speaker, text, and either next_id (linear) or choices (branching).
## Used by the dialogue UI and attached to NPCs via InteractableNPC.
## =============================================================================

@export var entry_id: StringName = &""
@export var nodes: Array[DialogueNode] = []


func get_node_by_id(node_id: StringName) -> DialogueNode:
	for node: DialogueNode in nodes:
		if node and node.id == node_id:
			return node
	return null
