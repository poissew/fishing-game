## Lightning called down on wherever the enemy is standing, a beat before it
## arrives.
##
## Two beats, and the gap between them is the whole spell: the moment it comes
## off cooldown a mark is put on the floor under **every** fish the caster may
## hit within `max_range`, and `windup` seconds later the bolt lands on that
## spot - the spot, not the fish. A fish that is still there takes it; a fish
## that has flopped clear of it takes nothing at all.
##
## Unlike LaserSpellData the caster is not held still for any of it. It calls
## the strike down and carries on, so the cost is entirely in the warning the
## target gets.
class_name LightningSpellData
extends SpellData

@export_category("Strike")
## Seconds between the mark going down and the bolt arriving. This is the only
## thing that makes it dodgeable, so it wants to be long enough to read.
@export_range(0.0, 5.0, 0.05, "suffix:s") var windup: float = 1.0
## How far from the marked spot the bolt reaches. It is a column from the sky,
## so only the distance along the floor counts.
##
## This is sized off what a fish actually does in the wind-up rather than off
## what a bolt of lightning ought to look like: FLOP_INTERVAL is 0.3 to 0.85 s,
## so a second is one to three hops, and the fish is reliably about 1.3 m from
## where it was marked when the bolt lands. At 0.6 the spell measured 0 hits in
## 30 casts of real arena.
@export_range(0.1, 5.0, 0.05, "suffix:m") var radius: float = 1.2
## A share of the target's own length counted on top of the radius, the same
## allowance SpellBeam makes: a shark is a wider thing to miss than a sardine.
@export_range(0.0, 1.0, 0.05) var target_girth: float = 0.3
## How far away a fish can be and still have one called down on it. The test
## arena's floor is 8 by 5, so this covers the whole of it.
@export_range(0.5, 40.0, 0.5, "suffix:m") var max_range: float = 12.0
## Damage as a share of the caster's magic damage, on top of base_power.
##
## Low, and deliberately: this is the one damaging spell that costs its caster
## nothing at all - no contact, no standing still, no aim. At 0.8 it went 25-5
## over 30 rounds against a fish with no spells, which is the strongest thing in
## the pool; at 0.4 it is 15-6, against a harness that runs 15-10 on its own.
@export var damage_scale: float = 0.4
## How much harder than a touch the bolt throws what it hits. The mark is under
## the fish, so this mostly means "off its feet" rather than any direction.
@export_range(0.0, 4.0, 0.1) var knockback_scale: float = 1.0

@export_category("Look")
## The mark drawn on the floor while the strike is on its way. Left empty it
## uses the project icon, the same as a patch of Wildfire does - a shape that
## reads at 480x270 beats a tasteful circle.
@export var texture: Texture2D
@export var tint: Color = Color(1.0, 0.85, 0.2, 0.8)
## And the bolt itself, once it lands.
@export var bolt_tint: Color = Color(1.0, 0.97, 0.75, 1.0)
## How long the bolt is drawn for. Long enough to see, short enough to read as
## a flash rather than a beam.
@export_range(0.05, 2.0, 0.05, "suffix:s") var bolt_time: float = 0.3
## How tall and wide it is drawn.
@export_range(0.5, 10.0, 0.1, "suffix:m") var bolt_height: float = 3.0
@export_range(0.05, 3.0, 0.05, "suffix:m") var bolt_width: float = 0.7

## Flat damage plus a share of the caster's magic.
func compute_damage(caster_power: int) -> int:
	return maxi(0, base_power + int(round(caster_power * damage_scale)))
