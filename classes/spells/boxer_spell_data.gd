## A passive: the fish does not do magic, it does fists.
##
## Everything it would have put into a spell goes into what it hits things with
## instead - `conversion` of its magic damage is added to its physical damage,
## and `magic_scale` of its magic damage is what it has left, which by default
## is none of it. It is a conversion and not a bonus: a boxer carrying Detonate
## blows up for nothing at all.
##
## Both halves land on BattleFish.phys_dmg() / magic_dmg(), the two numbers the
## arena reads for everything - a touch, a spell's damage, the stat lines on the
## cards. The FishInstance's own stats are untouched, so the catch is still
## reported honestly on the selection screen: this is a fish that fights
## differently, not a fish that is worth something different.
class_name BoxerSpellData
extends SpellData

@export_category("Boxer")
## How much of the fish's magic damage is added to its physical damage, per
## point. 1.0 is the straight swap.
@export_range(0.0, 5.0, 0.05) var conversion: float = 1.0
## What is left of its magic damage afterwards, as a share. 0.0 is nothing:
## every spell that scales off magic does nothing in its fins.
@export_range(0.0, 1.0, 0.05) var magic_scale: float = 0.0

## Never called - nothing casts a passive - and 0 so that anything totalling up
## what a fish can do does not count this as damage of its own.
func compute_damage(_caster_power: int) -> int:
	return 0
