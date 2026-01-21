extends Node

## Central signal hub for decoupled communication across all game systems.
## All major game events emit through EventBus to avoid tight coupling.

# Battle Signals
signal battle_started(enemy_data: Resource)
signal battle_ended(result: int)  # 0 = player win, 1 = player loss
signal turn_started(turn: int, is_player: bool)
signal turn_ended(turn: int, is_player: bool)
signal card_played(card_instance: RefCounted, lane: int, is_player: bool)
signal card_drawn(card_instance: RefCounted, is_player: bool)
signal combat_resolved(results: Array)
signal energy_changed(current: int, max_energy: int, is_player: bool)
signal energy_colors_changed(current_r: int, current_b: int, current_g: int, max_r: int, max_b: int, max_g: int, is_player: bool)
signal life_changed(current: int, max_life: int, is_player: bool)

# Exploration Signals
signal encounter_triggered(enemy_data: Resource)
signal player_moved(position: Vector3)
signal puzzle_solved(puzzle_id: StringName)
signal door_opened(door_id: StringName)
signal item_collected(item_id: StringName)
signal dash_cooldown_changed(cooldown: float, max_cooldown: float)
signal jump_count_changed(current: int, max: int)

# UI Signals
signal player_health_changed(current: int, maximum: int)
signal hand_updated(cards: Array, is_player: bool)
signal deck_updated(deck_size: int, is_player: bool)
signal card_selected(card_instance: RefCounted)
signal card_deselected()

# Targeting Signals
signal targeting_started(card: CardInstance)
signal targeting_cancelled()
signal target_selected(target: CardInstance, lane: int, is_player: bool)

# Energy Pick Signals
signal energy_color_pick_requested(is_player: bool)
signal energy_color_picked(color: int, is_player: bool)

# Card Draw Signals
signal draw_cards_requested(count: int, is_player: bool)

# Card State Signals
signal card_stats_changed(card: CardInstance)
signal card_died(card: CardInstance, lane: int, is_player: bool)

# Avatar Signals
signal avatar_clicked(is_player: bool)
signal avatar_attacked(attacker_is_player: bool, target_is_player: bool, damage: int)
signal avatar_stats_changed(is_player: bool, attack: int)

# Game State Signals
signal scene_transition_requested(scene_path: String)
signal game_paused
signal game_resumed
signal save_requested
signal load_requested(save_slot: int)

# Inventory Signals
signal inventory_opened
signal inventory_closed
signal item_equipped(item: ItemInstance, slot_type: int)
signal item_unequipped(item: ItemInstance, slot_type: int)
signal stats_changed

# Currency Signals
signal currency_changed(current: int)
signal currency_gained(amount: int)
