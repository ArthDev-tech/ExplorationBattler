extends Node3D

@export var amount: int = 1
@export var spin_speed_rad: float = 2.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0
@export var pickup_material_override: Material = null

@onready var _area: Area3D = $Area3D
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D

var _start_y: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_start_y = global_position.y
	if _mesh_instance and pickup_material_override:
		_mesh_instance.material_override = pickup_material_override
	if _area and not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotate_y(spin_speed_rad * delta)
	
	if bob_height > 0.0 and bob_speed > 0.0:
		_time += delta
		var pos: Vector3 = global_position
		pos.y = _start_y + sin(_time * bob_speed) * bob_height
		global_position = pos

func _on_body_entered(body: Node) -> void:
	# PlayerController is a CharacterBody3D; keep it generic to avoid tight coupling.
	if body is CharacterBody3D:
		EventBus.currency_gained.emit(amount)
		GameManager.add_currency(amount)
		queue_free()
