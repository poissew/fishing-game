## A stay of execution: the blow that would have finished this fish leaves it on
## one point of health instead, and for `duration` after that nothing can take
## that last point off it. When the time is up it dies anyway.
##
## What it gets in exchange for those seconds is very little to fight with -
## `power_scale` of its own attack and magic - so this is not a second wind. It
## is a chance to land something small before it goes, and if whatever it is
## fighting happens to die first, the round is over and the fish walks away.
##
## **Once per fight.** BattleFish remembers it has been spent, and bind_fish()
## is what gives it back - a fish sent into the arena again gets a fresh one,
## the same way it gets its health back.
class_name LastStandSpellData
extends SpellData

@export_category("Last stand")
## How long the fish is held on its feet for.
@export_range(0.1, 30.0, 0.1, "suffix:s") var duration: float = 2.0
## What it has left to fight with while it lasts, as a share of its own attack
## and magic. 0.1 is the tenth the spell promises.
@export_range(0.0, 1.0, 0.05) var power_scale: float = 0.1

## Never called - nothing casts a passive - and 0 so that anything totalling up
## what a fish can do does not count this as damage of its own.
func compute_damage(_caster_power: int) -> int:
	return 0
