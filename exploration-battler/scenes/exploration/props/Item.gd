extends Node3D

@export var spin_speed_rad: float = 2.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0

var _start_y: float = 0.0
var _time: float = 0.0

func _process(delta: float) -> void:
	rotate_y(spin_speed_rad * delta)
	
	if bob_height > 0.0 and bob_speed > 0.0:
		_time += delta
		var pos: Vector3 = global_position
		pos.y = _start_y + sin(_time * bob_speed) * bob_height
		global_position = pos
