extends Control
class_name UIInventory

signal item_requested_equip(item: ItemInstance)

const CELL_SIZE    := 16
const PREVIEW_W    := 140
const GRID_GAP     := 8

const COLOR_BG        := Color(0.08, 0.12, 0.08, 1.0)
const COLOR_GRID_LINE := Color(0.18, 0.28, 0.18, 1.0)
const COLOR_ITEM      := Color(0.20, 0.55, 0.20, 0.90)
const COLOR_HELD_OK   := Color(0.35, 0.75, 0.35, 0.80)
const COLOR_HELD_BAD  := Color(0.75, 0.18, 0.18, 0.80)

@onready var _name_label:  Label = $ItemPreview/Name
@onready var _stats_label: Label = $ItemPreview/Stats

var inventory: Inventory
var _default_icon: Texture2D = preload("res://icon.svg")

# Layout – computed once in _ready()
var _grid_offset: Vector2

# Drag state
var _held_item:    ItemInstance = null
var _grab_offset:  Vector2i    = Vector2i.ZERO   # clicked cell relative to item top-left
var _origin_pos:   Vector2i    = Vector2i.ZERO   # grid pos before drag
var _origin_rot:   bool        = false           # rotated state before drag

# Mouse tracking
var _mouse_pos:     Vector2  = Vector2.ZERO
var _hovered_cell:  Vector2i = Vector2i(-1, -1)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func bind_inventory(inv: Inventory) -> void:
	inventory = inv

func _ready() -> void:
	var grid_px := Vector2(inventory.width, inventory.height) * CELL_SIZE
	var panel_w := grid_px.x + GRID_GAP + PREVIEW_W
	var vp      := get_viewport_rect().size
	_grid_offset = Vector2(floor((vp.x - panel_w) / 2.0), floor((vp.y - grid_px.y) / 2.0))
	$ItemPreview.position = Vector2(_grid_offset.x + grid_px.x + GRID_GAP, _grid_offset.y)
	($ItemPreview as Control).size = Vector2(PREVIEW_W, grid_px.y)

func open() -> void:
	_held_item = null
	_clear_preview()
	visible = true
	queue_redraw()

func close() -> void:
	if _held_item != null:
		_cancel_drag()
	visible = false
	_clear_preview()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if inventory == null:
		return
	_draw_grid()
	_draw_items()
	_draw_held()

func _draw_grid() -> void:
	var w := inventory.width
	var h := inventory.height
	var px := Vector2(w, h) * CELL_SIZE
	draw_rect(Rect2(_grid_offset, px), COLOR_BG)
	for x in range(w + 1):
		var xp := _grid_offset.x + x * CELL_SIZE
		draw_line(Vector2(xp, _grid_offset.y), Vector2(xp, _grid_offset.y + px.y), COLOR_GRID_LINE)
	for y in range(h + 1):
		var yp := _grid_offset.y + y * CELL_SIZE
		draw_line(Vector2(_grid_offset.x, yp), Vector2(_grid_offset.x + px.x, yp), COLOR_GRID_LINE)

func _draw_items() -> void:
	for item in inventory.items:
		_draw_item(item, _grid_offset + Vector2(item.position) * CELL_SIZE, COLOR_ITEM)

func _draw_held() -> void:
	if _held_item == null:
		return
	var placement := _placement_cell()
	var draw_pos: Vector2
	if placement == Vector2i(-1, -1):
		# Outside grid – draw centred on cursor with grab offset
		draw_pos = _mouse_pos - Vector2(_grab_offset) * CELL_SIZE
	else:
		draw_pos = _grid_offset + Vector2(placement) * CELL_SIZE
	var ok := placement != Vector2i(-1, -1) and inventory.can_place(_held_item, placement)
	_draw_item(_held_item, draw_pos, COLOR_HELD_OK if ok else COLOR_HELD_BAD)

func _draw_item(item: ItemInstance, pos: Vector2, color: Color) -> void:
	var fp   := Vector2(item.get_footprint()) * CELL_SIZE
	var rect := Rect2(pos, fp)
	draw_rect(rect, color)
	draw_rect(rect, COLOR_GRID_LINE, false)
	var icon: Texture2D = item.data.icon if item.data.icon else _default_icon
	var s    := minf(fp.x, fp.y) - 2.0
	draw_texture_rect(icon, Rect2(pos + (fp - Vector2(s, s)) * 0.5, Vector2(s, s)), false)

# ── Input ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos    = event.position
		_hovered_cell = _cell_at(event.position)
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed:
		var cell := _cell_at(event.position)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _held_item != null:
					_try_drop(cell)
				else:
					_try_pickup(cell)
			MOUSE_BUTTON_RIGHT:
				if _held_item != null:
					_rotate_held()
				else:
					_rotate_at(cell)

	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _held_item != null:
			_try_drop(_cell_at(event.position))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") and _held_item != null:
		emit_signal("item_requested_equip", _held_item)
		_held_item = null
		_clear_preview()

# ── Drag helpers ──────────────────────────────────────────────────────────────

func _try_pickup(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		return
	var item := _item_at(cell)
	if item == null:
		return
	_origin_pos  = item.position
	_origin_rot  = item.rotated
	_grab_offset = cell - item.position
	inventory.items.erase(item)
	_held_item = item
	_show_preview(item)
	queue_redraw()

func _try_drop(cell: Vector2i) -> void:
	var placement := _placement_cell()
	if placement != Vector2i(-1, -1) and inventory.can_place(_held_item, placement):
		inventory.place_item(_held_item, placement)
		_held_item = null
		_clear_preview()
	# else: keep dragging – don't snap back until they release outside
	queue_redraw()

func _cancel_drag() -> void:
	_held_item.rotated = _origin_rot
	inventory.place_item(_held_item, _origin_pos)
	_held_item = null

func _rotate_held() -> void:
	if _held_item == null or not _held_item.data.rotatable:
		return
	_held_item.rotated = not _held_item.rotated
	# Adjust grab offset so cursor stays over the same logical corner
	_grab_offset = Vector2i(_grab_offset.y, _held_item.get_footprint().y - 1 - _grab_offset.x)
	queue_redraw()

func _rotate_at(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		return
	var item := _item_at(cell)
	if item != null:
		inventory.rotate_item(item)
		queue_redraw()

func _placement_cell() -> Vector2i:
	if _hovered_cell == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	return _hovered_cell - _grab_offset

# ── Helpers ───────────────────────────────────────────────────────────────────

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
		var fp := item.get_footprint()
		if cell.x >= item.position.x and cell.x < item.position.x + fp.x \
		and cell.y >= item.position.y and cell.y < item.position.y + fp.y:
			return item
	return null

func _show_preview(item: ItemInstance) -> void:
	_name_label.text = item.data.name
	if item is FishInstance:
		_stats_label.text = "Size:    %.2f\nWeight: %.2f\nQuality: %d\nValue:   %d" % [
			item.size, item.weight, item.quality, item.get_value()
		]
	elif item is RodInstance:
		_stats_label.text = "Durability:\n%.0f / %.0f" % [item.durability, item.data.durability_max]
	else:
		_stats_label.text = ""

func _clear_preview() -> void:
	_name_label.text  = ""
	_stats_label.text = ""
