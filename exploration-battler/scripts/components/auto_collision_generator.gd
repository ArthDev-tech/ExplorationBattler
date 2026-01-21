extends MeshInstance3D

## Automatically generates collision shapes from mesh geometry.
## Attach this script to a MeshInstance3D to automatically create collision shapes
## that adapt to the mesh shape.

enum CollisionType {
	CONVEX,  # Faster, simpler shape. Good for most objects.
	TRIMESH  # Exact mesh shape. More accurate but slower. Only works with StaticBody3D.
}

@export var collision_type: CollisionType = CollisionType.CONVEX
@export var auto_create_static_body: bool = true
@export var auto_generate_on_ready: bool = true

var _generated_collision_shape: CollisionShape3D = null
var _created_static_body: StaticBody3D = null

func _ready() -> void:
	if auto_generate_on_ready:
		generate_collision()

func generate_collision() -> void:
	# Check if mesh exists
	if not mesh:
		push_warning("AutoCollisionGenerator: No mesh found on MeshInstance3D: " + name)
		return
	
	# Handle StaticBody3D parent if needed
	var parent_body: StaticBody3D = null
	if auto_create_static_body:
		parent_body = _ensure_static_body_parent()
	
	# Clear existing generated collision if any
	clear_collision()
	
	# Generate collision shape based on type
	var shape: Shape3D = null
	match collision_type:
		CollisionType.CONVEX:
			shape = mesh.create_convex_shape()
		CollisionType.TRIMESH:
			# Trimesh only works with StaticBody3D
			if not parent_body:
				parent_body = _ensure_static_body_parent()
			if not parent_body:
				push_error("AutoCollisionGenerator: Trimesh collision requires StaticBody3D. Cannot generate collision.")
				return
			shape = mesh.create_trimesh_shape()
	
	if not shape:
		push_error("AutoCollisionGenerator: Failed to generate collision shape from mesh: " + name)
		return
	
	# Create CollisionShape3D node
	_generated_collision_shape = CollisionShape3D.new()
	_generated_collision_shape.name = "GeneratedCollisionShape"
	_generated_collision_shape.shape = shape
	
	# Determine where to add the collision shape
	# If we have a StaticBody3D (existing parent or created), add collision there
	# Otherwise, add to mesh's parent
	var target_parent: Node = parent_body if parent_body else get_parent()
	
	if not target_parent:
		push_error("AutoCollisionGenerator: No parent node found to add collision shape")
		return
	
	# Add collision shape to target parent
	target_parent.add_child(_generated_collision_shape)
	_generated_collision_shape.owner = get_tree().edited_scene_root
	
	# Sync transform with mesh
	if parent_body and parent_body != get_parent():
		# If StaticBody3D is a sibling, the StaticBody3D's global_transform already matches the mesh
		# So the collision shape should have identity transform (relative to StaticBody3D)
		_generated_collision_shape.transform = Transform3D.IDENTITY
	else:
		# If same parent or StaticBody3D is the parent, use local transform to match mesh
		_generated_collision_shape.transform = transform

func clear_collision() -> void:
	if _generated_collision_shape:
		_generated_collision_shape.queue_free()
		_generated_collision_shape = null

func _ensure_static_body_parent() -> StaticBody3D:
	# Check if parent is already a StaticBody3D
	var parent: Node = get_parent()
	if parent is StaticBody3D:
		return parent as StaticBody3D
	
	# If we need to create a StaticBody3D (for trimesh or if auto_create_static_body is true)
	if auto_create_static_body or collision_type == CollisionType.TRIMESH:
		# Create StaticBody3D as sibling to hold the collision
		_created_static_body = StaticBody3D.new()
		_created_static_body.name = name + "_CollisionBody"
		_created_static_body.global_transform = global_transform
		
		var parent_node: Node = get_parent()
		if parent_node:
			parent_node.add_child(_created_static_body)
			_created_static_body.owner = get_tree().edited_scene_root
			return _created_static_body
		else:
			push_warning("AutoCollisionGenerator: No parent found for StaticBody3D creation")
			return null
	
	# No StaticBody3D needed
	return null
