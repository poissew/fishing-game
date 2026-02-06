class_name FishInstance
extends ItemInstance

@export var size: float
@export var weight: float
@export var quality: int

func get_value() -> int:
	var fish_data:Item = data as FishData
	return int(fish_data.base_value * (size / fish_data.max_size))

func create_fish_instance(fish_data: FishData) -> FishInstance:
	var fish := FishInstance.new()
	fish.data = fish_data
	fish.size = randomizer.RNG.randf_range(fish_data.min_size, fish_data.max_size)
	fish.weight = fish.size * 0.8
	fish.quality = randomizer.RNG.randi_range(1, 5)
	return fish
