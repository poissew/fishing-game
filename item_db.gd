extends Node
class_name ItemDB

@export var item_list: Array[Item] = []

var items := {}

func _ready() -> void:
	print("ItemDB READY")
	for item in item_list:
		items[item.id] = item

func get_item(id: int):
	return items.get(id)
