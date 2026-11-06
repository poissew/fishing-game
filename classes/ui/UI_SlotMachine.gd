extends Control
class_name UISlotMachine

## What is left of the slot machine's screen once the machine itself became
## the panel: the "[E]" prompt while one is in reach, and a line above it for
## whatever the last pull had to say.
##
## The reels, the lever and the result are all in the world now - see
## SlotMachine - so this only says the two things the cabinet cannot say for
## itself: what a pull costs out of the player's own wallet, and where a charm
## went once it was won. There is no panel, nothing to open, and the mouse is
## never taken off the camera.

## How long a line hangs about before it fades out of the way.
const NOTICE_HOLD := 4.5

const C_BG     := Color(0.09, 0.13, 0.09, 0.92)
const C_PROMPT := Color(0.55, 0.80, 0.45, 1.00)
const C_MONEY  := Color(0.92, 0.82, 0.32, 1.00)
const C_LOSE   := Color(0.82, 0.36, 0.30, 1.00)

## Baseline-to-baseline for the stacked lines. monogram caps are 7px with 2px
## descenders, so 13 keeps the backing plates from touching.
const LINE_H := 13.0

var _wallet: Wallet = null
var _nearby: SlotMachine = null
var _notice: String = ""
var _notice_color: Color = C_PROMPT
var _notice_left: float = 0.0

func _ready() -> void:
	set_process(false)

func bind_wallet(wallet: Wallet) -> void:
	_wallet = wallet
	if _wallet != null and not _wallet.changed.is_connected(queue_redraw):
		_wallet.changed.connect(queue_redraw)

## Machine the player is standing next to, or null. Drives the prompt.
func set_nearby(machine: SlotMachine) -> void:
	_nearby = machine
	set_process(_nearby != null or _notice != "")
	queue_redraw()

## Something to say about the last pull.
func notice(text: String, color: Color = C_PROMPT) -> void:
	if text == "":
		return
	_notice = text
	_notice_color = color
	_notice_left = NOTICE_HOLD
	set_process(true)
	queue_redraw()

func clear_notice() -> void:
	_notice = ""
	_notice_left = 0.0
	set_process(_nearby != null)
	queue_redraw()

## What a finished pull came to. Connected to SlotMachine.spin_finished, so it
## arrives when the drums stop rather than when the money moved.
func won(prize: SpellData) -> void:
	if prize == null:
		notice("Nothing. The machine keeps your money.", C_LOSE)
	else:
		notice("WON: %s - in your bag (Tab), drag it onto a fish."
			% prize.name.to_upper(), C_MONEY)

func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left = maxf(0.0, _notice_left - delta)
		if _notice_left == 0.0:
			_notice = ""
	if _nearby == null and _notice == "":
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var lines: Array = []
	if _notice != "":
		lines.append([_notice, _notice_color])
	if _nearby != null:
		lines.append([_prompt(), C_PROMPT])
	if lines.is_empty():
		return
	var font := UIFont.FONT
	var vp := get_viewport_rect().size
	var y := vp.y - 24.0
	# Drawn bottom-up, so the prompt sits lowest and the notice stacks above it.
	for i in range(lines.size() - 1, -1, -1):
		var text: String = lines[i][0]
		var color: Color = lines[i][1]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE).x
		var pos := Vector2(floor((vp.x - w) / 2.0), y)
		draw_rect(Rect2(pos + Vector2(-4, -9), Vector2(w + 8, 13)), C_BG)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIFont.SIZE, color)
		y -= LINE_H

func _prompt() -> String:
	var name := _nearby.machine_name.to_upper()
	if _nearby.is_spinning():
		return "%s  SPINNING..." % name
	if _wallet != null and not _wallet.can_afford(_nearby.cost):
		return "%s  NEED $%d" % [name, _nearby.cost]
	return "[E] %s  $%d" % [name, _nearby.cost]
