class_name FishData
extends Item

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	ULTRARARE,
	LEGENDARY,
	GOD
}

@export_category("Base Data")
@export var min_size: float
@export var max_size: float
@export var base_value: int
@export var rarity:Rarity

@export_category("Fighting Data")
## PHYS_DMG — physical damage, scales with the value of the individual catch.
@export var phys_dmg_per_value: float = 0.5
## +- random int applied on top of the value-scaled physical damage.
@export var phys_dmg_variance: int = 2
## MAGIC_DMG — magic damage used by fish abilities, rolled at random.
@export var magic_dmg_min: int = 1
@export var magic_dmg_max: int = 10
## HEALTH — scales with the fish's real size (min_size..max_size), not its inventory size.
@export var health_base: int = 10
@export var health_per_size: float = 8.0
## SPELLS — how many spells a fish can roll. The spell datatype is not implemented yet.
@export var max_spells: int = 3

@export_category("Advanced Shit")
@export var price_curve: Curve

## Physical damage scales with what the catch is worth, plus or minus a random int.
func roll_phys_dmg(value: int) -> int:
	var scaled := int(round(value * phys_dmg_per_value))
	var variance := randomizer.RNG.randi_range(-phys_dmg_variance, phys_dmg_variance)
	return maxi(1, scaled + variance)

## Magic damage is purely random, but rarer fish get a luck boost: they roll
## once per rarity tier and keep the best result.
func roll_magic_dmg() -> int:
	var rolls := rarity + 1
	var best := magic_dmg_min
	for _i in rolls:
		best = maxi(best, randomizer.RNG.randi_range(magic_dmg_min, magic_dmg_max))
	return best

## Health scales with the fish's real (world) size, not its inventory footprint.
func roll_health(real_size: float) -> int:
	return maxi(1, int(round(health_base + real_size * health_per_size)))

## Spells are purely random. The spell datatype is not implemented yet, so this
## only reserves the rolled number of slots.
## TODO: fill with actual Spell resources once the datatype exists.
func roll_spells() -> Array:
	var spells := []
	spells.resize(randomizer.RNG.randi_range(0, max_spells))
	return spells
