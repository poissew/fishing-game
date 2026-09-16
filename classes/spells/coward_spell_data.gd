## A passive: the fish wants nothing to do with the fight.
##
## Everything else a fish carries waits for a moment and then goes off. This one
## never fires at all - it sits on the FishInstance and changes what the fish
## does with every hop it takes, which is why its trigger is PASSIVE and why
## base_power and base_cooldown mean nothing to it.
##
## A fish carrying this hops away from whatever is nearest instead of towards
## it, hardest when that thing is close. It still hits back when it is caught -
## contact damage in the arena is traded both ways and neither fish gets a say
## in it - so this buys distance, not immunity. Two cowards in one arena will
## never finish a fight.
class_name CowardSpellData
extends SpellData

@export_category("Coward")
## How much of a hop goes into getting away, 0 pure wandering and 1 a straight
## line for the far wall. The same distance falloff that shapes BattleFish's
## chase_bias applies on top: a threat across the arena is barely worth running
## from, one right there is worth nothing else.
@export_range(0.0, 1.0, 0.05) var flee_bias: float = 0.9

## Never called - nothing casts a passive - and 0 rather than inherited so that
## anything totalling up what a fish can do does not count this as damage.
func compute_damage(_caster_power: int) -> int:
	return 0
