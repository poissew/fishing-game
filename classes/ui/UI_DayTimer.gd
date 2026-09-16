extends Control
class_name UIDayTimer

## Centre-top countdown showing how much real time is left in the current day,
## as MM:SS. A full cycle is 20 minutes, so it starts each dawn at 20:00, ticks
## down through 19:59, and rolls back over to 20:00 as the next day begins.
##
## Drawn in _draw() like the rest of the UI, but unlike UIDayNightIcon it only
## queues a redraw when the displayed second actually changes - the string is
## identical for sixty-odd frames at a time, so there is nothing to animate.

## monogram is drawn on a 16px grid, so keep this a whole multiple of
## UIFont.SIZE - anything in between lands glyphs on half pixels and the digits
## come out unevenly wide.
@export var font_size: int = UIFont.SIZE * 2
## Gap between the top of the screen and the top of the digits.
@export var margin_top: float = 6.0
@export var color: Color = Color(0.96, 0.96, 0.92, 1.0)
## The timer sits over open sky rather than on a panel, so it carries its own
## outline instead of relying on a background for contrast.
@export var outline_color: Color = Color(0.05, 0.06, 0.09, 0.85)
## Scaled with the text so the outline keeps the same visual weight.
@export var outline_size: int = 2

## The string currently on screen, kept so _process can tell when it is stale.
var _text: String = ""

func _ready() -> void:
	_text = _format(daynight.time_left_in_day())

func _process(_delta: float) -> void:
	var next := _format(daynight.time_left_in_day())
	if next != _text:
		_text = next
		queue_redraw()

func _draw() -> void:
	var font := UIFont.FONT
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# draw_string takes a baseline, not a top-left corner, hence the ascent.
	var origin := Vector2((size.x - width) * 0.5, margin_top + font.get_ascent(font_size))
	if outline_size > 0:
		draw_string_outline(font, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, outline_size, outline_color)
	draw_string(font, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## Rounded up, so the timer reads 20:00 for the whole of its first second and
## only shows 00:00 as the day actually runs out - a countdown that spent its
## first second already reading 19:59 would look broken.
static func _format(seconds_left: float) -> String:
	var total := int(ceil(maxf(seconds_left, 0.0)))
	return "%02d:%02d" % [total / 60, total % 60]
