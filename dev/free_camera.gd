extends Camera3D

## Fly-around camera for the test arena, so a fight can be watched from any
## angle instead of the one the scene was saved at.
##
## Dev-only, like the rest of `dev/`. Nothing in the game uses it.
##
##   Right mouse - toggle looking (the mouse is captured while it is on)
##   WASD        - fly, relative to where the camera is pointed
##   Space/Ctrl  - straight up and down
##   Shift/Alt   - faster / finer
##   Wheel       - change the base speed
##   F           - back to the view the scene opens on
##
## The keys and the mouse are read by test_arena.gd, not here: this camera
## lives inside a SubViewport, and a SubViewport only ever sees the input its
## container passes on, while the arena root sits in the main viewport and gets
## the lot. So this half is the camera - look(), fly, speed, home - and the
## arena calls into it. Movement is the exception: it polls Input directly,
## which needs no events at all, and through the game's own WASD actions rather
## than hardcoded keys, so it follows the input map.

## Units per second at the default speed, and the range the wheel can take it.
const SPEED_DEFAULT := 4.0
const SPEED_MIN := 0.5
const SPEED_MAX := 40.0
## Multiplier per wheel notch.
const SPEED_STEP := 1.2

## Held-modifier multipliers.
const SPRINT := 3.0
const CREEP := 0.25

## How close to straight up or down the camera can look. Stopping just short of
## a right angle keeps the horizon from flipping over.
const PITCH_LIMIT := 1.55

## Current fly speed, before the modifier keys.
var speed := SPEED_DEFAULT

var _looking := false
var _yaw := 0.0
var _pitch := 0.0
## The transform the scene was saved with, to come back to with F.
var _home := Transform3D.IDENTITY

func _ready() -> void:
	_home = transform
	_read_angles_from_transform()

func _process(delta: float) -> void:
	_fly(delta)

func _notification(what: int) -> void:
	# Alt-tabbing away hands the mouse back on its own; take it again on the way
	# in, so the camera is never left thinking it still has a cursor it lost.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _looking:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# -- Flying --------------------------------------------------------------------

func _fly(delta: float) -> void:
	var move := Vector3.ZERO
	# basis.z points backwards out of the screen, hence the minus.
	move -= basis.z * (Input.get_action_strength("forward") - Input.get_action_strength("backward"))
	move += basis.x * (Input.get_action_strength("right") - Input.get_action_strength("left"))
	# Up and down stay world-aligned even when looking at the floor, which is
	# what makes a freecam feel like one.
	move += Vector3.UP * (_key(KEY_SPACE) - _key(KEY_CTRL))
	if move == Vector3.ZERO:
		return
	position += move.normalized() * speed * _modifier() * delta

func _modifier() -> float:
	if Input.is_key_pressed(KEY_SHIFT):
		return SPRINT
	if Input.is_key_pressed(KEY_ALT):
		return CREEP
	return 1.0

func _key(keycode: Key) -> float:
	return 1.0 if Input.is_key_pressed(keycode) else 0.0

# -- What the arena drives -----------------------------------------------------

## True while the camera has the mouse, so Escape can hand the cursor back
## before it quits.
func is_looking() -> bool:
	return _looking

## Takes or hands back the mouse.
func set_looking(looking: bool) -> void:
	_looking = looking
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE

## Turns by a mouse movement, in the same units the player's head uses so the
## two feel alike. Ignored unless the camera is looking.
func look(relative: Vector2) -> void:
	if not _looking:
		return
	_yaw -= relative.x * options.MOUSE_SENS
	_pitch = clampf(_pitch - relative.y * options.MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)
	_apply_angles()

## One wheel notch up (+1) or down (-1).
func nudge_speed(notches: int) -> void:
	speed = clampf(speed * pow(SPEED_STEP, notches), SPEED_MIN, SPEED_MAX)

## Back to the angle and place the scene opens on, for when flying about has
## left the arena somewhere off screen.
func go_home() -> void:
	transform = _home
	speed = SPEED_DEFAULT
	_read_angles_from_transform()

# -- Angles --------------------------------------------------------------------

## Yaw and pitch are tracked separately and written back whole, so the camera
## can never pick up any roll from accumulated rotations.
func _apply_angles() -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)

func _read_angles_from_transform() -> void:
	_pitch = clampf(rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
	_yaw = rotation.y
	_apply_angles()
