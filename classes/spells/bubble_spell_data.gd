## A spell that waits for the top of a hop: the fish stops dead in mid-air and
## spits a volley of bubbles at whatever it is fighting.
##
## The bubbles are slow and they do not home. Each one is aimed at where the
## target stood when it left, so a fish that keeps moving is dodging them, and
## the caster spends the whole volley hanging there unable to do anything about
## it. That trade - it cannot miss with a touch, it can easily miss with these -
## is the whole of the spell.
class_name BubbleSpellData
extends SpellData

@export_category("Volley")
## Bubbles per cast.
@export_range(1, 10, 1) var count: int = 3
## Seconds between two of them, so a volley reads as three shots and not one.
@export_range(0.0, 2.0, 0.01, "suffix:s") var interval: float = 0.15
## How long the fish hangs there, frozen, from the moment it fires the first.
## Needs to outlast the volley itself or the last bubbles leave on the way down.
@export_range(0.0, 5.0, 0.05, "suffix:s") var hang_time: float = 0.6

@export_category("Bubble")
## Damage is base_power plus this much of the caster's magic damage: 5 and 0.5
## make a MAG 10 fish deal 10 a bubble, 30 if the whole volley lands.
@export var damage_scale: float = 0.5
## Travel speed is base_speed plus speed_per_power per point of magic damage.
## Slow on purpose - a fish flops at about 3 units/s, so anything much faster
## than this could not be dodged and the spell would just be damage.
@export var base_speed: float = 1.0
@export var speed_per_power: float = 0.2
## How far a bubble gets before it pops on its own, in world units. The test
## arena floor is 8 by 5, so this crosses it.
@export_range(0.5, 30.0, 0.5, "suffix:m") var max_range: float = 7.0
## Radius of the bubble itself for the purpose of hitting something. The fish it
## is aimed at counts as wide as a share of its own length on top of this.
@export_range(0.01, 2.0, 0.01, "suffix:m") var hit_radius: float = 0.18
## Multiplier on the shove a hit this size is worth. Under 1.0: a bubble is a
## nudge, not the explosion.
@export_range(0.0, 5.0, 0.1) var knockback_scale: float = 0.8

@export_category("Look")
## World diameter the bubble is drawn at.
@export_range(0.05, 2.0, 0.01, "suffix:m") var bubble_size: float = 0.28
## Left empty, SpellBubble draws its own - see SpellBubble._shared_texture().
@export var texture: Texture2D

## base_power flat, plus a share of the caster's magic damage. Rounded once at
## the end rather than per term, so 5 + 0.5 * 7 is 9 and not 8.
func compute_damage(caster_power: int) -> int:
	return maxi(0, int(round(base_power + caster_power * damage_scale)))

## How fast a bubble from this caster travels, in units per second.
func speed(caster_power: int) -> float:
	return maxf(0.1, base_speed + speed_per_power * caster_power)
