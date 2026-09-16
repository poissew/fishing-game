extends Control
class_name UIFishSelect

## End-of-day panel: the fishing day is over, so one of the day's catch has to
## be sent to the arena. Draws itself in _draw() with the same palette and the
## same monogram-sized columns as UIShop, so it stays legible at 480x270.
##
## The panel knows nothing about what happens next. It lists the fish it was
## handed and reports the one that was picked; `gamephase` decides the rest.

## A fish was picked and confirmed.
signal fish_chosen(fish: FishInstance)
## Nothing to send, or the player passed on the fight.
signal skip_requested()

const PANEL_W  := 320.0
const ROW_H    := 12.0
const ROWS     := 8
const PAD      := 4.0
const TITLE_H  := 12.0
## Column captions above the list - the stat columns are unreadable without.
const HEADER_H := 10.0
## Two lines: the confirm button on one, the key hints underneath.
const FOOTER_H := 32.0
const ICON     := 10.0
## Confirm button, wide enough for "SEND TO BATTLE".
const BTN_W    := 100.0
const BTN_H    := 13.0

## Column offsets from a row's left edge. monogram is 6px per character, so
## these are whole-character positions and no column runs into the next.
const COL_SIZE := 108.0
const COL_HP   := 150.0
const COL_PHY  := 196.0
const COL_MAG  := 246.0

# Panel colors - same palette as the inventory and the shop
const C_PANEL_BG     := Color(0.09, 0.13, 0.09, 0.97)
const C_PANEL_BORDER := Color(0.32, 0.48, 0.28, 1.00)
const C_TITLE_BG     := Color(0.13, 0.20, 0.11, 1.00)
const C_TITLE_TEXT   := Color(0.55, 0.80, 0.45, 1.00)
const C_SEP          := Color(0.22, 0.34, 0.18, 1.00)
## Dims harder than the shop does: the day is over and the world behind this
## panel is frozen, so it should read as stopped rather than merely backgrounded.
const C_DIM          := Color(0.00, 0.00, 0.00, 0.78)
# Rows
const C_ROW          := Color(0.05, 0.08, 0.05, 1.00)
const C_ROW_ALT      := Color(0.07, 0.11, 0.07, 1.00)
const C_ROW_HOVER    := Color(0.16, 0.46, 0.18, 0.55)
const C_ROW_PICKED   := Color(0.16, 0.46, 0.18, 0.92)
const C_TEXT         := Color(0.62, 0.80, 0.56, 1.00)
const C_TEXT_DIM     := Color(0.40, 0.55, 0.36, 1.00)
## Combat numbers read warm, so they stand apart from the catch stats next door.
const C_STAT         := Color(0.86, 0.62, 0.32, 1.00)
# Confirm button
const C_BTN          := Color(0.16, 0.46, 0.18, 0.92)
const C_BTN_HOVER    := Color(0.22, 0.60, 0.24, 0.92)
const C_BTN_OFF      := Color(0.12, 0.18, 0.11, 0.92)

var _default_icon: Texture2D = preload("res://icon.svg")

# Layout - computed in _ready()
var _panel_rect: Rect2
var _list_rect:  Rect2
var _btn_rect:   Rect2

var _fish: Array[FishInstance] = []
## Index into _fish of the fish that will be sent, or -1 when there is none.
var _picked: int = -1
var _scroll: int = 0
var _hovered: int = -1
var _btn_hovered: bool = false
var _mouse_pos: Vector2 = Vector2.ZERO

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	var panel_h := TITLE_H + PAD + HEADER_H + ROWS * ROW_H + PAD + FOOTER_H
	var vp := get_viewport_rect().size
	var xy := Vector2(floor((vp.x - PANEL_W) / 2.0), floor((vp.y - panel_h) / 2.0))
	_panel_rect = Rect2(xy, Vector2(PANEL_W, panel_h))
	_list_rect  = Rect2(xy + Vector2(PAD, TITLE_H + PAD + HEADER_H),
		Vector2(PANEL_W - PAD * 2.0, ROWS * ROW_H))
	_btn_rect = Rect2(
		Vector2(xy.x + PANEL_W - PAD - BTN_W, _list_rect.end.y + PAD),
		Vector2(BTN_W, BTN_H))

## Open on `fish`, everything the player is carrying. Strongest first, so the
## obvious pick is the top row and a hurried player can just hit Enter.
func open(fish: Array[FishInstance]) -> void:
	_fish = fish.duplicate()
	_fish.sort_custom(func(a, b): return _battle_power(a) > _battle_power(b))
	_picked = 0 if not _fish.is_empty() else -1
	_scroll = 0
	_mouse_pos = get_local_mouse_position()
	_update_hover()
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	_fish.clear()
	_picked = -1

## What the list is sorted on: a rough "how good is this in a fight" number,
## not a real power rating. Good enough to float the best catch to the top.
static func _battle_power(fish: FishInstance) -> int:
	if fish == null:
		return 0
	return fish.health + fish.phys_dmg + fish.magic_dmg

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_DIM)
	_draw_panel()
	_draw_header()
	_draw_rows()
	_draw_footer()

func _draw_panel() -> void:
	var r := _panel_rect
	var font := UIFont.FONT
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, C_PANEL_BG)
	draw_rect(Rect2(r.position, Vector2(r.size.x, TITLE_H)), C_TITLE_BG)
	# The clock rolls over to the new day before this opens, so the day that
	# just ended is the one before the one the clock is counting.
	draw_string(font, r.position + Vector2(PAD, TITLE_H - 3),
		"DAY %d OVER - PICK YOUR FIGHTER" % maxi(1, daynight.day - 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TITLE_TEXT)
	_draw_right(font, r.end.x - PAD, r.position.y + TITLE_H - 3,
		"%d FISH" % _fish.size(), C_TEXT_DIM)
	draw_line(Vector2(r.position.x, r.position.y + TITLE_H),
		Vector2(r.end.x, r.position.y + TITLE_H), C_PANEL_BORDER)
	draw_rect(r, C_PANEL_BORDER, false)

func _draw_header() -> void:
	var font := UIFont.FONT
	var x := _list_rect.position.x
	var base_y := _list_rect.position.y - 3.0
	draw_string(font, Vector2(x + ICON + 5.0, base_y), "FISH",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_SEP)
	draw_string(font, Vector2(x + COL_SIZE, base_y), "SIZE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_SEP)
	draw_string(font, Vector2(x + COL_HP, base_y), "HP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_SEP)
	draw_string(font, Vector2(x + COL_PHY, base_y), "PHYS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_SEP)
	draw_string(font, Vector2(x + COL_MAG, base_y), "MAG",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_SEP)
	_draw_right(font, _list_rect.end.x - 2.0, base_y, "SPL", C_SEP)

func _draw_rows() -> void:
	var font := UIFont.FONT
	draw_rect(_list_rect, C_ROW)
	if _fish.is_empty():
		draw_string(font, _list_rect.position + Vector2(PAD, ROW_H - 3.0),
			"No fish on you. Nobody fights tonight.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT_DIM)
		return

	for i in range(_scroll, mini(_scroll + ROWS, _fish.size())):
		var fish := _fish[i]
		var rect := _row_rect(i)
		if i == _picked:
			draw_rect(rect, C_ROW_PICKED)
		elif i == _hovered:
			draw_rect(rect, C_ROW_HOVER)
		else:
			draw_rect(rect, C_ROW_ALT if i % 2 == 0 else C_ROW)

		var icon: Texture2D = fish.data.icon if fish.data.icon else _default_icon
		draw_texture_rect(icon,
			Rect2(rect.position + Vector2(1, (ROW_H - ICON) * 0.5), Vector2(ICON, ICON)), false)

		var x := rect.position.x
		var base_y := rect.position.y + ROW_H - 3.0
		draw_string(font, Vector2(x + ICON + 5.0, base_y), fish.data.name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT)
		draw_string(font, Vector2(x + COL_SIZE, base_y), "%.2fm" % fish.size,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT_DIM)
		draw_string(font, Vector2(x + COL_HP, base_y), str(fish.health),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_STAT)
		draw_string(font, Vector2(x + COL_PHY, base_y), str(fish.phys_dmg),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_STAT)
		draw_string(font, Vector2(x + COL_MAG, base_y), str(fish.magic_dmg),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_STAT)
		_draw_right(font, rect.end.x - 2.0, base_y, str(fish.spells.size()), C_TEXT_DIM)

func _draw_footer() -> void:
	var font := UIFont.FONT
	# Caps are CAP_H tall, so this baseline centres the label in the button.
	var base_y := _btn_rect.position.y + (BTN_H + UIFont.CAP_H) * 0.5
	if _fish.size() > ROWS:
		_draw_right(font, _btn_rect.position.x - 6.0, base_y,
			"%d-%d / %d" % [_scroll + 1, mini(_scroll + ROWS, _fish.size()), _fish.size()],
			C_TEXT_DIM)
	var armed := _has_pick()
	draw_rect(_btn_rect, (C_BTN_HOVER if _btn_hovered else C_BTN) if armed else C_BTN_OFF)
	draw_rect(_btn_rect, C_PANEL_BORDER, false)
	var label := "SEND TO BATTLE" if armed else "SKIP BATTLE"
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	draw_string(font, Vector2(_btn_rect.position.x + (BTN_W - w) * 0.5, base_y),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TITLE_TEXT)
	draw_string(font, Vector2(_panel_rect.position.x + PAD,
			_btn_rect.end.y + 2.0 + UIFont.CAP_H),
		"click a fish  |  up/down: pick  |  Enter: send",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_SEP)

func _draw_right(font: Font, right_x: float, baseline_y: float, text: String,
		color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	draw_string(font, Vector2(right_x - w, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, color)

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
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
		# Eaten so a bobber still floating out there does not read the click as
		# a reel while the day is being wrapped up.
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up"):
		_move_pick(-1)
	elif event.is_action_pressed("ui_down"):
		_move_pick(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	else:
		return
	get_viewport().set_input_as_handled()

## A click on a row picks it; a second click on the row already picked sends it,
## so the screen can be got through with the mouse alone.
func _click() -> void:
	if _btn_rect.has_point(_mouse_pos):
		_confirm()
		return
	if _hovered < 0:
		return
	if _hovered == _picked:
		_confirm()
		return
	_picked = _hovered
	queue_redraw()

func _confirm() -> void:
	if not _has_pick():
		skip_requested.emit()
		return
	fish_chosen.emit(_fish[_picked])

func _has_pick() -> bool:
	return _picked >= 0 and _picked < _fish.size()

## Move the pick by `delta` rows, dragging the scroll along to keep it on screen.
func _move_pick(delta: int) -> void:
	if _fish.is_empty():
		return
	_picked = clampi(_picked + delta, 0, _fish.size() - 1)
	_scroll = clampi(_scroll, maxi(0, _picked - ROWS + 1), _picked)
	_scroll = clampi(_scroll, 0, maxi(0, _fish.size() - ROWS))
	_update_hover()
	queue_redraw()

func _scroll_by(delta: int) -> void:
	var next := clampi(_scroll + delta, 0, maxi(0, _fish.size() - ROWS))
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
	if index >= 0 and index < _fish.size():
		_hovered = index

func _row_rect(index: int) -> Rect2:
	return Rect2(
		Vector2(_list_rect.position.x, _list_rect.position.y + (index - _scroll) * ROW_H),
		Vector2(_list_rect.size.x, ROW_H))
