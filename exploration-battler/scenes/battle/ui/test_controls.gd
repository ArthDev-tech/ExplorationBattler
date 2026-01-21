extends Control

## Test controls panel for debugging battle system.

@onready var _start_battle_button: Button = $VBox/StartBattleButton
@onready var _end_turn_button: Button = $VBox/EndTurnButton
@onready var _draw_card_button: Button = $VBox/DrawCardButton
@onready var _damage_player_button: Button = $VBox/DealDamagePlayerButton
@onready var _damage_enemy_button: Button = $VBox/DealDamageEnemyButton
@onready var _add_energy_button: Button = $VBox/AddEnergyButton
@onready var _reset_battle_button: Button = $VBox/ResetBattleButton

var _battle_manager: Node = null

func _ready() -> void:
	_battle_manager = get_node_or_null("/root/BattleArena")
	
	_start_battle_button.pressed.connect(_on_start_battle)
	_end_turn_button.pressed.connect(_on_end_turn)
	_draw_card_button.pressed.connect(_on_draw_card)
	_damage_player_button.pressed.connect(_on_damage_player)
	_damage_enemy_button.pressed.connect(_on_damage_enemy)
	_add_energy_button.pressed.connect(_on_add_energy)
	_reset_battle_button.pressed.connect(_on_reset_battle)

func _on_start_battle() -> void:
	var enemy_data = load("res://resources/enemies/lost_wanderer.tres")
	if enemy_data:
		EventBus.battle_started.emit(enemy_data)

func _on_end_turn() -> void:
	if _battle_manager and _battle_manager.has_method("end_turn"):
		_battle_manager.end_turn()

func _on_draw_card() -> void:
	# This would need to be implemented in battle_manager
	pass

func _on_damage_player() -> void:
	# For testing - directly damage player
	pass

func _on_damage_enemy() -> void:
	# For testing - directly damage enemy
	pass

func _on_add_energy() -> void:
	# For testing - add energy
	pass

func _on_reset_battle() -> void:
	# Reload battle scene
	get_tree().reload_current_scene()

func _exit_tree() -> void:
	if _start_battle_button and _start_battle_button.pressed.is_connected(_on_start_battle):
		_start_battle_button.pressed.disconnect(_on_start_battle)
	if _end_turn_button and _end_turn_button.pressed.is_connected(_on_end_turn):
		_end_turn_button.pressed.disconnect(_on_end_turn)
	if _draw_card_button and _draw_card_button.pressed.is_connected(_on_draw_card):
		_draw_card_button.pressed.disconnect(_on_draw_card)
	if _damage_player_button and _damage_player_button.pressed.is_connected(_on_damage_player):
		_damage_player_button.pressed.disconnect(_on_damage_player)
	if _damage_enemy_button and _damage_enemy_button.pressed.is_connected(_on_damage_enemy):
		_damage_enemy_button.pressed.disconnect(_on_damage_enemy)
	if _add_energy_button and _add_energy_button.pressed.is_connected(_on_add_energy):
		_add_energy_button.pressed.disconnect(_on_add_energy)
	if _reset_battle_button and _reset_battle_button.pressed.is_connected(_on_reset_battle):
		_reset_battle_button.pressed.disconnect(_on_reset_battle)
