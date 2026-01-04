class_name ItemInstance
extends Resource

@export var data: Item
@export var position: Vector2i
@export var rotated: bool = false

func get_footprint() -> Vector2i:
	return data.size if not rotated else Vector2i(data.size.y, data.size.x)
