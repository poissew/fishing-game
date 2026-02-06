# TablesDB.gd (attaché à TablesDB.tscn et autoloadé)
extends Node
class_name TablesDB

@export var tables:Array[LootTable] = []
var by_id:Dictionary = {}

func _ready() -> void:
	for t in tables:
		assert(t != null)
		assert(t.id != "")
		by_id[t.id] = t

func get_table(id: String) -> LootTable:
	return by_id.get(id)
