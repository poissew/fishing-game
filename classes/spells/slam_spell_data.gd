## A spell with no moment of its own: it waits for the fish to be standing over
## somebody. Any fish the carrier is allowed to hit that is underneath it -
## inside `reach` to either side and at least `min_drop` below - is driven into
## the floor and loses the carrier's magic damage.
##
## `min_drop` is what makes it a slam rather than a nudge. Two fish side by side
## on the floor are at nearly the same height, so without a drop to clear the
## spell would fire the moment they touched; with one, the carrier has to have
## got itself above the other, which on dry land means a flop, a knockback or a
## blast has put it there.
##
## The shove is straight down, so a target already on the floor takes the damage
## and goes nowhere. One in mid-air is put back on the ground.
class_name SlamSpellData
extends SpellData

@export_category("Slam")
## Damage as a share of the caster's magic damage. 1.0: the spell is that stat,
## once, and the type is ARCANE so that it is the magic stat and not the
## physical one that SpellInstance reads.
@export var damage_scale: float = 1.0
## How far to either side the fish below can be and still count as underneath.
@export_range(0.1, 10.0, 0.1, "suffix:m") var reach: float = 1.0
## How far below the carrier it has to be before it counts as under it at all.
@export_range(0.0, 5.0, 0.05, "suffix:m") var min_drop: float = 0.35
## Multiplier on the shove, which goes straight down with none of the lift a
## touch puts into its knockback. Not scaled by mass, the same as every other
## shove in the arena: a heavy fish is harder to drive into the floor.
@export_range(0.0, 10.0, 0.1) var slam_scale: float = 2.0

## The caster's magic damage, scaled. `caster_power` is magic_dmg for every
## non-PHYSICAL type - see SpellInstance.caster_power().
func compute_damage(caster_power: int) -> int:
	return maxi(0, int(round(caster_power * damage_scale)))
