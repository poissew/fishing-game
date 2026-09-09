extends Control
class_name UIHands

## The player's hands, shown as two Sprite2D viewmodels at the bottom corners of
## the screen. A fish is drawn at a size derived from its actual length, so a
## big catch looks big and a sardine looks tiny.
##
## Purely a view: it never mutates the Hands resource. While the inventory is
## dragging an item, UIInventory hit-tests slot_at() and asks for a drop hint,
## which is the only thing this node ever draws itself.

# Sprite sizing, in viewport pixels
const BASE_H   := 84.0  # height of a non-fish item, and of a REF_SIZE fish
const MIN_H    := 30.0
const MAX_H    := 150.0
const REF_SIZE := 1.0   # fish length (same unit as FishData) drawn at BASE_H

const EDGE_MARGIN := 10.0  # gap from the screen's left / right edge
const SINK        := 14.0  # how far the sprites hang below the bottom edge

const SLOT_LABELS := ["L", "R"]

# Drop-hint colors — only ever visible mid-drag
const C_ZONE_FILL     := Color(0.30, 0.70, 0.32, 0.22)
const C_ZONE_FILL_DIM := Color(0.05, 0.08, 0.05, 0.35)
const C_ZONE_LINE     := Color(0.42, 0.86, 0.44, 1.00)
const C_ZONE_LINE_DIM := Color(0.22, 0.34, 0.18, 1.00)
const C_ZONE_LABEL    := Color(0.30, 0.44, 0.26, 1.00)

var hands: Hands = null

@onready var _sprites: Array[Sprite2D] = [$LeftHand as Sprite2D, $RightHand as Sprite2D]

var _default_icon: Texture2D = preload("res://icon.svg")
var _drag_active: bool = false
var _highlight:   int  = -1

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func bind_hands(h: Hands) -> void:
	if hands != null and hands.changed.is_connected(_on_hands_changed):
		hands.changed.disconnect(_on_hands_changed)
	hands = h
	if hands != null:
		hands.changed.connect(_on_hands_changed)
	_on_hands_changed()

func _ready() -> void:
	# HUD only — never swallow clicks meant for the world or the inventory.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_on_hands_changed)
	_on_hands_changed()

func _on_hands_changed() -> void:
	queue_redraw()
	_refresh_sprites()

## Show where a dragged item can be dropped. `slot` is the hovered hand, or -1.
func set_drop_hint(active: bool, slot: int) -> void:
	if active == _drag_active and slot == _highlight:
		return
	_drag_active = active
	_highlight   = slot
	queue_redraw()

# ── Layout ────────────────────────────────────────────────────────────────────

## Fixed-size drop target for a hand, whatever it currently holds — an empty
## hand still needs somewhere to drop onto.
func get_slot_rect(slot: int) -> Rect2:
	var vp  := get_viewport_rect().size
	var top := vp.y + SINK - BASE_H
	var x   := EDGE_MARGIN if slot == Hands.Slot.LEFT else vp.x - EDGE_MARGIN - BASE_H
	return Rect2(Vector2(x, top), Vector2(BASE_H, BASE_H))

## Hand under `pos` (this control's local space), or -1.
func slot_at(pos: Vector2) -> int:
	if hands == null:
		return -1
	for i in Hands.SLOT_COUNT:
		if get_slot_rect(i).has_point(pos):
			return i
	return -1

# ── Sprites ───────────────────────────────────────────────────────────────────

func _refresh_sprites() -> void:
	# bind_hands() runs before the node enters the tree, so @onready isn't set yet
	if not is_node_ready() or hands == null:
		return
	for slot in Hands.SLOT_COUNT:
		_update_sprite(slot)

func _update_sprite(slot: int) -> void:
	var sprite := _sprites[slot]
	var item   := hands.get_item(slot)
	if item == null:
		sprite.visible = false
		return

	sprite.texture = item.data.icon if item.data.icon else _default_icon
	var tex_size := sprite.texture.get_size()
	if tex_size.y <= 0.0:
		sprite.visible = false
		return

	var h := _sprite_height(item)
	sprite.scale = Vector2.ONE * (h / tex_size.y)
	# Bottom-aligned on a shared baseline, so a bigger fish grows upward
	var w  := tex_size.x * sprite.scale.x
	var vp := get_viewport_rect().size
	var x  := EDGE_MARGIN + w * 0.5 if slot == Hands.Slot.LEFT else vp.x - EDGE_MARGIN - w * 0.5
	sprite.position = Vector2(x, vp.y + SINK - h * 0.5)
	sprite.visible  = true

## On-screen height for an item. Fish scale with their real length; the square
## root keeps a 9.8m shark from dwarfing a 0.2m sardine by 49x.
func _sprite_height(item: ItemInstance) -> float:
	if not (item is FishInstance):
		return BASE_H
	var fish := item as FishInstance
	if fish.size <= 0.0:
		return BASE_H
	return clampf(BASE_H * sqrt(fish.size / REF_SIZE), MIN_H, MAX_H)

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if hands == null or not _drag_active:
		return
	var font := ThemeDB.fallback_font
	for slot in Hands.SLOT_COUNT:
		var r  := get_slot_rect(slot)
		var on := slot == _highlight
		draw_rect(r, C_ZONE_FILL if on else C_ZONE_FILL_DIM)
		draw_rect(r, C_ZONE_LINE if on else C_ZONE_LINE_DIM, false)
		draw_string(font, r.position + Vector2(3, 9), SLOT_LABELS[slot],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_ZONE_LABEL)
