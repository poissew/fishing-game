## A passive that turns a share of incoming magic aside - the other half of what
## ArmourSpellData does for a punch.
##
## A **share** and not a flat amount, which is the difference between the two:
## armour is worth most against a lot of small hits and can shrug one off
## entirely, while a ward is worth exactly as much against a big spell as a
## small one and can never take a hit to nothing.
##
## Only magic. A touch goes through it untouched, and so do the two things
## nothing defends against - the arena's sudden-death drain and the blow that
## Immunity was holding off. See BattleFish.DamageKind.
class_name WardSpellData
extends SpellData

@export_category("Ward")
## Share of every magical hit that never arrives. 0.3 is the three tenths the
## spell promises; 1.0 would be flat immunity to magic and is almost certainly
## not what anyone wants.
@export_range(0.0, 1.0, 0.05) var resistance: float = 0.3

## Never called - nothing casts a passive - and 0 so that anything totalling up
## what a fish can do does not count this as damage of its own.
func compute_damage(_caster_power: int) -> int:
	return 0
