## The game's round structure: a day of fishing, then one fish sent to fight.
##
##   FISHING  ->  SELECTION  ->  BATTLE  ->  FISHING (next day)
##
## Like `daynight` this node is state and signals only - no scene, no UI, no
## reference to the player. Whoever is running the game (Player today, an arena
## scene tomorrow) listens to the signals and puts things on screen; this only
## says which phase the game is in and refuses transitions that make no sense.
##
## The day ending is what starts a round's second half: the clock's day_passed
## fires when the 20-minute cycle wraps, the world clock is frozen so the day
## does not tick on behind the selection screen, and it is set running again
## when the battle is over.
extends Node

enum Phase {
	FISHING,   ## Free roaming: cast, sell, restock. Ends when the day runs out.
	SELECTION, ## Day over, clock frozen: pick the fish that will fight.
	BATTLE,    ## The chosen fish is in the arena. Ends with end_battle().
}

## Emitted on every transition, with the phase just entered.
signal phase_changed(phase: Phase)
## The day ran out: a champion has to be picked out of the day's catch.
signal selection_started()
## `fish` has been sent to the arena. This is the hook an arena scene binds to;
## it is handed the fish and owns the fight until it calls end_battle().
signal battle_started(fish: FishInstance)
## The fight is over. `won` is the outcome and `fish` the champion that fought,
## which may be dead - check is_alive() rather than trusting `won` alone.
signal battle_ended(won: bool, fish: FishInstance)

## Where the game currently is. Only ever written by _set_phase().
var phase: Phase = Phase.FISHING
## The fish picked for the current battle, null outside of one.
var champion: FishInstance = null

## The clock's time_scale as it was before the day was frozen, so resuming puts
## back whatever it was rather than assuming 1.0.
var _clock_scale: float = 1.0

func _ready() -> void:
	daynight.day_passed.connect(_on_day_passed)

func is_fishing() -> bool:
	return phase == Phase.FISHING

func is_selecting() -> bool:
	return phase == Phase.SELECTION

func is_battling() -> bool:
	return phase == Phase.BATTLE

## True while the world is on hold - nothing in the level should move, and the
## player should not be able to walk or cast.
func is_world_paused() -> bool:
	return not is_fishing()

# ── Transitions ───────────────────────────────────────────────────────────────

## The 20-minute cycle wrapped round to a new dawn: the fishing day is over.
func _on_day_passed(_day: int) -> void:
	begin_selection()

## Close the fishing day and ask for a champion. Safe to call by hand (a boat
## back to shore, a debug key) - it is ignored unless the game is fishing.
func begin_selection() -> void:
	if not is_fishing():
		return
	champion = null
	_freeze_clock()
	_set_phase(Phase.SELECTION)
	selection_started.emit()

## Send `fish` into the arena. Returns false if it is not a valid champion -
## no fish given, or the game is not waiting for one.
func send_to_battle(fish: FishInstance) -> bool:
	if not is_selecting() or fish == null:
		return false
	champion = fish
	# Whatever the fish went through on the way in, it fights at full health.
	champion.reset_health()
	_set_phase(Phase.BATTLE)
	battle_started.emit(champion)
	return true

## No fish to send (an empty creel, or the player passing): go straight to the
## next fishing day without a fight.
func skip_battle() -> void:
	if not is_selecting():
		return
	champion = null
	_begin_fishing()

## Called by whoever ran the fight - the placeholder screen today, the arena
## once it exists. `won` is the outcome from the player's side.
func end_battle(won: bool) -> void:
	if not is_battling():
		return
	var fought := champion
	champion = null
	battle_ended.emit(won, fought)
	_begin_fishing()

## Back to the water. The clock has already rolled over to the new day, so this
## only has to start it ticking again.
func _begin_fishing() -> void:
	_thaw_clock()
	_set_phase(Phase.FISHING)

func _set_phase(next: Phase) -> void:
	if next == phase:
		return
	phase = next
	phase_changed.emit(phase)

# ── World clock ───────────────────────────────────────────────────────────────

func _freeze_clock() -> void:
	_clock_scale = daynight.time_scale
	daynight.time_scale = 0.0

func _thaw_clock() -> void:
	daynight.time_scale = _clock_scale
