extends Panel
class_name InventorySlot

signal slot_selected(slot_index: int)

@export var slot_index: int
var item: ItemInstance = null

func set_item(new_item: ItemInstance):
	item = new_item
	queue_redraw()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		emit_signal("slot_selected", slot_index)

func _draw():
	if item == null:
		return

	if item.data.icon:
		draw_texture(item.data.icon, Vector2.ZERO)
