class_name BattleState
extends RefCounted

## Runtime battle state: life totals, energy, lanes, hands.

const MAX_TOTAL_ENERGY: int = 10
const LANE_COUNT: int = 3

const COLOR_RED: int = 0
const COLOR_BLUE: int = 1
const COLOR_GREEN: int = 2

var player_life: int = 20
var player_max_life: int = 20
var player_energy_red: int = 1
var player_energy_blue: int = 1
var player_energy_green: int = 1
var player_max_energy_red: int = 1
var player_max_energy_blue: int = 1
var player_max_energy_green: int = 1
var player_hand: Array[CardInstance] = []
var player_lanes: Array[CardInstance] = [null, null, null]  # 3 lanes
var player_backrow: Array[CardInstance] = []

var enemy_life: int = 10
var enemy_max_life: int = 10
var enemy_energy_red: int = 1
var enemy_energy_blue: int = 1
var enemy_energy_green: int = 1
var enemy_max_energy_red: int = 1
var enemy_max_energy_blue: int = 1
var enemy_max_energy_green: int = 1
var enemy_hand: Array[CardInstance] = []
var enemy_lanes: Array[CardInstance] = [null, null, null]  # 3 lanes
var enemy_backrow: Array[CardInstance] = []

# Avatar system - special units that can attack and be targeted
var player_avatar: CardInstance = null
var enemy_avatar: CardInstance = null
var player_avatar_attack: int = 0  # Cached from PlayerStats
var enemy_avatar_attack: int = 0  # Cached from EnemyData

var turn_number: int = 1
var is_player_turn: bool = true
var momentum: int = 0  # Builds when dealing direct damage

func initialize_player(max_life: int, starting_energy: int) -> void:
	player_max_life = max_life
	player_life = max_life
	_set_player_starting_energy(starting_energy)
	_emit_energy_signals(true)

func initialize_enemy(max_life: int, starting_energy: int) -> void:
	enemy_max_life = max_life
	enemy_life = max_life
	_set_enemy_starting_energy(starting_energy)
	_emit_energy_signals(false)

func initialize_player_avatar(attack: int, avatar_card_data: CardData) -> void:
	player_avatar_attack = attack
	if avatar_card_data:
		player_avatar = CardInstance.new(avatar_card_data)
		player_avatar.current_attack = attack
		player_avatar.has_summoning_sickness = false  # Avatars can attack immediately

func initialize_enemy_avatar(attack: int, avatar_card_data: CardData) -> void:
	enemy_avatar_attack = attack
	if avatar_card_data:
		enemy_avatar = CardInstance.new(avatar_card_data)
		enemy_avatar.current_attack = attack
		enemy_avatar.has_summoning_sickness = false  # Avatars can attack immediately

func start_player_turn() -> void:
	is_player_turn = true
	# Reset card states
	for card in player_lanes:
		if card:
			card.reset_turn_state()
	for card in player_backrow:
		if card:
			card.reset_turn_state()
	# Reset avatar state
	if player_avatar:
		player_avatar.reset_turn_state()

func start_enemy_turn() -> void:
	is_player_turn = false
	# Reset card states
	for card in enemy_lanes:
		if card:
			card.reset_turn_state()
	for card in enemy_backrow:
		if card:
			card.reset_turn_state()
	# Reset avatar state
	if enemy_avatar:
		enemy_avatar.reset_turn_state()

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
	return spend_player_generic(amount)

func spend_enemy_energy(amount: int) -> bool:
	return spend_enemy_generic(amount)

func place_card_in_lane(card: CardInstance, lane: int, is_player: bool) -> bool:
	if lane < 0 or lane >= LANE_COUNT:
		return false
	var lanes: Array[CardInstance] = enemy_lanes if not is_player else player_lanes
	if lanes[lane] != null:
		return false  # Lane occupied
	lanes[lane] = card
	return true

func remove_card_from_lane(lane: int, is_player: bool) -> CardInstance:
	if lane < 0 or lane >= LANE_COUNT:
		return null
	var lanes: Array[CardInstance] = enemy_lanes if not is_player else player_lanes
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

func apply_player_energy_pick(color: int) -> void:
	_increase_player_max_color(color)
	_refill_player_energy()
	_emit_energy_signals(true)

func apply_enemy_energy_pick(color: int) -> void:
	_increase_enemy_max_color(color)
	_refill_enemy_energy()
	_emit_energy_signals(false)

func get_player_energy_total() -> int:
	return player_energy_red + player_energy_blue + player_energy_green

func get_player_max_energy_total() -> int:
	return player_max_energy_red + player_max_energy_blue + player_max_energy_green

func get_enemy_energy_total() -> int:
	return enemy_energy_red + enemy_energy_blue + enemy_energy_green

func get_enemy_max_energy_total() -> int:
	return enemy_max_energy_red + enemy_max_energy_blue + enemy_max_energy_green

func can_afford_player_cost(card: CardData) -> bool:
	if not card:
		return false
	var req_r: int = card.get_red_pips()
	var req_b: int = card.get_blue_pips()
	var req_g: int = card.get_green_pips()
	if player_energy_red < req_r or player_energy_blue < req_b or player_energy_green < req_g:
		return false
	var remaining_total: int = (player_energy_red - req_r) + (player_energy_blue - req_b) + (player_energy_green - req_g)
	return remaining_total >= card.get_generic_cost()

func can_afford_enemy_cost(card: CardData) -> bool:
	if not card:
		return false
	var req_r: int = card.get_red_pips()
	var req_b: int = card.get_blue_pips()
	var req_g: int = card.get_green_pips()
	if enemy_energy_red < req_r or enemy_energy_blue < req_b or enemy_energy_green < req_g:
		return false
	var remaining_total: int = (enemy_energy_red - req_r) + (enemy_energy_blue - req_b) + (enemy_energy_green - req_g)
	return remaining_total >= card.get_generic_cost()

func spend_player_cost(card: CardData) -> bool:
	if not can_afford_player_cost(card):
		return false
	player_energy_red -= card.get_red_pips()
	player_energy_blue -= card.get_blue_pips()
	player_energy_green -= card.get_green_pips()
	_spend_player_generic(card.get_generic_cost())
	_emit_energy_signals(true)
	return true

func spend_enemy_cost(card: CardData) -> bool:
	if not can_afford_enemy_cost(card):
		return false
	enemy_energy_red -= card.get_red_pips()
	enemy_energy_blue -= card.get_blue_pips()
	enemy_energy_green -= card.get_green_pips()
	_spend_enemy_generic(card.get_generic_cost())
	_emit_energy_signals(false)
	return true

func spend_player_generic(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_player_energy_total() < amount:
		return false
	_spend_player_generic(amount)
	_emit_energy_signals(true)
	return true

func spend_enemy_generic(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_enemy_energy_total() < amount:
		return false
	_spend_enemy_generic(amount)
	_emit_energy_signals(false)
	return true

func _set_player_starting_energy(total: int) -> void:
	var dist: PackedInt32Array = _distribute_total_energy(total)
	player_max_energy_red = dist[COLOR_RED]
	player_max_energy_blue = dist[COLOR_BLUE]
	player_max_energy_green = dist[COLOR_GREEN]
	_refill_player_energy()

func _set_enemy_starting_energy(total: int) -> void:
	var dist: PackedInt32Array = _distribute_total_energy(total)
	enemy_max_energy_red = dist[COLOR_RED]
	enemy_max_energy_blue = dist[COLOR_BLUE]
	enemy_max_energy_green = dist[COLOR_GREEN]
	_refill_enemy_energy()

func _distribute_total_energy(total: int) -> PackedInt32Array:
	# Deterministic split across R/B/G (round-robin remainder).
	var safe_total: int = maxi(0, total)
	var base: int = int(floor(float(safe_total) / 3.0))
	var rem: int = safe_total % 3
	var dist: PackedInt32Array = PackedInt32Array([base, base, base])
	for i in range(rem):
		dist[i] += 1
	return dist

func _increase_player_max_color(color: int) -> void:
	if get_player_max_energy_total() >= MAX_TOTAL_ENERGY:
		return
	match color:
		COLOR_RED:
			player_max_energy_red += 1
		COLOR_BLUE:
			player_max_energy_blue += 1
		COLOR_GREEN:
			player_max_energy_green += 1
		_:
			player_max_energy_red += 1

func _increase_enemy_max_color(color: int) -> void:
	if get_enemy_max_energy_total() >= MAX_TOTAL_ENERGY:
		return
	match color:
		COLOR_RED:
			enemy_max_energy_red += 1
		COLOR_BLUE:
			enemy_max_energy_blue += 1
		COLOR_GREEN:
			enemy_max_energy_green += 1
		_:
			enemy_max_energy_red += 1

func _refill_player_energy() -> void:
	player_energy_red = player_max_energy_red
	player_energy_blue = player_max_energy_blue
	player_energy_green = player_max_energy_green

func _refill_enemy_energy() -> void:
	enemy_energy_red = enemy_max_energy_red
	enemy_energy_blue = enemy_max_energy_blue
	enemy_energy_green = enemy_max_energy_green

func _spend_player_generic(amount: int) -> void:
	# Generic spending uses a fixed deterministic priority: Red -> Blue -> Green.
	var remaining: int = maxi(0, amount)
	var spend_r: int = mini(player_energy_red, remaining)
	player_energy_red -= spend_r
	remaining -= spend_r
	if remaining <= 0:
		return
	var spend_b: int = mini(player_energy_blue, remaining)
	player_energy_blue -= spend_b
	remaining -= spend_b
	if remaining <= 0:
		return
	var spend_g: int = mini(player_energy_green, remaining)
	player_energy_green -= spend_g

func _spend_enemy_generic(amount: int) -> void:
	var remaining: int = maxi(0, amount)
	var spend_r: int = mini(enemy_energy_red, remaining)
	enemy_energy_red -= spend_r
	remaining -= spend_r
	if remaining <= 0:
		return
	var spend_b: int = mini(enemy_energy_blue, remaining)
	enemy_energy_blue -= spend_b
	remaining -= spend_b
	if remaining <= 0:
		return
	var spend_g: int = mini(enemy_energy_green, remaining)
	enemy_energy_green -= spend_g

func _emit_energy_signals(is_player: bool) -> void:
	if is_player:
		EventBus.energy_changed.emit(get_player_energy_total(), get_player_max_energy_total(), true)
		if EventBus.has_signal("energy_colors_changed"):
			EventBus.energy_colors_changed.emit(
				player_energy_red,
				player_energy_blue,
				player_energy_green,
				player_max_energy_red,
				player_max_energy_blue,
				player_max_energy_green,
				true
			)
	else:
		EventBus.energy_changed.emit(get_enemy_energy_total(), get_enemy_max_energy_total(), false)
		if EventBus.has_signal("energy_colors_changed"):
			EventBus.energy_colors_changed.emit(
				enemy_energy_red,
				enemy_energy_blue,
				enemy_energy_green,
				enemy_max_energy_red,
				enemy_max_energy_blue,
				enemy_max_energy_green,
				false
			)
