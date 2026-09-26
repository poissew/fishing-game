extends Control
class_name UISlotMachine

## The slot machine's panel: three reels, a PULL button and what came out.
## Drawn in _draw() like UIShop, and like UIShop it stays visible while closed
## because it also owns the "[E]" prompt - `is_open` is what gates the panel.
##
## The panel never decides anything. Player takes the money, rolls the machine
## and hands the charm over before the reels have even started, then calls
## spin() with the result; the reels are only the reveal. That way closing the
## panel mid-spin, or the day ending under it, can never lose a prize that was
## paid for.

signal pull_requested()
signal close_requested()

const PANEL_W  := 264.0
const PAD      := 4.0
const TITLE_H  := 12.0
const REEL_W   := 80.0
const REEL_H   := 32.0
const REEL_GAP := 4.0
const REELS    := 3
## Baseline-to-baseline for the text block under the reels. monogram caps are
## 7px with 2px descenders, so 10 keeps lines apart without wasting height.
const LINE_H   := 10.0
## Lines in the result block: a headline, the description, and a footer line.
## The longest spell description wraps to five lines at WRAP_CHARS.
const RESULT_LINES := 7
## Characters per line in the result block. monogram is a 6px monospace.
const WRAP_CHARS := 40
const BTN_W    := 100.0
const BTN_H    := 13.0

## How far one symbol travels to replace the one before it, and how many
## symbols go past per second while a reel is spinning.
const REEL_STEP  := 16.0
const REEL_SPEED := 14.0
## Spin length for the first reel, and how much later each next one stops -
## the staggered stop is what makes it read as a slot machine.
const SPIN_FIRST   := 0.7
const SPIN_STAGGER := 0.45
## How long the reels blink after a win.
const WIN_FLASH := 1.6
## Chance a losing pull lands the first two reels on the same spell. Near
## misses are what slot machines are made of.
const NEAR_MISS := 0.3
## Symbol for the losing half of the reels. It also covers a machine whose
## pool holds a single spell, where three reels could not otherwise show a loss.
const DUD := "FISHBONE"

# Palette - the shop's, plus a warning red for losing.
const C_PANEL_BG     := Color(0.09, 0.13, 0.09, 0.97)
const C_PANEL_BORDER := Color(0.32, 0.48, 0.28, 1.00)
const C_TITLE_BG     := Color(0.13, 0.20, 0.11, 1.00)
const C_TITLE_TEXT   := Color(0.55, 0.80, 0.45, 1.00)
const C_SEP          := Color(0.22, 0.34, 0.18, 1.00)
const C_DIM          := Color(0.00, 0.00, 0.00, 0.60)
const C_REEL         := Color(0.05, 0.08, 0.05, 1.00)
const C_TEXT         := Color(0.62, 0.80, 0.56, 1.00)
const C_TEXT_DIM     := Color(0.40, 0.55, 0.36, 1.00)
const C_MONEY        := Color(0.92, 0.82, 0.32, 1.00)
const C_LOSE         := Color(0.82, 0.36, 0.30, 1.00)
const C_BTN          := Color(0.16, 0.46, 0.18, 0.92)
const C_BTN_HOVER    := Color(0.22, 0.60, 0.24, 0.92)
const C_BTN_OFF      := Color(0.10, 0.16, 0.10, 0.92)

var is_open: bool = false

var _wallet:  Wallet      = null
var _machine: SlotMachine = null
var _nearby:  SlotMachine = null

# Layout - computed in _ready()
var _panel_rect: Rect2
var _reel_rects: Array[Rect2] = []
var _odds_y:     float
var _result_y:   float
var _btn_rect:   Rect2
var _hint_y:     float

var _mouse_pos: Vector2 = Vector2.ZERO
var _btn_hovered: bool = false

# Reels. `_text` is the symbol sitting in the window, `_next` the one scrolling
# in above it, `_phase` how far along that swap is (0..1).
var _symbols: Array[String] = []
var _text:    Array[String] = []
var _next:    Array[String] = []
var _final:   Array[String] = []
var _phase:   Array[float] = []
var _stop_at: Array[float] = []
var _landing: Array[bool] = []
var _done:    Array[bool] = []
var _spinning: bool = false
var _spin_time: float = 0.0

# What the result block says. `_prize` is set once the reels have stopped.
var _prize: SpellData = null
var _headline: String = ""
var _headline_color: Color = C_TEXT
var _body: String = ""
## Last line of the block, kept apart from `_body` so a long description is
## what gets cut short, never the instruction under it.
var _footer: String = ""
var _flash_left: float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func bind_wallet(wallet: Wallet) -> void:
	_wallet = wallet
	if _wallet != null and not _wallet.changed.is_connected(queue_redraw):
		_wallet.changed.connect(queue_redraw)

func _ready() -> void:
	var reels_w := REELS * REEL_W + (REELS - 1) * REEL_GAP
	var panel_h := TITLE_H + PAD + 2.0 + REEL_H + PAD + LINE_H + PAD \
		+ RESULT_LINES * LINE_H + PAD + BTN_H + PAD + LINE_H + PAD
	var vp := get_viewport_rect().size
	var xy := Vector2(floor((vp.x - PANEL_W) / 2.0), floor((vp.y - panel_h) / 2.0))
	_panel_rect = Rect2(xy, Vector2(PANEL_W, panel_h))

	var y :float = xy.y + TITLE_H + PAD + 2.0
	var x :float = xy.x + floor((PANEL_W - reels_w) / 2.0)
	_reel_rects.clear()
	for i in REELS:
		_reel_rects.append(Rect2(Vector2(x + i * (REEL_W + REEL_GAP), y),
			Vector2(REEL_W, REEL_H)))
	y += REEL_H + PAD
	_odds_y = y + UIFont.CAP_H
	y += LINE_H + PAD
	_result_y = y + UIFont.CAP_H
	y += RESULT_LINES * LINE_H + PAD
	_btn_rect = Rect2(Vector2(xy.x + floor((PANEL_W - BTN_W) / 2.0), y),
		Vector2(BTN_W, BTN_H))
	y += BTN_H + PAD
	_hint_y = y + UIFont.CAP_H
	set_process(false)

## Machine the player is standing next to, or null. Drives the "[E]" prompt.
func set_nearby(machine: SlotMachine) -> void:
	_nearby = machine
	queue_redraw()

func open(machine: SlotMachine) -> void:
	_machine   = machine
	_mouse_pos = get_local_mouse_position()
	is_open    = true
	_symbols   = _symbols_for(machine)
	_reset_reels()
	_prize = null
	_say("Pull for a spell charm.", C_TEXT,
		"Win and the charm drops into your bag. Drag it onto a fish there to teach it the spell.\nA fish carries up to %d spells, never the same one twice." % FishInstance.SPELL_SLOTS)
	_update_hover()
	queue_redraw()

## Closing mid-spin is allowed: the prize was handed over before the reels
## started, so all that is lost is the show.
func close() -> void:
	is_open   = false
	_machine  = null
	_spinning = false
	_flash_left = 0.0
	set_process(false)
	queue_redraw()

func is_spinning() -> bool:
	return _spinning

## Start the reels. `prize` is what the pull already paid out - null for
## nothing - and the reels are made to land on it.
func spin(prize: SpellData) -> void:
	if not is_open:
		return
	_prize = prize
	_final = _outcome(prize)
	_spin_time = 0.0
	_flash_left = 0.0
	for i in REELS:
		_phase[i]   = 0.0
		_landing[i] = false
		_done[i]    = false
		_next[i]    = _random_symbol()
		_stop_at[i] = SPIN_FIRST + i * SPIN_STAGGER
	_spinning = true
	_say("", C_TEXT, "")
	set_process(true)
	_update_hover()
	queue_redraw()

## A pull that was turned down before any money moved.
func refuse(reason: String) -> void:
	if is_open and not _spinning:
		_say(reason, C_LOSE, "")
		queue_redraw()

# ── Reels ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _spinning:
		_spin_time += delta
		for i in REELS:
			_advance_reel(i, delta)
		if not _done.has(false):
			_finish_spin()
	elif _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		if _flash_left == 0.0:
			set_process(false)
	else:
		set_process(false)
	queue_redraw()

## Rolls one reel on. Once its stop time is up the final symbol is fed in as
## the next one, so it scrolls into the window rather than snapping there.
func _advance_reel(i: int, delta: float) -> void:
	if _done[i]:
		return
	_phase[i] += delta * REEL_SPEED
	while _phase[i] >= 1.0:
		_phase[i] -= 1.0
		_text[i] = _next[i]
		if _landing[i]:
			_done[i]  = true
			_phase[i] = 0.0
			return
		if _spin_time >= _stop_at[i]:
			_next[i] = _final[i]
			_landing[i] = true
		else:
			_next[i] = _random_symbol()

func _finish_spin() -> void:
	_spinning = false
	if _machine == null:
		return
	if _prize != null:
		_flash_left = WIN_FLASH
		_say("WON: %s" % _prize.name.to_upper(), C_MONEY, _prize.description,
			"In your bag (Tab) - drag it onto a fish.")
		_play(_machine.sfx_win)
	else:
		_say("Nothing. The machine keeps your $%d." % _machine.cost, C_LOSE, "")
		_play(_machine.sfx_lose)
	_update_hover()

## Where the three reels land. A win is three of the prize; a loss is anything
## else, sometimes deliberately one reel short of a win.
func _outcome(prize: SpellData) -> Array[String]:
	if prize != null:
		var symbol := _symbol_of(prize)
		var jackpot: Array[String] = [symbol, symbol, symbol]
		return jackpot
	var rng: RandomNumberGenerator = randomizer.RNG
	var picks: Array[String] = [_random_symbol(), _random_symbol(), _random_symbol()]
	if rng.randf() < NEAR_MISS:
		var spell := _random_spell_symbol()
		if spell != "":
			picks[0] = spell
			picks[1] = spell
			picks[2] = DUD
	# Three of one spell reads as a win, so a loss never lands on one.
	if picks[0] == picks[1] and picks[1] == picks[2] and picks[0] != DUD:
		picks[2] = DUD
	return picks

func _reset_reels() -> void:
	_text.clear(); _next.clear(); _final.clear(); _phase.clear()
	_stop_at.clear(); _landing.clear(); _done.clear()
	for i in REELS:
		_text.append(_random_symbol())
		_next.append(_random_symbol())
		_final.append(_text[i])
		_phase.append(0.0)
		_stop_at.append(0.0)
		_landing.append(false)
		_done.append(true)
	_spinning = false
	_flash_left = 0.0

func _symbols_for(machine: SlotMachine) -> Array[String]:
	var symbols: Array[String] = []
	if machine != null:
		for spell in machine.prizes():
			symbols.append(_symbol_of(spell))
	return symbols

## What a spell looks like on a reel. Clipped so it fits the window.
func _symbol_of(spell: SpellData) -> String:
	return spell.name.to_upper().left(int(REEL_W / 6.0) - 1)

## Any symbol on the strip, the dud included - once for every three spells,
## so a spinning reel does not mostly show bones.
func _random_symbol() -> String:
	var rng: RandomNumberGenerator = randomizer.RNG
	if _symbols.is_empty() or rng.randi_range(0, 3) == 0:
		return DUD
	return _symbols[rng.randi_range(0, _symbols.size() - 1)]

func _random_spell_symbol() -> String:
	if _symbols.is_empty():
		return ""
	return _symbols[randomizer.RNG.randi_range(0, _symbols.size() - 1)]

func _play(stream: AudioStream) -> void:
	if stream != null:
		audio.play_ui(stream)

func _say(headline: String, color: Color, body: String, footer: String = "") -> void:
	_headline = headline
	_headline_color = color
	_body = body
	_footer = footer

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if is_open and _machine != null:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), C_DIM)
		_draw_panel()
		_draw_reels()
		_draw_text()
		_draw_button()
	elif _nearby != null:
		_draw_prompt()

func _draw_prompt() -> void:
	var font := UIFont.FONT
	var vp   := get_viewport_rect().size
	var text := "[E] %s  $%d" % [_nearby.machine_name, _nearby.cost]
	var w    := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	var pos  := Vector2(floor((vp.x - w) / 2.0), vp.y - 24.0)
	draw_rect(Rect2(pos + Vector2(-4, -9), Vector2(w + 8, 13)), C_PANEL_BG)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TITLE_TEXT)

func _draw_panel() -> void:
	var r := _panel_rect
	var font := UIFont.FONT
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.45))
	draw_rect(r, C_PANEL_BG)
	draw_rect(Rect2(r.position, Vector2(r.size.x, TITLE_H)), C_TITLE_BG)
	draw_string(font, r.position + Vector2(PAD, TITLE_H - 3), _machine.machine_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TITLE_TEXT)
	if _wallet != null:
		_draw_right(r.end.x - PAD, r.position.y + TITLE_H - 3, "$ %d" % _wallet.money, C_MONEY)
	draw_line(Vector2(r.position.x, r.position.y + TITLE_H),
		Vector2(r.end.x, r.position.y + TITLE_H), C_PANEL_BORDER)
	draw_rect(r, C_PANEL_BORDER, false)

func _draw_reels() -> void:
	var font := UIFont.FONT
	# Blinks on and off at 6 Hz while a win is being celebrated.
	var lit := _flash_left > 0.0 and fmod(_flash_left * 6.0, 1.0) < 0.5
	for i in REELS:
		var rect := _reel_rects[i]
		draw_rect(rect, C_REEL)
		var centre := rect.position.y + REEL_H * 0.5
		_draw_symbol(font, rect, centre + _phase[i] * REEL_STEP, _text[i])
		if not _done[i]:
			_draw_symbol(font, rect, centre + (_phase[i] - 1.0) * REEL_STEP, _next[i])
		# Pay line.
		draw_line(Vector2(rect.position.x, floor(centre)), Vector2(rect.position.x + 3, floor(centre)),
			C_MONEY if lit else C_SEP)
		draw_rect(rect, C_MONEY if lit else C_PANEL_BORDER, false)

## One symbol, its caps centred on `centre_y`, fading out as it scrolls away
## from the middle of the window. Past REEL_STEP * 0.7 it is skipped outright,
## which is what keeps it inside the window without clipping.
func _draw_symbol(font: Font, rect: Rect2, centre_y: float, text: String) -> void:
	var off := absf(centre_y - (rect.position.y + REEL_H * 0.5))
	if off > REEL_STEP * 0.7:
		return
	var alpha := 1.0 - off / REEL_STEP
	var color := (C_TEXT_DIM if text == DUD else C_TEXT)
	color.a = alpha
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	var pos := Vector2(rect.position.x + (REEL_W - w) * 0.5, centre_y + UIFont.CAP_H * 0.5).floor()
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, color)

func _draw_text() -> void:
	var font := UIFont.FONT
	var x := _panel_rect.position.x + PAD * 2.0
	var odds := "%d%% of pulls pay a spell  -  %d to be won" % [
		int(round(_machine.win_chance * 100.0)), _symbols.size()]
	draw_string(font, Vector2(x, _odds_y), odds, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UIFont.SIZE, C_TEXT_DIM)
	draw_line(Vector2(_panel_rect.position.x + PAD, _odds_y + 4.0),
		Vector2(_panel_rect.end.x - PAD, _odds_y + 4.0), C_SEP)

	var row := 0
	if _headline != "":
		draw_string(font, Vector2(x, _result_y), _headline,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, _headline_color)
		row += 1
	var room := RESULT_LINES - row - (1 if _footer != "" else 0)
	var body := _wrap(_body)
	if body.size() > room:
		body.resize(room)
		body[room - 1] = body[room - 1].left(WRAP_CHARS - 3) + "..."
	for line in body:
		draw_string(font, Vector2(x, _result_y + row * LINE_H), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TEXT_DIM)
		row += 1
	if _footer != "":
		draw_string(font, Vector2(x, _result_y + (RESULT_LINES - 1) * LINE_H), _footer,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TITLE_TEXT)

func _draw_button() -> void:
	var font := UIFont.FONT
	var usable := _can_pull()
	var fill := C_BTN_OFF
	if usable:
		fill = C_BTN_HOVER if _btn_hovered else C_BTN
	draw_rect(_btn_rect, fill)
	draw_rect(_btn_rect, C_PANEL_BORDER, false)
	var label := "PULL  $%d" % _machine.cost
	if _spinning:
		label = "SPINNING..."
	elif _wallet != null and not _wallet.can_afford(_machine.cost):
		label = "NEED $%d" % _machine.cost
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	var base_y := _btn_rect.position.y + (BTN_H + UIFont.CAP_H) * 0.5
	draw_string(font, Vector2(floor(_btn_rect.position.x + (BTN_W - w) * 0.5), floor(base_y)),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_TITLE_TEXT if usable else C_TEXT_DIM)
	draw_string(font, Vector2(_panel_rect.position.x + PAD, _hint_y),
		"Enter: pull  |  E / Esc: leave",
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, C_SEP)

func _draw_right(right_x: float, baseline_y: float, text: String, color: Color) -> void:
	var font := UIFont.FONT
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
	draw_string(font, Vector2(right_x - w, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, color)

## Greedy word wrap by character count, which is exact for a monospace font.
## Explicit newlines in `text` are kept.
func _wrap(text: String) -> Array[String]:
	var out: Array[String] = []
	for paragraph in text.split("\n", false):
		var line := ""
		for word in paragraph.split(" ", false):
			if line == "":
				line = word
			elif line.length() + 1 + word.length() <= WRAP_CHARS:
				line += " " + word
			else:
				out.append(line)
				line = word
		if line != "":
			out.append(line)
	return out

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventMouseMotion:
		_mouse_pos = get_local_mouse_position()
		_update_hover()
		queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn_rect.has_point(_mouse_pos) and _can_pull():
			pull_requested.emit()
		return

	if event.is_action_pressed("ui_accept"):
		if _can_pull():
			pull_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		close_requested.emit()
		get_viewport().set_input_as_handled()

## Whether the button does anything. Player checks the wallet again before
## taking money; this is only what the button looks like.
func _can_pull() -> bool:
	return _machine != null and not _spinning \
		and (_wallet == null or _wallet.can_afford(_machine.cost))

func _update_hover() -> void:
	_btn_hovered = _btn_rect.has_point(_mouse_pos)
