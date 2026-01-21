extends StaticBody3D

## Automatically syncs CollisionShape3D transform with MeshInstance3D transform.
## Attach this script to StaticBody3D nodes that have both MeshInstance3D and CollisionShape3D children.
## When you transform the mesh in the editor, the collision shape will automatically match.

func _ready() -> void:
	var mesh: MeshInstance3D = _find_mesh_instance()
	var collision: CollisionShape3D = _find_collision_shape()
	
	if mesh and collision:
		collision.transform = mesh.transform
	else:
		if not mesh:
			push_warning("MeshCollisionSync: No MeshInstance3D found in " + name)
		if not collision:
			push_warning("MeshCollisionSync: No CollisionShape3D found in " + name)

func _find_mesh_instance() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null

func _find_collision_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null
