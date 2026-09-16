## A camera that goes off the moment it has finished winding on, whether or not
## there is anything in front of it to photograph.
##
## The flash is a cone out of the fish's front: `spread_degrees` either side of
## the way it is facing, out to `max_range`. Anything the carrier may hit that
## is caught in it is left standing there, and **how long for depends on how
## close it was** - the whole of `max_stun` with the lens against it, down to
## `min_stun` at the far edge. That is the shotgun part: the spread is the same
## at any range, what changes is how much of it lands.
##
## It does no damage at all. What it does is take the other fish out of the
## fight for a few seconds, which in an arena where everything is decided by
## touching is its own kind of damage.
class_name PaparazziSpellData
extends SpellData

@export_category("Flash")
## How far down its own nose the flash reaches.
@export_range(0.5, 20.0, 0.1, "suffix:m") var max_range: float = 2.5
## Half-angle of the cone, in degrees: 45 makes a quarter-turn of arc in front
## of the fish, 180 would be the whole room.
@export_range(1.0, 180.0, 1.0) var spread_degrees: float = 45.0

@export_category("Stun")
## With the lens against it, and at the very edge of the cone's reach.
@export_range(0.0, 30.0, 0.1, "suffix:s") var max_stun: float = 5.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var min_stun: float = 0.5

@export_category("Look")
## World height the flash is drawn at, before it grows.
@export_range(0.05, 5.0, 0.05, "suffix:m") var flash_size: float = 0.6
## How long the flash itself is on screen. Nothing to do with the stun.
@export_range(0.02, 2.0, 0.01, "suffix:s") var flash_time: float = 0.18
## Left empty, SpellFlash draws its own - see SpellFlash._shared_texture().
@export var texture: Texture2D

## None. The whole of this spell is the stun.
func compute_damage(_caster_power: int) -> int:
	return 0

## How long a fish `distance` away is left standing there: all of max_stun at
## point blank, min_stun at the far edge, straight line between.
func stun_for(distance: float) -> float:
	var reach := clampf(distance / maxf(max_range, 0.01), 0.0, 1.0)
	return lerpf(max_stun, min_stun, reach)
