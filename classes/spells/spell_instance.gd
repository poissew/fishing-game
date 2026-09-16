## One spell as carried by one fish in one battle: a SpellData reference plus
## the only thing that actually changes while fighting, its cooldown.
##
## The battler owns the clock - it calls tick() every frame and try_cast() when
## it wants this spell to fire. SpellInstance never touches the target itself;
## it returns the damage it rolled and lets the battler apply it, so a fight
## can be simulated without anything being rendered.
class_name SpellInstance
extends Resource

## Returned by try_cast() when the spell was still on cooldown.
const NOT_READY := -1

@export var data: SpellData

## Seconds left before the next cast. Deliberately not exported: it is
## per-battle state, worthless in a save file, unlike RodInstance.durability.
var cooldown_left: float = 0.0

static func create_spell_instance(spell_data: SpellData) -> SpellInstance:
	var spell := SpellInstance.new()
	spell.data = spell_data
	return spell

## Spells start a battle ready to fire.
func reset() -> void:
	cooldown_left = 0.0

func tick(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)

func is_ready() -> bool:
	return data != null and cooldown_left <= 0.0

## 0.0 just after a cast, 1.0 when ready again. For cooldown swipes in the UI.
func cooldown_ratio() -> float:
	if data == null or data.base_cooldown <= 0:
		return 1.0
	return clampf(1.0 - cooldown_left / float(data.base_cooldown), 0.0, 1.0)

## The caster stat this spell scales off: phys_dmg for PHYSICAL, magic_dmg for
## every other type.
func caster_power(caster: FishInstance) -> int:
	if caster == null or data == null:
		return 0
	return caster.magic_dmg if data.is_magical() else caster.phys_dmg

## Fires the spell and returns the damage rolled, or NOT_READY if it is still
## cooling down. Check is_ready() first if you need to branch before spending
## the cast.
##
## Reads the caster's stats straight off it, which is right for anything
## simulating a fight with no bodies in it. A battler casts through
## try_cast_at() instead: in an arena a fish's stats are what its passives say
## they are, and the FishInstance does not know about those.
func try_cast(caster: FishInstance) -> int:
	return try_cast_at(caster_power(caster))

## Fires the spell with a power the caller has already worked out.
func try_cast_at(power: int) -> int:
	if not is_ready():
		return NOT_READY
	cooldown_left = float(data.base_cooldown)
	return data.compute_damage(power)
