extends Control
class_name UIHands

## View of what the player is holding, in two parts:
##   - the small HANDS slot panel, pinned bottom-right
##   - two big Sprite2D viewmodels of the held items, at the bottom screen edges
## Purely a view: it never mutates the Hands resource. UIInventory drives
## drag/drop into the slot panel via slot_at().

const SLOT_SIZE := 28
const GAP       := 4
const PAD       := 3
const TITLE_H   := 10
const MARGIN    := 6

const SLOT_LABELS := ["L", "R"]

# Viewmodel: the big Sprite2D of what each hand holds, down at the screen edges
const VIEW_H      := 84.0   # on-screen sprite height, in viewport pixels
const EDGE_MARGIN := 10.0   # left sprite's gap from the screen edge
const PANEL_GAP   := 6.0    # right sprite's gap from the HANDS panel
const SINK        := 14.0   # how far the sprites hang below the bottom edge

# Panel colors
const C_PANEL_BG     := Color(0.09, 0.13, 0.09, 0.97)
const C_PANEL_BORDER := Color(0.32, 0.48, 0.28, 1.00)
const C_TITLE_BG     := Color(0.13, 0.20, 0.11, 1.00)
const C_TITLE_TEXT   := Color(0.55, 0.80, 0.45, 1.00)
# Slot colors
const C_CELL         := Color(0.05, 0.08, 0.05, 1.00)
const C_SLOT_BORDER  := Color(0.22, 0.34, 0.18, 1.00)
const C_SLOT_HL      := Color(0.42, 0.86, 0.44, 1.00)
const C_SLOT_LABEL   := Color(0.30, 0.44, 0.26, 1.00)
# Durability bar
const C_BAR_BG       := Color(0.05, 0.08, 0.05, 1.00)
const C_BAR_FG       := Color(0.36, 0.74, 0.34, 1.00)

var hands: Hands = null

@onready var _viewmodels: Array[Sprite2D] = [$LeftHand as Sprite2D, $RightHand as Sprite2D]

var _default_icon: Texture2D = preload("res://icon.svg")
var _highlight: int = -1
var _viewmodel_visible: bool = true

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func bind_hands(h: Hands) -> void:
	if hands != null and hands.changed.is_connected(_on_hands_changed):
		hands.changed.disconnect(_on_hands_changed)
	hands = h
	if hands != null:
		hands.changed.connect(_on_hands_changed)
	_on_hands_changed()

func _ready() -> void:
	# The panel is HUD only — never swallow clicks meant for the world/inventory.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_on_hands_changed)
	_on_hands_changed()

func _on_hands_changed() -> void:
	queue_redraw()
	_refresh_viewmodels()

## Highlight a slot (drop target / hover). -1 clears it.
func set_highlight(slot: int) -> void:
	if slot == _highlight:
		return
	_highlight = slot
	queue_redraw()

## Hide the big hand sprites — e.g. while the inventory dims the whole screen.
func set_viewmodel_visible(value: bool) -> void:
	if value == _viewmodel_visible:
		return
	_viewmodel_visible = value
	_refresh_viewmodels()

# ── Viewmodel ─────────────────────────────────────────────────────────────────

func _refresh_viewmodels() -> void:
	# bind_hands() runs before the node enters the tree, so @onready isn't set yet
	if not is_node_ready() or hands == null:
		return
	for slot in Hands.SLOT_COUNT:
		_update_viewmodel(slot)

func _update_viewmodel(slot: int) -> void:
	var sprite := _viewmodels[slot]
	var item   := hands.get_item(slot)
	if item == null or not _viewmodel_visible:
		sprite.visible = false
		return

	sprite.texture = item.data.icon if item.data.icon else _default_icon
	var tex_size := sprite.texture.get_size()
	if tex_size.y <= 0.0:
		sprite.visible = false
		return

	sprite.scale    = Vector2.ONE * (VIEW_H / tex_size.y)
	sprite.position = _viewmodel_position(slot, tex_size.x * sprite.scale.x)
	sprite.visible  = true

func _viewmodel_position(slot: int, width: float) -> Vector2:
	var vp := get_viewport_rect().size
	var y  := vp.y - VIEW_H * 0.5 + SINK
	if slot == Hands.Slot.LEFT:
		return Vector2(EDGE_MARGIN + width * 0.5, y)
	# The right hand tucks inboard of the HANDS panel so the two never overlap
	return Vector2(_panel_origin().x - PANEL_GAP - width * 0.5, y)

# ── Layout ────────────────────────────────────────────────────────────────────

func _panel_size() -> Vector2:
	var inner := Hands.SLOT_COUNT * SLOT_SIZE + (Hands.SLOT_COUNT - 1) * GAP
	return Vector2(PAD + inner + PAD, TITLE_H + PAD + SLOT_SIZE + PAD)

func _panel_origin() -> Vector2:
	return (get_viewport_rect().size - _panel_size() - Vector2(MARGIN, MARGIN)).floor()

func get_slot_rect(slot: int) -> Rect2:
	var origin := _panel_origin() + Vector2(PAD, TITLE_H + PAD)
	origin.x += slot * (SLOT_SIZE + GAP)
	return Rect2(origin, Vector2(SLOT_SIZE, SLOT_SIZE))

## Hand slot under `pos` (this control's local space), or -1.
func slot_at(pos: Vector2) -> int:
	if hands == null:
		return -1
	for i in Hands.SLOT_COUNT:
		if get_slot_rect(i).has_point(pos):
			return i
	return -1

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if hands == null:
		return
	_draw_panel()
	for i in Hands.SLOT_COUNT:
		_draw_slot(i)

func _draw_panel() -> void:
	var r := Rect2(_panel_origin(), _panel_size())
	# Drop shadow
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, C_PANEL_BG)
	# Title bar
	draw_rect(Rect2(r.position, Vector2(r.size.x, TITLE_H)), C_TITLE_BG)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(PAD, TITLE_H - 3), "HANDS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, C_TITLE_TEXT)
	draw_line(Vector2(r.position.x, r.position.y + TITLE_H),
		Vector2(r.position.x + r.size.x, r.position.y + TITLE_H), C_PANEL_BORDER)
	# Outer border last so it sits on top
	draw_rect(r, C_PANEL_BORDER, false)

func _draw_slot(slot: int) -> void:
	var r    := get_slot_rect(slot)
	var item := hands.get_item(slot)
	draw_rect(r, C_CELL)

	if item != null:
		var icon: Texture2D = item.data.icon if item.data.icon else _default_icon
		var s := r.size.x - 8.0
		draw_texture_rect(icon, Rect2(r.position + Vector2(4, 3), Vector2(s, s)), false)
		if item is RodInstance:
			_draw_durability(r, item as RodInstance)

	# Hand letter, always visible so empty slots still read as L / R
	draw_string(ThemeDB.fallback_font, r.position + Vector2(2, 7), SLOT_LABELS[slot],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 6, C_SLOT_LABEL)
	draw_rect(r, C_SLOT_HL if slot == _highlight else C_SLOT_BORDER, false)

func _draw_durability(r: Rect2, rod: RodInstance) -> void:
	var rod_data := rod.data as RodData
	if rod_data == null or rod_data.durability_max <= 0.0:
		return
	var bar := Rect2(r.position + Vector2(2, r.size.y - 4), Vector2(r.size.x - 4, 2))
	draw_rect(bar, C_BAR_BG)
	var ratio := clampf(rod.durability / rod_data.durability_max, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), C_BAR_FG)
