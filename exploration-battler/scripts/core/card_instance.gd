class_name CardInstance
extends RefCounted

## =============================================================================
## CardInstance - Runtime Card State
## =============================================================================
## Represents a single card instance during gameplay with mutable state.
## Created from CardData when a card is drawn or summoned.
##
## Unlike CardData (shared resource), CardInstance tracks:
## - Current health/attack (may differ from base due to buffs/damage)
## - Status effects and temporary states
## - Per-card flags (has_attacked, summoning_sickness, etc.)
##
## Each card in hand/on field is a unique CardInstance, even if they share
## the same CardData (e.g., 3 copies of "Forest Whelp" = 3 CardInstances).
## =============================================================================

# -----------------------------------------------------------------------------
# STATE VARIABLES
# -----------------------------------------------------------------------------

## Reference to the base CardData resource (read-only stats, effects).
var data: CardData

## Current health - modified by damage/healing. Death occurs at 0.
var current_health: int

## Current attack - modified by buffs/debuffs.
var current_attack: int

## Active status effects. Each entry: {type: StringName, value: int}
## Example: [{type: &"Burn", value: 2}] = takes 2 burn damage per turn
var status_effects: Array[Dictionary] = []

## Phasing: Can't be targeted this turn. Set by Phasing keyword.
var is_phasing: bool = false

## Tracks if creature has attacked this turn (prevents multiple attacks).
var has_attacked_this_turn: bool = false

## Summoning sickness: Creatures can't attack the turn they're played.
## Cleared at start of owner's next turn. Haste keyword bypasses this.
var has_summoning_sickness: bool = true

## Shield: Negates the first damage taken, then removed.
var shield_active: bool = false

## Soulbound: Can only trigger its death effect once per battle.
var soulbound_used: bool = false

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

## Creates a new CardInstance from CardData.
## @param card_data: The base card definition
func _init(card_data: CardData) -> void:
	data = card_data
	current_health = data.health
	current_attack = data.attack
	# Haste keyword bypasses summoning sickness
	has_summoning_sickness = not data.has_keyword(&"Haste")

# -----------------------------------------------------------------------------
# DAMAGE & HEALING
# -----------------------------------------------------------------------------

## Deals damage to this creature.
## Shield absorbs first hit. Emits card_stats_changed signal.
## @param amount: Damage to deal (non-negative)
func take_damage(amount: int) -> void:
	# Shield absorbs first damage instance
	if shield_active:
		shield_active = false
		return
	
	current_health = maxi(0, current_health - amount)
	EventBus.card_stats_changed.emit(self)

## Heals this creature up to its base max health.
## @param amount: Health to restore (non-negative)
func heal(amount: int) -> void:
	# Cannot exceed base health from CardData
	current_health = mini(data.health, current_health + amount)
	EventBus.card_stats_changed.emit(self)

# -----------------------------------------------------------------------------
# STAT MODIFICATION
# -----------------------------------------------------------------------------

## Modifies attack stat (can go negative to 0 minimum).
## @param amount: Positive to buff, negative to debuff
func modify_attack(amount: int) -> void:
	current_attack = maxi(0, current_attack + amount)
	EventBus.card_stats_changed.emit(self)

## Modifies max health stat (minimum 1 to stay alive).
## @param amount: Positive to buff, negative to debuff
func modify_health(amount: int) -> void:
	# Minimum 1 health to prevent instant death from debuffs
	current_health = maxi(1, current_health + amount)
	EventBus.card_stats_changed.emit(self)

# -----------------------------------------------------------------------------
# STATE QUERIES
# -----------------------------------------------------------------------------

## Returns true if creature is alive (health > 0).
func is_alive() -> bool:
	return current_health > 0

## Checks if this card has a specific keyword (delegates to CardData).
func has_keyword(keyword: StringName) -> bool:
	return data.has_keyword(keyword)

## Returns true if this creature can attack this turn.
## Blocked by: summoning sickness, already attacked (unless Frenzy), death
func can_attack() -> bool:
	if has_summoning_sickness:
		return false
	# Frenzy keyword allows multiple attacks per turn
	if has_attacked_this_turn and not has_keyword(&"Frenzy"):
		return false
	return is_alive()

# -----------------------------------------------------------------------------
# TURN MANAGEMENT
# -----------------------------------------------------------------------------

## Resets per-turn state at the start of owner's turn.
## Called by BattleState.start_player_turn/start_enemy_turn.
func reset_turn_state() -> void:
	has_attacked_this_turn = false
	is_phasing = false
	var had_sickness: bool = has_summoning_sickness
	has_summoning_sickness = false  # Clear after first turn - creatures can attack
	# Only emit signal if state actually changed (optimization)
	if had_sickness:
		EventBus.card_stats_changed.emit(self)

## Applies keyword effects that trigger on summon.
## Called when creature enters the battlefield.
func apply_keyword_effects() -> void:
	# Shield keyword grants shield on entry
	if data.has_keyword(&"Shield"):
		shield_active = true
	# Phasing keyword grants phasing on entry
	if data.has_keyword(&"Phasing"):
		is_phasing = true
