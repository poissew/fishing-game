extends Control
class_name UIInventory

signal item_requested_equip(item: ItemInstance)

const CELL_SIZE := 16
const GRID_OFFSET := Vector2(4.0, 4.0)

const COLOR_BG        := Color(0.08, 0.12, 0.08, 1.0)
const COLOR_GRID_LINE := Color(0.18, 0.28, 0.18, 1.0)
const COLOR_ITEM      := Color(0.20, 0.55, 0.20, 0.90)
const COLOR_HELD      := Color(0.35, 0.75, 0.35, 0.85)
const COLOR_INVALID   := Color(0.75, 0.18, 0.18, 0.80)

@onready var _name_label: Label = $ItemPreview/Name
@onready var _stats_label: Label = $ItemPreview/Stats

var inventory: Inventory
var held_item: ItemInstance = null
var _mouse_pos: Vector2 = Vector2.ZERO
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _default_icon: Texture2D = preload("res://icon.svg")

func bind_inventory(inv: Inventory) -> void:
	inventory = inv

func open() -> void:
	held_item = null
	_clear_preview()
	visible = true
	queue_redraw()

func close() -> void:
	if held_item != null:
		inventory.add_or_place(held_item)
		held_item = null
	visible = false
	_clear_preview()

# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	if inventory == null:
		return
	_draw_background()
	_draw_items()
	_draw_held_item()

func _draw_background() -> void:
	var size := Vector2(inventory.width, inventory.height) * CELL_SIZE
	draw_rect(Rect2(GRID_OFFSET, size), COLOR_BG)
	for x in range(inventory.width + 1):
		var x_px := GRID_OFFSET.x + x * CELL_SIZE
		draw_line(Vector2(x_px, GRID_OFFSET.y),
				  Vector2(x_px, GRID_OFFSET.y + size.y), COLOR_GRID_LINE)
	for y in range(inventory.height + 1):
		var y_px := GRID_OFFSET.y + y * CELL_SIZE
		draw_line(Vector2(GRID_OFFSET.x, y_px),
				  Vector2(GRID_OFFSET.x + size.x, y_px), COLOR_GRID_LINE)

func _draw_items() -> void:
	for item in inventory.items:
		_draw_item_at(item, Vector2(item.position) * CELL_SIZE + GRID_OFFSET, COLOR_ITEM)

func _draw_held_item() -> void:
	if held_item == null:
		return
	var cell := _hovered_cell
	var draw_pos: Vector2
	if cell == Vector2i(-1, -1):
		draw_pos = _mouse_pos
	else:
		draw_pos = Vector2(cell) * CELL_SIZE + GRID_OFFSET
	var color := COLOR_HELD if (cell == Vector2i(-1, -1) or inventory.can_place(held_item, cell)) else COLOR_INVALID
	_draw_item_at(held_item, draw_pos, color)

func _draw_item_at(item: ItemInstance, pos: Vector2, color: Color) -> void:
	var fp := Vector2(item.get_footprint()) * CELL_SIZE
	var rect := Rect2(pos, fp)
	draw_rect(rect, color)
	draw_rect(rect, COLOR_GRID_LINE, false)
	var icon: Texture2D = item.data.icon if item.data.icon else _default_icon
	var icon_size := minf(fp.x, fp.y) - 2.0
	var icon_rect := Rect2(pos + (fp - Vector2(icon_size, icon_size)) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(icon, icon_rect, false)

# ── Input ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos = event.position
		_hovered_cell = _get_cell_at(event.position)
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_handle_left_click(_get_cell_at(event.position))
			MOUSE_BUTTON_RIGHT:
				if held_item != null:
					inventory.rotate_item(held_item)
					queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") and held_item != null:
		emit_signal("item_requested_equip", held_item)
		held_item = null
		_clear_preview()

func _handle_left_click(cell: Vector2i) -> void:
	if held_item != null:
		if cell != Vector2i(-1, -1) and inventory.can_place(held_item, cell):
			inventory.place_item(held_item, cell)
			held_item = null
			_clear_preview()
	else:
		if cell != Vector2i(-1, -1):
			var item := _get_item_at(cell)
			if item != null:
				inventory.items.erase(item)
				held_item = item
				_show_preview(item)
	queue_redraw()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_cell_at(pos: Vector2) -> Vector2i:
	var rel := pos - GRID_OFFSET
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var cell := Vector2i(int(rel.x / CELL_SIZE), int(rel.y / CELL_SIZE))
	if cell.x >= inventory.width or cell.y >= inventory.height:
		return Vector2i(-1, -1)
	return cell

func _get_item_at(cell: Vector2i) -> ItemInstance:
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
		_stats_label.text = "Durability: %.0f / %.0f" % [item.durability, item.data.durability_max]
	else:
		_stats_label.text = ""

func _clear_preview() -> void:
	_name_label.text = ""
	_stats_label.text = ""
