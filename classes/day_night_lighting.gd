## Turns the `daynight` clock into something you can see: it swings the sun,
## recolours it, dims the sky, and lays a tint over the whole frame.
##
## The tint is the part that matters here. This game is sprite-first and most
## of what is on screen ignores lights entirely - the ground material is
## SHADING_MODE_UNSHADED, the trees and every held item are Sprite3D - so
## rotating a DirectionalLight3D on its own would leave the world exactly as
## bright at midnight as at noon. A full-screen ColorRect multiplied over the
## viewport darkens the unshaded majority too, and being inside the low-res
## SubViewport it is pixelated along with everything else.
##
## Drop this anywhere in the level and point `sun` at the DirectionalLight3D.
class_name DayNightLighting
extends Node3D

## The sun. Its rotation, colour and energy are driven from here, so whatever
## is set in the editor gets overwritten on the first frame.
@export var sun: DirectionalLight3D

## Brightest the sun gets (at noon). The night's moonlight is a fraction of it.
@export var sun_energy: float = 0.65
## Moonlight energy as a share of `sun_energy`, reached in the middle of night.
@export_range(0.0, 1.0) var moon_energy_ratio: float = 0.28
## Share of `sun_energy` left at the horizon. Day and night both fade to this
## same value, which is what stops the light popping as one phase hands over to
## the other.
@export_range(0.0, 1.0) var twilight_energy_ratio: float = 0.2
## How far the sky itself is dimmed at midnight, on top of the screen tint.
@export_range(0.0, 1.0) var night_sky_energy: float = 0.45

## Compass direction the sun comes from. The moon rises from the opposite side.
@export_range(-180.0, 180.0) var sun_azimuth_degrees: float = 35.0

## Canvas layer the tint sits on. Negative so it covers the 3D world but stays
## under the inventory and shop UI, which live on the default layer 0.
const TINT_LAYER := -1

## What the frame is multiplied by, keyed on daynight.cycle_progress():
## 0.0 dawn, 0.25 noon, 0.5 dusk, 0.75 midnight. White is a no-op, so daytime
## renders exactly as it did before this existed.
const TINT_KEYS := [
	[0.00, Color(0.78, 0.58, 0.52)],
	[0.07, Color(1.00, 1.00, 1.00)],
	[0.40, Color(1.00, 1.00, 1.00)],
	[0.50, Color(0.88, 0.54, 0.42)],
	[0.58, Color(0.30, 0.36, 0.60)],
	[0.92, Color(0.30, 0.36, 0.60)],
	[1.00, Color(0.78, 0.58, 0.52)],
]

## Colour of the light itself, on the same 0..1 cycle key. Only the handful of
## shaded surfaces react to this, but it is what keeps the water warm at dusk.
const LIGHT_KEYS := [
	[0.00, Color(1.00, 0.72, 0.50)],
	[0.10, Color(1.00, 0.98, 0.92)],
	[0.40, Color(1.00, 0.95, 0.86)],
	[0.50, Color(1.00, 0.60, 0.38)],
	[0.60, Color(0.55, 0.65, 1.00)],
	[0.92, Color(0.55, 0.65, 1.00)],
	[1.00, Color(1.00, 0.72, 0.50)],
]

var _tint_rect: ColorRect = null
var _environment: Environment = null
## Sky energy as authored, so night_sky_energy dims from the artist's value
## rather than from a hardcoded 1.0.
var _base_sky_energy: float = 1.0

func _ready() -> void:
	_build_tint()
	_apply(daynight.cycle_progress())

func _process(_delta: float) -> void:
	_apply(daynight.cycle_progress())

func _apply(progress: float) -> void:
	var tint := _sample(TINT_KEYS, progress)
	if _tint_rect != null:
		_tint_rect.color = tint

	if sun != null:
		sun.rotation = _light_rotation(progress)
		sun.light_color = _sample(LIGHT_KEYS, progress)
		sun.light_energy = sun_energy * _energy_ratio(progress)

	_apply_sky(progress)

## Sun and moon share one arc: each rises at the start of its own phase, sits
## overhead halfway through it and sets at the end. A moon straight overhead at
## midnight is not astronomy, but it keeps the light coming from above all night
## instead of shining up through the floor.
func _light_rotation(progress: float) -> Vector3:
	var azimuth := deg_to_rad(sun_azimuth_degrees)
	if _is_night(progress):
		azimuth += PI
	return Vector3(-_arc(progress) * PI, azimuth, 0.0)

## 1.0 at noon and `moon_energy_ratio` at midnight, both falling off to
## `twilight_energy_ratio` as the body reaches the horizon. Sharing that one
## floor across the two phases keeps the light continuous through dawn and dusk
## even though the peak either side of them is wildly different.
func _energy_ratio(progress: float) -> float:
	var peak := moon_energy_ratio if _is_night(progress) else 1.0
	return lerpf(twilight_energy_ratio, peak, _height(progress))

## Resolved lazily and retried until it lands: on the very first frame the
## Player's camera may not be the current one yet, so there is nothing to ask.
func _apply_sky(progress: float) -> void:
	if _environment == null:
		_environment = _resolve_environment()
		if _environment == null:
			return
		_base_sky_energy = _environment.background_energy_multiplier

	var target := 1.0
	if _is_night(progress):
		target = lerpf(1.0, night_sky_energy, _height(progress))
	_environment.background_energy_multiplier = _base_sky_energy * target

## The Player's Camera3D carries its own Environment, which overrides the
## level's WorldEnvironment while that camera is current - so the camera has to
## be asked first or the sky would never change.
func _resolve_environment() -> Environment:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.environment != null:
		return camera.environment
	return _find_world_environment(get_tree().current_scene)

func _find_world_environment(node: Node) -> Environment:
	if node == null:
		return null
	if node is WorldEnvironment:
		return (node as WorldEnvironment).environment
	for child in node.get_children():
		var found := _find_world_environment(child)
		if found != null:
			return found
	return null

func _build_tint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DayNightTint"
	layer.layer = TINT_LAYER

	_tint_rect = ColorRect.new()
	_tint_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint_rect.color = Color.WHITE

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint_rect.material = material

	layer.add_child(_tint_rect)
	add_child(layer)

## Which half of the cycle `progress` falls in. Taken from the progress passed
## around rather than from daynight.is_night() so that everything _apply() does
## comes from the one value, and a caller can preview any moment of the cycle.
func _is_night(progress: float) -> bool:
	return fposmod(progress, 1.0) >= 0.5

## Position through the current phase, 0 at its start, 1 at its end.
func _arc(progress: float) -> float:
	return fposmod(progress, 0.5) / 0.5

## How high the sun (or moon) sits: 0 at both horizons, 1 halfway through the
## phase.
func _height(progress: float) -> float:
	return sin(_arc(progress) * PI)

## Linear interpolation across a table of [offset, Color] pairs sorted by
## offset, the first and last of which should match so the cycle loops cleanly.
func _sample(keys: Array, offset: float) -> Color:
	var p := clampf(offset, 0.0, 1.0)
	for i in range(keys.size() - 1):
		var from: Array = keys[i]
		var to: Array = keys[i + 1]
		if p <= to[0]:
			var span: float = to[0] - from[0]
			var t: float = 0.0 if span <= 0.0 else (p - from[0]) / span
			return (from[1] as Color).lerp(to[1] as Color, t)
	return keys[keys.size() - 1][1] as Color
