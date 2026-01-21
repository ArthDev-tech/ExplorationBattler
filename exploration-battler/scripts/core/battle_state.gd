class_name BattleState
extends RefCounted

## Runtime battle state: life totals, energy, lanes, hands.

var player_life: int = 20
var player_max_life: int = 20
var player_energy: int = 3
var player_max_energy: int = 3
var player_hand: Array[CardInstance] = []
var player_lanes: Array[CardInstance] = [null, null, null, null, null]  # 5 lanes
var player_backrow: Array[CardInstance] = []

var enemy_life: int = 10
var enemy_max_life: int = 10
var enemy_energy: int = 3
var enemy_max_energy: int = 3
var enemy_hand: Array[CardInstance] = []
var enemy_lanes: Array[CardInstance] = [null, null, null, null, null]  # 5 lanes
var enemy_backrow: Array[CardInstance] = []

var turn_number: int = 1
var is_player_turn: bool = true
var momentum: int = 0  # Builds when dealing direct damage

func initialize_player(max_life: int, starting_energy: int) -> void:
	player_max_life = max_life
	player_life = max_life
	player_max_energy = starting_energy
	player_energy = starting_energy

func initialize_enemy(max_life: int, starting_energy: int) -> void:
	enemy_max_life = max_life
	enemy_life = max_life
	enemy_max_energy = starting_energy
	enemy_energy = starting_energy

func start_player_turn() -> void:
	is_player_turn = true
	# Energy refills and increases
	player_max_energy = mini(10, player_max_energy + 1)
	player_energy = player_max_energy
	# Emit energy change signal
	EventBus.energy_changed.emit(player_energy, player_max_energy, true)
	# Reset card states
	for card in player_lanes:
		if card:
			card.reset_turn_state()
	for card in player_backrow:
		if card:
			card.reset_turn_state()

func start_enemy_turn() -> void:
	is_player_turn = false
	# Energy refills and increases
	enemy_max_energy = mini(10, enemy_max_energy + 1)
	enemy_energy = enemy_max_energy
	# Emit energy change signal
	EventBus.energy_changed.emit(enemy_energy, enemy_max_energy, false)
	# Reset card states
	for card in enemy_lanes:
		if card:
			card.reset_turn_state()
	for card in enemy_backrow:
		if card:
			card.reset_turn_state()

func end_turn() -> void:
	turn_number += 1
	is_player_turn = not is_player_turn

func deal_damage_to_player(amount: int) -> void:
	player_life = maxi(0, player_life - amount)
	EventBus.life_changed.emit(player_life, player_max_life, true)

func deal_damage_to_enemy(amount: int) -> void:
	enemy_life = maxi(0, enemy_life - amount)
	momentum += amount  # Direct damage builds momentum
	EventBus.life_changed.emit(enemy_life, enemy_max_life, false)

func spend_player_energy(amount: int) -> bool:
	if player_energy >= amount:
		player_energy -= amount
		EventBus.energy_changed.emit(player_energy, player_max_energy, true)
		return true
	return false

func spend_enemy_energy(amount: int) -> bool:
	if enemy_energy >= amount:
		enemy_energy -= amount
		EventBus.energy_changed.emit(enemy_energy, enemy_max_energy, false)
		return true
	return false

func place_card_in_lane(card: CardInstance, lane: int, is_player: bool) -> bool:
	if lane < 0 or lane >= 5:
		return false
	var lanes: Array = enemy_lanes if not is_player else player_lanes
	if lanes[lane] != null:
		return false  # Lane occupied
	lanes[lane] = card
	return true

func remove_card_from_lane(lane: int, is_player: bool) -> CardInstance:
	if lane < 0 or lane >= 5:
		return null
	var lanes: Array = enemy_lanes if not is_player else player_lanes
	var card: CardInstance = lanes[lane]
	lanes[lane] = null
	return card

func is_battle_over() -> bool:
	return player_life <= 0 or enemy_life <= 0

func get_winner() -> int:  # 0 = player, 1 = enemy, -1 = ongoing
	if player_life <= 0:
		return 1
	if enemy_life <= 0:
		return 0
	return -1
