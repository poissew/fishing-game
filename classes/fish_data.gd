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
	preload("res://data/spells/wildfire.tres"),
	preload("res://data/spells/immunity.tres"),
	preload("res://data/spells/snipe.tres"),
	preload("res://data/spells/decoy.tres"),
	preload("res://data/spells/fishnet.tres"),
	preload("res://data/spells/fish_lazer.tres"),
	preload("res://data/spells/lightning.tres"),
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
## PHYS_DMG — contact damage. A fish is worth `phys_base` plus `phys_per_size`
## for every unit of SIZE_CURVE, so a shark hits harder than a sardine without
## hitting five times harder.
@export var phys_base: float = 3.0
@export var phys_per_size: float = 0.8
## +- random int applied on top, which is all that tells two fish of the same
## species and size apart in a fight.
@export var phys_dmg_variance: int = 1
## MAGIC_DMG — magic damage used by fish abilities, rolled at random.
@export var magic_dmg_min: int = 1
@export var magic_dmg_max: int = 10
## HEALTH — the same curve again: a base every fish gets, plus a share for how
## big this one actually is.
@export var health_base: int = 100
@export var health_per_size: float = 20.0
## SPELLS — how many spells a fish can roll, out of SPELL_POOL.
@export var max_spells: int = 3

@export_category("Advanced Shit")
@export var price_curve: Curve

## How much of a fish its real length is worth in a fight. The square root,
## which is the curve BattleFish.world_length() already draws a fish on: a
## shark is 12 times a sardine end to end and looks about three times the fish,
## and this is what makes it fight like three times the fish rather than twelve.
##
## Straight length would put a record shark 40 points of health and 10 points of
## damage clear of everything else in the game, which is where this started -
## measured, a shark won 10 rounds out of 10 and killed anything it touched in a
## single hit.
static func size_curve(real_size: float) -> float:
	return sqrt(maxf(real_size, 0.0))

## Physical damage is what the fish is, not what it sells for: its size on the
## curve above, plus or minus a random int.
##
## It used to scale off get_value(), which meant rarity and quality and the
## price curve all landed on top of each other in one number - a legendary
## shark hit for 44 and a sardine for 2. Value decides what a catch is worth at
## the shop; size decides what it is worth in the arena.
func roll_phys_dmg(real_size: float) -> int:
	var scaled := phys_base + phys_per_size * size_curve(real_size)
	var variance := randomizer.RNG.randi_range(-phys_dmg_variance, phys_dmg_variance)
	return maxi(1, int(round(scaled)) + variance)

## Magic damage is purely random, but rarer fish get a luck boost: they roll
## once per rarity tier and keep the best result.
func roll_magic_dmg() -> int:
	var rolls := rarity + 1
	var best := magic_dmg_min
	for _i in rolls:
		best = maxi(best, randomizer.RNG.randi_range(magic_dmg_min, magic_dmg_max))
	return best

## Health scales with the fish's real (world) size, not its inventory
## footprint, on the same curve as its damage.
func roll_health(real_size: float) -> int:
	return maxi(1, int(round(health_base + health_per_size * size_curve(real_size))))

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
