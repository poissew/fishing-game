extends Control
class_name UIDayNightIcon

## Top-right clock face: the sun while it is up, swapped for the moon once it
## sets. Like UIInventory and UIShop it draws itself in _draw() rather than
## using child controls, which is also what makes the sun's spin a one-liner -
## draw_set_transform() rotates about the icon's centre without a pivot to keep
## in sync with the size.
##
## The sun turns on itself and the moon pulses from dim to bright and back, both
## over the same `spin_period`, so the two phases read at one tempo. That is
## also why `_phase` keeps running across the handover instead of resetting:
## picking up mid-turn means neither icon pops when it appears.
##
## Nothing here is wired to the lighting. It reads the `daynight` clock in
## _draw() exactly like DayNightLighting does, so the icon cannot drift out of
## step with the sky.

## Loaded rather than preloaded: these PNGs are imported by the editor, and a
## preload would take the whole script down if it ran before that happened.
const SUN_PATH := "res://ui/icons/sun.png"
const MOON_PATH := "res://ui/icons/lune.png"

## Seconds for one full turn of the sun, and for one full dim-bright-dim pulse
## of the moon.
@export var spin_period: float = 10.0
## Drawn size in the game's 480x270 internal resolution. The source art is
## 64x64, so this is a downscale.
@export var icon_size: float = 24.0
## Gap between the icon and the top-right corner of the screen.
@export var margin: float = 8.0
## How dim the moon gets at the bottom of its pulse, 1.0 being full brightness.
@export_range(0.0, 1.0) var moon_min_brightness: float = 0.45

var _sun: Texture2D = null
var _moon: Texture2D = null
## Runs 0 -> 1 over spin_period, then wraps. Drives both the sun's angle and
## the moon's brightness.
var _phase: float = 0.0

func _ready() -> void:
	_sun = load(SUN_PATH) as Texture2D
	_moon = load(MOON_PATH) as Texture2D

func _process(delta: float) -> void:
	if spin_period > 0.0:
		_phase = fposmod(_phase + delta / spin_period, 1.0)
	queue_redraw()

func _draw() -> void:
	var is_day := daynight.is_day()
	var texture := _sun if is_day else _moon
	if texture == null:
		return

	var extent := Vector2(icon_size, icon_size)
	var centre := Vector2(size.x - margin - icon_size * 0.5, margin + icon_size * 0.5)
	# Drawn around the origin so draw_set_transform's rotation is about the
	# icon's own centre rather than the corner of the screen.
	var rect := Rect2(-extent * 0.5, extent)

	if is_day:
		draw_set_transform(centre, _phase * TAU, Vector2.ONE)
		draw_texture_rect(texture, rect, false)
	else:
		draw_set_transform(centre, 0.0, Vector2.ONE)
		draw_texture_rect(texture, rect, false, _moon_tint())

## Dim at the start of the pulse, full brightness halfway through, back down by
## the end - one complete swing per spin_period, matching the sun's one turn.
func _moon_tint() -> Color:
	var swing := 0.5 - 0.5 * cos(_phase * TAU)
	var brightness := lerpf(moon_min_brightness, 1.0, swing)
	return Color(brightness, brightness, brightness, 1.0)
