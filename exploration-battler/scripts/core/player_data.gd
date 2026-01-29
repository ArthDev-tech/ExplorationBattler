class_name PlayerData
extends Resource

## =============================================================================
## PlayerData - Static Player Definition (Resource)
## =============================================================================
## Defines base player statistics and progression values.
## This is a Resource saved to player_data.tres and loaded by GameManager.
##
## Values here define the starting point and level-up scaling.
## Runtime state (current health, XP, etc.) is tracked in PlayerStats.
##
## HARDCODED: All default values below can be adjusted in the .tres file.
## =============================================================================

# -----------------------------------------------------------------------------
# IDENTITY
# -----------------------------------------------------------------------------

## Display name shown in UI.
@export var display_name: String = "Player"

# -----------------------------------------------------------------------------
# BASE STATS
# -----------------------------------------------------------------------------

## Starting/maximum life points.
## HARDCODED: Default 20 - adjust for game balance
@export var max_life: int = 20

## Base attack power (avatar damage in battle).
## HARDCODED: Default 5 - affects avatar combat
@export var base_attack: int = 5

## Base defense (damage reduction - not yet implemented).
## HARDCODED: Default 3 - reserved for future use
@export var base_defense: int = 3

## Base intelligence (displayed in inventory; equipment bonuses reserved for future use).
@export var base_intelligence: int = 5

## Base strength (displayed in inventory; equipment bonuses reserved for future use).
@export var base_strength: int = 5

## Base agility (displayed in inventory; equipment bonuses reserved for future use).
@export var base_agility: int = 5

## Starting currency/gold.
## HARDCODED: Default 0 - set higher for easier starts
@export var starting_gold: int = 0

## Starting energy total (distributed across colors).
## HARDCODED: Default 3 - affects early game card plays
@export var starting_energy: int = 3

# -----------------------------------------------------------------------------
# LEVEL PROGRESSION
# -----------------------------------------------------------------------------

## Attack gained per level.
## HARDCODED: Default 1 - affects combat scaling
@export var attack_per_level: int = 1

## Defense gained per level.
## HARDCODED: Default 1 - reserved for future use
@export var defense_per_level: int = 1

## Health gained per level.
## HARDCODED: Default 5 - affects survivability scaling
@export var health_per_level: int = 5

## Experience required for first level-up.
## HARDCODED: Default 100 - affects early game pacing
@export var base_exp_to_level: int = 100

## Experience requirement multiplier per level.
## HARDCODED: Default 1.5 - affects late game pacing
@export var exp_growth_multiplier: float = 1.5
