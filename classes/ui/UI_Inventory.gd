extends Control
class_name UIInventory

signal item_requested_equip(item: ItemInstance)

@onready var grid := $Grid
@onready var preview := $ItemPreview

var inventory: Inventory
var selected_slot := -1

func bind_inventory(inv: Inventory):
	inventory = inv
	_refresh()

func _refresh():
	for i in grid.get_child_count():
		var slot := grid.get_child(i) as InventorySlot
		slot.set_item(inventory.items[i])
		slot.slot_selected.connect(_on_slot_selected)

func _on_slot_selected(index: int):
	selected_slot = index
	var item := inventory.items[index]
	if item:
		preview.show_item(item)

func _input(event):
	if event.is_action_pressed("ui_accept") and selected_slot != -1:
		var item := inventory.items[selected_slot]
		if item:
			emit_signal("item_requested_equip", item)
