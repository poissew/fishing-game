extends Control
class_name UIInventory

signal item_requested_equip(item: ItemInstance)

const CELL_SIZE  := 16
const PREVIEW_W  := 140
const GRID_GAP   := 8
const PAD        := 4
const TITLE_H    := 12

# Panel colors
const C_PANEL_BG     := Color(0.09, 0.13, 0.09, 0.97)
const C_PANEL_BORDER := Color(0.32, 0.48, 0.28, 1.00)
const C_TITLE_BG     := Color(0.13, 0.20, 0.11, 1.00)
const C_TITLE_TEXT   := Color(0.55, 0.80, 0.45, 1.00)
const C_SEP          := Color(0.22, 0.34, 0.18, 1.00)
# Grid colors
const C_CELL         := Color(0.05, 0.08, 0.05, 1.00)
const C_GRID_LINE    := Color(0.14, 0.20, 0.12, 1.00)
# Item colors
const C_ITEM         := Color(0.16, 0.46, 0.18, 0.92)
const C_ITEM_HOVER   := Color(0.22, 0.60, 0.24, 0.92)
const C_ITEM_BORDER  := Color(0.28, 0.68, 0.30, 1.00)
const C_HELD_OK      := Color(0.30, 0.70, 0.32, 0.88)
const C_HELD_BAD     := Color(0.72, 0.16, 0.14, 0.88)

@onready var _name_label:  Label = $ItemPreview/Name
@onready var _stats_label: Label = $ItemPreview/Stats

var inventory:     Inventory
var hands:         Hands   = null
var _hands_ui:     UIHands = null
var _default_icon: Texture2D = preload("res://icon.svg")

# Layout – computed in _ready()
var _grid_offset: Vector2
var _panel_rect:  Rect2

# Drag state
var _held_item:   ItemInstance = null
var _grab_offset: Vector2i    = Vector2i.ZERO
var _origin_pos:  Vector2i    = Vector2i.ZERO
var _origin_rot:  bool        = false
# Hand slot the drag started from, or -1 when it came from the grid
var _held_from_hand: int      = -1

# Mouse
var _mouse_pos:    Vector2  = Vector2.ZERO
var _hovered_cell: Vector2i = Vector2i(-1, -1)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func bind_inventory(inv: Inventory) -> void:
	inventory = inv

func bind_hands(h: Hands, ui: UIHands) -> void:
	hands = h
	_hands_ui = ui

func _ready() -> void:
	var grid_px  := Vector2(inventory.width, inventory.height) * CELL_SIZE
	var panel_w  := PAD + grid_px.x + GRID_GAP + PREVIEW_W + PAD
	var panel_h  := TITLE_H + PAD + grid_px.y + PAD
	var vp       := get_viewport_rect().size
	var panel_xy := Vector2(floor((vp.x - panel_w) / 2.0), floor((vp.y - panel_h) / 2.0))
	_panel_rect  = Rect2(panel_xy, Vector2(panel_w, panel_h))
	_grid_offset = panel_xy + Vector2(PAD, TITLE_H + PAD)

	var preview := $ItemPreview as Control
	preview.position = _grid_offset + Vector2(grid_px.x + GRID_GAP, 0)
	preview.size     = Vector2(PREVIEW_W, grid_px.y)

func open() -> void:
	_held_item = null
	_clear_preview()
	visible = true
	queue_redraw()

func close() -> void:
	if _held_item != null:
		_cancel_drag()
	visible = false
	_update_drop_hint()
	_clear_preview()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if inventory == null:
		return
	_draw_panel()
	_draw_grid()
	_draw_items()
	_draw_held()

func _draw_panel() -> void:
	var r := _panel_rect
	# Drop shadow
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.45))
	# Panel background
	draw_rect(r, C_PANEL_BG)
	# Title bar
	var title_r := Rect2(r.position, Vector2(r.size.x, TITLE_H))
	draw_rect(title_r, C_TITLE_BG)
	# Title text
	var font := ThemeDB.fallback_font
	draw_string(font, r.position + Vector2(PAD, TITLE_H - 2), "INVENTORY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_TITLE_TEXT)
	# Hint text right-aligned
	draw_string(font, r.position + Vector2(r.size.x - PAD, TITLE_H - 2),
		"RMB: rotate  |  E / drag to hands: equip",
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 6, C_SEP)
	# Separator under title
	draw_line(Vector2(r.position.x, r.position.y + TITLE_H),
		Vector2(r.position.x + r.size.x, r.position.y + TITLE_H), C_PANEL_BORDER)
	# Vertical separator between grid and preview
	var sep_x := _grid_offset.x + inventory.width * CELL_SIZE + GRID_GAP * 0.5
	draw_line(Vector2(sep_x, _grid_offset.y),
		Vector2(sep_x, _grid_offset.y + inventory.height * CELL_SIZE), C_SEP)
	# Outer border (drawn last so it's on top)
	draw_rect(r, C_PANEL_BORDER, false)

func _draw_grid() -> void:
	var grid_px := Vector2(inventory.width, inventory.height) * CELL_SIZE
	draw_rect(Rect2(_grid_offset, grid_px), C_CELL)
	for x in range(inventory.width + 1):
		var xp := _grid_offset.x + x * CELL_SIZE
		draw_line(Vector2(xp, _grid_offset.y),
			Vector2(xp, _grid_offset.y + grid_px.y), C_GRID_LINE)
	for y in range(inventory.height + 1):
		var yp := _grid_offset.y + y * CELL_SIZE
		draw_line(Vector2(_grid_offset.x, yp),
			Vector2(_grid_offset.x + grid_px.x, yp), C_GRID_LINE)

func _draw_items() -> void:
	for item in inventory.items:
		var hovered := _held_item == null and _is_cell_over_item(_hovered_cell, item)
		var color   := C_ITEM_HOVER if hovered else C_ITEM
		_draw_item(item, _grid_offset + Vector2(item.position) * CELL_SIZE, color)

func _draw_held() -> void:
	if _held_item == null:
		return
	var placement := _placement_for(_hovered_cell)
	var draw_pos: Vector2
	if placement == Vector2i(-1, -1):
		draw_pos = _mouse_pos - Vector2(_grab_offset) * CELL_SIZE
	else:
		draw_pos = _grid_offset + Vector2(placement) * CELL_SIZE
	var ok := placement != Vector2i(-1, -1) and inventory.can_place(_held_item, placement)
	if not ok:
		ok = _can_drop_in_hand(_hand_slot_at_mouse())
	_draw_item(_held_item, draw_pos, C_HELD_OK if ok else C_HELD_BAD)

func _draw_item(item: ItemInstance, pos: Vector2, color: Color) -> void:
	var fp   := Vector2(item.get_footprint()) * CELL_SIZE
	var rect := Rect2(pos, fp)
	draw_rect(rect.grow(-1), color)
	draw_rect(rect, C_ITEM_BORDER if color == C_ITEM or color == C_ITEM_HOVER else color.lightened(0.25), false)
	var icon: Texture2D = item.data.icon if item.data.icon else _default_icon
	var s    := minf(fp.x, fp.y) - 4.0
	if s > 0:
		draw_texture_rect(icon, Rect2(pos + (fp - Vector2(s, s)) * 0.5, Vector2(s, s)), false)

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return

	var mpos := get_local_mouse_position()

	if event is InputEventMouseMotion:
		_mouse_pos    = mpos
		_hovered_cell = _cell_at(mpos)
		var hand_slot := _hand_slot_at_mouse()
		_update_drop_hint()
		if _held_item == null:
			var hand_item: ItemInstance = hands.get_item(hand_slot) if hands != null else null
			if hand_item != null:
				_show_preview(hand_item)
			else:
				_clear_preview()
		queue_redraw()
		return

	if event is InputEventMouseButton:
		var cell := _cell_at(mpos)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_pickup(cell)
			elif _held_item != null:
				_try_drop(_cell_at(mpos))
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _held_item != null:
				_rotate_held()
			else:
				_rotate_at(cell)
		return

	if event.is_action_pressed("interact") and _held_item != null:
		_equip_held()

# ── Drag helpers ──────────────────────────────────────────────────────────────

func _try_pickup(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		_try_pickup_hand()
		return
	var item := _item_at(cell)
	if item == null:
		return
	_origin_pos     = item.position
	_origin_rot     = item.rotated
	_grab_offset    = cell - item.position
	_held_from_hand = -1
	inventory.items.erase(item)
	_held_item = item
	_show_preview(item)
	_update_drop_hint()
	queue_redraw()

func _try_pickup_hand() -> void:
	var slot := _hand_slot_at_mouse()
	var item: ItemInstance = hands.get_item(slot) if hands != null else null
	if item == null:
		return
	_origin_pos     = item.position
	_origin_rot     = item.rotated
	_grab_offset    = Vector2i.ZERO
	_held_from_hand = slot
	hands.clear(slot)
	_held_item = item
	_show_preview(item)
	_update_drop_hint()
	queue_redraw()

func _try_drop(hovered: Vector2i) -> void:
	var slot := _hand_slot_at_mouse()
	if slot >= 0:
		if _drop_in_hand(slot):
			_release_held()
		else:
			_cancel_drag()
		queue_redraw()
		return

	var placement := _placement_for(hovered)
	if placement != Vector2i(-1, -1) and inventory.can_place(_held_item, placement):
		inventory.place_item(_held_item, placement)
		_release_held()
	else:
		_cancel_drag()
	queue_redraw()

## Put the held item in `slot`. What was there is swapped back into the hand the
## drag came from, or pushed into the inventory. Fails if neither is possible.
func _drop_in_hand(slot: int) -> bool:
	if hands == null:
		return false
	var displaced := hands.get_item(slot)
	if displaced != null:
		if _held_from_hand >= 0:
			hands.set_item(_held_from_hand, displaced)
		elif not inventory.add_or_place(displaced):
			return false
	# Hands have no orientation — an item put down in one keeps its own.
	_held_item.rotated = _origin_rot
	hands.set_item(slot, _held_item)
	return true

func _release_held() -> void:
	_held_item      = null
	_held_from_hand = -1
	_clear_preview()
	_update_drop_hint()

func _cancel_drag() -> void:
	_held_item.rotated = _origin_rot
	if _held_from_hand >= 0:
		hands.set_item(_held_from_hand, _held_item)
	elif not inventory.place_item(_held_item, _origin_pos):
		# Fallback: force back to avoid losing the item
		_held_item.position = _origin_pos
		inventory.items.append(_held_item)
	_held_item      = null
	_held_from_hand = -1
	_update_drop_hint()

## Hand the dragged item to the player. Clearing the drag first matters: the
## listener may close the inventory, which would otherwise cancel the drag and
## duplicate the item.
func _equip_held() -> void:
	var item := _held_item
	var from := _held_from_hand
	_release_held()
	item_requested_equip.emit(item)
	if hands != null and hands.slot_of(item) >= 0:
		return
	if inventory.items.has(item):
		return
	# Equip refused it — put it back where the drag started.
	if from >= 0 and hands != null:
		hands.set_item(from, item)
	else:
		item.rotated = _origin_rot
		if not inventory.place_item(item, _origin_pos):
			inventory.add_or_place(item)

func _rotate_held() -> void:
	if _held_item == null or not _held_item.data.rotatable:
		return
	# Capture old height BEFORE toggling — needed for the CW offset transform
	var old_h := _held_item.get_footprint().y
	_held_item.rotated = not _held_item.rotated
	# 90° CW: point (gx, gy) in (W × H) → (old_H - 1 - gy, gx) in (H × W)
	_grab_offset = Vector2i(old_h - 1 - _grab_offset.y, _grab_offset.x)
	queue_redraw()

func _rotate_at(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		return
	var item := _item_at(cell)
	if item != null:
		inventory.rotate_item(item)
		queue_redraw()

func _placement_for(hovered: Vector2i) -> Vector2i:
	if hovered == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	return hovered - _grab_offset

# ── Helpers ───────────────────────────────────────────────────────────────────

## Whether dropping the held item in `slot` would succeed — mirrors _drop_in_hand().
func _can_drop_in_hand(slot: int) -> bool:
	if hands == null or slot < 0 or _held_item == null:
		return false
	var displaced := hands.get_item(slot)
	return displaced == null or _held_from_hand >= 0 or inventory.has_space_for(displaced)

func _hand_slot_at_mouse() -> int:
	if _hands_ui == null or hands == null:
		return -1
	return _hands_ui.slot_at(_hands_ui.get_local_mouse_position())

## Ask UIHands to show its drop zones while a drag is in flight.
func _update_drop_hint() -> void:
	if _hands_ui != null:
		_hands_ui.set_drop_hint(_held_item != null, _hand_slot_at_mouse())

func _cell_at(pos: Vector2) -> Vector2i:
	var rel := pos - _grid_offset
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var cell := Vector2i(int(rel.x / CELL_SIZE), int(rel.y / CELL_SIZE))
	if cell.x >= inventory.width or cell.y >= inventory.height:
		return Vector2i(-1, -1)
	return cell

func _item_at(cell: Vector2i) -> ItemInstance:
	for item in inventory.items:
		if _is_cell_over_item(cell, item):
			return item
	return null

func _is_cell_over_item(cell: Vector2i, item: ItemInstance) -> bool:
	if cell == Vector2i(-1, -1):
		return false
	var fp := item.get_footprint()
	return cell.x >= item.position.x and cell.x < item.position.x + fp.x \
		and cell.y >= item.position.y and cell.y < item.position.y + fp.y

func _show_preview(item: ItemInstance) -> void:
	_name_label.text = item.data.name
	if item is FishInstance:
		_stats_label.text = "Size:    %.2f\nWeight:  %.2f\nQuality: %d\nValue:   %d" % [
			item.size, item.weight, item.quality, item.get_value()
		]
	elif item is RodInstance:
		_stats_label.text = "Durability:\n%.0f / %.0f" % [item.durability, item.data.durability_max]
	else:
		_stats_label.text = ""

func _clear_preview() -> void:
	_name_label.text  = ""
	_stats_label.text = ""
