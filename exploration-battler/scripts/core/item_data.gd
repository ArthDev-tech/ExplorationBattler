class_name ItemData
extends Resource

## Resource defining item properties: name, stats, type, etc.

enum ItemType {
	WEAPON,
	ARMOR,
	ACCESSORY
}

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null
@export var item_type: ItemType = ItemType.WEAPON
@export var size: Vector2i = Vector2i(1, 1)  # Inventory grid size (width x height)
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var health_bonus: int = 0
