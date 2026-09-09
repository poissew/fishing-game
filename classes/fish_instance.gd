class_name FishInstance
extends ItemInstance

## What a fish sells for is its species' base_value pushed around by how good
## the individual catch is: rarity, length, build (weight for that length) and
## quality. Rarity is by far the biggest lever, then size.

## Sale multiplier per FishData.Rarity, COMMON → GOD.
const RARITY_MULTIPLIER := [1.0, 1.6, 2.6, 4.2, 7.0, 12.0]

## Multiplier for a fish at min_size and at max_size of its species.
const SIZE_MIN_FACTOR := 0.5
const SIZE_MAX_FACTOR := 2.5
## Size pays off faster than linearly, so a record catch feels like a jackpot.
const SIZE_EXPONENT := 1.5

## kg per unit of length for an average-built fish, and how far off that a
## given individual can be. A heavy fish for its length is worth more.
const WEIGHT_RATIO := 0.8
const WEIGHT_SPREAD := 0.25

## quality (1..5) maps to QUALITY_BASE + QUALITY_STEP * quality.
const QUALITY_BASE := 0.8
const QUALITY_STEP := 0.1

@export var size: float
@export var weight: float
@export var quality: int

func get_value() -> int:
	var fish_data := data as FishData
	if fish_data == null:
		return 0
	var value := float(fish_data.base_value) \
		* rarity_multiplier(fish_data.rarity) \
		* _size_factor(fish_data) \
		* _weight_factor() \
		* _quality_factor()
	return maxi(1, int(round(value)))

## How far along its species' size range this fish sits, 0 (runt) to 1 (record).
func get_size_ratio() -> float:
	var fish_data := data as FishData
	if fish_data == null or fish_data.max_size <= fish_data.min_size:
		return 1.0
	return clampf(inverse_lerp(fish_data.min_size, fish_data.max_size, size), 0.0, 1.0)

static func rarity_multiplier(rarity: int) -> float:
	return RARITY_MULTIPLIER[clampi(rarity, 0, RARITY_MULTIPLIER.size() - 1)]

## Species with a price_curve use it (sampled over the size ratio); the rest
## fall back to the default curve between SIZE_MIN_FACTOR and SIZE_MAX_FACTOR.
func _size_factor(fish_data: FishData) -> float:
	var ratio := get_size_ratio()
	if fish_data.price_curve != null:
		return maxf(0.0, fish_data.price_curve.sample(ratio))
	return lerpf(SIZE_MIN_FACTOR, SIZE_MAX_FACTOR, pow(ratio, SIZE_EXPONENT))

## A fish heavier than usual for its length is a fatter, better catch.
func _weight_factor() -> float:
	if size <= 0.0:
		return 1.0
	var build := (weight / size) / WEIGHT_RATIO  # 1.0 = average build
	return clampf(build, 1.0 - WEIGHT_SPREAD, 1.0 + WEIGHT_SPREAD)

func _quality_factor() -> float:
	return QUALITY_BASE + QUALITY_STEP * float(quality)

func create_fish_instance(fish_data: FishData) -> FishInstance:
	var fish := FishInstance.new()
	fish.data = fish_data
	fish.size = randomizer.RNG.randf_range(fish_data.min_size, fish_data.max_size)
	fish.weight = fish.size * WEIGHT_RATIO * randomizer.RNG.randf_range(
		1.0 - WEIGHT_SPREAD, 1.0 + WEIGHT_SPREAD)
	fish.quality = randomizer.RNG.randi_range(1, 5)
	return fish
