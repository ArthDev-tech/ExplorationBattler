extends Node3D

## =============================================================================
## Item - Collectible Item Pickup
## =============================================================================
## Floating, spinning item prop that can be picked up by the player.
## Adds item to player inventory when touched.
##
## Animation:
## - Continuous Y-axis spin (spin_speed_rad)
## - Sinusoidal vertical bob (bob_height, bob_speed)
##
## Settings:
## - Can use shared ItemFloatSettings resource or override with per-instance values
## - Set override_settings=true to use exported values instead of settings resource
##
## HARDCODED: Default animation values below - adjust for different feel.
## =============================================================================

const ItemFloatSettingsScript = preload("res://scripts/core/item_float_settings.gd")

@export var settings: Resource = preload("res://resources/props/item_float_settings_default.tres")

## If true, use this node's override values instead of `settings` (per-instance tuning without duplicating a .tres).
@export var override_settings: bool = false
@export var spin_speed_rad: float = 2.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0
@export var item_data: ItemData = null

var _start_y: float = 0.0
var _time: float = 0.0

@onready var _area: Area3D = get_node_or_null("Area3D")

func _ready() -> void:
	# Cache the placed local height so bobbing is relative to where the item was positioned in the scene.
	_start_y = position.y
	
	# Connect pickup detection if Area3D exists
	if _area and not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var spin: float = spin_speed_rad
	var bob_h: float = bob_height
	var bob_s: float = bob_speed
	if not override_settings and settings:
		var maybe_spin: Variant = settings.get("spin_speed_rad")
		if maybe_spin != null:
			spin = float(maybe_spin)
		var maybe_bob_h: Variant = settings.get("bob_height")
		if maybe_bob_h != null:
			bob_h = float(maybe_bob_h)
		var maybe_bob_s: Variant = settings.get("bob_speed")
		if maybe_bob_s != null:
			bob_s = float(maybe_bob_s)
	
	rotate_y(spin * delta)
	
	if bob_h > 0.0 and bob_s > 0.0:
		_time += delta
		var pos: Vector3 = position
		pos.y = _start_y + sin(_time * bob_s) * bob_h
		position = pos

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D and item_data:
		# Any CharacterBody3D entering is assumed to be the player
		# (enemies don't pick up items, and player is the only CharacterBody3D that moves around)
		if GameManager.add_item_to_inventory(item_data):
			queue_free()
