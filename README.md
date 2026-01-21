[Readme.txt](https://github.com/user-attachments/files/24754538/Readme.txt)
# ExplorationBattler

A hybrid **3D exploration + 2D card battler** made in **Godot 4.x** (GDScript).

You explore a 3D level, encounter enemies, and transition into lane-based card battles. The project is under active development and many systems are still evolving.

## Tech
- Godot 4.x
- GDScript (strict typing)
- Resource-driven data (`.tres`) for cards/enemies
- Signals + autoloads for decoupled systems

## Project Structure (high level)
- `exploration-battler/scenes/`
  - `exploration/` – 3D exploration levels, player, enemies, exploration UI
  - `battle/` – battle arena, lanes, card UI
- `exploration-battler/scripts/`
  - `core/` – data/runtime classes (cards, enemies, inventory, etc.)
  - `battle/` – battle flow and resolution
  - `components/` – reusable components
- `exploration-battler/resources/` – card/enemy resources (`.tres`)
- `exploration-battler/autoloads/` – global singletons (EventBus, GameManager, SaveManager, etc.)

## How to Run
1. Install **Godot 4.x**.
2. Open the project folder in Godot (the `project.godot` file is in `exploration-battler/`).
3. Press Play.

## Controls (current)
- Movement: WASD
- Inventory: `I` (if bound in Input Map)
- Other controls may change during development.

## Notes
- `.godot/` is editor cache and should not be committed.
- This repo is a work-in-progress prototype; expect rough edges and frequent changes.

## License
TBD
