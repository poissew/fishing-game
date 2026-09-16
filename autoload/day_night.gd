## Global clock driving the 20-minute day/night cycle: 10 minutes of daylight
## (06:00 -> 18:00) then 10 minutes of night (18:00 -> 06:00).
##
## This node only keeps time. Nothing here touches lights, sky or materials -
## that is DayNightLighting's job, and it reads the clock rather than the clock
## pushing to it. Anything else that wants to care about the hour (night-only
## fish, a shop that closes) can query is_night() or connect to the signals
## without a scene dependency.
extends Node

## Emitted when the world flips between day and night.
signal phase_changed(is_day: bool)
## Emitted once per in-game hour, with the hour just reached (0-23).
signal hour_passed(hour: int)
## Emitted at each dawn, with the number of the day that just started (1-based).
signal day_passed(day: int)

## Real seconds of daylight, then of night. Together they make one full day.
const DAY_LENGTH := 600.0
const NIGHT_LENGTH := 600.0
const CYCLE_LENGTH := DAY_LENGTH + NIGHT_LENGTH

## In-game hours the two phases are pinned to: the sun rises at 06:00 and sets
## at 18:00, so each phase covers 12 of the 24 hours.
const DAWN_HOUR := 6
const DUSK_HOUR := 18
const HOURS_PER_DAY := 24
const DAYLIGHT_HOURS := DUSK_HOUR - DAWN_HOUR
const NIGHT_HOURS := HOURS_PER_DAY - DAYLIGHT_HOURS

## Hour the very first day starts at - mid-morning, so a new game opens in
## daylight with some of it left.
const START_HOUR := 8.0

## Seconds elapsed since the last dawn, always in [0, CYCLE_LENGTH).
var time: float = 0.0
## How many days have begun, counting the one the game starts on.
var day: int = 1
## Multiplier on the passage of time. 0 freezes the clock, higher values are
## handy for eyeballing the whole cycle without waiting 20 minutes.
var time_scale: float = 1.0

var _was_day: bool = true
var _last_hour: int = -1

func _ready() -> void:
	set_time_of_day(START_HOUR)

func _process(delta: float) -> void:
	advance(delta * time_scale)

## Push the clock forward by `seconds` of real time and fire whatever signals
## that crosses. Wrapping counts one day per whole cycle, so a jump of several
## days still emits day_passed for each of them; phase_changed and hour_passed
## only report the state landed on, not every step skipped over.
func advance(seconds: float) -> void:
	if seconds <= 0.0:
		return

	time += seconds
	while time >= CYCLE_LENGTH:
		time -= CYCLE_LENGTH
		day += 1
		day_passed.emit(day)

	_emit_crossings()

## Jump straight to an hour of the in-game day, e.g. set_time_of_day(21.5) for
## half past nine at night. Does not count as a new day.
##
## `announce` decides whether a jump that lands in the other phase is reported
## as one: off for a silent reposition, which is how the clock seeds itself in
## _ready(), and on for the dev skip below, where a listener waiting on
## phase_changed would otherwise miss the transition entirely.
func set_time_of_day(hour: float, announce: bool = false) -> void:
	time = _time_for_hour(hour)
	if announce:
		_emit_crossings()
	else:
		_sync_markers()

## Dev shortcut: drop straight to nightfall rather than waiting the day out.
func skip_to_night() -> void:
	set_time_of_day(DUSK_HOUR, true)

## Dev shortcut: jump to first light.
func skip_to_day() -> void:
	set_time_of_day(DAWN_HOUR, true)

## Dev shortcut: whichever of the two above is not where the clock already is,
## so the same key can be pressed repeatedly to step day -> night -> day.
func skip_to_next_phase() -> void:
	if is_day():
		skip_to_night()
	else:
		skip_to_day()

## True between dawn and dusk.
func is_day() -> bool:
	return time < DAY_LENGTH

func is_night() -> bool:
	return not is_day()

## Position through the whole 20-minute cycle: 0.0 at dawn, 0.25 at noon,
## 0.5 at dusk, 0.75 at midnight. This is what the lighting is keyed on.
func cycle_progress() -> float:
	return time / CYCLE_LENGTH

## Position through the current phase alone, 0.0 at its start and 1.0 at its
## end, whether that phase is the day or the night.
func phase_progress() -> float:
	if is_day():
		return time / DAY_LENGTH
	return (time - DAY_LENGTH) / NIGHT_LENGTH

## Real seconds left before the current phase ends.
func time_until_phase_change() -> float:
	if is_day():
		return DAY_LENGTH - time
	return CYCLE_LENGTH - time

## The in-game hour as a fraction, e.g. 18.5 for 18:30.
func hour_of_day() -> float:
	if is_day():
		return DAWN_HOUR + phase_progress() * DAYLIGHT_HOURS
	return fposmod(DUSK_HOUR + phase_progress() * NIGHT_HOURS, HOURS_PER_DAY)

## The clock as "HH:MM", for a HUD or for debugging.
func time_string() -> String:
	var hours := hour_of_day()
	var whole := int(hours)
	var minutes := int((hours - whole) * 60.0)
	return "%02d:%02d" % [whole, minutes]

## Inverse of hour_of_day(): where in the cycle a given in-game hour falls.
func _time_for_hour(hour: float) -> float:
	var wrapped := fposmod(hour, float(HOURS_PER_DAY))
	if wrapped >= DAWN_HOUR and wrapped < DUSK_HOUR:
		return (wrapped - DAWN_HOUR) / DAYLIGHT_HOURS * DAY_LENGTH
	var since_dusk := fposmod(wrapped - DUSK_HOUR, float(HOURS_PER_DAY))
	return DAY_LENGTH + since_dusk / NIGHT_HOURS * NIGHT_LENGTH

func _emit_crossings() -> void:
	var day_now := is_day()
	if day_now != _was_day:
		_was_day = day_now
		phase_changed.emit(day_now)

	var hour_now := int(hour_of_day())
	if hour_now != _last_hour:
		_last_hour = hour_now
		hour_passed.emit(hour_now)

## Re-arm the crossing detectors after a jump, so set_time_of_day() does not
## report a phase change or an hour that was never lived through.
func _sync_markers() -> void:
	_was_day = is_day()
	_last_hour = int(hour_of_day())
