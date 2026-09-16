## A passive: the fish wants nothing to do with the fight.
##
## Everything else a fish carries waits for a moment and then goes off. This one
## never fires at all - it sits on the FishInstance and changes what the fish
## does with every hop it takes, which is why its trigger is PASSIVE and why
## base_power and base_cooldown mean nothing to it.
##
## A fish carrying this hops away from whatever is nearest instead of towards
## it, hardest when that thing is close, and deals nothing at all when it is
## caught: `phys_scale` takes its contact damage to zero. It does not fight, in
## either direction.
##
## That has teeth. Contact is how a fish normally wins, so a coward can only
## win on its other spells, and a coward carrying none cannot win at all - it
## runs until something corners it and kills it. Two cowards in one arena will
## never finish a fight in either direction.
class_name CowardSpellData
extends SpellData

@export_category("Coward")
## How much of a hop goes into getting away, 0 pure wandering and 1 a straight
## line for the far wall. The same distance falloff that shapes BattleFish's
## chase_bias applies on top: a threat across the arena is barely worth running
## from, one right there is worth nothing else.
@export_range(0.0, 1.0, 0.05) var flee_bias: float = 0.9

## What is left of the fish's physical damage while it carries this, as a share
## of it. 0.0 is the spell as it is meant to be - it will not fight - and this
## is a number rather than a switch so that a half-hearted coward is one edit
## away if nothing at all turns out to be too much.
##
## Only what the body deals on contact. A PHYSICAL spell would still scale off
## the fish's own phys_dmg, which is untouched: this is the fish refusing to
## fight, not the fish getting weaker.
@export_range(0.0, 1.0, 0.05) var phys_scale: float = 0.0

## Never called - nothing casts a passive - and 0 rather than inherited so that
## anything totalling up what a fish can do does not count this as damage.
func compute_damage(_caster_power: int) -> int:
	return 0
