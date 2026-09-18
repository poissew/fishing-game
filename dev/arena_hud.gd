extends Control

## Readout for the test arena: one card per fighter with its stats and health,
## the round clock across the top, a running log of the hits, and the banner
## when one of them goes belly up.
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
const C_DOT          := Color(0.72, 0.45, 0.85, 1.00)
const C_STUN         := Color(1.00, 0.95, 0.55, 1.00)
const C_ARMOUR       := Color(0.55, 0.75, 0.95, 1.00)
const C_WARD         := Color(0.60, 0.55, 0.95, 1.00)
const C_IMMUNE       := Color(0.85, 0.95, 1.00, 1.00)
const C_LEECH        := Color(0.90, 0.35, 0.45, 1.00)
const C_CLOCK        := Color(0.62, 0.80, 0.56, 1.00)
const C_SUDDEN       := Color(0.90, 0.35, 0.30, 1.00)

## Seconds left below which the clock turns red, and how fast the sudden-death
## banner blinks, in blinks a second.
const CLOCK_LOW := 10.0
const SUDDEN_BLINK := 2.0

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

	_draw_clock(vp)
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

	# Whatever is on this fish, right-aligned on the name row. Stun first,
	# because a fish that cannot act is the more urgent news; with a long name
	# and both at once the two can touch, which is a dev readout's problem and
	# not worth a second row.
	var status_x := at.x + CARD_W - PAD
	# Armour first, so the permanent tag sits outermost and the news of the
	# moment - a stun, something ticking - pushes in beside the name.
	if battler.physical_reduction() > 0:
		status_x = _draw_status(font, status_x, at.y + PAD + UIFont.CAP_H,
			"ARM %d" % battler.physical_reduction(), C_ARMOUR)
	if battler.magic_resistance() > 0.0:
		status_x = _draw_status(font, status_x, at.y + PAD + UIFont.CAP_H,
			"WARD %d" % roundi(battler.magic_resistance() * 100.0), C_WARD)
	if battler.dot_ticks_left() > 0:
		status_x = _draw_status(font, status_x, at.y + PAD + UIFont.CAP_H,
			"DOT %dx%d" % [battler.dot_ticks_left(), battler.dot_damage()], C_DOT)
	if battler.is_stunned():
		status_x = _draw_status(font, status_x, at.y + PAD + UIFont.CAP_H,
			"STUN %.1f" % battler.stun_left(), C_STUN)
	if battler.is_in_last_stand():
		status_x = _draw_status(font, status_x, at.y + PAD + UIFont.CAP_H,
			"IMMUNE %.1f" % battler.last_stand_left(), C_IMMUNE)
	if battler.leech_count() > 0:
		# How many this fish has out, not how many are on it: a leech belongs to
		# whoever dropped it for as long as it lives.
		status_x = _draw_status(font, status_x, at.y + PAD + UIFont.CAP_H,
			"LEECH %d" % battler.leech_count(), C_LEECH)
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

## One status tag, right-aligned ending at `right`. Returns where the next one
## to its left should end.
func _draw_status(font: Font, right: float, baseline: float, text: String,
		color: Color) -> float:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	draw_string(font, Vector2(right - width, baseline),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, color)
	return right - width - PAD

# -- Round clock ---------------------------------------------------------------

## Centre top, between the two cards: the time left while there is any, then
## what sudden death is costing once there is not.
func _draw_clock(vp: Vector2) -> void:
	# Typed, unlike _arena itself: BattleRound is game code with a class_name, so
	# there is a real type to put here and time_left() comes back as a float.
	var clock: BattleRound = _arena.round_clock
	if clock == null:
		return

	var text := ""
	var color := C_CLOCK
	if clock.is_sudden_death():
		# Blinking, because by now the fish are not the ones deciding this.
		if fmod(Time.get_ticks_msec() / 1000.0 * SUDDEN_BLINK, 1.0) > 0.5:
			return
		text = "SUDDEN DEATH  -%d" % clock.drain_amount()
		color = C_SUDDEN
	else:
		var left := clock.time_left()
		text = "%d:%02d" % [int(left) / 60, int(left) % 60]
		if left <= CLOCK_LOW:
			color = C_SUDDEN

	var font := UIFont.FONT
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	draw_string(font, Vector2((vp.x - width) * 0.5, PAD + UIFont.CAP_H),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, color)

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
