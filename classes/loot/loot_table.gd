# LootTable.gd
class_name LootTable
extends Resource

@export var entries:Array[LootEntry] = []
@export var id:String = ""

func pick_entry(rng: RandomNumberGenerator) -> LootEntry:
	if rng == null:
		push_error("LootTable.pick_entry: rng est null")
		return null

	var total:int = 0
	var valid:Array[LootEntry] = []

	for e in entries:
		if e == null:
			continue
		if e.item == null:
			continue
		if e.weight <= 0:
			continue

		valid.append(e)
		total += e.weight

	if total <= 0 or valid.is_empty():
		push_error("LootTable: aucune entrée valide (item != null && weight > 0)")
		return null
		
		
	var roll:int = rng.randi_range(1, total)
	var acc:int = 0

	for e in valid:
		acc += e.weight
		if roll <= acc:
			return e

	# Fallback réellement safe
	return valid[0]

func pick_item(rng: RandomNumberGenerator) -> Item:
	return pick_entry(rng).item
