class_name CardInstance
extends RefCounted

## Runtime card instance with mutable state. Created from CardData when drawn.

var data: CardData
var current_health: int
var current_attack: int
var status_effects: Array[Dictionary] = []  # Array of {type: StringName, value: int}
var is_phasing: bool = false  # Can't be targeted this turn
var has_attacked_this_turn: bool = false
var has_summoning_sickness: bool = true  # Can't attack unless Haste
var shield_active: bool = false  # Negates first damage
var soulbound_used: bool = false  # Soulbound can only trigger once per battle

func _init(card_data: CardData) -> void:
	data = card_data
	current_health = data.health
	current_attack = data.attack
	has_summoning_sickness = not data.has_keyword(&"Haste")

func take_damage(amount: int) -> void:
	if shield_active:
		shield_active = false
		return
	
	current_health = maxi(0, current_health - amount)
	EventBus.card_stats_changed.emit(self)

func heal(amount: int) -> void:
	current_health = mini(data.health, current_health + amount)
	EventBus.card_stats_changed.emit(self)

func modify_attack(amount: int) -> void:
	current_attack = maxi(0, current_attack + amount)
	EventBus.card_stats_changed.emit(self)

func modify_health(amount: int) -> void:
	current_health = maxi(1, current_health + amount)
	EventBus.card_stats_changed.emit(self)

func is_alive() -> bool:
	return current_health > 0

func has_keyword(keyword: StringName) -> bool:
	return data.has_keyword(keyword)

func can_attack() -> bool:
	if has_summoning_sickness:
		return false
	if has_attacked_this_turn and not has_keyword(&"Frenzy"):
		return false
	return is_alive()

func reset_turn_state() -> void:
	has_attacked_this_turn = false
	is_phasing = false
	var had_sickness: bool = has_summoning_sickness
	has_summoning_sickness = false  # Clear after first turn - creatures can attack
	if had_sickness:
		EventBus.card_stats_changed.emit(self)

func apply_keyword_effects() -> void:
	if data.has_keyword(&"Shield"):
		shield_active = true
	if data.has_keyword(&"Phasing"):
		is_phasing = true
