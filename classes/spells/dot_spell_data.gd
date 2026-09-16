## A spell that leaves something behind: it does no damage when it lands, it
## puts an effect on the fish it hit and that effect does the damage, a tick at
## a time, until it wears off.
##
## Landing it again on a fish that is already under it does not start a second
## effect and does not buy the first one more time - it multiplies what is
## already ticking by `stack_multiplier`. So the way to make it hurt is to keep
## getting touches in before it wears off, and the clock is running from the
## first one whatever happens after.
##
## `base_cooldown` is 0 on the resource: the limit on how fast it can be
## reapplied is BattleFish.HIT_COOLDOWN, the same gate that stops two fish
## resting against each other trading damage every frame.
class_name DotSpellData
extends SpellData

@export_category("Damage over time")
## Damage a tick is worth, as a share of the caster's magic damage. Rolled once
## when the effect is applied, so a fish that gets stronger mid-fight does not
## make an effect already ticking hurt more.
@export var damage_scale: float = 0.5
## Seconds between two ticks.
@export_range(0.05, 10.0, 0.05, "suffix:s") var interval: float = 1.0
## How long one application lasts. Reapplying does **not** extend this - see
## the class comment - so this is the whole window, from the first touch.
@export_range(0.1, 60.0, 0.1, "suffix:s") var duration: float = 4.0
## What each reapplication multiplies the damage of the running effect by.
## 2.0 doubles it, 1.0 would make reapplying do nothing at all.
@export_range(1.0, 5.0, 0.1) var stack_multiplier: float = 2.0

## Damage for one tick of a fresh application.
func compute_damage(caster_power: int) -> int:
	return maxi(0, int(round(caster_power * damage_scale)))

## How many ticks one application is worth. Counted rather than timed: a fish
## should take four ticks of a four-second effect at one a second, and a float
## clock that runs out a hair early would quietly drop the last one.
func tick_count() -> int:
	return maxi(1, int(round(duration / maxf(interval, 0.01))))
