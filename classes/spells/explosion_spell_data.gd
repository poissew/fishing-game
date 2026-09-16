## A spell that goes off on contact: the fish carrying it blows up the next
## thing it runs into - another fish, a wall, the floor it lands on after a flop
## - damaging and shoving everything it is allowed to hit within `radius` of the
## impact. The caster is thrown by its own blast as well, but never hurt by it.
##
## Damage is flat magic damage times `damage_scale` - base_power is not used,
## because the whole point of it is that it is the fish's own magic stat put
## through the caster and not a number picked per spell. Distance only softens
## the shove, never the damage: a fish at the rim of the blast takes the same
## hit as one at the centre, it is just not thrown as far.
class_name ExplosionSpellData
extends SpellData

## Share of the shove left at the very edge of the blast. The middle gets all
## of knockback_scale, the rim this much of it, straight line between.
const EDGE_KNOCKBACK := 0.45

@export_category("Explosion")
## Multiplier on the caster's magic damage. 1.5 by default, so a fish with
## MAG 10 blows up for 15.
@export var damage_scale: float = 1.5
## How far from the impact the blast reaches, in world units. A fish is
## caught when its own origin is inside this.
@export_range(0.1, 10.0, 0.1, "or_greater", "suffix:m") var radius: float = 1.6
## Multiplier on the knockback a hit this size would normally be worth, so an
## explosion throws fish much further than the touch that set it off.
##
## It scales BattleFish's ceiling on a single shove along with the shove, so it
## is really a multiplier on the fastest a fish can be sent flying: 3.0 puts a
## point-blank blast at 7.5 units/s, which is past BattleFish.MAX_SPEED and so
## means "as fast as a fish is allowed to go". Pushing it higher does nothing
## the clamp does not immediately take back.
@export_range(0.0, 10.0, 0.1) var knockback_scale: float = 3.0

## Share of that shove the caster gets, thrown back the way it came. It takes no
## damage from its own blast - only the recoil - so this is the whole of what
## going off in its face costs it.
@export_range(0.0, 2.0, 0.05) var self_knockback: float = 0.7

@export_category("Look")
## The animation played at the impact. Runs once and frees itself.
@export var frames: SpriteFrames
## World height of that animation, as a share of the blast's diameter. 1.0
## draws the art exactly as big as the damage reaches.
@export_range(0.1, 3.0, 0.05) var visual_scale: float = 1.0

## Flat magic damage: the caster's own stat, scaled. `caster_power` is its
## magic_dmg for every non-PHYSICAL type - see SpellInstance.caster_power().
func compute_damage(caster_power: int) -> int:
	return maxi(0, int(round(caster_power * damage_scale)))

## How much of knockback_scale survives `distance` from the centre of the
## blast. Damage does not fade this way; only the shove does.
func knockback_at(distance: float) -> float:
	var reach := clampf(distance / maxf(radius, 0.0001), 0.0, 1.0)
	return knockback_scale * lerpf(1.0, EDGE_KNOCKBACK, reach)

## World height the animation is drawn at.
func visual_size() -> float:
	return radius * 2.0 * visual_scale
