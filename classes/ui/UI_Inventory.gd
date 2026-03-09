extends Control
class_name UIInventory

signal item_requested_equip(item: ItemInstance)

@onready var grid: GridContainer = $Grid
@onready var item_icon: TextureRect = $ItemPreview/Icon
@onready var item_name: Label = $ItemPreview/Name
@onready var item_stats: Label = $ItemPreview/Stats

const SLOT_SIZE := 16

var inventory: Inventory
var selected_item: ItemInstance = null

func bind_inventory(inv: Inventory) -> void:
	inventory = inv

func build_grid() -> void:
	for child in grid.get_children():
		child.free()
	grid.columns = inventory.width
	for y in range(inventory.height):
		for x in range(inventory.width):
			var slot := InventorySlot.new()
			slot.slot_index = y * inventory.width + x
			slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
			slot.slot_selected.connect(_on_slot_selected)
			grid.add_child(slot)

func refresh() -> void:
	if inventory == null or grid.get_child_count() == 0:
		return
	var occupied: Dictionary = {}
	for item in inventory.items:
		occupied[item.position] = item
	for i in range(grid.get_child_count()):
		var slot := grid.get_child(i) as InventorySlot
		var pos := Vector2i(i % inventory.width, i / inventory.width)
		slot.set_item(occupied.get(pos))

func open() -> void:
	build_grid()
	refresh()
	visible = true

func close() -> void:
	visible = false
	selected_item = null
	_show_preview(null)

func _on_slot_selected(index: int) -> void:
	var pos := Vector2i(index % inventory.width, index / inventory.width)
	var found: ItemInstance = null
	for item in inventory.items:
		var fp := item.get_footprint()
		if pos.x >= item.position.x and pos.x < item.position.x + fp.x \
		and pos.y >= item.position.y and pos.y < item.position.y + fp.y:
			found = item
			break
	selected_item = found
	_show_preview(found)

func _show_preview(item: ItemInstance) -> void:
	if item == null:
		item_icon.texture = null
		item_name.text = ""
		item_stats.text = ""
		return
	item_icon.texture = item.data.icon
	item_name.text = item.data.name
	if item is FishInstance:
		item_stats.text = "Size: %.2f\nWeight: %.2f\nQuality: %d\nValue: %d" % [
			item.size, item.weight, item.quality, item.get_value()
		]
	elif item is RodInstance:
		item_stats.text = "Durability: %.0f / %.0f" % [
			item.durability, item.data.durability_max
		]
	else:
		item_stats.text = ""

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") and selected_item != null:
		emit_signal("item_requested_equip", selected_item)
