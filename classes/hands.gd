class_name Hands
extends Resource

## Runtime state of what the player physically holds.
## Two slots (left / right); each holds a single ItemInstance or null.

enum Slot { LEFT, RIGHT }

const SLOT_COUNT := 2

## Redraws are driven by Resource's built-in `changed` signal (see emit_changed).

@export var slots: Array[ItemInstance] = [null, null]

func _init() -> void:
	if slots.size() != SLOT_COUNT:
		slots.resize(SLOT_COUNT)

func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT

func get_item(slot: int) -> ItemInstance:
	if not is_valid_slot(slot):
		return null
	return slots[slot]

func set_item(slot: int, item: ItemInstance) -> void:
	if not is_valid_slot(slot):
		return
	slots[slot] = item
	emit_changed()

func clear(slot: int) -> ItemInstance:
	var item := get_item(slot)
	if item != null:
		set_item(slot, null)
	return item

func is_empty(slot: int) -> bool:
	return get_item(slot) == null

func first_free_slot() -> int:
	for i in SLOT_COUNT:
		if slots[i] == null:
			return i
	return -1

func slot_of(item: ItemInstance) -> int:
	if item == null:
		return -1
	return slots.find(item)

## Slot holding a rod, or -1. Only one rod can be wielded at a time.
func slot_of_rod() -> int:
	for i in SLOT_COUNT:
		if slots[i] is RodInstance:
			return i
	return -1

func get_rod() -> RodInstance:
	var slot := slot_of_rod()
	return slots[slot] as RodInstance if slot >= 0 else null
