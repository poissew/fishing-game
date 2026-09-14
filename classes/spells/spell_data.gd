## Static definition of a spell. One resource per spell, shared by every fish
## that rolls it; anything that changes during a battle (remaining cooldown,
## stacks applied) belongs on the runtime spell, not here.
class_name SpellData
extends Resource

@export_category("Base Data")
@export var name: String
@export_multiline var description: String

@export_category("Combat")
## Base damage before the caster's phys_dmg / magic_dmg is applied.
@export var base_power: int = 1
## Elemental family, decides which of the caster's damage stats it scales off.
@export var base_type: SpellType.Type = SpellType.Type.PHYSICAL
## Turns to wait between two casts. 0 means it can be cast every turn.
@export var base_cooldown: int = 0

func is_magical() -> bool:
	return SpellType.is_magical(base_type)

func type_name() -> String:
	return SpellType.display_name(base_type)
