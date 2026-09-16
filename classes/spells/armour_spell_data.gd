## A passive that takes the edge off a punch: every physical hit this fish takes
## is worth `flat` plus `per_power` of its own magic damage less than it would
## have been, to a minimum of nothing at all.
##
## Only **physical** damage. A spell's damage goes past it untouched unless that
## spell is itself PHYSICAL, and so does the arena's own sudden-death drain -
## there would be no point in a clock that armour could sit out.
##
## The magic half is what makes it a spell and not a stat: it is worth most on a
## fish that had magic to spare. A fish carrying Boxer as well has already spent
## that magic on its fists, so it keeps only the flat part - which is the same
## trade made twice, and reads exactly as it should.
class_name ArmourSpellData
extends SpellData

@export_category("Armour")
## Taken off every physical hit before anything else.
@export var flat: float = 3.0
## And this much of the fish's magic damage on top, per point.
@export var per_power: float = 0.5

## How much this fish shrugs off, for a given magic damage. Rounded once at the
## end, so 3 + 0.5 * 9 is 8 rather than 7.
func reduction(magic_power: int) -> int:
	return maxi(0, int(round(flat + magic_power * per_power)))

## Never called - nothing casts a passive - and 0 so that anything totalling up
## what a fish can do does not count this as damage.
func compute_damage(_caster_power: int) -> int:
	return 0
