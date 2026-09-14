## Static definition of a spell. One resource per spell, shared by every fish
## that rolls it; anything that changes during a battle (remaining cooldown,
## stacks applied) belongs on SpellInstance, not here.
class_name SpellData
extends Resource

## How much of the caster's damage stat is folded into base_power. Higher
## values flatten the gap between a weak and a strong caster.
const POWER_SCALE := 10.0

@export_category("Base Data")
@export var name: String
@export_multiline var description: String

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
