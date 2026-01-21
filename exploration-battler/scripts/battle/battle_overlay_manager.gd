extends Node

## Manages battle overlay lifecycle, world pause/unpause, and enemy defeat handling.

var _current_battle_overlay: Node = null
var _triggering_enemy: Node3D = null
var _battle_scene: PackedScene = null
var _hide_timer: float = 0.0
var _waiting_to_hide: bool = false

func _ready() -> void:
	# Ensure overlay manager processes even when world is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load battle scene
	_battle_scene = load("res://scenes/battle/battle_arena.tscn") as PackedScene
	if not _battle_scene:
		push_error("Failed to load battle arena scene")
	
	# Connect to battle end signal
	EventBus.battle_ended.connect(_on_battle_ended)

func show_battle_overlay(enemy_data: EnemyData, triggering_enemy: Node3D = null) -> void:
	if _current_battle_overlay:
		push_warning("Battle overlay already active, hiding previous one")
		hide_battle_overlay()
	
	if not _battle_scene:
		push_error("Battle scene not loaded, cannot show overlay")
		return
	
	# Store reference to triggering enemy
	_triggering_enemy = triggering_enemy
	
	# Instantiate battle scene
	_current_battle_overlay = _battle_scene.instantiate()
	if not _current_battle_overlay:
		push_error("Failed to instantiate battle overlay")
		return
	
	# Add to scene tree (as child of root, so it's on top)
	var root: Node = get_tree().root
	root.add_child(_current_battle_overlay)
	
	# Ensure battle processes even when world is paused
	_current_battle_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Pause the world (except nodes with PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	
	# Emit battle started signal (battle manager will handle initialization)
	EventBus.battle_started.emit(enemy_data)

func hide_battle_overlay() -> void:
	if _current_battle_overlay:
		_current_battle_overlay.queue_free()
		_current_battle_overlay = null
	
	# Unpause the world
	get_tree().paused = false
	
	# Clear enemy reference
	_triggering_enemy = null

func _on_battle_ended(result: int) -> void:
	# result: 0 = player win, 1 = player loss
	if result == 0 and _triggering_enemy:
		# Player won - mark enemy as defeated
		if _triggering_enemy.has_method("defeated_enemy"):
			_triggering_enemy.defeated_enemy()
		else:
			push_warning("Triggering enemy does not have defeated_enemy() method")
	
	# Start timer to hide overlay after delay (for victory/defeat display)
	_waiting_to_hide = true
	_hide_timer = 2.0

func _process(delta: float) -> void:
	if _waiting_to_hide:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_waiting_to_hide = false
			hide_battle_overlay()

func _exit_tree() -> void:
	if EventBus.battle_ended.is_connected(_on_battle_ended):
		EventBus.battle_ended.disconnect(_on_battle_ended)
