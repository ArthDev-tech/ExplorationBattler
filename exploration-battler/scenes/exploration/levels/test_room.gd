extends Node3D

## =============================================================================
## TestRoom - Test Level Controller
## =============================================================================
## Test room script - handles kill zone and player respawn.
## This is the primary development/testing level.
##
## Features:
## - Kill zone at bottom to respawn fallen players
## - Player spawn point for initial/respawn position
## - Contains various test enemies and props
##
## Kill Zone:
## - Area3D at bottom of level
## - When player enters, resets position and velocity
## =============================================================================

@onready var _kill_zone: Area3D = $PlatformsFloorECT/KillZone
@onready var _player_spawn: Marker3D = $PlayerSpawn
@onready var _player: CharacterBody3D = $PlayerController

func _ready() -> void:
	if _kill_zone:
		_kill_zone.body_entered.connect(_on_kill_zone_entered)

func _on_kill_zone_entered(body: Node3D) -> void:
	if body == _player or body.name == "PlayerController":
		reset_player_position()

func reset_player_position() -> void:
	if _player and _player_spawn:
		_player.global_position = _player_spawn.global_position
		# Reset velocity to prevent continued falling
		if _player is CharacterBody3D:
			_player.velocity = Vector3.ZERO

func _exit_tree() -> void:
	if _kill_zone and _kill_zone.body_entered.is_connected(_on_kill_zone_entered):
		_kill_zone.body_entered.disconnect(_on_kill_zone_entered)
