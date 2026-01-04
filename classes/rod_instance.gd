class_name RodInstance
extends ItemInstance

@export var durability: float

func is_broken() -> bool:
	return durability <= 0
