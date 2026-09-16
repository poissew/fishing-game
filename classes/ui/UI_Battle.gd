extends Control
class_name UIBattle

## Stand-in for the arena. The battle phase is a real phase - the clock is
## frozen, the player cannot move or cast, and a champion has been handed over -
## but there is nothing to fight in yet, so this card holds the phase open,
## shows who was sent, and lets the round be closed out.
##
## Replacing it is the whole job of the arena scene: listen to
## `gamephase.battle_started(fish)`, run the fight, then call
## `gamephase.end_battle(won)`. Nothing else in the game reaches into this file.

## Emitted when the placeholder round is closed out. `won` is the outcome that
## gets reported to `gamephase`.
signal battle_finished(won: bool)

const PANEL_W := 240.0
const PAD     := 6.0
const TITLE_H := 12.0
const LINE_H  := 11.0
## Portrait of the champion, drawn from its Item icon like everywhere else.
const PORTRAIT := 40.0
const BAR_H   := 8.0
const FOOT_H  := 26.0

const C_PANEL_BG     := Color(0.09, 0.13, 0.09, 0.97)
const C_PANEL_BORDER := Color(0.32, 0.48, 0.28, 1.00)
const C_TITLE_BG     := Color(0.13, 0.20, 0.11, 1.00)
const C_TITLE_TEXT   := Color(0.55, 0.80, 0.45, 1.00)
const C_SEP          := Color(0.22, 0.34, 0.18, 1.00)
const C_DIM          := Color(0.00, 0.00, 0.00, 0.85)
const C_TEXT         := Color(0.62, 0.80, 0.56, 1.00)
const C_TEXT_DIM     := Color(0.40, 0.55, 0.36, 1.00)
const C_STAT         := Color(0.86, 0.62, 0.32, 1.00)
const C_HP_BG        := Color(0.05, 0.08, 0.05, 1.00)
const C_HP           := Color(0.30, 0.70, 0.32, 1.00)

var _default_icon: Texture2D = preload("res://icon.svg")

var _panel_rect: Rect2
var _fish: FishInstance = null
## True for the frame the card opens on, so the keypress or click that picked
## the champion cannot carry straight through and close the fight it started.
var _opened_this_frame: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	var panel_h := TITLE_H + PAD + PORTRAIT + PAD + BAR_H + PAD + LINE_H + PAD + FOOT_H
	var vp := get_viewport_rect().size
	var xy := Vector2(floor((vp.x - PANEL_W) / 2.0), floor((vp.y - panel_h) / 2.0))
	_panel_rect = Rect2(xy, Vector2(PANEL_W, panel_h))

func open(fish: FishInstance) -> void:
	_fish = fish
	_opened_this_frame = true
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	_fish = null

func _process(_delta: float) -> void:
	_opened_this_frame = false

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _fish == null:
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_DIM)

	var font := UIFont.FONT
	var r := _panel_rect
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, C_PANEL_BG)
	draw_rect(Rect2(r.position, Vector2(r.size.x, TITLE_H)), C_TITLE_BG)
	draw_string(font, r.position + Vector2(PAD, TITLE_H - 3), "BATTLE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TITLE_TEXT)
	draw_line(Vector2(r.position.x, r.position.y + TITLE_H),
		Vector2(r.end.x, r.position.y + TITLE_H), C_PANEL_BORDER)

	var top := r.position.y + TITLE_H + PAD
	var icon: Texture2D = _fish.data.icon if _fish.data.icon else _default_icon
	draw_texture_rect(icon,
		Rect2(Vector2(r.position.x + PAD, top), Vector2(PORTRAIT, PORTRAIT)), false)

	# Name and stats, stacked to the right of the portrait.
	var text_x := r.position.x + PAD + PORTRAIT + PAD
	draw_string(font, Vector2(text_x, top + UIFont.CAP_H), _fish.data.name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT)
	draw_string(font, Vector2(text_x, top + LINE_H + UIFont.CAP_H),
		"%.2fm  %.2fkg  Q%d" % [_fish.size, _fish.weight, _fish.quality],
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT_DIM)
	draw_string(font, Vector2(text_x, top + LINE_H * 2.0 + UIFont.CAP_H),
		"PHYS %d   MAG %d   SPL %d" % [_fish.phys_dmg, _fish.magic_dmg, _fish.spells.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_STAT)

	# Health bar, full width of the panel under the portrait.
	var bar := Rect2(Vector2(r.position.x + PAD, top + PORTRAIT + PAD),
		Vector2(PANEL_W - PAD * 2.0, BAR_H))
	draw_rect(bar, C_HP_BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _fish.health_ratio(), bar.size.y)), C_HP)
	draw_rect(bar, C_PANEL_BORDER, false)
	var hp := "%d / %d" % [_fish.current_health, _fish.health]
	var hp_w := font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	draw_string(font, Vector2(bar.position.x + (bar.size.x - hp_w) * 0.5,
			bar.position.y + (BAR_H + UIFont.CAP_H) * 0.5),
		hp, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT)

	# What this screen is standing in for, said plainly rather than dressed up
	# as a fight that is not happening.
	var foot_y := bar.end.y + PAD + UIFont.CAP_H
	draw_string(font, Vector2(r.position.x + PAD, foot_y),
		"No arena yet - your fighter waits.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT_DIM)
	draw_string(font, Vector2(r.position.x + PAD, foot_y + LINE_H + PAD),
		"Enter: back to the water",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_SEP)

	draw_rect(r, C_PANEL_BORDER, false)

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or _opened_this_frame:
		return
	# A fight that never happened is not a fight that was lost, so the champion
	# comes home intact. A real arena will pass the actual outcome instead.
	var clicked: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT
	if event.is_action_pressed("ui_accept") or clicked:
		battle_finished.emit(true)
		get_viewport().set_input_as_handled()
