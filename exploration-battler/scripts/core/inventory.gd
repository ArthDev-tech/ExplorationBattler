class_name Inventory
extends RefCounted

## =============================================================================
## Inventory - Grid-Based Item Storage
## =============================================================================
## Manages player's unequipped items in a grid-based inventory system.
## Items occupy cells based on their size (e.g., 2x3 for large weapons).
##
## Grid Layout:
## - GRID_WIDTH x GRID_HEIGHT cells (default 6x8 = 48 slots)
## - Items can span multiple cells based on ItemData.size
## - Items are stored in both a 2D grid (for position) and a flat list
##
## Usage:
##   if inventory.add_item(item_instance):
##       print("Item added!")
##   var item = inventory.get_item_at(Vector2i(3, 2))
## =============================================================================

# -----------------------------------------------------------------------------
# CONSTANTS
# -----------------------------------------------------------------------------

## HARDCODED: Grid dimensions - change requires UI updates in inventory_menu
const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 8

# -----------------------------------------------------------------------------
# STATE
# -----------------------------------------------------------------------------

## 2D grid array: grid[row][col] = ItemInstance or null.
## Multiple cells can reference the same ItemInstance for multi-cell items.
var grid: Array[Array] = []

## Flat list of all unique items in inventory.
## Use this for iteration; grid contains duplicate references for large items.
var items: Array[ItemInstance] = []

# -----------------------------------------------------------------------------
# INITIALIZATION
# -----------------------------------------------------------------------------

func _init() -> void:
	_initialize_grid()

## Creates empty grid structure.
func _initialize_grid() -> void:
	grid.clear()
	for row in range(GRID_HEIGHT):
		var row_array: Array = []
		for col in range(GRID_WIDTH):
			row_array.append(null)
		grid.append(row_array)

# -----------------------------------------------------------------------------
# ITEM MANAGEMENT
# -----------------------------------------------------------------------------

## Adds an item to the inventory.
## @param item: ItemInstance to add
## @param position: Specific grid position, or (-1,-1) for auto-placement
## @return: True if added successfully, false if no space or invalid
func add_item(item: ItemInstance, position: Vector2i = Vector2i(-1, -1)) -> bool:
	if not item or not item.data:
		return false
	
	# If position specified, try to place there
	if position.x >= 0 and position.y >= 0:
		if _can_place_at(item, position):
			_place_item_at(item, position)
			items.append(item)
			return true
		return false
	
	# Auto-placement: find first available space
	var found_pos: Vector2i = find_space(item)
	if found_pos.x >= 0:
		_place_item_at(item, found_pos)
		items.append(item)
		return true
	
	return false

## Removes an item from the inventory.
## @param item: ItemInstance to remove
## @return: True if found and removed, false otherwise
func remove_item(item: ItemInstance) -> bool:
	if not item:
		return false
	
	var index: int = items.find(item)
	if index < 0:
		return false
	
	# Clear all grid cells occupied by this item
	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			if grid[row][col] == item:
				grid[row][col] = null
	
	items.remove_at(index)
	return true

## Finds a position where the item can fit.
## @param item: ItemInstance to find space for
## @return: Grid position (col, row) or (-1,-1) if no space
func find_space(item: ItemInstance) -> Vector2i:
	if not item or not item.data:
		return Vector2i(-1, -1)
	
	var item_size: Vector2i = item.data.size
	
	# Scan grid left-to-right, top-to-bottom for first fit
	for row in range(GRID_HEIGHT - item_size.y + 1):
		for col in range(GRID_WIDTH - item_size.x + 1):
			if _can_place_at(item, Vector2i(col, row)):
				return Vector2i(col, row)
	
	return Vector2i(-1, -1)

# -----------------------------------------------------------------------------
# PRIVATE - PLACEMENT HELPERS
# -----------------------------------------------------------------------------

## Checks if an item can be placed at a specific position.
func _can_place_at(item: ItemInstance, position: Vector2i) -> bool:
	if not item or not item.data:
		return false
	
	var item_size: Vector2i = item.data.size
	
	# Check bounds
	if position.x + item_size.x > GRID_WIDTH or position.y + item_size.y > GRID_HEIGHT:
		return false
	
	# Check if all required cells are empty
	for row in range(item_size.y):
		for col in range(item_size.x):
			var check_row: int = position.y + row
			var check_col: int = position.x + col
			if grid[check_row][check_col] != null:
				return false
	
	return true

## Places an item at a specific position, filling all its cells.
func _place_item_at(item: ItemInstance, position: Vector2i) -> void:
	var item_size: Vector2i = item.data.size
	
	# Fill all cells the item occupies with a reference to the item
	for row in range(item_size.y):
		for col in range(item_size.x):
			grid[position.y + row][position.x + col] = item

# -----------------------------------------------------------------------------
# QUERIES
# -----------------------------------------------------------------------------

## Returns the item at a specific grid position.
## @param position: Grid position (col, row)
## @return: ItemInstance at position, or null if empty/invalid
func get_item_at(position: Vector2i) -> ItemInstance:
	if position.x < 0 or position.x >= GRID_WIDTH or position.y < 0 or position.y >= GRID_HEIGHT:
		return null
	return grid[position.y][position.x] as ItemInstance

## Returns the number of unique items in inventory.
func get_item_count() -> int:
	return items.size()

## Checks if inventory has no empty cells.
## Note: This checks for ANY empty cell, not if a specific item fits.
func is_full() -> bool:
	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			if grid[row][col] == null:
				return false
	return true
