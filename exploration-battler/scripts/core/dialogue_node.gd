class_name DialogueNode
extends Resource

## =============================================================================
## DialogueNode - Single node in a dialogue tree (Resource)
## =============================================================================
## One line of dialogue: speaker, text, and either a linear next_id (Continue)
## or branching choices. If choices is non-empty, use choices; otherwise
## use next_id (or end dialogue if next_id is empty).
## =============================================================================

@export var id: StringName = &""
@export var speaker: String = ""
@export var text: String = ""
## Next node id when no choices (linear). Use &"" for end of dialogue.
@export var next_id: StringName = &""
## If non-empty, show choice buttons instead of a single Continue.
@export var choices: Array[DialogueChoice] = []
