class_name HandsViewmodel
extends Node3D

## First-person view of what the player is holding, in the world rather than on
## the HUD: the item's own 3D model, parented to the camera so it rides along
## with the view and takes the scene's lighting and the pixel/edge post-process.
##
## Fish are scaled by their real caught length, using the same unit convention
## as Fish._apply_random_scale().
##
## The LeftHand / RightHand anchors are plain Node3Ds in Player.tscn — move or
## rotate them in the editor to pose the hands.

const MODEL_SCALE   := 0.15  # matches Fish.gd
const MIN_FISH_SIZE := 0.1   # keeps a zero-size fish (unset min/max) visible
const ROD_SCENE: PackedScene = preload("res://objects/Rod.tscn")

## Side of the square screen-space drop target, in viewport pixels
const DROP_SIZE := 48.0

var hands: Hands = null

@onready var _anchors: Array[Node3D] = [$LeftHand as Node3D, $RightHand as Node3D]

var _camera: Camera3D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func bind_hands(h: Hands, camera: Camera3D) -> void:
	if hands != null and hands.changed.is_connected(_rebuild):
		hands.changed.disconnect(_rebuild)
	hands = h
	_camera = camera
	if hands != null:
		hands.changed.connect(_rebuild)
	_rebuild()

func _ready() -> void:
	_rebuild()

# ── Building the held models ──────────────────────────────────────────────────

func _rebuild() -> void:
	# bind_hands() can run before the node is in the tree, so @onready isn't set
	if not is_node_ready() or hands == null:
		return
	for slot in Hands.SLOT_COUNT:
		_rebuild_slot(slot)

func _rebuild_slot(slot: int) -> void:
	var anchor := _anchors[slot]
	for child in anchor.get_children():
		anchor.remove_child(child)
		child.queue_free()

	var visual := _make_visual(hands.get_item(slot))
	if visual != null:
		anchor.add_child(visual)

func _make_visual(item: ItemInstance) -> Node3D:
	if item is FishInstance:
		return _make_fish_visual(item as FishInstance)
	if item is RodInstance:
		var node := ROD_SCENE.instantiate() as Node3D
		var rod  := node as Rod
		if rod != null:
			rod._update_rod(item as RodInstance)
		return node
	return null

func _make_fish_visual(fish: FishInstance) -> Node3D:
	var fish_data := fish.data as FishData
	if fish_data == null or fish_data.mesh == null:
		return null
	# A holder keeps the scale off the model scene, which may carry its own
	var holder := Node3D.new()
	holder.add_child(fish_data.mesh.instantiate())
	holder.scale = Vector3.ONE * maxf(fish.size, MIN_FISH_SIZE) * MODEL_SCALE
	return holder

# ── Screen-space drop targets ─────────────────────────────────────────────────

## Where a hand lands on screen. Empty when it is behind the camera or the
## viewmodel is not set up yet.
func get_screen_rect(slot: int) -> Rect2:
	if _camera == null or not is_node_ready():
		return Rect2()
	var origin := _anchors[slot].global_position
	if _camera.is_position_behind(origin):
		return Rect2()
	var half := Vector2(DROP_SIZE, DROP_SIZE) * 0.5
	return Rect2(_camera.unproject_position(origin) - half, half * 2.0)

## Hand under `pos` (viewport coordinates), or -1.
func slot_at(pos: Vector2) -> int:
	if hands == null:
		return -1
	for i in Hands.SLOT_COUNT:
		var r := get_screen_rect(i)
		if r.size.x > 0.0 and r.has_point(pos):
			return i
	return -1
