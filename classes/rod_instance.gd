class_name RodInstance
extends ItemInstance

@export var durability: float

func is_broken() -> bool:
	return durability <= 0

func create_rod_instance(rod_data: RodData) -> RodInstance:
	var rod := RodInstance.new()
	rod.data = rod_data
	rod.durability = rod_data.durability_max
	return rod
