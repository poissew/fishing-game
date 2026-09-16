extends Node3D

## Dev-only scene: two BattleFish in a box, so the flopping and the contact
## damage can actually be watched. Run it on its own with F6 - it is not part
## of the game, nothing loads it, and `gamephase` is left alone (the fight here
## is not a round, so no phase is entered and no day is ended).
##
## It is the same 480x270 SubViewport the game renders through, so the fish and
## the readout pixelate exactly as they would in the real arena.
##
## The round itself - the clock, sudden death, and which fish is handed the win -
## is BattleRound, which is game code and not part of this scene. This just
## starts one per pair and listens.
##
##   R / Enter - fresh pair of fighters
##   1 / 2     - rematch the same two, healed up
##   E         - rematch with both of them given the next spell in the pool,
##               and every spell at once on the last press
##   Escape    - hand the mouse back, then quit
##
## The camera keys are listed in free_camera.gd, which does the flying; the
## events that drive it are read here, in _camera_input().

const SPECIES := [
	preload("res://data/items/fish/sardine.tres"),
	preload("res://data/items/fish/goldfish.tres"),
	preload("res://data/items/fish/trout.tres"),
	preload("res://data/items/fish/bass.tres"),
	preload("res://data/items/fish/cod.tres"),
	preload("res://data/items/fish/catfish.tres"),
	preload("res://data/items/fish/shark.tres"),
]

## Handed to both fighters by the E key, so a spell can be watched without
## waiting for one to roll on a fish.
const TEST_SPELLS := FishData.SPELL_POOL

## One colour per side, so the two fighters are told apart at a glance even in
## a rematch. The fish keep their own icon; this only tints it.
const TEAM_TINTS := [
	Color(1.00, 0.72, 0.62, 1.0),
	Color(0.66, 0.84, 1.00, 1.0),
]

## Where the two fighters drop in, and how high above the floor.
const SPAWN_X := 2.6
const SPAWN_Y := 1.2

@onready var _fighters: Node3D = $pixel/SubViewport/Fighters
## Untyped for the same reason as the HUD: free_camera.gd is a dev script with
## no class_name, and a Camera3D type here could not see is_looking().
@onready var _camera = $pixel/SubViewport/Camera3D
## Left untyped on purpose: the HUD is a dev-only script with no class_name, so
## a static type here would mean putting one in the game's global class list.
@onready var _hud = $pixel/SubViewport/HUD

## The two fighters, in team order. The HUD reads this.
var battlers: Array[BattleFish] = []
## Set when the round is decided, and read by the HUD for the banner.
var winner: BattleFish = null
## The clock this round is running on. The HUD reads it for the countdown.
var round_clock: BattleRound = null
## Which spell the E key hands out next: an index into TEST_SPELLS, or the size
## of it for "all of them at once".
var armed_index := 0

func _ready() -> void:
	round_clock = BattleRound.new()
	round_clock.name = "BattleRound"
	add_child(round_clock)
	round_clock.time_up.connect(_on_time_up)
	round_clock.drained.connect(_on_drained)
	round_clock.finished.connect(_on_round_finished)
	_hud.bind_arena(self)
	start_round()

# -- Rounds --------------------------------------------------------------------

## Clears the floor and drops in two fresh fish of different species.
func start_round() -> void:
	var picks := _pick_species()
	_spawn_pair([
		FishInstance.new().create_fish_instance(picks[0]),
		FishInstance.new().create_fish_instance(picks[1]),
	])
	_hud.log_line("%s vs %s" % [picks[0].name, picks[1].name])

## Runs the same two fish again. bind_fish() heals them on the way in, so this
## is a rematch between the exact same rolls rather than a new pair - handy for
## seeing whether a matchup is actually as one-sided as it looked.
func rematch() -> void:
	if battlers.size() < 2:
		start_round()
		return
	_spawn_pair([battlers[0].fish, battlers[1].fish])
	_hud.log_line("rematch")

## Rematch with both fish carrying a spell they did not roll. One spell at a
## time, stepping to the next on each press and finishing on the whole pool:
## handing both fish everything at once includes Coward, and two cowards spend
## the round running away from each other.
func armed_rematch() -> void:
	if battlers.size() < 2:
		start_round()
	var handed: Array[SpellData] = []
	if armed_index >= TEST_SPELLS.size():
		handed.assign(TEST_SPELLS)
	else:
		handed.append(TEST_SPELLS[armed_index])
	armed_index = (armed_index + 1) % (TEST_SPELLS.size() + 1)

	for battler in battlers:
		var spells: Array[SpellInstance] = []
		for spell_data in handed:
			spells.append(SpellInstance.create_spell_instance(spell_data))
		battler.fish.spells = spells
	_spawn_pair([battlers[0].fish, battlers[1].fish])
	_hud.log_line("armed: %s" % _spell_names(handed))

func _spell_names(spells: Array[SpellData]) -> String:
	var names := PackedStringArray()
	for spell in spells:
		names.append(spell.name)
	return ", ".join(names)

func _spawn_pair(fish: Array) -> void:
	for child in _fighters.get_children():
		child.queue_free()
	battlers.clear()
	winner = null
	_hud.clear_log()

	for i in 2:
		var battler := BattleFish.spawn(fish[i])
		battler.team = i
		battler.tint = TEAM_TINTS[i]
		battler.position = Vector3(SPAWN_X if i == 1 else -SPAWN_X, SPAWN_Y, 0.0)
		battler.dealt_damage.connect(_on_dealt_damage.bind(battler))
		battler.cast_spell.connect(_on_cast_spell.bind(battler))
		battler.stunned.connect(_on_stunned.bind(battler))
		battler.died.connect(_on_battler_died)
		_fighters.add_child(battler)
		battlers.append(battler)

	# Each one flops at the other, otherwise two fish wandering a floor this
	# size would take all afternoon to bump into each other.
	battlers[0].chase_target = battlers[1]
	battlers[1].chase_target = battlers[0]

	round_clock.start(battlers)

## Two different species, so a round is never a fish against its own twin.
func _pick_species() -> Array:
	var pool := SPECIES.duplicate()
	pool.shuffle()
	return [pool[0], pool[1]]

# -- Reporting -----------------------------------------------------------------

func _on_dealt_damage(target: BattleFish, amount: int, attacker: BattleFish) -> void:
	_hud.log_line("%s hits %s for %d" % [
		attacker.fish.data.name, target.fish.data.name, amount])

func _on_cast_spell(spell: SpellData, _target: BattleFish, caster: BattleFish) -> void:
	_hud.log_line("%s casts %s" % [caster.fish.data.name, spell.name])

func _on_stunned(seconds: float, battler: BattleFish) -> void:
	_hud.log_line("%s is seeing spots for %.1fs" % [battler.fish.data.name, seconds])

func _on_battler_died(battler: BattleFish) -> void:
	# Deferred: `died` comes out of take_damage(), so it beats the attacker's
	# dealt_damage to the log and the kill would otherwise print above the hit
	# that caused it.
	_hud.log_line.call_deferred("%s is done for" % battler.fish.data.name)

func _on_time_up() -> void:
	_hud.log_line("time up - sudden death")

func _on_drained(amount: int) -> void:
	_hud.log_line("the arena takes %d" % amount)

## BattleRound decides the winner, here and when a fish simply dies: the arena
## only has to remember it for the banner.
func _on_round_finished(round_winner: BattleFish) -> void:
	winner = round_winner

# -- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _camera_input(event):
		return

	if event.is_action_pressed("pause"):
		# One Escape to get the cursor back off the camera, a second to leave.
		if _camera.is_looking():
			_camera.set_looking(false)
		else:
			get_tree().quit()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_R, KEY_ENTER, KEY_KP_ENTER:
			start_round()
		KEY_1, KEY_2:
			rematch()
		KEY_E:
			armed_rematch()

## Everything the freecam listens for, read here rather than in free_camera.gd.
## The camera is inside the SubViewport, which only sees the input its container
## chooses to pass on; this node is in the main viewport and gets all of it.
## Returns true when the event was the camera's, so nothing else acts on it.
func _camera_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_camera.look((event as InputEventMouseMotion).relative)
		return true

	if event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_RIGHT:
				_camera.set_looking(not _camera.is_looking())
			MOUSE_BUTTON_WHEEL_UP:
				_camera.nudge_speed(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera.nudge_speed(-1)
			_:
				return false
		return true

	if event is InputEventKey and event.pressed and not event.echo 		and (event as InputEventKey).keycode == KEY_F:
		_camera.go_home()
		return true

	return false
