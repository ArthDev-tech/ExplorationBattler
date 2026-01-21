class_name Inventory
extends RefCounted

## Grid-based inventory management system (6x8 = 48 slots).

const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 8

var grid: Array[Array] = []  # 2D array: grid[row][col] = ItemInstance or null
var items: Array[ItemInstance] = []  # List of all items in inventory

func _init() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	grid.clear()
	for row in range(GRID_HEIGHT):
		var row_array: Array = []
		for col in range(GRID_WIDTH):
			row_array.append(null)
		grid.append(row_array)

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
	
	# Find first available space
	var found_pos: Vector2i = find_space(item)
	if found_pos.x >= 0:
		_place_item_at(item, found_pos)
		items.append(item)
		return true
	
	return false

func remove_item(item: ItemInstance) -> bool:
	if not item:
		return false
	
	var index: int = items.find(item)
	if index < 0:
		return false
	
	# Remove from grid
	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			if grid[row][col] == item:
				grid[row][col] = null
	
	items.remove_at(index)
	return true

func find_space(item: ItemInstance) -> Vector2i:
	if not item or not item.data:
		return Vector2i(-1, -1)
	
	var item_size: Vector2i = item.data.size
	
	# Try each position
	for row in range(GRID_HEIGHT - item_size.y + 1):
		for col in range(GRID_WIDTH - item_size.x + 1):
			if _can_place_at(item, Vector2i(col, row)):
				return Vector2i(col, row)
	
	return Vector2i(-1, -1)

func _can_place_at(item: ItemInstance, position: Vector2i) -> bool:
	if not item or not item.data:
		return false
	
	var item_size: Vector2i = item.data.size
	
	# Check bounds
	if position.x + item_size.x > GRID_WIDTH or position.y + item_size.y > GRID_HEIGHT:
		return false
	
	# Check if all cells are empty
	for row in range(item_size.y):
		for col in range(item_size.x):
			var check_row: int = position.y + row
			var check_col: int = position.x + col
			if grid[check_row][check_col] != null:
				return false
	
	return true

func _place_item_at(item: ItemInstance, position: Vector2i) -> void:
	var item_size: Vector2i = item.data.size
	
	for row in range(item_size.y):
		for col in range(item_size.x):
			grid[position.y + row][position.x + col] = item

func get_item_at(position: Vector2i) -> ItemInstance:
	if position.x < 0 or position.x >= GRID_WIDTH or position.y < 0 or position.y >= GRID_HEIGHT:
		return null
	return grid[position.y][position.x] as ItemInstance

func get_item_count() -> int:
	return items.size()

func is_full() -> bool:
	# Check if there's any empty space
	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			if grid[row][col] == null:
				return false
	return true
