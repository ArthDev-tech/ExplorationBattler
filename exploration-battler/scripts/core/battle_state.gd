class_name BattleState
extends RefCounted

## =============================================================================
## BattleState - Runtime Battle Data Container
## =============================================================================
## Holds all mutable state for an active battle: life totals, energy pools,
## lane contents, hands, and turn tracking. Created fresh for each battle.
##
## This class is the single source of truth for battle state. BattleManager
## orchestrates the battle flow; BattleState stores the data.
##
## Energy System:
## - Three colors: Red (COLOR_RED), Blue (COLOR_BLUE), Green (COLOR_GREEN)
## - Cards have colored pip costs that must be paid with matching energy
## - Generic costs can be paid with any color
## - Energy refills each turn; max energy increases via picks
##
## Lane System:
## - LANE_COUNT (3) lanes per side
## - Creatures occupy lanes and block attacks to the player
## - Backrow holds spells, traps, and relics
## =============================================================================

# -----------------------------------------------------------------------------
# CONSTANTS
# -----------------------------------------------------------------------------

## HARDCODED: Maximum combined energy across all colors.
const MAX_TOTAL_ENERGY: int = 10

## HARDCODED: Number of lanes per side. Change requires UI updates.
const LANE_COUNT: int = 3

## Energy color indices for array access.
const COLOR_RED: int = 0
const COLOR_BLUE: int = 1
const COLOR_GREEN: int = 2

# -----------------------------------------------------------------------------
# PLAYER STATE
# -----------------------------------------------------------------------------

## HARDCODED: Default player starting life (overridden by initialize_player).
var player_life: int = 20
var player_max_life: int = 20

## Current energy by color (spent when playing cards).
var player_energy_red: int = 1
var player_energy_blue: int = 1
var player_energy_green: int = 1

## Maximum energy by color (refilled each turn).
var player_max_energy_red: int = 1
var player_max_energy_blue: int = 1
var player_max_energy_green: int = 1

## Cards currently in player's hand.
var player_hand: Array[CardInstance] = []

## Creatures in player's lanes. Array size must equal LANE_COUNT.
## null = empty lane, CardInstance = creature in that lane.
var player_lanes: Array[CardInstance] = [null, null, null]

## Non-creature cards in player's backrow (spells, traps, relics).
## HARDCODED: Max 3 backrow slots (see is_backrow_full).
var player_backrow: Array[CardInstance] = []

# -----------------------------------------------------------------------------
# ENEMY STATE
# -----------------------------------------------------------------------------

## HARDCODED: Default enemy starting life (overridden by initialize_enemy).
var enemy_life: int = 10
var enemy_max_life: int = 10

## Current enemy energy by color.
var enemy_energy_red: int = 1
var enemy_energy_blue: int = 1
var enemy_energy_green: int = 1

## Maximum enemy energy by color.
var enemy_max_energy_red: int = 1
var enemy_max_energy_blue: int = 1
var enemy_max_energy_green: int = 1

## Cards in enemy's hand.
var enemy_hand: Array[CardInstance] = []

## Creatures in enemy's lanes.
var enemy_lanes: Array[CardInstance] = [null, null, null]

## Non-creature cards in enemy's backrow.
var enemy_backrow: Array[CardInstance] = []

# -----------------------------------------------------------------------------
# AVATAR SYSTEM
# -----------------------------------------------------------------------------

## Player/enemy avatars - special units that can attack and be targeted.
## Represents the player/enemy themselves as a targetable entity.
var player_avatar: CardInstance = null
var enemy_avatar: CardInstance = null

## Cached attack values for avatars (from PlayerStats/EnemyData).
var player_avatar_attack: int = 0
var enemy_avatar_attack: int = 0

# -----------------------------------------------------------------------------
# TURN TRACKING
# -----------------------------------------------------------------------------

## Current turn number (1-indexed).
var turn_number: int = 1

## True if it's currently the player's turn.
var is_player_turn: bool = true

## Momentum: Builds when dealing direct damage to enemy.
## Can be spent on powerful abilities (not yet implemented).
var momentum: int = 0

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

## Initializes player state at battle start.
## @param max_life: Maximum health (from equipment + base)
## @param current_life: Current health (persistent between battles)
## @param starting_energy: Total energy to distribute across colors
func initialize_player(max_life: int, current_life: int, starting_energy: int) -> void:
	player_max_life = max_life
	# Use current_life, but cap it at max_life in case max_life decreased
	player_life = mini(current_life, max_life)
	# Ensure health is never negative
	player_life = maxi(0, player_life)
	_set_player_starting_energy(starting_energy)
	_emit_energy_signals(true)
	# Emit life_changed signal to notify UI of initial health state
	EventBus.life_changed.emit(player_life, player_max_life, true)

## Initializes enemy state at battle start.
## @param max_life: Enemy's maximum health (from EnemyData)
## @param starting_energy: Total energy to distribute across colors
func initialize_enemy(max_life: int, starting_energy: int) -> void:
	enemy_max_life = max_life
	enemy_life = max_life  # Enemies always start at full health
	_set_enemy_starting_energy(starting_energy)
	_emit_energy_signals(false)

## Creates player avatar from stats and optional card data.
## @param attack: Avatar attack value (from PlayerStats)
## @param avatar_card_data: Optional CardData for avatar abilities
func initialize_player_avatar(attack: int, avatar_card_data: CardData) -> void:
	player_avatar_attack = attack
	if avatar_card_data:
		player_avatar = CardInstance.new(avatar_card_data)
		player_avatar.current_attack = attack
		player_avatar.has_summoning_sickness = false  # Avatars can attack immediately

## Creates enemy avatar from stats and optional card data.
func initialize_enemy_avatar(attack: int, avatar_card_data: CardData) -> void:
	enemy_avatar_attack = attack
	if avatar_card_data:
		enemy_avatar = CardInstance.new(avatar_card_data)
		enemy_avatar.current_attack = attack
		enemy_avatar.has_summoning_sickness = false  # Avatars can attack immediately

# -----------------------------------------------------------------------------
# TURN MANAGEMENT
# -----------------------------------------------------------------------------

## Called at start of player's turn. Resets creature states.
func start_player_turn() -> void:
	is_player_turn = true
	# Reset card states for all player creatures
	for card in player_lanes:
		if card:
			card.reset_turn_state()
	for card in player_backrow:
		if card:
			card.reset_turn_state()
	# Reset avatar state
	if player_avatar:
		player_avatar.reset_turn_state()

## Called at start of enemy's turn. Resets creature states.
func start_enemy_turn() -> void:
	is_player_turn = false
	# Reset card states for all enemy creatures
	for card in enemy_lanes:
		if card:
			card.reset_turn_state()
	for card in enemy_backrow:
		if card:
			card.reset_turn_state()
	# Reset avatar state
	if enemy_avatar:
		enemy_avatar.reset_turn_state()

## Advances turn counter and swaps active player.
func end_turn() -> void:
	turn_number += 1
	is_player_turn = not is_player_turn

# -----------------------------------------------------------------------------
# DAMAGE
# -----------------------------------------------------------------------------

## Deals damage directly to player (bypasses creatures).
func deal_damage_to_player(amount: int) -> void:
	player_life = maxi(0, player_life - amount)
	EventBus.life_changed.emit(player_life, player_max_life, true)

## Deals damage directly to enemy and builds momentum.
func deal_damage_to_enemy(amount: int) -> void:
	enemy_life = maxi(0, enemy_life - amount)
	momentum += amount  # Direct damage builds momentum
	EventBus.life_changed.emit(enemy_life, enemy_max_life, false)

# -----------------------------------------------------------------------------
# ENERGY SPENDING (Legacy API - use spend_player_cost for cards)
# -----------------------------------------------------------------------------

## Spends generic player energy. Prefer spend_player_cost for cards.
func spend_player_energy(amount: int) -> bool:
	return spend_player_generic(amount)

## Spends generic enemy energy. Prefer spend_enemy_cost for cards.
func spend_enemy_energy(amount: int) -> bool:
	return spend_enemy_generic(amount)

# -----------------------------------------------------------------------------
# LANE MANAGEMENT
# -----------------------------------------------------------------------------

## Places a creature in a lane.
## @param card: The CardInstance to place
## @param lane: Lane index (0 to LANE_COUNT-1)
## @param is_player: True for player's side
## @return: True if placed, false if lane occupied or invalid
func place_card_in_lane(card: CardInstance, lane: int, is_player: bool) -> bool:
	if lane < 0 or lane >= LANE_COUNT:
		return false
	var lanes: Array[CardInstance] = enemy_lanes if not is_player else player_lanes
	if lanes[lane] != null:
		return false  # Lane occupied
	lanes[lane] = card
	return true

## Removes and returns a creature from a lane.
func remove_card_from_lane(lane: int, is_player: bool) -> CardInstance:
	if lane < 0 or lane >= LANE_COUNT:
		return null
	var lanes: Array[CardInstance] = enemy_lanes if not is_player else player_lanes
	var card: CardInstance = lanes[lane]
	lanes[lane] = null
	return card

# -----------------------------------------------------------------------------
# BACKROW MANAGEMENT
# -----------------------------------------------------------------------------

## Adds a card to the backrow.
## @return: Slot index (0-2) or -1 if full
func add_to_backrow(card: CardInstance, is_player: bool) -> int:
	var backrow: Array[CardInstance] = player_backrow if is_player else enemy_backrow
	# HARDCODED: Max 3 backrow slots
	if backrow.size() >= 3:
		return -1
	backrow.append(card)
	return backrow.size() - 1

## Removes and returns the card at the specified backrow index.
func remove_from_backrow(index: int, is_player: bool) -> CardInstance:
	var backrow: Array[CardInstance] = player_backrow if is_player else enemy_backrow
	if index < 0 or index >= backrow.size():
		return null
	return backrow.pop_at(index)

## Gets the card at the specified backrow index without removing.
func get_backrow_card(index: int, is_player: bool) -> CardInstance:
	var backrow: Array[CardInstance] = player_backrow if is_player else enemy_backrow
	if index < 0 or index >= backrow.size():
		return null
	return backrow[index]

## Returns number of cards in the backrow.
func get_backrow_count(is_player: bool) -> int:
	var backrow: Array[CardInstance] = player_backrow if is_player else enemy_backrow
	return backrow.size()

## Checks if backrow is at max capacity.
func is_backrow_full(is_player: bool) -> bool:
	# HARDCODED: 3 backrow slots max
	return get_backrow_count(is_player) >= 3

# -----------------------------------------------------------------------------
# BATTLE RESOLUTION
# -----------------------------------------------------------------------------

## Returns true if battle has ended (either side at 0 life).
func is_battle_over() -> bool:
	return player_life <= 0 or enemy_life <= 0

## Returns winner: 0 = player, 1 = enemy, -1 = ongoing.
func get_winner() -> int:
	if player_life <= 0:
		return 1
	if enemy_life <= 0:
		return 0
	return -1

# -----------------------------------------------------------------------------
# ENERGY PICK SYSTEM (Turn start choice)
# -----------------------------------------------------------------------------

## Applies player's energy color choice, increasing that color's max.
func apply_player_energy_pick(color: int) -> void:
	_increase_player_max_color(color)
	_refill_player_energy()
	_emit_energy_signals(true)

## Applies enemy's energy color choice.
func apply_enemy_energy_pick(color: int) -> void:
	_increase_enemy_max_color(color)
	_refill_enemy_energy()
	_emit_energy_signals(false)

# -----------------------------------------------------------------------------
# ENERGY QUERIES
# -----------------------------------------------------------------------------

func get_player_energy_total() -> int:
	return player_energy_red + player_energy_blue + player_energy_green

func get_player_max_energy_total() -> int:
	return player_max_energy_red + player_max_energy_blue + player_max_energy_green

func get_enemy_energy_total() -> int:
	return enemy_energy_red + enemy_energy_blue + enemy_energy_green

func get_enemy_max_energy_total() -> int:
	return enemy_max_energy_red + enemy_max_energy_blue + enemy_max_energy_green

# -----------------------------------------------------------------------------
# COST CHECKING & SPENDING
# -----------------------------------------------------------------------------

## Checks if player can afford a card's cost.
func can_afford_player_cost(card: CardData) -> bool:
	if not card:
		return false
	var req_r: int = card.get_red_pips()
	var req_b: int = card.get_blue_pips()
	var req_g: int = card.get_green_pips()
	# First check colored requirements
	if player_energy_red < req_r or player_energy_blue < req_b or player_energy_green < req_g:
		return false
	# Then check if remaining energy covers generic cost
	var remaining_total: int = (player_energy_red - req_r) + (player_energy_blue - req_b) + (player_energy_green - req_g)
	return remaining_total >= card.get_generic_cost()

## Checks if enemy can afford a card's cost.
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

## Spends player energy to pay a card's cost.
## @return: True if cost was paid, false if couldn't afford
func spend_player_cost(card: CardData) -> bool:
	if not can_afford_player_cost(card):
		return false
	# Pay colored costs first
	player_energy_red -= card.get_red_pips()
	player_energy_blue -= card.get_blue_pips()
	player_energy_green -= card.get_green_pips()
	# Then pay generic from remaining
	_spend_player_generic(card.get_generic_cost())
	_emit_energy_signals(true)
	return true

## Spends enemy energy to pay a card's cost.
func spend_enemy_cost(card: CardData) -> bool:
	if not can_afford_enemy_cost(card):
		return false
	enemy_energy_red -= card.get_red_pips()
	enemy_energy_blue -= card.get_blue_pips()
	enemy_energy_green -= card.get_green_pips()
	_spend_enemy_generic(card.get_generic_cost())
	_emit_energy_signals(false)
	return true

## Spends generic player energy (any color, priority: R > B > G).
func spend_player_generic(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_player_energy_total() < amount:
		return false
	_spend_player_generic(amount)
	_emit_energy_signals(true)
	return true

## Spends generic enemy energy.
func spend_enemy_generic(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_enemy_energy_total() < amount:
		return false
	_spend_enemy_generic(amount)
	_emit_energy_signals(false)
	return true

# -----------------------------------------------------------------------------
# PRIVATE - ENERGY INITIALIZATION
# -----------------------------------------------------------------------------

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

## Distributes total energy evenly across colors (round-robin remainder).
func _distribute_total_energy(total: int) -> PackedInt32Array:
	var safe_total: int = maxi(0, total)
	var base: int = int(floor(float(safe_total) / 3.0))
	var rem: int = safe_total % 3
	var dist: PackedInt32Array = PackedInt32Array([base, base, base])
	# Distribute remainder: first to red, then blue, then green
	for i in range(rem):
		dist[i] += 1
	return dist

# -----------------------------------------------------------------------------
# PRIVATE - ENERGY MAX INCREASE
# -----------------------------------------------------------------------------

func _increase_player_max_color(color: int) -> void:
	if get_player_max_energy_total() >= MAX_TOTAL_ENERGY:
		return  # Cap reached
	match color:
		COLOR_RED:
			player_max_energy_red += 1
		COLOR_BLUE:
			player_max_energy_blue += 1
		COLOR_GREEN:
			player_max_energy_green += 1
		_:
			# HARDCODED: Default to red if invalid color
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

# -----------------------------------------------------------------------------
# PRIVATE - ENERGY REFILL
# -----------------------------------------------------------------------------

func _refill_player_energy() -> void:
	player_energy_red = player_max_energy_red
	player_energy_blue = player_max_energy_blue
	player_energy_green = player_max_energy_green

func _refill_enemy_energy() -> void:
	enemy_energy_red = enemy_max_energy_red
	enemy_energy_blue = enemy_max_energy_blue
	enemy_energy_green = enemy_max_energy_green

# -----------------------------------------------------------------------------
# PRIVATE - GENERIC ENERGY SPENDING
# -----------------------------------------------------------------------------

## Spends generic energy using fixed priority: Red -> Blue -> Green.
## This is deterministic to avoid player confusion.
func _spend_player_generic(amount: int) -> void:
	var remaining: int = maxi(0, amount)
	# Spend red first
	var spend_r: int = mini(player_energy_red, remaining)
	player_energy_red -= spend_r
	remaining -= spend_r
	if remaining <= 0:
		return
	# Then blue
	var spend_b: int = mini(player_energy_blue, remaining)
	player_energy_blue -= spend_b
	remaining -= spend_b
	if remaining <= 0:
		return
	# Then green
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

# -----------------------------------------------------------------------------
# PRIVATE - SIGNAL EMISSION
# -----------------------------------------------------------------------------

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
