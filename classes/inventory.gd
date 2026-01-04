class_name Inventory
extends Resource

@export var width: int
@export var height: int
@export var items: Array[ItemInstance] = []

func can_place(item: ItemInstance, pos: Vector2i) -> bool:
	var size := item.get_footprint()

	if pos.x < 0 or pos.y < 0:
		return false
	if pos.x + size.x > width or pos.y + size.y > height:
		return false

	for other in items:
		if other == item:
			continue
		if _overlaps(pos, size, other):
			return false

	return true

func _overlaps(pos: Vector2i, size: Vector2i, other: ItemInstance) -> bool:
	var o_pos := other.position
	var o_size := other.get_footprint()

	return not (
		pos.x + size.x <= o_pos.x or
		pos.x >= o_pos.x + o_size.x or
		pos.y + size.y <= o_pos.y or
		pos.y >= o_pos.y + o_size.y
	)

func place_item(item: ItemInstance, pos: Vector2i) -> bool:
	if not can_place(item, pos):
		return false

	item.position = pos
	if not items.has(item):
		items.append(item)

	return true

func rotate_item(item: ItemInstance) -> bool:
	if not item.data.rotatable:
		return false

	item.rotated = !item.rotated
	if not can_place(item, item.position):
		item.rotated = !item.rotated
		return false

	return true
