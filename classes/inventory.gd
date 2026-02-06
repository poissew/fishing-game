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

func has_space_for(item: ItemInstance) -> bool:
	# ne modifie rien, juste teste
	var footprint := item.get_footprint()
	for y in range(height - footprint.y + 1):
		for x in range(width - footprint.x + 1):
			if can_place(item, Vector2i(x, y)):
				return true

	# Si rotatable, on teste aussi la rotation (sans modifier l'item définitivement)
	if item.data.rotatable:
		var old_rot := item.rotated
		item.rotated = !old_rot
		footprint = item.get_footprint()

		for y in range(height - footprint.y + 1):
			for x in range(width - footprint.x + 1):
				if can_place(item, Vector2i(x, y)):
					item.rotated = old_rot
					return true

		item.rotated = old_rot

	return false


func try_place_anywhere(item: ItemInstance, allow_rotate: bool = true) -> bool:
	# essaie sans rotation
	var footprint := item.get_footprint()
	for y in range(height - footprint.y + 1):
		for x in range(width - footprint.x + 1):
			if place_item(item, Vector2i(x, y)):
				return true

	# essaie avec rotation
	if allow_rotate and item.data.rotatable:
		item.rotated = !item.rotated
		footprint = item.get_footprint()

		for y in range(height - footprint.y + 1):
			for x in range(width - footprint.x + 1):
				if place_item(item, Vector2i(x, y)):
					return true

		# rollback si échec
		item.rotated = !item.rotated

	return false


func add_or_place(item: ItemInstance) -> bool:
	# API simple pour le gameplay
	return try_place_anywhere(item, true)
