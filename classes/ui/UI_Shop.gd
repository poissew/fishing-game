extends Control
class_name UIShop

## Placeholder shop panel. Like UIInventory it draws itself in _draw() instead
## of using child controls, so it stays legible at the game's 480x270 internal
## resolution. It also owns the always-on money counter and the "[E] talk"
## prompt, which is why the node stays visible when the panel is closed —
## `is_open` is what gates the panel and its input, not `visible`.

signal sell_requested(item: ItemInstance)
signal sell_all_requested()
signal close_requested()

const PANEL_W  := 260.0
const ROW_H    := 11.0
const ROWS     := 12
const PAD      := 4.0
const TITLE_H  := 12.0
const FOOTER_H := 16.0
const ICON     := 9.0

const FS_TITLE := 8
const FS_ROW   := 7

# Panel colors — same palette as the inventory
const C_PANEL_BG     := Color(0.09, 0.13, 0.09, 0.97)
const C_PANEL_BORDER := Color(0.32, 0.48, 0.28, 1.00)
const C_TITLE_BG     := Color(0.13, 0.20, 0.11, 1.00)
const C_TITLE_TEXT   := Color(0.55, 0.80, 0.45, 1.00)
const C_SEP          := Color(0.22, 0.34, 0.18, 1.00)
const C_DIM          := Color(0.00, 0.00, 0.00, 0.60)
# Rows
const C_ROW          := Color(0.05, 0.08, 0.05, 1.00)
const C_ROW_ALT      := Color(0.07, 0.11, 0.07, 1.00)
const C_ROW_HOVER    := Color(0.16, 0.46, 0.18, 0.92)
const C_TEXT         := Color(0.62, 0.80, 0.56, 1.00)
const C_TEXT_DIM     := Color(0.40, 0.55, 0.36, 1.00)
const C_MONEY        := Color(0.92, 0.82, 0.32, 1.00)
# Sell-all button
const C_BTN          := Color(0.16, 0.46, 0.18, 0.92)
const C_BTN_HOVER    := Color(0.22, 0.60, 0.24, 0.92)

var is_open: bool = false

var _wallet: Wallet     = null
var _keeper: Shopkeeper = null
var _nearby: Shopkeeper = null

var _default_icon: Texture2D = preload("res://icon.svg")

# Layout — computed in _ready()
var _panel_rect: Rect2
var _list_rect:  Rect2
var _btn_rect:   Rect2

# One entry per sellable carried item: {"item": ItemInstance, "price": int}
var _offers: Array[Dictionary] = []
var _scroll: int = 0
var _hovered: int = -1
var _btn_hovered: bool = false
var _mouse_pos: Vector2 = Vector2.ZERO

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func bind_wallet(wallet: Wallet) -> void:
	_wallet = wallet
	if _wallet != null and not _wallet.changed.is_connected(_on_wallet_changed):
		_wallet.changed.connect(_on_wallet_changed)

func _ready() -> void:
	var panel_h := TITLE_H + PAD + ROWS * ROW_H + PAD + FOOTER_H
	var vp := get_viewport_rect().size
	var xy := Vector2(floor((vp.x - PANEL_W) / 2.0), floor((vp.y - panel_h) / 2.0))
	_panel_rect = Rect2(xy, Vector2(PANEL_W, panel_h))
	_list_rect  = Rect2(xy + Vector2(PAD, TITLE_H + PAD),
		Vector2(PANEL_W - PAD * 2.0, ROWS * ROW_H))
	var btn_w := 56.0
	_btn_rect = Rect2(
		Vector2(xy.x + PANEL_W - PAD - btn_w, _list_rect.end.y + PAD + 1.0),
		Vector2(btn_w, FOOTER_H - 5.0))

## Shopkeeper the player is standing next to, or null. Drives the "[E]" prompt.
func set_nearby(keeper: Shopkeeper) -> void:
	_nearby = keeper
	queue_redraw()

func open(keeper: Shopkeeper, carried: Array[ItemInstance]) -> void:
	_keeper    = keeper
	_scroll    = 0
	_hovered   = -1
	_mouse_pos = get_local_mouse_position()
	is_open    = true
	refresh(carried)

func close() -> void:
	is_open = false
	_keeper = null
	_offers.clear()
	queue_redraw()

## Rebuild the offer list from what the player is carrying. Called on open and
## after every sale; priciest catch first.
func refresh(carried: Array[ItemInstance]) -> void:
	_offers.clear()
	if _keeper != null:
		for item in carried:
			var price := _keeper.offer_for(item)
			if price > 0:
				_offers.append({"item": item, "price": price})
		_offers.sort_custom(func(a, b): return int(a["price"]) > int(b["price"]))
	_scroll = clampi(_scroll, 0, maxi(0, _offers.size() - ROWS))
	_update_hover()
	queue_redraw()

func _on_wallet_changed() -> void:
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _wallet == null:
		return
	_draw_money()
	if is_open:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_DIM)
		_draw_panel()
		_draw_rows()
		_draw_footer()
	elif _nearby != null:
		_draw_prompt()

func _draw_money() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(6, 12), "$ %d" % _wallet.money,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_TITLE, C_MONEY)

func _draw_prompt() -> void:
	var font := ThemeDB.fallback_font
	var vp   := get_viewport_rect().size
	var text := "[E] %s" % _nearby.shop_name
	var w    := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_TITLE).x
	var pos  := Vector2(floor((vp.x - w) / 2.0), vp.y - 24.0)
	draw_rect(Rect2(pos + Vector2(-4, -9), Vector2(w + 8, 13)), C_PANEL_BG)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_TITLE, C_TITLE_TEXT)

func _draw_panel() -> void:
	var r := _panel_rect
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, C_PANEL_BG)
	draw_rect(Rect2(r.position, Vector2(r.size.x, TITLE_H)), C_TITLE_BG)
	var title: String = _keeper.shop_name.to_upper() if _keeper != null else "SHOP"
	draw_string(font, r.position + Vector2(PAD, TITLE_H - 3), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_TITLE, C_TITLE_TEXT)
	_draw_right(font, r.end.x - PAD, r.position.y + TITLE_H - 3,
		"$ %d" % _wallet.money, FS_TITLE, C_MONEY)
	draw_line(Vector2(r.position.x, r.position.y + TITLE_H),
		Vector2(r.end.x, r.position.y + TITLE_H), C_PANEL_BORDER)
	draw_rect(r, C_PANEL_BORDER, false)

func _draw_rows() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(_list_rect, C_ROW)
	if _offers.is_empty():
		draw_string(font, _list_rect.position + Vector2(PAD, 14),
			"Nothing to sell. Go catch something.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, C_TEXT_DIM)
		return

	for i in range(_scroll, mini(_scroll + ROWS, _offers.size())):
		var offer := _offers[i]
		var item  := offer["item"] as ItemInstance
		var rect  := _row_rect(i)
		var hover := i == _hovered
		draw_rect(rect, C_ROW_HOVER if hover else (C_ROW_ALT if i % 2 == 0 else C_ROW))

		var icon: Texture2D = item.data.icon if item.data.icon else _default_icon
		draw_texture_rect(icon,
			Rect2(rect.position + Vector2(1, (ROW_H - ICON) * 0.5), Vector2(ICON, ICON)), false)

		var base_y := rect.position.y + ROW_H - 3.0
		draw_string(font, Vector2(rect.position.x + ICON + 4.0, base_y), item.data.name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, C_TEXT)
		draw_string(font, Vector2(rect.position.x + 84.0, base_y), _describe(item),
			HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, C_TEXT_DIM)
		_draw_right(font, rect.end.x - 2.0, base_y, "$ %d" % int(offer["price"]),
			FS_ROW, C_MONEY)

func _draw_footer() -> void:
	var font := ThemeDB.fallback_font
	var base_y := _btn_rect.end.y - 3.0
	draw_string(font, Vector2(_panel_rect.position.x + PAD, base_y),
		"click a line to sell  |  E / Esc: leave",
		HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, C_SEP)
	if _offers.size() > ROWS:
		_draw_right(font, _btn_rect.position.x - 6.0, base_y,
			"%d-%d / %d" % [_scroll + 1, mini(_scroll + ROWS, _offers.size()), _offers.size()],
			FS_ROW, C_TEXT_DIM)
	draw_rect(_btn_rect, C_BTN_HOVER if _btn_hovered else C_BTN)
	draw_rect(_btn_rect, C_PANEL_BORDER, false)
	var label := "SELL ALL $%d" % _total_value()
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW).x
	draw_string(font, _btn_rect.position + Vector2((_btn_rect.size.x - w) * 0.5, ROW_H - 3.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, FS_ROW, C_TITLE_TEXT)

func _draw_right(font: Font, right_x: float, baseline_y: float, text: String,
		size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(right_x - w, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _describe(item: ItemInstance) -> String:
	if item is FishInstance:
		var fish := item as FishInstance
		return "%.2fm  %.2fkg  Q%d" % [fish.size, fish.weight, fish.quality]
	return ""

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventMouseMotion:
		_mouse_pos = get_local_mouse_position()
		_update_hover()
		queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_click()
			MOUSE_BUTTON_WHEEL_UP:
				_scroll_by(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_by(1)
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		close_requested.emit()
		get_viewport().set_input_as_handled()

func _click() -> void:
	if _btn_rect.has_point(_mouse_pos):
		sell_all_requested.emit()
		return
	if _hovered >= 0 and _hovered < _offers.size():
		sell_requested.emit(_offers[_hovered]["item"] as ItemInstance)

func _scroll_by(delta: int) -> void:
	var next := clampi(_scroll + delta, 0, maxi(0, _offers.size() - ROWS))
	if next == _scroll:
		return
	_scroll = next
	_update_hover()
	queue_redraw()

func _update_hover() -> void:
	_btn_hovered = _btn_rect.has_point(_mouse_pos)
	_hovered = -1
	if not _list_rect.has_point(_mouse_pos):
		return
	var index := _scroll + int((_mouse_pos.y - _list_rect.position.y) / ROW_H)
	if index >= 0 and index < _offers.size():
		_hovered = index

func _row_rect(index: int) -> Rect2:
	return Rect2(
		Vector2(_list_rect.position.x, _list_rect.position.y + (index - _scroll) * ROW_H),
		Vector2(_list_rect.size.x, ROW_H))

func _total_value() -> int:
	var total := 0
	for offer in _offers:
		total += int(offer["price"])
	return total
