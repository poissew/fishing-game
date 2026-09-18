class_name FishInstance
extends ItemInstance

## Fired whenever current_health moves, with the new value and the pool it is
## measured against, so a health bar can bind to it without polling.
signal health_changed(current: int, maximum: int)
## Fired the moment current_health reaches 0.
signal died

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

@export_category("Fighting Data")
@export var phys_dmg: int
@export var magic_dmg: int
## The full health pool, rolled from the fish's real size. Damage taken during
## a fight comes off current_health, not this.
@export var health: int:
	set(value):
		health = maxi(0, value)
		# Shrinking the pool must not leave the fish above its own maximum.
		if current_health > health:
			current_health = health
## What this fish can cast, rolled once with the rest of its fighting data.
## The instances are per-fish: two fish carrying the same spell cool down
## independently, because the cooldown lives on the instance.
@export var spells: Array[SpellInstance] = []

## Health remaining right now, clamped to 0..health. Not exported: like
## SpellInstance.cooldown_left it is per-battle state, not worth saving.
var current_health: int = 0:
	set(value):
		var clamped := clampi(value, 0, health)
		if clamped == current_health:
			return
		current_health = clamped
		health_changed.emit(current_health, health)
		if current_health == 0:
			died.emit()

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
	fish.roll_fighting_data()
	return fish

## Rolls the fighting stats. Both damage and health come off the fish's real
## length, so this must run after size is set.
func roll_fighting_data() -> void:
	var fish_data := data as FishData
	if fish_data == null:
		return
	phys_dmg = fish_data.roll_phys_dmg(size)
	magic_dmg = fish_data.roll_magic_dmg()
	health = fish_data.roll_health(size)
	current_health = health
	spells = fish_data.roll_spells()

## Sends the fish into a fight at full health.
func reset_health() -> void:
	current_health = health

## Spells enter a fight ready to cast, the way health enters it full.
func reset_spells() -> void:
	for spell in spells:
		if spell != null:
			spell.reset()

## Counts every spell down. The battler owns the clock and calls this.
func tick_spells(delta: float) -> void:
	for spell in spells:
		if spell != null:
			spell.tick(delta)

## Every spell waiting on `trigger` that is off cooldown, in the order the fish
## carries them. All of them rather than the first: two spells that both go off
## on a touch are two separate spells with two separate cooldowns, and a fish
## carrying both should get both.
func ready_spells(trigger: SpellData.Trigger) -> Array[SpellInstance]:
	var ready: Array[SpellInstance] = []
	for spell in spells:
		if spell != null and spell.is_ready() and spell.data.trigger == trigger:
			ready.append(spell)
	return ready

func is_alive() -> bool:
	return current_health > 0

## 0.0 dead, 1.0 untouched. For health bars.
func health_ratio() -> float:
	if health <= 0:
		return 0.0
	return float(current_health) / float(health)

## Returns the damage actually taken, which is less than `amount` when the hit
## kills - useful for overkill numbers and battle logs.
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := current_health
	current_health -= amount
	return before - current_health

## Returns the health actually restored, capped by the missing amount.
func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := current_health
	current_health += amount
	return current_health - before
