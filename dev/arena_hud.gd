extends Control

## Readout for the test arena: one card per fighter with its stats and health,
## a running log of the hits, and the banner when one of them goes belly up.
##
## Dev-only and deliberately without a class_name - it is not part of the game's
## UI, it just has to make the numbers visible while the fish flop. Same
## monogram-on-a-dark-panel palette as the real panels so it reads at 480x270.

const PAD    := 4.0
const CARD_W := 152.0
const LINE_H := 11.0
const BAR_H  := 8.0
## Hits kept on screen. Older ones scroll off the top.
const LOG_LINES := 6

const C_PANEL_BG     := Color(0.09, 0.13, 0.09, 0.90)
const C_PANEL_BORDER := Color(0.32, 0.48, 0.28, 1.00)
const C_TEXT         := Color(0.62, 0.80, 0.56, 1.00)
const C_TEXT_DIM     := Color(0.40, 0.55, 0.36, 1.00)
const C_STAT         := Color(0.86, 0.62, 0.32, 1.00)
const C_HP_BG        := Color(0.05, 0.08, 0.05, 1.00)
const C_HP           := Color(0.30, 0.70, 0.32, 1.00)
const C_HP_LOW       := Color(0.80, 0.30, 0.25, 1.00)
const C_DEAD         := Color(0.45, 0.45, 0.50, 1.00)
const C_WIN          := Color(0.95, 0.85, 0.40, 1.00)

## Below this share of health the bar turns red.
const HP_LOW := 0.3

## Untyped: the arena script has no class_name, so a static type here would
## mean adding one to the game's global class list for a dev scene.
var _arena = null
var _log: Array[String] = []

func bind_arena(arena) -> void:
	_arena = arena

func log_line(text: String) -> void:
	_log.append(text)
	while _log.size() > LOG_LINES:
		_log.pop_front()

func clear_log() -> void:
	_log.clear()

## Health is changing every time a fish lands a hit, so the whole thing is
## simply redrawn each frame rather than wired up to a pile of signals.
func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _arena == null:
		return
	var battlers: Array = _arena.battlers
	var vp := get_viewport_rect().size

	for i in battlers.size():
		var battler: BattleFish = battlers[i]
		if not is_instance_valid(battler) or battler.fish == null:
			continue
		# Team 0 on the left, team 1 on the right, matching which side of the
		# floor each one drops in on.
		var x := PAD if i == 0 else vp.x - CARD_W - PAD
		_draw_card(Vector2(x, PAD), battler)

	_draw_log(vp)
	_draw_banner(vp)

# -- Fighter card --------------------------------------------------------------

func _draw_card(at: Vector2, battler: BattleFish) -> void:
	var font := UIFont.FONT
	var fish := battler.fish
	var card := Rect2(at, Vector2(CARD_W, PAD * 4.0 + LINE_H * 2.0 + BAR_H))
	draw_rect(card, C_PANEL_BG)
	draw_rect(card, C_PANEL_BORDER, false)

	var left := at.x + PAD
	var name_color := C_DEAD if not battler.is_alive() else battler.tint
	draw_string(font, Vector2(left, at.y + PAD + UIFont.CAP_H), fish.data.name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, name_color)
	draw_string(font, Vector2(left, at.y + PAD + LINE_H + UIFont.CAP_H),
		"%.2fm  PHYS %d  MAG %d" % [fish.size, battler.phys_dmg(), battler.magic_dmg()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_STAT)

	var bar := Rect2(Vector2(left, at.y + PAD * 2.0 + LINE_H * 2.0),
		Vector2(CARD_W - PAD * 2.0, BAR_H))
	var ratio := battler.health_ratio()
	draw_rect(bar, C_HP_BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)),
		C_HP_LOW if ratio <= HP_LOW else C_HP)
	draw_rect(bar, C_PANEL_BORDER, false)

	var hp := "%d / %d" % [fish.current_health, fish.health]
	var hp_w := font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	draw_string(font, Vector2(bar.position.x + (bar.size.x - hp_w) * 0.5,
			bar.position.y + (BAR_H + UIFont.CAP_H) * 0.5),
		hp, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT)

# -- Log and banner ------------------------------------------------------------

## Bottom-left, oldest at the top, the newest line brightest. It starts two
## lines up to clear the key hints along the bottom.
func _draw_log(vp: Vector2) -> void:
	var font := UIFont.FONT
	var baseline := vp.y - PAD - LINE_H * 2.0
	for i in range(_log.size() - 1, -1, -1):
		var age := _log.size() - 1 - i
		draw_string(font, Vector2(PAD, baseline - age * LINE_H),
			_log[i], HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE,
			C_TEXT if age == 0 else C_TEXT_DIM)

## Two centred lines of keys along the bottom - the camera on top, the round
## underneath - and the winner over the middle of the floor once there is one.
func _draw_banner(vp: Vector2) -> void:
	var font := UIFont.FONT
	_draw_centered(font, vp, "RMB: look   WASD/Space/Ctrl: fly   Shift: faster   F: reset view",
		vp.y - PAD - LINE_H, C_TEXT_DIM)
	_draw_centered(font, vp, "R: new pair   1: rematch   E: arm next spell   Esc: cursor, then quit",
		vp.y - PAD, C_TEXT_DIM)

	var winner: BattleFish = _arena.winner
	if winner == null or not is_instance_valid(winner) or winner.fish == null:
		return
	var text := "%s WINS" % winner.fish.data.name.to_upper()
	# Twice the panel size, the way UIDayTimer does its countdown - monogram
	# only sits right on whole multiples of UIFont.SIZE.
	var big := UIFont.SIZE * 2
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	draw_string(font, Vector2((vp.x - text_w) * 0.5, vp.y * 0.34),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, C_WIN)

func _draw_centered(font: Font, vp: Vector2, text: String, baseline: float, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	draw_string(font, Vector2((vp.x - w) * 0.5, baseline),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, color)
