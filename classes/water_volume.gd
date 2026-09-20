@tool
class_name WaterVolume
extends Area3D

## A body of water built from brushes. Placed in TrenchBroom as [code]water_volume[/code].
##
## [Bobber] never looks for this class. It looks for the [code]water[/code] group and then
## reads the biome off whatever other groups the node is in — see
## [method Bobber.get_water_state] — so all this has to do is wear the right group
## names. That is deliberate: the hand-built pool in [code]levels/trees.tscn[/code] and a
## brush-built one are identical as far as the fishing loop is concerned, and
## neither of them needs the other to exist.
##
## The brush is built as an [Area3D] with a [MeshInstance3D] beside it, so one entity
## is both the surface you see and the volume you fish in. Physics layer 2
## ([code]Water[/code]) is what the bobber's own [Area3D] scans for.

## The group that makes a volume fishable at all.
const WATER_GROUP := &"water"

## Biome name meaning "no extra group": [method Bobber.get_water_state] falls through
## to WATER_STATE.DEFAULT when it finds nothing it recognises, so the plainest
## water is the one wearing the fewest groups.
const DEFAULT_BIOME := &"default"

## Which loot table the bobber picks when it lands in here. The value is the
## group name [method Bobber.get_water_state] matches on, not a table id — the bobber
## maps one to the other itself.
@export var biome: StringName = DEFAULT_BIOME:
	set(value):
		if biome == value:
			return
		_leave(biome)
		biome = value
		_apply_groups()

## Filled by FuncGodot on map build. Never read after [method _func_godot_apply_properties]
## has copied what it needs out of it.
@export var func_godot_properties: Dictionary = {}

func _ready() -> void:
	_apply_groups()

func _func_godot_apply_properties(props: Dictionary) -> void:
	biome = StringName(str(props.get("biome", biome)))
	# Persistent, so the groups survive into the scene the built map is saved as.
	_apply_groups(true)

func _apply_groups(persistent: bool = false) -> void:
	_join(WATER_GROUP, persistent)
	if biome != &"" and biome != DEFAULT_BIOME:
		_join(biome, persistent)

## [method Node.add_to_group] returns early when the node is already in the group, so it
## will not upgrade a non-persistent membership to a persistent one — the group
## has to be dropped and re-joined. That ordering is not hypothetical: the FGD
## definition and [method _ready] both join before FuncGodot applies properties, and
## only the last of the three knows the build is meant to be saved.
func _join(group: StringName, persistent: bool) -> void:
	if is_in_group(group):
		if not persistent:
			return
		remove_from_group(group)
	add_to_group(group, persistent)

func _leave(group: StringName) -> void:
	if group != &"" and group != DEFAULT_BIOME and is_in_group(group):
		remove_from_group(group)
