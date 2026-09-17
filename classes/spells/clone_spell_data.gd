## The fish puts a copy of itself on the floor and lets whatever it is fighting
## go for that instead.
##
## The clone is a real BattleFish - same species, same icon, same size, and it
## flops about like anything else, which is the whole point of it - but it has
## no attack, no magic and no spells of its own, so it cannot win a fight or
## even join in one. It is somewhere for the other fish to be for a few seconds.
##
## It is **not** one of the arena's battlers: `BattleRound` was handed the real
## pair and never hears about this one, so a clone can neither win a round nor
## keep one from ending.
class_name CloneSpellData
extends SpellData

@export_category("Clone")
## How long it stands in for the real fish before it goes.
@export_range(0.2, 30.0, 0.1, "suffix:s") var duration: float = 4.0
## Health it gets, as a share of the fish it copied. A clone that goes down
## early takes the lure with it - so this is really how long the decoy lasts
## against something that keeps hitting it.
@export_range(0.05, 2.0, 0.05) var health_scale: float = 0.5
## How far to one side of the real fish it appears, in world units.
@export_range(0.0, 5.0, 0.05, "suffix:m") var spawn_offset: float = 0.6

## None. A clone deals none either - the spell is the distraction.
func compute_damage(_caster_power: int) -> int:
	return 0
