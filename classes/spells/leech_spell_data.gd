## Leeches dropped on the floor, which latch onto whatever stands on them and
## drink.
##
## The fish leaves one behind every time it lands, up to `max_stacks` of them at
## once - that cap is the real pacing, not the cooldown, because a fish lands
## constantly. A leech waits `life` seconds for somebody to come along; once it
## has caught one it rides that fish for `duration`, taking `damage_scale` of the
## owner's magic every `interval` and handing `heal_share` of it back.
##
## It is the only spell that gives health rather than only taking it, so the
## swing is twice what the damage says: what the victim loses, the owner gains.
class_name LeechSpellData
extends SpellData

@export_category("Leeches")
## How many of one fish's leeches can be out at once, waiting or attached. The
## fish simply does not drop another until one of them is gone.
@export_range(1, 10, 1) var max_stacks: int = 3
## Seconds a leech lies on the floor waiting before it dries up.
@export_range(1.0, 60.0, 0.5, "suffix:s") var life: float = 12.0
## And how long it drinks for once it has latched on.
@export_range(0.5, 30.0, 0.5, "suffix:s") var duration: float = 5.0
## Seconds between two mouthfuls.
@export_range(0.1, 5.0, 0.05, "suffix:s") var interval: float = 0.5

@export_category("Bite")
## Damage a mouthful is worth, as a share of the owner's magic damage.
##
## Low, and the healing lower still, because this spell swings twice: what it
## takes off one fish it puts on another. At 0.3 and a full share back it won
## 9 arena rounds out of 9 and dragged three of them into sudden death, the
## owner simply out-drinking the damage it was taking.
@export var damage_scale: float = 0.2
## How much of what it drinks goes back to the fish that dropped it. 1.0 is all
## of it; the owner has to still be alive to get any.
@export_range(0.0, 2.0, 0.05) var heal_share: float = 0.5
## How close a fish has to be to be caught, and how far off the floor it may be
## while it happens - a leech is on the ground, so something flying over it is
## not standing on it.
@export_range(0.05, 3.0, 0.05, "suffix:m") var radius: float = 0.45
@export_range(0.05, 3.0, 0.05, "suffix:m") var height: float = 0.6

@export_category("Look")
## What a leech is drawn as. Left empty it uses the project icon, the same
## stand-in Wildfire uses until there is art for it.
@export var texture: Texture2D
@export var tint: Color = Color(0.45, 0.10, 0.18, 1.0)
## And the tint it takes once it is attached and feeding.
@export var fed_tint: Color = Color(0.85, 0.15, 0.25, 1.0)
## How big one is drawn, nose to tail.
@export_range(0.05, 2.0, 0.05, "suffix:m") var leech_size: float = 0.3

## A share of the owner's magic damage, per mouthful.
func compute_damage(caster_power: int) -> int:
	return maxi(1, int(round(caster_power * damage_scale)))

## How much of a bite of `amount` the owner gets back.
func healing_for(amount: int) -> int:
	return maxi(0, int(round(amount * heal_share)))

## How many mouthfuls one leech gets, if it is left to finish.
func bite_count() -> int:
	return maxi(1, int(floor(maxf(duration, 0.1) / maxf(interval, 0.05))))
