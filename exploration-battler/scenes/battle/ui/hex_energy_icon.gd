class_name HexEnergyIcon
extends Control

## Flat-top hexagon energy pip (filled, dim when spent).

@export var fill_color: Color = Color(1, 1, 1, 1)
@export var is_available: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(18, 18)

func _draw() -> void:
	var size_vec: Vector2 = size
	if size_vec.x <= 0.0 or size_vec.y <= 0.0:
		return
	
	# Flat-top hex points (clockwise).
	# Use the smaller dimension so it fits nicely in a row.
	var radius: float = minf(size_vec.x, size_vec.y) * 0.48
	var center: Vector2 = size_vec * 0.5
	
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var angle: float = deg_to_rad(60.0 * float(i))
		var x: float = cos(angle) * radius
		var y: float = sin(angle) * radius
		points.append(center + Vector2(x, y))
	
	var c: Color = fill_color
	if not is_available:
		c = Color(0.25, 0.25, 0.25, 1.0)
	
	draw_colored_polygon(points, c)
	# Subtle outline for readability
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.35), 1.0, true)

