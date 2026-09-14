## The elemental families a spell can belong to.
##
## Kept in its own class so fish resistances, UI colours and the future type
## chart can all refer to SpellType.Type without depending on SpellData.
class_name SpellType
extends RefCounted

enum Type {
	PHYSICAL,
	FIRE,
	ICE,
	WATER,
	LIGHTNING,
	POISON,
	ARCANE,
}

const DISPLAY_NAMES := {
	Type.PHYSICAL: "Physical",
	Type.FIRE: "Fire",
	Type.ICE: "Ice",
	Type.WATER: "Water",
	Type.LIGHTNING: "Lightning",
	Type.POISON: "Poison",
	Type.ARCANE: "Arcane",
}

static func display_name(type: Type) -> String:
	return DISPLAY_NAMES.get(type, "Unknown")

## PHYSICAL spells scale off a fish's phys_dmg, every other type off magic_dmg.
static func is_magical(type: Type) -> bool:
	return type != Type.PHYSICAL
