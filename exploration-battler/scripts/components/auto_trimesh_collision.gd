extends StaticBody3D

## =============================================================================
## AutoTrimeshCollision - Runtime Collision Generator
## =============================================================================
## Automatically generates trimesh collision from all child MeshInstance3D nodes.
## Attach to a StaticBody3D that wraps imported FBX geometry.
##
## Usage:
## 1. Create a StaticBody3D node
## 2. Attach this script
## 3. Place imported FBX/GLTF scene as child
## 4. Collision shapes are generated at runtime
##
## How It Works:
## - Recursively finds all MeshInstance3D children
## - Creates ConcavePolygonShape3D (trimesh) for each mesh
## - Positions collision shapes to match mesh world transforms
##
## Performance Note:
## - Trimesh collision is accurate but slower than primitive shapes
## - Best for static geometry that needs precise collision
## - Deferred execution ensures transforms are finalized
##
## HARDCODED: collision_layer_mask sets which layer the collision is on.
## =============================================================================

@export var collision_layer_mask: int = 1
@export var debug_output: bool = true

func _ready() -> void:
	collision_layer = collision_layer_mask
	# Defer to ensure all transforms are finalized after scene tree is ready
	call_deferred("_generate_collision_from_meshes")

func _generate_collision_from_meshes() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(self, meshes)
	
	if debug_output:
		print("[AutoTrimesh] Found %d meshes in '%s'" % [meshes.size(), name])
	
	var shapes_created: int = 0
	for mesh_instance in meshes:
		var mesh: Mesh = mesh_instance.mesh
		if not mesh:
			if debug_output:
				print("[AutoTrimesh] Skipping '%s' - no mesh" % mesh_instance.name)
			continue
		
		var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
		if not shape:
			if debug_output:
				print("[AutoTrimesh] Failed to create trimesh for '%s'" % mesh_instance.name)
			continue
		
		var col := CollisionShape3D.new()
		col.shape = shape
		col.name = "Col_" + mesh_instance.name
		# Set global transform directly to match the mesh's world position
		add_child(col)
		col.global_transform = mesh_instance.global_transform
		shapes_created += 1
		
		if debug_output:
			print("[AutoTrimesh] Created collision for '%s'" % mesh_instance.name)
	
	if debug_output:
		print("[AutoTrimesh] Total: %d collision shapes created" % shapes_created)

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)
