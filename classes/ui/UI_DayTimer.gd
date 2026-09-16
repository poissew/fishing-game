extends Control
class_name UIDayTimer

## Centre-top countdown showing how much real time is left in the current day,
## as MM:SS. A full cycle is 20 minutes, so it starts each dawn at 20:00, ticks
## down through 19:59, and rolls back over to 20:00 as the next day begins.
##
## Drawn in _draw() like the rest of the UI, but unlike UIDayNightIcon it only
## queues a redraw when the displayed second actually changes - the string is
## identical for sixty-odd frames at a time, so there is nothing to animate.

const FONT_PATH := "res://ui/fonts/monogram.ttf"

## monogram is drawn on a 16px grid, so keep this a whole multiple of 16 -
## anything in between lands glyphs on half pixels and the digits come out
## unevenly wide.
@export var font_size: int = 32
## Gap between the top of the screen and the top of the digits.
@export var margin_top: float = 6.0
@export var color: Color = Color(0.96, 0.96, 0.92, 1.0)
## The timer sits over open sky rather than on a panel, so it carries its own
## outline instead of relying on a background for contrast.
@export var outline_color: Color = Color(0.05, 0.06, 0.09, 0.85)
## Scaled with the text so the outline keeps the same visual weight.
@export var outline_size: int = 2

var _font: Font = null
## The string currently on screen, kept so _process can tell when it is stale.
var _text: String = ""

func _ready() -> void:
	_font = _load_font()
	_text = _format(daynight.time_left_in_day())

func _process(_delta: float) -> void:
	var next := _format(daynight.time_left_in_day())
	if next != _text:
		_text = next
		queue_redraw()

func _draw() -> void:
	if _font == null:
		return
	var width := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# draw_string takes a baseline, not a top-left corner, hence the ascent.
	var origin := Vector2((size.x - width) * 0.5, margin_top + _font.get_ascent(font_size))
	if outline_size > 0:
		draw_string_outline(_font, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, outline_size, outline_color)
	draw_string(_font, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## Rounded up, so the timer reads 20:00 for the whole of its first second and
## only shows 00:00 as the day actually runs out - a countdown that spent its
## first second already reading 19:59 would look broken.
static func _format(seconds_left: float) -> String:
	var total := int(ceil(maxf(seconds_left, 0.0)))
	return "%02d:%02d" % [total / 60, total % 60]

## monogram is a pixel font, so it has to be told not to antialias, hint or
## subpixel-position itself; Godot's default import settings would otherwise
## smear it at the game's 480x270 internal resolution. Applied to a duplicate so
## those choices do not leak onto the shared cached resource.
func _load_font() -> Font:
	var loaded := load(FONT_PATH)
	if loaded == null:
		return null
	var file := loaded as FontFile
	if file == null:
		return loaded as Font
	var pixel := file.duplicate() as FontFile
	pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel.hinting = TextServer.HINTING_NONE
	pixel.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return pixel
