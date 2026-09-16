## Static definition of a spell. One resource per spell, shared by every fish
## that rolls it; anything that changes during a battle (remaining cooldown,
## stacks applied) belongs on SpellInstance, not here.
class_name SpellData
extends Resource

## How much of the caster's damage stat is folded into base_power. Higher
## values flatten the gap between a weak and a strong caster.
const POWER_SCALE := 10.0

## What makes a spell go off.
enum Trigger {
	## Fired by whatever is driving the fight, whenever it decides to.
	MANUAL,
	## Armed the moment it comes off cooldown, and spent on the caster's next
	## contact of any kind - the fish does not aim it, it just goes off.
	ON_HIT,
	## Held until the fish is at the top of a hop with nothing underneath it.
	## What it does there is the spell's own business; BattleFish only spots
	## the peak and hands the cast over.
	AT_JUMP_PEAK,
	## Never cast at all. It is read off the fish and changes how the fish
	## behaves for as long as it is carried, so cooldown and damage mean
	## nothing to it.
	PASSIVE,
}

@export_category("Base Data")
@export var name: String
@export_multiline var description: String
## When the battler should cast this. See Trigger.
@export var trigger: Trigger = Trigger.MANUAL
## ON_HIT only. False - the default - and the spell goes off on any contact at
## all, a wall or the floor included, which is what a fish that simply explodes
## wants. True and it waits for a touch that actually landed damage on an enemy,
## which is what anything that has to have something to do *to* needs.
@export var needs_hit: bool = false

@export_category("Combat")
## Base damage before the caster's phys_dmg / magic_dmg is applied.
@export var base_power: int = 1
## Elemental family, decides which of the caster's damage stats it scales off.
@export var base_type: SpellType.Type = SpellType.Type.PHYSICAL
## Seconds to wait between two casts. 0 means it can be recast immediately.
@export_range(0, 60, 1, "or_greater", "suffix:s") var base_cooldown: int = 0

func is_magical() -> bool:
	return SpellType.is_magical(base_type)

func type_name() -> String:
	return SpellType.display_name(base_type)

## Damage for one cast. `caster_power` is the caster's phys_dmg for PHYSICAL
## spells and its magic_dmg for every other type - SpellInstance picks which.
##
## Takes a plain int rather than the caster itself so SpellData stays free of
## any dependency on FishInstance, and so children can be tested in isolation.
## Override in children that do not deal flat damage.
func compute_damage(caster_power: int) -> int:
	return maxi(0, int(round(base_power * (1.0 + caster_power / POWER_SCALE))))
