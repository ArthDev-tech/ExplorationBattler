@tool
extends Node3D

## Grass patch that uses the stylized grass shader.
## Fills a MultiMeshInstance3D child named "Grass" with quad blades in a rectangle.
## Instance [grass_patch.tscn] into any level and move it onto the floor; tune extent and count in the inspector.
## Assign [grass_sprite_texture] per instance to use a different sprite; visible in the editor.
## Assign [reference_larger_patch] to another GrassPatch to copy its extent and instance count when this patch builds.

@export var reference_larger_patch: Node3D = null

@export var extent_x: float = 5.0
@export var extent_z: float = 5.0
@export var instance_count: int = 400
@export var seed_value: int = 0
@export var scale_jitter: float = 0.0

@export_group("Displacement")
@export var displacement_radius: float = 2.0

var _grass_sprite_texture: Texture2D = null
var _last_player_position: Vector3 = Vector3.ZERO
var _player_position_received: bool = false

@export_group("Grass Appearance")
@export var grass_sprite_texture: Texture2D = null:
	set(value):
		_grass_sprite_texture = value
		# Update material when changed (works in editor and runtime)
		_apply_grass_texture()
	get:
		return _grass_sprite_texture
@export var blade_width: float = 0.08
@export var blade_height: float = 0.5

@onready var _grass: MultiMeshInstance3D = $Grass

const GRASS_MATERIAL: ShaderMaterial = preload("res://materials/materials/stylized_grass_material.tres")

func _apply_grass_texture() -> void:
	if not _grass:
		return
	var mat: ShaderMaterial = GRASS_MATERIAL.duplicate()
	if _grass_sprite_texture != null:
		mat.set_shader_parameter("albedo_texture", _grass_sprite_texture)
	_grass.material_override = mat

func _ready() -> void:
	_build_multimesh()
	if not Engine.is_editor_hint():
		if not EventBus.player_moved.is_connected(_on_player_moved):
			EventBus.player_moved.connect(_on_player_moved)

func _on_player_moved(pos: Vector3) -> void:
	_last_player_position = pos
	_player_position_received = true

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _grass:
		return
	var mat: ShaderMaterial = _grass.material_override as ShaderMaterial
	if mat == null:
		return
	var arr: PackedVector4Array = PackedVector4Array()
	arr.resize(64)
	if _player_position_received:
		arr[0] = Vector4(_last_player_position.x, _last_player_position.y, _last_player_position.z, displacement_radius)
	else:
		arr[0] = Vector4(0.0, 0.0, 0.0, 0.0)
	for i in range(1, 64):
		arr[i] = Vector4(0.0, 0.0, 0.0, 0.0)
	mat.set_shader_parameter("character_positions", arr)

func _exit_tree() -> void:
	if EventBus.player_moved.is_connected(_on_player_moved):
		EventBus.player_moved.disconnect(_on_player_moved)

func _build_multimesh() -> void:
	if not _grass:
		push_error("GrassPatch: MultiMeshInstance3D child 'Grass' not found.")
		return

	# Use reference's extent and count for this build when it's another GrassPatch (does not overwrite exports)
	var use_extent_x: float = extent_x
	var use_extent_z: float = extent_z
	var use_count: int = instance_count
	if reference_larger_patch != null and reference_larger_patch.get_script() == get_script():
		use_extent_x = reference_larger_patch.extent_x
		use_extent_z = reference_larger_patch.extent_z
		use_count = reference_larger_patch.instance_count

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(blade_width, blade_height)

	var mm: MultiMesh = MultiMesh.new()
	mm.mesh = quad
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = use_count

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = hash(seed_value)

	for i in range(use_count):
		var x: float
		var z: float
		if seed_value != 0:
			x = (rng.randf() - 0.5) * use_extent_x
			z = (rng.randf() - 0.5) * use_extent_z
		else:
			x = (randf() - 0.5) * use_extent_x
			z = (randf() - 0.5) * use_extent_z

		var scale_factor: float = 1.0
		if scale_jitter > 0.0:
			if seed_value != 0:
				scale_factor = 1.0 + (rng.randf() - 0.5) * scale_jitter * 0.2
			else:
				scale_factor = 1.0 + (randf() - 0.5) * scale_jitter * 0.2
		scale_factor = clampf(scale_factor, 0.5, 1.5)

		var blade_basis: Basis = Basis.IDENTITY.scaled(Vector3(scale_factor, scale_factor, scale_factor))
		var pos: Vector3 = Vector3(x, 0.0, z)
		var t: Transform3D = Transform3D(blade_basis, pos)
		mm.set_instance_transform(i, t)

	_grass.multimesh = mm
	_apply_grass_texture()
