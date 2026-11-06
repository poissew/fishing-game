class_name SlotMachine
extends StaticBody3D

## A one-armed bandit by the pond: pay cash, pull, and either a SpellCharm
## drops out or nothing does. Placed in TrenchBroom as [code]slot_machine_spawn[/code].
##
## Like Shopkeeper it knows nothing about the player. It names a price and
## rolls a prize; taking the money and handing the charm over is Player's job
## (Player.gamble()).
##
## What it does own is the show, and the show is [b]in the world[/b] rather
## than on a panel: three drums behind the glass, a lever that swings, and the
## price tag turning into the result. Player settles the pull first and then
## calls [method spin] with what came out, so closing the game on it, walking
## away mid-spin or the day ending under it all lose the show and never the
## prize.

## The reels have started turning.
signal spin_started()
## They have all stopped. `prize` is what was already paid out, null for nothing.
signal spin_finished(prize: SpellData)

## The eight symbols painted round each drum, in the order they run down
## [code]models/slot_reel_symbols.png[/code]. FISHBONE is the blank: nothing
## in the pool maps to it, so three of a kind can only ever be a win.
enum Symbol { FISH, FISHBONE, HOOK, STAR, BUBBLE, WORM, SEVEN, CHERRY }
const SYMBOL_COUNT := 8
const DUD := Symbol.FISHBONE
## The seven that can pay. Order matters: it is what spells are laid over.
const PRIZE_SYMBOLS: Array[int] = [Symbol.FISH, Symbol.HOOK, Symbol.STAR,
	Symbol.BUBBLE, Symbol.WORM, Symbol.SEVEN, Symbol.CHERRY]

## Turns a second while a drum is running flat out.
const SPIN_RATE := 2.6
## How long the first drum runs before it starts to brake, and how much later
## each one after it - the staggered stop is what reads as a slot machine.
const SPIN_FIRST := 1.1
const SPIN_STAGGER := 0.5
## How long a drum takes to come to rest once it starts braking.
const SETTLE := 0.75
## Shortest run-in the brake is allowed. Any less and the drum takes another
## whole turn first, because easing out of a quarter turn reads as a stutter.
const SETTLE_MIN_ARC := 1.2
## Chance a losing pull lands the first two drums on the same symbol. Near
## misses are what slot machines are made of.
const NEAR_MISS := 0.3
## How long the price tag shows the outcome before going back to the price.
const RESULT_HOLD := 4.0

const C_PRICE := Color(0.92, 0.72, 0.22)
const C_WIN   := Color(0.98, 0.88, 0.42)
const C_LOSE  := Color(0.85, 0.35, 0.30)

@export var machine_name: String = "Lucky Lure"
## What one pull costs.
@export_range(0, 1000, 1, "or_greater") var cost: int = 20
## Chance a pull pays out a spell at all. The rest of the time the money is gone.
@export_range(0.0, 1.0, 0.01) var win_chance: float = 0.4
## What it can pay out, drawn evenly. Empty means every spell in
## FishData.SPELL_POOL, so a new spell shows up in the machine on its own.
@export var spell_pool: Array[SpellData] = []

@export_category("Sound")
## Each of these is optional; a machine with none of them set is silent.
@export var sfx_pull: AudioStream
@export var sfx_win: AudioStream
@export var sfx_lose: AudioStream

## The cabinet's name board and price tag, filled from the exports so a map
## that renames or reprices the machine does not leave the old ones painted on.
@onready var _sign: Label3D = get_node_or_null("Sign")
@onready var _price: Label3D = get_node_or_null("Price")

## The three drums, left to right as the player sees them, and the glb's own
## AnimationPlayer. Found by name rather than by path: the model is an
## instanced scene and Godot's glTF importer decides how deep its root sits.
var _reels: Array[Node3D] = []
var _anim: AnimationPlayer = null
var _spinning: bool = false
var _result_left: float = 0.0

func _ready() -> void:
	if _sign != null:
		_sign.text = machine_name.to_upper()
	_show_price()
	for i in 3:
		var reel := find_child("Reel%d" % (i + 1), true, false) as Node3D
		if reel != null:
			_reels.append(reel)
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	set_process(false)

## Only ever running while the price tag is showing a result.
func _process(delta: float) -> void:
	_result_left = maxf(0.0, _result_left - delta)
	if _result_left == 0.0:
		_show_price()
		set_process(false)

## Every spell this machine can pay out.
func prizes() -> Array[SpellData]:
	var pool: Array[SpellData] = []
	if spell_pool.is_empty():
		pool.assign(FishData.SPELL_POOL)
	else:
		pool.assign(spell_pool)
	return pool

## One pull: a spell, or null for nothing. Does not charge anything - the
## caller has already taken [member cost].
func pull() -> SpellData:
	var pool := prizes()
	if pool.is_empty() or randomizer.RNG.randf() >= win_chance:
		return null
	return pool[randomizer.RNG.randi_range(0, pool.size() - 1)]

func is_spinning() -> bool:
	return _spinning

# ── The show ──────────────────────────────────────────────────────────────────

## Run the drums. `prize` is what the pull already paid out - null for nothing
## - and they are made to land on it. A machine with no model under it (a bare
## node in a test) finishes on the spot, so the prize never depends on this.
func spin(prize: SpellData) -> void:
	if _spinning:
		return
	_spinning = true
	# No countdown on this one: it stands until the drums land and _land()
	# writes the result over it.
	_result_left = 0.0
	set_process(false)
	if _price != null:
		_price.text = "GOOD LUCK"
		_price.modulate = C_PRICE
	spin_started.emit()
	_play(sfx_pull)
	if _anim != null and _anim.has_animation("pull"):
		_anim.play("pull")

	var picks := _outcome(prize)
	if _reels.is_empty():
		_land(prize)
		return
	var last: Tween = null
	for i in _reels.size():
		last = _run_reel(_reels[i], picks[i % picks.size()], SPIN_FIRST + i * SPIN_STAGGER)
	if last == null:
		_land(prize)
	else:
		last.finished.connect(_land.bind(prize))

## One drum: a flat-out run of `hold` seconds, then a braked turn onto
## `symbol`. The brake overshoots a touch and comes back, which is the clack
## of a real reel dropping onto its stop.
func _run_reel(reel: Node3D, symbol: int, hold: float) -> Tween:
	var from := reel.rotation.x
	# Drums turn the way that walks the symbols downwards past the window,
	# which is the direction the strip was wound on.
	var flat_out := from - TAU * SPIN_RATE * hold
	var arc := fposmod(flat_out - angle_for(symbol), TAU)
	if arc < SETTLE_MIN_ARC:
		arc += TAU
	var tween := create_tween()
	tween.tween_property(reel, "rotation:x", flat_out, hold).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(reel, "rotation:x", flat_out - arc, SETTLE) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

func _land(prize: SpellData) -> void:
	_spinning = false
	if prize != null:
		if _anim != null and _anim.has_animation("win"):
			_anim.play("win")
		_say("WON: %s" % prize.name.to_upper(), C_WIN)
		_play(sfx_win)
	else:
		_say("NO LUCK", C_LOSE)
		_play(sfx_lose)
	spin_finished.emit(prize)

## A pull that was turned down before any money moved.
func refuse(reason: String) -> void:
	if not _spinning:
		_say(reason.to_upper(), C_LOSE)

# ── Symbols ───────────────────────────────────────────────────────────────────

## Where a drum has to sit for `symbol` to be the one in the window. The strip
## runs round the drum exactly once, so one symbol is an eighth of a turn, and
## the half-step puts the symbol's middle on the pay line rather than its edge.
static func angle_for(symbol: int) -> float:
	return TAU * (float(symbol) + 0.5) / float(SYMBOL_COUNT) - PI * 0.5

## What a spell looks like on a drum. The pool is laid over the seven paying
## symbols in order, so a machine offering seven spells or fewer gives each
## its own and a bigger pool doubles up - the price tag is what says which
## spell actually came out, so sharing a symbol costs nothing.
func symbol_for(spell: SpellData) -> int:
	var at := prizes().find(spell)
	return PRIZE_SYMBOLS[maxi(at, 0) % PRIZE_SYMBOLS.size()]

## Where the three drums land. A win is three of the prize's symbol; a loss is
## anything else, sometimes deliberately one drum short of a win.
func _outcome(prize: SpellData) -> Array[int]:
	if prize != null:
		var won := symbol_for(prize)
		var jackpot: Array[int] = [won, won, won]
		return jackpot
	var rng: RandomNumberGenerator = randomizer.RNG
	var picks: Array[int] = [_random_symbol(), _random_symbol(), _random_symbol()]
	if rng.randf() < NEAR_MISS:
		var near := PRIZE_SYMBOLS[rng.randi_range(0, PRIZE_SYMBOLS.size() - 1)]
		picks[0] = near
		picks[1] = near
		picks[2] = DUD
	# Three of a kind reads as a win however it got there, bones included.
	if picks[0] == picks[1] and picks[1] == picks[2]:
		picks[2] = Symbol.SEVEN if picks[0] == DUD else DUD
	return picks

func _random_symbol() -> int:
	return randomizer.RNG.randi_range(0, SYMBOL_COUNT - 1)

# ── Cabinet ───────────────────────────────────────────────────────────────────

func _say(text: String, color: Color) -> void:
	if _price == null:
		return
	_price.text = text
	_price.modulate = color
	_result_left = RESULT_HOLD
	set_process(true)

func _show_price() -> void:
	if _price != null:
		_price.text = "$%d A PULL" % cost
		_price.modulate = C_PRICE

## The machine is a thing in the world now, so its noises come from it.
func _play(stream: AudioStream) -> void:
	if stream != null:
		audio.play_sfx_on(self, stream)
