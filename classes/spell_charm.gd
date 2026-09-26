class_name SpellCharm
extends ItemInstance

## A spell in a bottle: what a SlotMachine pays out. It sits in the inventory
## like any other item, and dropping it on a fish there teaches the fish the
## spell and uses the charm up - see FishInstance.learn_spell().
##
## Every charm shares one Item (data/items/spell_charm.tres) for its footprint
## and icon; which spell it holds is the instance's business, the way a fish's
## size is FishInstance's and not FishData's.

const ITEM: Item = preload("res://data/items/spell_charm.tres")

@export var spell: SpellData

static func create(spell_data: SpellData) -> SpellCharm:
	var charm := SpellCharm.new()
	charm.data = ITEM
	charm.spell = spell_data
	return charm

## "Charm: Detonate" - the Item's own name says nothing about what is inside.
func display_name() -> String:
	return "Charm: %s" % spell.name if spell != null else ITEM.name
