class_name FishInstance
extends ItemInstance

@export var size: float
@export var weight: float
@export var quality: int

func get_value() -> int:
	var fish_data := data as FishData
	return int(fish_data.base_value * (size / fish_data.max_size))
