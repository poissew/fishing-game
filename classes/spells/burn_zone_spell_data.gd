## A fish that hits the ground hard enough to set it alight: every landing
## leaves a small patch of fire behind, and anything standing in it burns.
##
## The type is **PHYSICAL**, which is what makes `SpellInstance.caster_power()`
## hand it the fish's phys_dmg rather than its magic - this is the one spell
## that scales off how hard the fish hits rather than off what it knows. The
## same choice is what makes the burn count as physical damage on the way in,
## so `ArmourSpellData` takes the edge off it like any other punch.
##
## The zone does not burn whoever lit it. A fish lands in the middle of its own
## fire every time it drops one, so anything else would be a spell that kills
## its owner.
class_name BurnZoneSpellData
extends SpellData

@export_category("Zone")
## How far the fire reaches along the floor.
@export_range(0.1, 5.0, 0.05, "suffix:m") var radius: float = 0.7
## And how high above it: a fish flopping over the top still gets singed, one
## thrown well clear does not.
@export_range(0.1, 5.0, 0.05, "suffix:m") var height: float = 1.0
## How long the patch burns for.
@export_range(0.2, 30.0, 0.1, "suffix:s") var duration: float = 4.0
## Seconds between two burns for anything standing in it.
@export_range(0.05, 5.0, 0.05, "suffix:s") var interval: float = 0.5

@export_category("Burn")
## Damage a tick is worth, as a share of the caster's **physical** damage.
@export var damage_scale: float = 0.25

@export_category("Look")
## The animation the patch plays. It is stretched over the whole `duration`
## rather than looped, so a zone flares up and burns down to smoke on its own.
@export var frames: SpriteFrames
## World height it is drawn at.
@export_range(0.05, 5.0, 0.05, "suffix:m") var zone_size: float = 0.55

## A share of the caster's physical damage - `caster_power` is phys_dmg for a
## PHYSICAL spell, which is the whole reason this one is typed that way.
func compute_damage(caster_power: int) -> int:
	return maxi(0, int(round(caster_power * damage_scale)))

## How many times a fish standing in it the whole way through would be burnt.
func tick_count() -> int:
	return maxi(1, int(floor(duration / maxf(interval, 0.01))))
