class_name FishData
extends Item

## Every spell a fish can turn up with. A stand-in for a spell registry: once
## there are more of them than fit in a const, this becomes a Spellsdb autoload
## keyed by id, the way Itemdb does it for items.
const SPELL_POOL := [
	preload("res://data/spells/explosion.tres"),
	preload("res://data/spells/bubble_blast.tres"),
	preload("res://data/spells/coward.tres"),
	preload("res://data/spells/trauma.tres"),
	preload("res://data/spells/ground_slam.tres"),
	preload("res://data/spells/paparazzi.tres"),
	preload("res://data/spells/boxer.tres"),
	preload("res://data/spells/sandbag.tres"),
]

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
## SPELLS — how many spells a fish can roll, out of SPELL_POOL.
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

## Spells are purely random: a fish rolls anywhere from none to max_spells of
## them, drawn without replacement so it never carries the same spell twice.
## A pool smaller than max_spells caps the count on its own.
func roll_spells() -> Array[SpellInstance]:
	var pool := SPELL_POOL.duplicate()
	var spells: Array[SpellInstance] = []
	var count := mini(randomizer.RNG.randi_range(0, max_spells), pool.size())
	for _i in count:
		var pick: SpellData = pool.pop_at(randomizer.RNG.randi_range(0, pool.size() - 1))
		spells.append(SpellInstance.create_spell_instance(pick))
	return spells
