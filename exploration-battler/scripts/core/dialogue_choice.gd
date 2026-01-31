class_name DialogueChoice
extends Resource

## =============================================================================
## DialogueChoice - Single choice in a dialogue node (Resource)
## =============================================================================
## Used when a dialogue node has branching choices; each choice has a label
## and the next node id to jump to.
## =============================================================================

@export var label: String = ""
@export var next_id: StringName = &""
