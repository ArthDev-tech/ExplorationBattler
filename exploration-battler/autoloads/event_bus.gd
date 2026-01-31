extends Node

## =============================================================================
## EventBus - Central Signal Hub (Autoload Singleton)
## =============================================================================
## Provides decoupled communication across all game systems using signals.
## All major game events emit through EventBus to avoid tight coupling between
## systems. Components connect to relevant signals without needing direct
## references to the emitting systems.
##
## Usage Pattern:
##   Emitting: EventBus.signal_name.emit(args)
##   Listening: EventBus.signal_name.connect(_handler)
##   Cleanup: EventBus.signal_name.disconnect(_handler) in _exit_tree()
##
## Access via: EventBus (autoload name in Project Settings)
## =============================================================================

# -----------------------------------------------------------------------------
# BATTLE SIGNALS
# -----------------------------------------------------------------------------

## Emitted when a battle begins.
## @param enemy_data: EnemyData resource for the encountered enemy
signal battle_started(enemy_data: Resource)

## Emitted when a battle concludes.
## @param result: 0 = player win, 1 = player loss
signal battle_ended(result: int)

## Emitted at the start of each turn.
## @param turn: Turn number (1-indexed)
## @param is_player: true if it's the player's turn
signal turn_started(turn: int, is_player: bool)

## Emitted at the end of each turn.
## @param turn: Turn number
## @param is_player: true if it was the player's turn
signal turn_ended(turn: int, is_player: bool)

## Emitted when a card is played to a lane or backrow.
## @param card_instance: The CardInstance that was played
## @param lane: Lane index (0-2), or -1 for backrow
## @param is_player: true if played by player
signal card_played(card_instance: RefCounted, lane: int, is_player: bool)

## Emitted when a card is drawn from deck to hand.
## @param card_instance: The CardInstance drawn
## @param is_player: true if drawn by player
signal card_drawn(card_instance: RefCounted, is_player: bool)

## Emitted after combat phase resolves.
## @param results: Array of combat result data
signal combat_resolved(results: Array)

## Emitted when energy amount changes (deprecated - use energy_colors_changed).
## @param current: Current energy total
## @param max_energy: Maximum energy capacity
## @param is_player: true for player energy
signal energy_changed(current: int, max_energy: int, is_player: bool)

## Emitted when colored energy amounts change.
## @param current_r/b/g: Current red/blue/green energy
## @param max_r/b/g: Maximum red/blue/green energy
## @param is_player: true for player energy
signal energy_colors_changed(current_r: int, current_b: int, current_g: int, max_r: int, max_b: int, max_g: int, is_player: bool)

## Emitted when life/health changes during battle.
## @param current: Current life
## @param max_life: Maximum life
## @param is_player: true for player life
signal life_changed(current: int, max_life: int, is_player: bool)

# -----------------------------------------------------------------------------
# EXPLORATION SIGNALS
# -----------------------------------------------------------------------------

## Emitted when player triggers an enemy encounter.
## @param enemy_data: EnemyData resource for the enemy
signal encounter_triggered(enemy_data: Resource)

## Emitted when player position changes (for position-based systems).
## @param position: New world position
signal player_moved(position: Vector3)

## Emitted when a puzzle is completed.
## @param puzzle_id: Unique identifier for the puzzle
signal puzzle_solved(puzzle_id: StringName)

## Emitted when a door opens.
## @param door_id: Unique identifier for the door
signal door_opened(door_id: StringName)

## Emitted when player picks up an item.
## @param item_id: The item's name/identifier
signal item_collected(item_id: StringName)

## Emitted when dash ability cooldown changes.
## @param cooldown: Current cooldown remaining
## @param max_cooldown: Total cooldown duration
signal dash_cooldown_changed(cooldown: float, max_cooldown: float)

## Emitted when available jump count changes (double jump, etc.).
## @param current: Jumps remaining
## @param max: Maximum jumps allowed
signal jump_count_changed(current: int, max: int)

## Emitted when an interactable prompt should be shown (e.g. "Press E to climb").
## @param prompt_text: Text to display
signal interact_prompt_shown(prompt_text: String)

## Emitted when the interact prompt should be hidden.
signal interact_prompt_hidden()

## Emitted when an NPC (or anything) wants to open dialogue.
## @param dialogue_tree: DialogueTreeData or Resource with entry_id and nodes
signal dialogue_requested(dialogue_tree: Resource)

## Emitted when the player closes or finishes a dialogue tree.
signal dialogue_ended()

## Emitted when dialogue (or anything) wants to open the card shop.
## @param shop_inventory: ShopInventoryData or Resource with cards array
signal shop_requested(shop_inventory: Resource)

# -----------------------------------------------------------------------------
# UI SIGNALS
# -----------------------------------------------------------------------------

## Emitted when player health changes (exploration/persistent health).
## @param current: Current health
## @param maximum: Maximum health
signal player_health_changed(current: int, maximum: int)

## Emitted when hand contents change.
## @param cards: Array of CardInstance in hand
## @param is_player: true for player hand
signal hand_updated(cards: Array, is_player: bool)

## Emitted when deck size changes.
## @param deck_size: Cards remaining in deck
## @param is_player: true for player deck
signal deck_updated(deck_size: int, is_player: bool)

## Emitted when a card is selected for play/targeting.
## @param card_instance: The selected CardInstance
signal card_selected(card_instance: RefCounted)

## Emitted when card selection is cancelled.
signal card_deselected()

# -----------------------------------------------------------------------------
# TARGETING SIGNALS
# -----------------------------------------------------------------------------

## Emitted when entering targeting mode for a spell.
## @param card: The spell CardInstance requiring a target
signal targeting_started(card: CardInstance)

## Emitted when targeting is cancelled without selecting.
signal targeting_cancelled()

## Emitted when a valid target is selected.
## @param target: The targeted CardInstance
## @param lane: Lane index of the target
## @param is_player: true if targeting player's side
signal target_selected(target: CardInstance, lane: int, is_player: bool)

# -----------------------------------------------------------------------------
# ENERGY PICK SIGNALS
# -----------------------------------------------------------------------------

## Emitted when player needs to choose an energy color (wild energy).
## @param is_player: true for player (always true for now)
signal energy_color_pick_requested(is_player: bool)

## Emitted when an energy color is chosen.
## @param color: EnergyColor enum value
## @param is_player: true for player
signal energy_color_picked(color: int, is_player: bool)

# -----------------------------------------------------------------------------
# CARD DRAW SIGNALS
# -----------------------------------------------------------------------------

## Emitted to request drawing cards (for draw effects).
## @param count: Number of cards to draw
## @param is_player: true for player
signal draw_cards_requested(count: int, is_player: bool)

# -----------------------------------------------------------------------------
# CARD STATE SIGNALS
# -----------------------------------------------------------------------------

## Emitted when a card's stats change (buffs, damage, etc.).
## @param card: The affected CardInstance
signal card_stats_changed(card: CardInstance)

## Emitted when a creature dies.
## @param card: The dying CardInstance
## @param lane: Lane the creature was in
## @param is_player: true if player's creature
signal card_died(card: CardInstance, lane: int, is_player: bool)

# -----------------------------------------------------------------------------
# AVATAR SIGNALS
# -----------------------------------------------------------------------------

## Emitted when player/enemy avatar is clicked (for targeting).
## @param is_player: true if player avatar was clicked
signal avatar_clicked(is_player: bool)

## Emitted when an avatar takes direct damage.
## @param attacker_is_player: true if attacker is player
## @param target_is_player: true if target is player
## @param damage: Amount of damage dealt
signal avatar_attacked(attacker_is_player: bool, target_is_player: bool, damage: int)

## Emitted when avatar attack stat changes.
## @param is_player: true for player avatar
## @param attack: New attack value
signal avatar_stats_changed(is_player: bool, attack: int)

# -----------------------------------------------------------------------------
# GAME STATE SIGNALS
# -----------------------------------------------------------------------------

## Emitted to request a scene transition.
## @param scene_path: Resource path to target scene
signal scene_transition_requested(scene_path: String)

## Emitted when game is paused.
signal game_paused

## Emitted when game is resumed from pause.
signal game_resumed

## Emitted to request saving the game.
signal save_requested

## Emitted to request loading a save.
## @param save_slot: Save slot index to load
signal load_requested(save_slot: int)

# -----------------------------------------------------------------------------
# INVENTORY SIGNALS
# -----------------------------------------------------------------------------

## Emitted when inventory menu opens.
signal inventory_opened

## Emitted when inventory menu closes.
signal inventory_closed

## Emitted when an item is equipped.
## @param item: The equipped ItemInstance
## @param slot_type: ItemData.ItemType enum value
signal item_equipped(item: ItemInstance, slot_type: int)

## Emitted when an item is unequipped.
## @param item: The unequipped ItemInstance
## @param slot_type: ItemData.ItemType enum value
signal item_unequipped(item: ItemInstance, slot_type: int)

## Emitted when player stats change (equipment, buffs, etc.).
signal stats_changed

# -----------------------------------------------------------------------------
# CURRENCY SIGNALS
# -----------------------------------------------------------------------------

## Emitted when currency total changes.
## @param current: New currency amount
signal currency_changed(current: int)

## Emitted when currency is gained (for popup display).
## @param amount: Amount gained
signal currency_gained(amount: int)
