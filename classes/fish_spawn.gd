@tool
class_name FishSpawn
extends Node3D

## Where a fighter drops into the arena. Placed in TrenchBroom as [code]fish_spawn[/code].
##
## The marker does not spawn anything itself — whoever runs the arena asks for
## the points and does the spawning, exactly the way [code]dev/test_arena.gd[/code] does it
## from its own SPAWN_X / SPAWN_Y constants today. That keeps the map out of
## the fight: a spawn point is a position and a side, nothing more.
##
## What it carries is the part the arena cannot work out from a position alone:
## which team the fish is on and what colour to tint it, so two fish of one
## species are still told apart. Both mirror the properties of the same name on
## [BattleFish].

## Group every spawn point joins, and the one an arena looks them up by. The FGD
## definition adds it on map build; [method _ready] covers a marker dropped into
## a scene by hand.
const GROUP := &"fish_spawn"

## Side this spawn belongs to, matching [member BattleFish.team]. -1 is free-for-all.
@export var team: int = -1

## Team colour laid over the fish's own icon, matching [member BattleFish.tint].
@export var tint: Color = Color.WHITE

## The order [method all] hands the points out in. Set this rather than relying
## on where the entity sits in the map file.
@export var spawn_order: int = 0

## Filled by FuncGodot on map build. Never read after [method _func_godot_apply_properties]
## has copied what it needs out of it.
@export var func_godot_properties: Dictionary = {}

func _ready() -> void:
	add_to_group(GROUP)

func _func_godot_apply_properties(props: Dictionary) -> void:
	team = props.get("team", team)
	tint = props.get("tint", tint)
	spawn_order = props.get("spawn_order", spawn_order)
	# Persistent, so the group survives into the scene the built map is saved as.
	add_to_group(GROUP, true)

## Every spawn point in the tree, ordered by [member spawn_order]. Ties fall back
## to node name so the order is at least stable between runs — but a map that
## cares which fish goes where should set [member spawn_order].
static func all(tree: SceneTree) -> Array[FishSpawn]:
	var points: Array[FishSpawn] = []
	for node in tree.get_nodes_in_group(GROUP):
		if node is FishSpawn:
			points.append(node as FishSpawn)
	points.sort_custom(func(a: FishSpawn, b: FishSpawn) -> bool:
		if a.spawn_order != b.spawn_order:
			return a.spawn_order < b.spawn_order
		return a.name < b.name)
	return points

## The spawn points on one side, in the same order [method all] gives.
static func for_team(tree: SceneTree, team_index: int) -> Array[FishSpawn]:
	var points: Array[FishSpawn] = []
	for point in all(tree):
		if point.team == team_index:
			points.append(point)
	return points

## Drops [param fish] in here under [param parent], wearing this point's team and
## tint. [param parent] is taken rather than assumed because the arena decides
## what it hangs fighters off — and the battler has to be in the tree before
## [member Node3D.global_position] means anything.
func spawn_fish(fish: FishInstance, parent: Node) -> BattleFish:
	var battler := BattleFish.spawn(fish)
	if battler == null:
		return null
	battler.team = team
	battler.tint = tint
	parent.add_child(battler)
	battler.global_position = global_position
	return battler
