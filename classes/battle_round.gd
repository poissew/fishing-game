## The clock a fight runs on, and the thing that decides who won it.
##
## A round is either won outright - one fish kills the other - or it runs out of
## time, and then the arena stops waiting politely. Once `duration` is up every
## fish still standing starts losing health on a timer, by more each tick, until
## there is one left. That is the whole of sudden death: nobody is helped, the
## fish that was doing better simply outlasts the one that was not.
##
## It is game code rather than dev code, even though `dev/TestArena.tscn` is the
## only thing using it today: a real arena needs a clock and a winner exactly as
## much as the test one does, and this is where both live. It owns no scene and
## draws nothing - hand it the battlers, listen for `finished`.
##
## Nothing here touches `gamephase`. Whoever runs the arena decides what winning
## a round means for the round after it.
class_name BattleRound
extends Node

## Fired the moment the clock runs out, before the first tick of the drain.
signal time_up
## Fired on every tick of sudden death, with what each fish still standing lost.
signal drained(amount: int)
## Fired once, when there is nobody left to fight: the last fish standing, or
## null if the round somehow ended with none.
signal finished(winner: BattleFish)

@export_category("Round")
## Seconds of ordinary fighting before sudden death starts.
@export_range(5.0, 600.0, 1.0, "suffix:s") var duration: float = 60.0

@export_category("Sudden death")
## Seconds between two turns of the screws.
@export_range(0.05, 10.0, 0.05, "suffix:s") var drain_interval: float = 1.0
## What the first tick costs, and what each tick adds to the one before it.
## Growth is what guarantees an end: a fish with a big enough health pool would
## sit out a flat drain for a very long time, and the arena has already decided
## it is bored.
@export var drain_base: int = 1
@export var drain_growth: int = 1

var _battlers: Array[BattleFish] = []
var _left := 0.0
var _drain_timer := 0.0
var _drain_step := 0
var _drain_amount := 0
var _winner: BattleFish = null
var _running := false

## Starts a fresh round over `battlers`. Anything already running is dropped.
func start(battlers: Array[BattleFish]) -> void:
	stop()
	_battlers = battlers.duplicate()
	for battler in _battlers:
		if is_instance_valid(battler) and not battler.died.is_connected(_on_battler_died):
			battler.died.connect(_on_battler_died)
	_left = duration
	_drain_timer = drain_interval
	_drain_step = 0
	_drain_amount = 0
	_winner = null
	_running = not _battlers.is_empty()

## Lets go of the current round without deciding anything.
func stop() -> void:
	for battler in _battlers:
		if is_instance_valid(battler) and battler.died.is_connected(_on_battler_died):
			battler.died.disconnect(_on_battler_died)
	_battlers.clear()
	_running = false

## Seconds of ordinary fighting left, 0 once sudden death has started.
func time_left() -> float:
	return _left

## Whether the clock has run out and the draining has begun.
func is_sudden_death() -> bool:
	return _running and _left <= 0.0

## What the last tick of the drain cost, for a readout. 0 before the first.
func drain_amount() -> int:
	return _drain_amount

## The fish that won, once `finished` has fired. Null before that.
func winner() -> BattleFish:
	return _winner

func is_running() -> bool:
	return _running

func _process(delta: float) -> void:
	if not _running:
		return
	if _left > 0.0:
		_left = maxf(0.0, _left - delta)
		if _left <= 0.0:
			time_up.emit()
		return
	_drain_timer -= delta
	while _running and _drain_timer <= 0.0:
		_drain_timer += maxf(drain_interval, 0.05)
		_drain()

## One turn of the screws. Everything still standing loses the same amount,
## weakest first, and the moment only one fish is left the rest of the tick is
## called off - so a tick can never take the last two together and leave nobody
## to hand the round to. A dead tie goes to whichever the sort put second, which
## is as good an answer as there is.
func _drain() -> void:
	_drain_step += 1
	_drain_amount = maxi(1, drain_base + drain_growth * (_drain_step - 1))
	# Announced before it lands, so that anything listening reports the tick and
	# then the death it caused, rather than the other way round: `finished` comes
	# out of take_tick_damage() below, by way of the fish's own died signal.
	drained.emit(_drain_amount)
	var standing := _standing()
	standing.sort_custom(func(a, b): return a.fish.current_health < b.fish.current_health)
	for battler in standing:
		if _standing().size() <= 1:
			break
		# No source and no direction: the arena itself is doing this, and a fish
		# shoved by the passage of time would be a strange sight.
		battler.take_tick_damage(_drain_amount)
	_check_over()

## Everything that is still in the fight.
func _standing() -> Array[BattleFish]:
	var alive: Array[BattleFish] = []
	for battler in _battlers:
		if is_instance_valid(battler) and battler.is_alive():
			alive.append(battler)
	return alive

func _on_battler_died(_battler: BattleFish) -> void:
	_check_over()

## Ends the round if there is nobody left to fight. Safe to call as often as
## anything likes: it only fires `finished` the once.
func _check_over() -> void:
	if not _running:
		return
	var standing := _standing()
	if standing.size() > 1:
		return
	_winner = standing[0] if standing.size() == 1 else null
	_running = false
	finished.emit(_winner)
