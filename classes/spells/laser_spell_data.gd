## The fish plants itself, winds up, and lets go of a beam.
##
## Two beats, and the first one is the point of it: for `charge_time` the fish
## is frozen and glowing and doing nothing at all, which is a long time to stand
## still in an arena where everything is decided by touching. Then the beam is
## on for `beam_time`, ticking every `interval` into everything the caster may
## hit along a straight line - it does not stop at the first fish.
##
## The line is **aimed once**, when the charge begins, and never corrects. A
## fish that was in front of it when the winding started and is not there when
## it fires has dodged the whole thing.
class_name LaserSpellData
extends SpellData

@export_category("Wind-up")
## Seconds the fish stands there charging before anything comes out.
@export_range(0.0, 5.0, 0.05, "suffix:s") var charge_time: float = 0.7
## And how long the beam is then on for.
@export_range(0.05, 5.0, 0.05, "suffix:s") var beam_time: float = 0.6
## Seconds between two ticks of it.
@export_range(0.02, 2.0, 0.01, "suffix:s") var interval: float = 0.15

@export_category("Beam")
## How far it reaches. The test arena's floor is 8 by 5, so this crosses it.
@export_range(0.5, 40.0, 0.5, "suffix:m") var max_range: float = 6.0
## Half-width of the line: a fish counts as caught when its middle is within
## this of the beam, plus a share of its own length.
@export_range(0.05, 3.0, 0.05, "suffix:m") var radius: float = 0.35
## Damage a tick is worth, as a share of the caster's magic damage. Four ticks
## at 0.5 is twice its magic to anything that stands in the whole beam.
@export var damage_scale: float = 0.5

@export_category("Look")
## What the beam is drawn in, and how thick.
@export var tint: Color = Color(0.55, 0.85, 1.0, 0.9)
@export_range(0.02, 2.0, 0.01, "suffix:m") var thickness: float = 0.22
## The fish is washed towards this while it winds up, because a fish standing
## still for three quarters of a second needs to look like it meant to.
@export var charge_tint: Color = Color(0.6, 0.9, 1.0, 1.0)

## A share of the caster's magic damage, per tick.
func compute_damage(caster_power: int) -> int:
	return maxi(0, int(round(caster_power * damage_scale)))

## Charge plus beam: how long the fish is out of the fight for altogether.
func total_time() -> float:
	return maxf(charge_time, 0.0) + maxf(beam_time, 0.05)

## How many times anything standing in the whole beam is hit.
func tick_count() -> int:
	return maxi(1, int(floor(maxf(beam_time, 0.05) / maxf(interval, 0.01))))
