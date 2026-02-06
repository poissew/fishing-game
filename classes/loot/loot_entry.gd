class_name LootEntry
extends Resource

@export var item:Item
@export var weight:int = 1
@export var min_amount:int = 1
@export var max_amount:int = 1

func roll_amount(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(min_amount, max_amount)
