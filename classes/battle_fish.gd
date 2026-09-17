class_name BattleFish
extends RigidBody3D

## One fish in the arena: a FishInstance given a body, a sprite and a way to
## hurt the fish next to it.
##
## Everything it is comes off the FishInstance it is bound to - the icon it is
## drawn with, how big it is (size), how heavy it flops (weight), how hard it
## hits (phys_dmg) and how much it can take (health). The instance stays the
## source of truth: damage goes through FishInstance.take_damage(), so the fish
## that fought is the same object the player carries home.
##
## Combat is contact based. Touching another BattleFish deals this fish's
## phys_dmg to it, and because both bodies see the touch, both take a hit. The
## per-target cooldown is what stops two fish resting against each other from
## draining one another every frame, and every hit shoves the fish that took it
## away from whatever landed it, by however much it hurt.
##
## Spells ride on the FishInstance and are cast from here. A spell that
## triggers ON_HIT goes off on the next thing this fish runs into, fish or wall
## or floor, rolls its damage through SpellInstance.try_cast_at() - on the stats
## this body reckons it has, passives and all, see caster_power() - and feeds it into
## the same take_damage() a touch uses - the only difference is that a blast
## comes from a point in the world rather than from another fish, and so shoves
## outwards from it, the caster included. A spell can also wait for the top of a
## hop instead - see _tick_peak() - and stop the fish there while it fires, or
## never fire at all and simply change how the fish behaves: a PASSIVE, read off
## the fish once in bind_fish() rather than cast. A spell can also leave damage
## behind it rather than dealing any - see apply_dot(), which is state on the
## fish that was hit and not on the fish that hit it - or wait on a condition
## rather than a moment, like a fish being underneath this one: _tick_overhead().
##
## The collider is a capsule lying down the length of the fish, sized off the
## icon's own aspect, so the hitbox is the shape of the thing on screen.
##
## The sprite does not billboard. Only yaw is locked, so the fish always faces
## +Z - point the camera down -Z (the direction a camera faces by default) and
## it reads right - while pitch and roll are the capsule's own, and it tumbles
## the way it is thrown. A capsule down the length of a fish log-rolls about
## that length readily, so the sprite does go thin edge-on a fair part of the
## time; that is the cost of the hitbox doing the rotating rather than a script,
## and _face_the_tumble() is what keeps it from ever settling that way.

const SCENE_PATH := "res://objects/BattleFish.tscn"
const DEFAULT_ICON: Texture2D = preload("res://icon.svg")

## Every battler in the tree joins this. A blast walks the group rather than
## asking the physics server what is inside a sphere: contact callbacks run
## mid-step, where a shape query is not welcome, and an arena holds a handful
## of fish rather than a crowd.
const GROUP := &"battlers"

# -- Look ---------------------------------------------------------------------

## World length of a fish of size 1.0, and the clamp either side of it. Same
## sqrt curve as the held viewmodel, but measured nose to tail rather than top
## to bottom: fish icons are long and shallow, so length is what decides how
## much room one takes up. The curve keeps a 9.8m shark bigger than a 0.2m
## sardine without being fifty times the size of it.
const BASE_LEN := 0.90
const MIN_LEN  := 0.35
const MAX_LEN  := 2.20
## Smallest collider a fish can have, in case an icon turns up with no height
## worth speaking of.
const MIN_RADIUS := 0.03

## Tint a fish on its last legs is washed out towards, and how much of it is
## mixed in. Paler than the stun, and it beats the stun when a fish is somehow
## both: being about to die is the more urgent news.
const LAST_STAND_COLOR := Color(0.85, 0.95, 1.00, 1.0)
const LAST_STAND_TINT_MIX := 0.70

## Tint a stunned fish is washed out towards, and how much of it is mixed in.
## It has to read at a glance: a fish standing still because it is stunned and a
## fish standing still because nothing is happening look the same otherwise.
const STUN_COLOR := Color(1.0, 0.95, 0.55, 1.0)
const STUN_TINT_MIX := 0.65

## Tint flashed on the sprite when the fish is hit, and how long it fades over.
const HIT_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const HIT_FLASH := 0.18

## How far the sprite rocks either side of upright while flopping, and how fast.
const WIGGLE_ANGLE := 0.45
const WIGGLE_SPEED := 14.0
## Seconds for a flop's wiggle to settle back to upright.
const WIGGLE_DECAY := 2.6

# -- Flopping -----------------------------------------------------------------

## Seconds between two flops, rolled fresh each time.
const FLOP_INTERVAL := Vector2(0.30, 0.85)
## Impulse per unit of mass, so a heavy fish hops as high as a light one - the
## weight shows in how hard it lands and shoves, not in it being glued down.
## Low and long rather than high: a fish out of water throws itself along the
## floor, and a hop that hangs in the air is a hop it cannot flop out of.
const FLOP_UP   := 2.4
const FLOP_SIDE := 3.2
## Angular kick, always about the axis the hop would roll around, so a fish
## tumbles the way it is thrown rather than spinning against it.
const FLOP_SPIN := 7.0

## Range over which chase_bias fades. Within CHASE_NEAR a fish has its opponent
## right there and commits to it; out past CHASE_FAR it keeps only
## CHASE_FAR_SCALE of its bias and throws itself around much more at random. A
## fish across the arena has no idea where it is going - it is a fish on dry
## land - and watching two of them blunder towards each other is the point.
const CHASE_NEAR := 1.5
const CHASE_FAR := 5.0
const CHASE_FAR_SCALE := 0.4

## Mass is the catch's weight in kilos, clamped so a sardine still has enough of
## it to shove with and a shark does not sit there like scenery.
const MASS_MIN := 0.25
const MASS_MAX := 6.00

## Ceilings on how fast a fish can move and turn, applied every physics frame.
##
## Nothing the fish does to itself gets near these - a flop is about 3 units/s
## and a hard knockback adds 2.5 - they are there for what the solver does to
## it. A capsule pinched between the floor and a wall while it spins comes out
## with energy that came from nowhere, and an unclamped fish rides that over the
## arena wall and out of the world. The spin cap earns its place twice over: a
## fish left to itself reached 200 rad/s, which is not a tumble, it is a blur.
const MAX_SPEED := 7.0
const MAX_SPIN := 12.0

# -- Combat -------------------------------------------------------------------

## Seconds before the same opponent can be hit again. Bouncing fish re-touch
## constantly; without this a fight would be over in a frame.
const HIT_COOLDOWN := 0.45

## Shove a hit is worth, in impulse per point of damage. Deliberately not
## scaled by mass: the same hit shoves a sardine well back and barely rocks a
## shark, which is what makes weight worth having.
##
## Kept well under FLOP_SIDE on purpose. A hit should knock a fish about, not
## out-throw its own flopping - at 0.35 a single 4-damage hit put 5.6 units/s
## into a goldfish, which cleared the arena wall.
const KNOCKBACK_PER_DAMAGE := 0.12
## Share of the shove aimed upwards, so a fish skips back rather than grinding
## along the floor.
const KNOCKBACK_LIFT := 0.25
## Ceiling on the speed one hit can add, in units per second, so that a shark
## hitting a sardine for 25 shoves it hard without firing it out of the arena.
## Scaled along with the shove itself, so a spell that throws harder than a
## touch is not handed back the difference by the cap.
const KNOCKBACK_MAX_SPEED := 2.5

## How fast the fish had to be rising the frame before for the top of a hop to
## count as a peak. Barely over zero on purpose, and it has to stay there: one
## physics frame of gravity is only 0.16 units/s at 60 Hz, so by definition a
## fish about to turn over the top is crawling. Anything larger than that never
## fires at all. What keeps the floor out of it is the _grounded check, not this.
const PEAK_RISE := 0.02

## Stands in for "this damage came from nowhere in particular". Damage carrying
## it leaves the fish where it stands instead of picking a direction on its own.
const NO_ORIGIN := Vector3.INF

## Fired after this fish lands a touch. `amount` is what the target actually
## lost, so an overkill hit reports the health it really took off.
signal dealt_damage(target: BattleFish, amount: int)
## Fired when this fish loses health. `from` is the fish that did it, or null
## for damage that came from somewhere else.
signal took_damage(amount: int, from: BattleFish)
## Fired when the blow that would have killed this fish is held off instead,
## with how long it has left on its feet.
signal last_stand_started(seconds: float)
## Fired when this fish is stunned, with how long it is out of action for.
signal stunned(seconds: float)
## Fired when this fish spends a spell, before the spell's damage lands.
## `target` is the fish whose touch set an ON_HIT spell off, null otherwise.
signal cast_spell(spell: SpellData, target: BattleFish)
## Fired the moment the bound fish runs out of health. The body is left in the
## arena, belly up - whoever spawned it decides when it leaves.
##
## It comes out of FishInstance.take_damage(), so on a killing blow it lands
## before the attacker's own dealt_damage: the death is known before the hit
## that caused it is reported.
signal died(battler: BattleFish)

## The catch this body is. Set through bind_fish(), never written directly.
var fish: FishInstance = null

## Fish sharing a team (0 or above) cannot hurt each other. -1, the default, is
## a free-for-all: everything hits everything.
@export var team: int = -1

## Colour the sprite is drawn in, white for the icon as it was painted. The hit
## flash fades back to this rather than to white, so a team colour survives
## being hit.
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		if _sprite != null and not _dead:
			_sprite.modulate = tint

## Something to flop towards - the opponent, usually. Leave it null and the
## fish flops off in whatever direction it feels like.
@export var chase_target: Node3D = null
## How much of a flop aims at chase_target, once the two are close. 0 is pure
## wandering, 1 a beeline. Full strength only within CHASE_NEAR - see
## _chase_strength().
@export_range(0.0, 1.0, 0.05) var chase_bias: float = 0.75

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _shape: CollisionShape3D = $CollisionShape3D

var _dead := false
var _flop_timer := 0.0
var _grounded := false
## Cooldown left per opponent, keyed by instance id.
var _hit_cooldowns := {}

## Seconds of stun left. A stunned fish does nothing whatsoever - no flopping,
## no casting, and no damage to whatever walks into it - but it can still be
## hurt, and anything already ticking on it keeps ticking.
var _stun_left := 0.0

## The damage-over-time effect this fish is under, if any. One slot rather than
## one per attacker: a second application - from anyone - multiplies what is
## already ticking instead of running alongside it, which is what "applying it
## again doubles the damage" means. The ticks left are never topped up.
var _dot: DotSpellData = null
var _dot_damage := 0
var _dot_ticks := 0
var _dot_timer := 0.0
var _dot_source: BattleFish = null

## The fish's CowardSpellData, if it carries one: read once when the fish is
## bound rather than looked up every hop. Null for a fish that will fight.
var _coward: CowardSpellData = null
## Its BoxerSpellData, likewise: the one that moves its magic into its fists.
var _boxer: BoxerSpellData = null
## And its ArmourSpellData: the one that takes the edge off a punch.
var _armour: ArmourSpellData = null
## And its LastStandSpellData: the one that refuses the killing blow, once.
var _last_stand: LastStandSpellData = null

## Seconds left of that stay of execution, and whether it has been spent. The
## fish cannot be taken below one point of health while the first is running,
## and cannot have it again once the second is true.
var _last_stand_left := 0.0
var _last_stand_used := false

## The clone this fish is hiding behind, how long it has left, and what every
## fish it lured off was looking at before - so they can be given it back.
var _clone: BattleFish = null
var _clone_left := 0.0
var _lured: Array = []

## The volley a spell left running: what there is still to fire, at what, and
## how long the fish hangs there before gravity gets it back.
var _volley: BubbleSpellData = null
var _volley_target: BattleFish = null
var _volley_damage := 0
var _volley_shots := 0
var _volley_timer := 0.0
var _hang_left := 0.0

## Whether the fish had something under it last frame, so that the moment it
## gets something under it again can be told from simply resting on the floor.
var _was_grounded := false

## The fish's velocity from before the physics step it is now being told about.
## By the time body_entered fires, the solver has already bounced the fish off
## whatever it hit, so this is the only record of which way it was going.
var _approach_velocity := Vector3.ZERO

var _wiggle_phase := 0.0
var _wiggle_amount := 0.0
var _flash_left := 0.0

# -- Spawning -----------------------------------------------------------------

## Builds a battler for `fish_instance`. The caller still has to add it to the
## tree and place it.
static func spawn(fish_instance: FishInstance) -> BattleFish:
	var scene := ResourceLoader.load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("BattleFish: missing scene at %s" % SCENE_PATH)
		return null
	var battler := scene.instantiate() as BattleFish
	battler.bind_fish(fish_instance)
	return battler

func _ready() -> void:
	add_to_group(GROUP)
	_flop_timer = _roll_flop_delay()
	body_entered.connect(_on_body_entered)
	_apply_fish()

## Puts `fish_instance` in this body. The fish enters the arena at full health
## and with every spell off cooldown, the way gamephase sends a champion in;
## set current_health afterwards if a fight is being resumed rather than
## started.
func bind_fish(fish_instance: FishInstance) -> void:
	if fish != null and fish.died.is_connected(_on_fish_died):
		fish.died.disconnect(_on_fish_died)
	fish = fish_instance
	_dead = false
	if fish != null:
		fish.reset_health()
		fish.reset_spells()
		fish.died.connect(_on_fish_died)
	_clear_dot()
	_stun_left = 0.0
	# A fish sent into the arena again gets its refusal back with its health.
	_last_stand_left = 0.0
	_last_stand_used = false
	_end_clone()
	_read_passives()
	# bind_fish() is usually called before the body is in the tree, so the
	# @onready nodes are not there yet - _ready() picks the work back up.
	if is_node_ready():
		_apply_fish()

## Picks up the spells that are never cast, only carried. Done once per fish
## rather than per hop: a passive cannot come or go in the middle of a fight.
func _read_passives() -> void:
	_coward = null
	_boxer = null
	_armour = null
	_last_stand = null
	if fish == null:
		return
	for spell in fish.spells:
		if spell == null:
			continue
		var coward := spell.data as CowardSpellData
		if coward != null:
			_coward = coward
		var boxer := spell.data as BoxerSpellData
		if boxer != null:
			_boxer = boxer
		var armour := spell.data as ArmourSpellData
		if armour != null:
			_armour = armour
		var last_stand := spell.data as LastStandSpellData
		if last_stand != null:
			_last_stand = last_stand

## Reads the size, weight and icon off the fish and builds the body out of them.
func _apply_fish() -> void:
	if fish == null or fish.data == null:
		return
	var length := world_length()
	_sprite.texture = fish.data.icon if fish.data.icon else DEFAULT_ICON
	# Scaled off the texture's width, so an icon's own aspect decides how deep
	# the fish is and a 32px and a 512px icon come out the same length.
	_sprite.pixel_size = length / maxf(float(_sprite.texture.get_width()), 1.0)
	_sprite.modulate = tint
	_sprite.rotation = Vector3.ZERO

	# A shape of its own per fish: the one in the scene is shared between every
	# instance, so resizing that would resize every other battler with it.
	#
	# A capsule down the length of the fish, as wide as the icon is tall: the
	# hitbox is the fish rather than a ball drawn around it, so a sardine stops
	# fighting inside a beach ball and every fish rests on the floor at the
	# height it is actually drawn at.
	var capsule := CapsuleShape3D.new()
	capsule.radius = maxf(_sprite_height(length) * 0.5, MIN_RADIUS)
	# CapsuleShape3D.height counts the caps, so it is the whole nose-to-tail
	# span. The max is for an icon taller than it is wide, where the fish is the
	# round part and there is no middle section left.
	capsule.height = maxf(length, capsule.radius * 2.0)
	_shape.shape = capsule
	# Capsules stand up the Y axis; this one has to lie down the fish instead.
	_shape.rotation = Vector3(0.0, 0.0, PI * 0.5)

	mass = clampf(fish.weight, MASS_MIN, MASS_MAX)

## How tall the fish is drawn, for a given nose-to-tail length. Taken from the
## icon's own aspect, so the collider is the shape of the art rather than a
## number picked to suit it.
func _sprite_height(length: float) -> float:
	var texture := _sprite.texture
	if texture == null or texture.get_width() <= 0:
		return length
	return length * float(texture.get_height()) / float(texture.get_width())

## The way the fish is drawn facing, as a direction along the floor. Sprites in
## this game face the camera and are flipped rather than turned, so which way a
## fish is pointing is a bool and this is the only "in front of it" there is.
func facing() -> Vector3:
	return Vector3.LEFT if _sprite != null and _sprite.flip_h else Vector3.RIGHT

## How long this fish is in world units, nose to tail. Same curve as the held
## viewmodel, scaled up: the arena is looked at rather than glanced down at, so
## the fish in it are bigger than the one in the hand.
func world_length() -> float:
	if fish == null or fish.size <= 0.0:
		return BASE_LEN
	return clampf(BASE_LEN * sqrt(fish.size), MIN_LEN, MAX_LEN)

# -- Stats --------------------------------------------------------------------

## Damage this fish deals on contact, once its passives have had their say: a
## boxer folds its magic damage in here, a coward keeps a share of the result -
## none, by default, because it will not fight.
##
## The FishInstance's own phys_dmg is left alone either way, so the selection
## screen still reports the catch honestly. This is the number the arena uses.
func phys_dmg() -> int:
	if fish == null:
		return 0
	var power := fish.phys_dmg
	if _boxer != null:
		power += int(round(fish.magic_dmg * _boxer.conversion))
	if _coward != null:
		power = int(round(power * _coward.phys_scale))
	# Last of all, and on whatever the rest of them left: a fish on its way out
	# swings with a tenth of what it had, not a tenth of what it started with.
	if is_in_last_stand():
		power = int(round(power * _last_stand.power_scale))
	return maxi(0, power)

## Damage this fish's spells scale off, once its passives have had their say: a
## boxer has spent it on its fists and has none of it left.
func magic_dmg() -> int:
	if fish == null:
		return 0
	var power := fish.magic_dmg
	if _boxer != null:
		power = int(round(power * _boxer.magic_scale))
	if is_in_last_stand():
		power = int(round(power * _last_stand.power_scale))
	return maxi(0, power)

## What this fish takes off every physical hit before it lands. 0 for anything
## not carrying armour, and worked out from magic_dmg() rather than the fish's
## own stat - so a boxer, having already spent its magic on its fists, keeps
## only the flat part of it.
func physical_reduction() -> int:
	if _armour == null:
		return 0
	return _armour.reduction(magic_dmg())

## The stat a spell of this type scales off, as this body reckons it. Every cast
## goes through here rather than reading the FishInstance, so a passive that
## rearranges what a fish's stats mean reaches its spells as well as its touches
## - a boxer's blast is worth nothing because a boxer has no magic left.
func caster_power(data: SpellData) -> int:
	return magic_dmg() if data.is_magical() else phys_dmg()

func is_alive() -> bool:
	return fish != null and fish.is_alive() and not _dead

## 0.0 dead, 1.0 untouched. For a health bar over the fish.
func health_ratio() -> float:
	return fish.health_ratio() if fish != null else 0.0

## Takes `amount` off the bound fish and returns what it actually lost. This is
## the way every touch gets applied; the shove is away from the fish that landed
## it, and the damage is physical, which is the kind armour is any use against.
func take_damage(amount: int, from: BattleFish = null) -> int:
	var origin := from.global_position if from != null and is_instance_valid(from) else NO_ORIGIN
	return _apply_damage(amount, from, origin, 1.0, true)

## Drives this fish into the floor and takes health off it. The shove is
## straight down rather than away from anything, and the damage itself carries
## NO_ORIGIN so that nothing pushes it sideways as well - the whole point is
## that it goes down.
##
## A fish already on the floor simply takes the damage: the impulse has nowhere
## to put it.
func slam_down(amount: int, slam_scale: float, from: BattleFish = null,
		physical := false) -> int:
	if not is_alive():
		return 0
	var dealt := _apply_damage(amount, from, NO_ORIGIN, 0.0, physical)
	_shove(Vector3.DOWN, amount, slam_scale, 0.0)
	return dealt

## Damage that comes from nowhere the fish can be pushed away from - a tick of
## something it is already under. `from` is still credited with it, so a health
## bar and a battle log can name whoever started it, but the fish is not shoved:
## there is no direction for a tick of damage to have come from.
func take_tick_damage(amount: int, from: BattleFish = null, physical := false) -> int:
	return _apply_damage(amount, from, NO_ORIGIN, 0.0, physical)

## Damage from a point in the world rather than from a fish - a spell's blast.
## The shove is outwards from `origin`, so everything caught is thrown away from
## the explosion instead of away from whoever set it off, and `knockback_scale`
## is how much harder than a touch of the same size it throws.
func take_blast(amount: int, origin: Vector3, knockback_scale: float = 1.0,
		from: BattleFish = null, physical := false) -> int:
	return _apply_damage(amount, from, origin, knockback_scale, physical)

## The one place health actually comes off. `origin` is what the fish is shoved
## away from, NO_ORIGIN for damage that should not move it at all, and
## `physical` says whether armour gets a say in it.
func _apply_damage(amount: int, from: BattleFish, origin: Vector3,
		knockback_scale: float, physical := false) -> int:
	if not is_alive():
		return 0
	# Armour comes off what the hit is worth, never off what it shoves with: a
	# sandbagged fish is harder to hurt, not harder to move, and one that shrugs
	# a touch off entirely still gets knocked about by it.
	var landed := amount
	if physical:
		landed = maxi(0, landed - physical_reduction())
	# Immunity: the blow that would have finished it starts a stay of execution
	# instead, and nothing gets through that last point while it runs.
	landed = _refuse_killing_blow(landed)
	var dealt := fish.take_damage(landed)
	# Knocked back by the size of the hit, not by the health it managed to take
	# off: a killing blow shoves just as hard when the fish had one point left
	# as when it had all of them, and a fully absorbed one shoves all the same.
	_knock_back(amount, origin, knockback_scale)
	if dealt > 0:
		_flash_left = HIT_FLASH
		took_damage.emit(dealt, from)
	return dealt

## Shoves this fish away from `origin`, harder the more the hit was worth.
## Damage that came from nowhere in particular - NO_ORIGIN, a spell with no
## caster given - leaves it where it stands rather than picking a direction on
## its own.
##
## A killing blow still lands one: the fish is already dead by the time this
## runs, and being knocked over by the hit that did it is exactly right.
func _knock_back(amount: int, origin: Vector3, scale: float) -> void:
	if origin == NO_ORIGIN:
		return
	var away := global_position - origin
	away.y = 0.0
	# Dead centre on top of each other: any direction will do.
	away = away.normalized() if away.length_squared() > 0.0001 else _random_horizontal()
	_shove(away, amount, scale)

## The impulse itself, along a direction already settled on. `amount` is the
## damage the shove is worth, `scale` how much harder than a touch it throws,
## and `lift` how much of it is aimed upwards - the default skips a fish back
## off the floor, and 0 is for a shove that is meant to go where it is pointed,
## like a slam into the ground.
func _shove(direction: Vector3, amount: int, scale: float,
		lift := KNOCKBACK_LIFT) -> void:
	if scale <= 0.0 or direction.is_zero_approx():
		return
	var lifted := (direction + Vector3.UP * lift).normalized()
	var impulse := lifted * float(amount) * KNOCKBACK_PER_DAMAGE * scale
	# The cap scales too: a blast that throws twice as hard as a touch would
	# otherwise hand the difference straight back at the ceiling.
	apply_central_impulse(impulse.limit_length(mass * KNOCKBACK_MAX_SPEED * scale))

## Whether this fish is allowed to hurt `other`: not itself, not a team mate,
## and both of them still fighting.
func can_hit(other: BattleFish) -> bool:
	if other == null or other == self:
		return false
	if not is_alive() or not other.is_alive():
		return false
	if team >= 0 and other.team == team:
		return false
	return true

# -- Frame --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_hit_cooldowns(delta)
	_tick_last_stand(delta)
	_tick_clone(delta)
	_tick_stun(delta)
	_tick_dot(delta)
	if fish != null and is_alive():
		fish.tick_spells(delta)
	_tick_volley(delta)
	_tick_flop(delta)
	_tick_peak()
	_tick_landing()
	_tick_overhead()
	_tick_ready_spells()
	_tick_look(delta)
	# Last thing in the frame, so it is the velocity going into the step the
	# next contact will come out of, and so _tick_peak() above still had the
	# frame before to compare against. See _approach_velocity.
	_approach_velocity = linear_velocity

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Cheapest honest answer to "is it standing on something". Flopping off
	# nothing would look like flying.
	_grounded = state.get_contact_count() > 0
	# Done here rather than in _physics_process so the cap lands on the same
	# step the solver blew the speed up on, not the frame after.
	state.linear_velocity = state.linear_velocity.limit_length(MAX_SPEED)
	state.angular_velocity = state.angular_velocity.limit_length(MAX_SPIN)

func _tick_hit_cooldowns(delta: float) -> void:
	for id in _hit_cooldowns.keys():
		var left: float = _hit_cooldowns[id] - delta
		if left <= 0.0:
			_hit_cooldowns.erase(id)
		else:
			_hit_cooldowns[id] = left

## Counts down to the next flop. The timer runs in mid-air but only fires on
## something solid, so a fish that is still bouncing flops the moment it lands
## instead of throwing itself around from nothing.
func _tick_flop(delta: float) -> void:
	if not is_alive() or _hang_left > 0.0 or is_stunned():
		return
	_flop_timer -= delta
	if _flop_timer > 0.0 or not _grounded:
		return
	_flop_timer = _roll_flop_delay()
	_flop()

func _flop() -> void:
	var dir := _flop_direction()
	apply_central_impulse((Vector3.UP * FLOP_UP + dir * FLOP_SIDE) * mass)
	# UP cross dir is the axis a body rolling that way turns about, so the fish
	# tumbles along its hop instead of spinning against it: thrown left it goes
	# over its own nose to the left, thrown away from the camera it rolls about
	# its own length. Only the strength is random - tumbling backwards out of
	# its own throw looks wrong.
	var roll_axis := Vector3.UP.cross(dir)
	apply_torque_impulse(roll_axis * randomizer.RNG.randf_range(FLOP_SPIN * 0.4, FLOP_SPIN) * mass)
	_wiggle_amount = 1.0

## A random direction along the floor, pulled towards chase_target by however
## much of chase_bias the distance leaves in play - or away from the nearest
## fish instead, by flee_bias, when this one is a coward.
func _flop_direction() -> Vector3:
	var wander := _random_horizontal()
	var bias := chase_bias
	var focus: Node3D = chase_target
	if _coward != null:
		# A coward runs from whoever is actually closest rather than from
		# whoever the arena pointed it at - the thing about to catch it is the
		# thing worth running from.
		bias = _coward.flee_bias
		var nearest := _nearest_enemy()
		if nearest != null:
			focus = nearest
	if focus == null or not is_instance_valid(focus) or bias <= 0.0:
		return wander
	var towards := focus.global_position - global_position
	towards.y = 0.0
	var distance := towards.length()
	if distance < 0.0001:
		return wander
	# The same heading either way round: a coward is a chaser with a minus sign.
	var heading := towards / distance
	if _coward != null:
		heading = -heading
	return wander.lerp(heading, bias * _chase_strength(distance)).normalized()

## How much of chase_bias - or of a coward's flee_bias - survives at `distance`:
## all of it up close, falling off to CHASE_FAR_SCALE of it once the other fish
## is right across the floor. A fish only commits, to either running at
## something or away from it, once that something is near.
func _chase_strength(distance: float) -> float:
	var closeness := clampf(inverse_lerp(CHASE_FAR, CHASE_NEAR, distance), 0.0, 1.0)
	return lerpf(CHASE_FAR_SCALE, 1.0, closeness)

## A unit direction along the floor, any way at all.
func _random_horizontal() -> Vector3:
	var angle := randomizer.RNG.randf_range(-PI, PI)
	return Vector3(cos(angle), 0.0, sin(angle))

func _roll_flop_delay() -> float:
	return randomizer.RNG.randf_range(FLOP_INTERVAL.x, FLOP_INTERVAL.y)

## The purely cosmetic half: the tumble taken off the ball, the rock of a flop,
## the red flash of a hit, and facing the way the fish is travelling.
func _tick_look(delta: float) -> void:
	if _dead:
		# Still follows the ball while the body settles, just belly up.
		_face_the_tumble()
		return

	if _wiggle_amount > 0.0:
		_wiggle_phase += delta * WIGGLE_SPEED
		_wiggle_amount = maxf(0.0, _wiggle_amount - delta / WIGGLE_DECAY)
	_face_the_tumble()

	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		_sprite.modulate = tint.lerp(HIT_COLOR, _flash_left / HIT_FLASH)
	elif is_in_last_stand():
		# Gone pale, and ahead of the stun: a fish about to die reads as that
		# first and as dazzled second.
		_sprite.modulate = tint.lerp(LAST_STAND_COLOR, LAST_STAND_TINT_MIX)
	elif is_stunned():
		# Washed out, the way anything looks after a camera has gone off in it.
		_sprite.modulate = tint.lerp(STUN_COLOR, STUN_TINT_MIX)
	else:
		_sprite.modulate = tint

	# Flipped rather than turned: turning a flat sprite edge-on makes it vanish.
	if absf(linear_velocity.x) > 0.15:
		_sprite.flip_h = linear_velocity.x < 0.0

## Points the sprite the way the body underneath it is lying - pitch and roll
## straight off the collider - but never its yaw.
##
## Yaw is locked and a fish can still pick some up: rotations about two axes
## compose into a turn about the third, so anything that unlocks pitch brings it
## back. Left alone a fish can settle at a right angle to the camera, and a flat
## sprite side-on is not a thin fish, it is no fish at all. Dropping the yaw out
## of the body's own orientation keeps the tipping and loses that.
##
## The wiggle of a flop, and being belly up once dead, ride on top as roll.
func _face_the_tumble() -> void:
	# Default Euler order is YXZ for both of these, so y really is the yaw.
	var tumble := global_basis.get_euler()
	var roll := tumble.z + _sprite_roll()
	_sprite.global_basis = Basis.from_euler(Vector3(tumble.x, 0.0, roll))

## Roll of the sprite within its own plane, on top of however the ball is lying.
func _sprite_roll() -> float:
	if _dead:
		return PI
	return sin(_wiggle_phase) * WIGGLE_ANGLE * _wiggle_amount

# -- Contact ------------------------------------------------------------------

func _on_body_entered(body: Node) -> void:
	# `other` is null for scenery - a wall, or the floor at the end of a flop.
	# There is nothing to trade damage with then, but a spell that goes off on
	# contact does not care what it was that got touched.
	var other := body as BattleFish
	var landed := _hit(other) if other != null else false
	_cast_on_hit(other, landed)

## Lands a touch on `other`. Both bodies run this on their own side of the
## collision, so a head-on flop trades damage both ways. A touch that is not
## allowed to hurt anything - a team mate, a fish already dead - still counts as
## a contact for a spell: that is decided in _on_body_entered(), not here.
## Returns whether the touch landed - past the team check and past the
## per-target cooldown - which is what a spell that has to have hit something
## waits for.
##
## Landing it is not the same as hurting with it: a coward connects and deals
## nothing, and a spell it carries that goes off on a hit should still go off.
## Only the damage is nullified, not the fish's ability to touch anything.
func _hit(other: BattleFish) -> bool:
	# A stunned fish is not hitting anything, though anything may hit it: the
	# other side of this collision runs its own _hit() and is unaffected.
	if is_stunned() or not can_hit(other):
		return false
	var id := other.get_instance_id()
	if _hit_cooldowns.has(id):
		return false
	_hit_cooldowns[id] = HIT_COOLDOWN
	var dealt := other.take_damage(phys_dmg(), self)
	if dealt > 0:
		dealt_damage.emit(other, dealt)
	return true

# -- Spells -------------------------------------------------------------------

## Spends every armed ON_HIT spell on the contact just made. `other` is the fish
## that was touched, or null for a wall or the floor, and `landed` says whether
## the touch got past the team check and the per-target cooldown and actually
## took health off.
##
## Anything the fish runs into sets an ON_HIT spell off, which is what keeps a
## fish with a blast going up on walls - unless the spell sets needs_hit, in
## which case scenery and touches that did not land are no good to it. Each
## spell is gated by its own cooldown and nothing else, so a fish carrying two
## of them gets both on the same touch.
func _cast_on_hit(other: BattleFish, landed: bool) -> void:
	if fish == null or not is_alive() or is_stunned():
		return
	for spell in fish.ready_spells(SpellData.Trigger.ON_HIT):
		if spell.data.needs_hit and not landed:
			continue
		var damage := spell.try_cast_at(caster_power(spell.data))
		if damage == SpellInstance.NOT_READY:
			continue
		cast_spell.emit(spell.data, other)
		_apply_on_hit(spell.data, other, damage)

## What an ON_HIT spell does once it has been paid for. A new one branches here
## on its own data type rather than dressing itself up as one of these.
func _apply_on_hit(data: SpellData, other: BattleFish, damage: int) -> void:
	var blast := data as ExplosionSpellData
	if blast != null:
		_explode(blast, _contact_point(other), damage)
		return
	var dot := data as DotSpellData
	# needs_hit is what guarantees there is an `other` here at all.
	if dot != null and other != null and is_instance_valid(other):
		other.apply_dot(dot, damage, self)

# -- Clone --------------------------------------------------------------------

## Puts a copy of this fish on the floor beside it and points everything that
## was fighting it at the copy instead.
##
## The copy is a real battler, so it flops and collides and can be hit, and it
## is deliberately **not** added to whatever the arena handed `BattleRound` -
## nothing that cannot win a round should be able to hold one open.
func _spawn_clone(spell: CloneSpellData) -> void:
	if fish == null or fish.data == null or _clone != null:
		return
	var copy := fish.duplicate() as FishInstance
	if copy == null:
		return
	# Everything that makes a fish dangerous, taken out: it is scenery that
	# happens to look exactly like the fish it came off.
	copy.phys_dmg = 0
	copy.magic_dmg = 0
	copy.spells = [] as Array[SpellInstance]
	copy.health = maxi(1, int(round(fish.health * spell.health_scale)))
	var decoy := BattleFish.spawn(copy)
	if decoy == null:
		return
	# Its own team, so it never fights back and this fish never turns on it.
	decoy.team = team
	decoy.tint = tint
	# It wanders: a decoy that made straight for the enemy would give itself up.
	decoy.chase_bias = 0.0
	_effect_parent().add_child(decoy)
	decoy.global_position = global_position + _random_horizontal() * spell.spawn_offset
	_clone = decoy
	_clone_left = maxf(spell.duration, 0.01)
	# The clone keeps its own clock as well as this one, because this one dies
	# with the fish: an arena that frees a battler mid-round - the way a
	# rematch does - would otherwise leave the decoy standing there for good,
	# with nothing left alive that knows to take it away. The timer belongs to
	# the tree and Godot drops the connection if the clone goes first.
	get_tree().create_timer(_clone_left).timeout.connect(decoy.queue_free)
	_lure_enemies()

## Points everything that could be fighting this fish at the clone, keeping what
## each of them was looking at so it can be handed back.
func _lure_enemies() -> void:
	_lured.clear()
	if _clone == null:
		return
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as BattleFish
		# can_hit(self) asks it the one question that matters: is this fish
		# something you would fight?
		if other == null or other == _clone or not other.can_hit(self):
			continue
		_lured.append([other, other.chase_target])
		other.chase_target = _clone

## Counts the clone down, and takes it away early if it is killed or if the fish
## it came off dies first.
func _tick_clone(delta: float) -> void:
	if _clone_left <= 0.0:
		return
	if not is_instance_valid(_clone) or not _clone.is_alive() or not is_alive():
		_end_clone()
		return
	_clone_left = maxf(0.0, _clone_left - delta)
	if _clone_left <= 0.0:
		_end_clone()

## Takes the clone away and gives everything it lured off its own target back -
## but only if that is still the clone, so an arena that has since repointed a
## fish somewhere else keeps its say.
func _end_clone() -> void:
	var clone := _clone
	_clone = null
	_clone_left = 0.0
	var clone_valid := is_instance_valid(clone)
	for pair in _lured:
		var other := pair[0] as BattleFish
		if not is_instance_valid(other):
			continue
		# Something else has pointed it somewhere since: leave that alone.
		if clone_valid and other.chase_target != clone:
			continue
		# And never hand back a target that has itself been freed in the
		# meantime - that is a round being torn down around us.
		other.chase_target = pair[1] if is_instance_valid(pair[1]) else null
	_lured.clear()
	if clone_valid:
		clone.queue_free()

# -- Last stand ---------------------------------------------------------------

## Caps `amount` at whatever would leave the fish on one point of health, when
## it is carrying Immunity and this blow would otherwise finish it - and starts
## the clock, or keeps it if one is already running. Returns the damage that may
## actually be taken.
##
## Everything runs through _apply_damage(), so there is no way to be killed that
## does not come past here: a touch, a blast, a burn, the arena's own drain.
func _refuse_killing_blow(amount: int) -> int:
	if _last_stand == null or fish == null:
		return amount
	# Not fatal: nothing to refuse.
	if amount < fish.current_health:
		return amount
	if is_in_last_stand():
		return maxi(0, fish.current_health - 1)
	if _last_stand_used:
		return amount
	_last_stand_used = true
	_last_stand_left = maxf(_last_stand.duration, 0.01)
	last_stand_started.emit(_last_stand_left)
	return maxi(0, fish.current_health - 1)

## Counts the stay of execution down, and collects on it when it runs out. The
## fish dies here of the blow it was holding off - through the ordinary damage
## path, so the death is reported the way any other is.
func _tick_last_stand(delta: float) -> void:
	if _last_stand_left <= 0.0:
		return
	_last_stand_left = maxf(0.0, _last_stand_left - delta)
	if _last_stand_left > 0.0:
		return
	if fish != null and fish.is_alive():
		take_tick_damage(fish.current_health)

func is_in_last_stand() -> bool:
	return _last_stand_left > 0.0

## Seconds of it left, for a readout.
func last_stand_left() -> float:
	return _last_stand_left

# -- Stun ---------------------------------------------------------------------

## Puts this fish out of action for `seconds`. The longest stun wins rather than
## them adding up, so a flash from across the room cannot extend one that landed
## point blank.
func stun(seconds: float) -> void:
	if not is_alive() or seconds <= 0.0:
		return
	_stun_left = maxf(_stun_left, seconds)
	# Whatever it was in the middle of, it is not any more.
	_end_hang()
	stunned.emit(_stun_left)

func is_stunned() -> bool:
	return _stun_left > 0.0

## Seconds of it left, for a readout.
func stun_left() -> float:
	return _stun_left

func _tick_stun(delta: float) -> void:
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)

# -- Damage over time ---------------------------------------------------------

## Puts `spell` on this fish, or multiplies what is already on it. The number of
## ticks left is set by the first application and never topped up: landing it
## again makes the effect hurt more, not last longer.
func apply_dot(spell: DotSpellData, damage: int, from: BattleFish) -> void:
	if spell == null or not is_alive():
		return
	if _dot != null and _dot_ticks > 0:
		_dot_damage = int(round(_dot_damage * spell.stack_multiplier))
	else:
		_dot = spell
		_dot_damage = damage
		_dot_ticks = spell.tick_count()
		_dot_timer = maxf(spell.interval, 0.01)
	_dot_source = from

## Counts the effect down and takes health off on the beat. Whoever applied it
## is credited with every tick, so a fish that walked away still shows up in the
## log as the one doing the damage.
func _tick_dot(delta: float) -> void:
	if _dot == null or _dot_ticks <= 0:
		return
	if not is_alive():
		_clear_dot()
		return
	var interval := maxf(_dot.interval, 0.01)
	_dot_timer -= delta
	while _dot_ticks > 0 and _dot_timer <= 0.0:
		_dot_ticks -= 1
		_dot_timer += interval
		var dealt := take_tick_damage(_dot_damage, _dot_source, not _dot.is_magical())
		if dealt > 0 and _dot_source != null and is_instance_valid(_dot_source):
			_dot_source.report_indirect_damage(self, dealt)
		# The tick that kills clears the effect on its way out - see
		# _on_fish_died - and there is nothing left to count down.
		if not is_alive():
			return
	if _dot_ticks <= 0:
		_clear_dot()

func _clear_dot() -> void:
	_dot = null
	_dot_damage = 0
	_dot_ticks = 0
	_dot_timer = 0.0
	_dot_source = null

## Ticks left of whatever this fish is under, and what one of them costs. For a
## readout - the test arena puts them on the fighter card - nothing in the fight
## itself reads them.
func dot_ticks_left() -> int:
	return _dot_ticks

func dot_damage() -> int:
	return _dot_damage

## Told to the fish that started a damage-over-time effect when one of its ticks
## lands, so damage it did not have to be present for is still reported as its
## own. Nothing else should be reaching for another fish's signals.
func report_indirect_damage(target: BattleFish, amount: int) -> void:
	if amount > 0:
		dealt_damage.emit(target, amount)

## Spots the top of a hop: rising the frame before, no longer rising now, and
## nothing underfoot. That is the moment a spell waiting on AT_JUMP_PEAK gets.
func _tick_peak() -> void:
	if _grounded or _hang_left > 0.0 or not is_alive() or is_stunned():
		return
	if _approach_velocity.y <= PEAK_RISE or linear_velocity.y > 0.0:
		return
	_cast_at_peak()

## Fires anything that simply goes off the moment it is ready - no moment to
## catch, no condition to meet, nothing to aim at. The cooldown is all of it.
func _tick_ready_spells() -> void:
	if fish == null or not is_alive() or is_stunned() or _hang_left > 0.0:
		return
	for spell in fish.ready_spells(SpellData.Trigger.WHEN_READY):
		if not _worth_casting(spell.data):
			continue
		if spell.try_cast_at(caster_power(spell.data)) == SpellInstance.NOT_READY:
			continue
		# No target: none of these are aimed at anybody in particular.
		cast_spell.emit(spell.data, null)
		_apply_when_ready(spell.data)

## Whether a WHEN_READY spell has anything to do right now. Almost all of them
## always have - the camera goes off whether or not there is anybody in the shot
## - but a second clone while the first is still standing would be a wasted
## cooldown, so that one waits.
func _worth_casting(data: SpellData) -> bool:
	if data is CloneSpellData:
		return _clone == null
	return data is PaparazziSpellData

## What a WHEN_READY spell does once it has been paid for.
func _apply_when_ready(data: SpellData) -> void:
	var camera := data as PaparazziSpellData
	if camera != null:
		_flash(camera)
		return
	var clone := data as CloneSpellData
	if clone != null:
		_spawn_clone(clone)

## Sets a camera off in front of the fish and leaves standing anything it may
## hit that was caught in the cone - the closer it was, the longer for.
func _flash(spell: PaparazziSpellData) -> void:
	var direction := _flash_direction(spell)
	SpellFlash.burst(_effect_parent(),
		global_position + direction * world_length() * 0.5, spell)
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as BattleFish
		if other == null or not can_hit(other):
			continue
		var offset := other.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > spell.max_range:
			continue
		# Point blank: whatever is against the lens is in the shot, whichever
		# way round the two of them are.
		if distance > 0.0001 \
				and rad_to_deg(direction.angle_to(offset / distance)) > spell.spread_degrees:
			continue
		other.stun(spell.stun_for(distance))

## Where the camera gets pointed: at the nearest fish worth photographing when
## one is in range, and straight ahead when there is not.
##
## A fish in this game is always drawn facing the camera and flipped rather than
## turned, so its "forwards" is only ever the way it was last thrown - which is
## hardly ever at its opponent. Fired strictly down that line the spell barely
## existed: 50 flashes over 120 seconds of arena landed **one** stun. Turning to
## face the subject is what a photographer does anyway, and the cone still
## decides who else is in the shot.
func _flash_direction(spell: PaparazziSpellData) -> Vector3:
	var subject := _nearest_enemy()
	if subject == null:
		return facing()
	var aim := subject.global_position - global_position
	aim.y = 0.0
	if aim.length() > spell.max_range or aim.length_squared() < 0.0001:
		return facing()
	return aim.normalized()

## Fires a spell that waits for this fish to be standing over somebody. Unlike
## the peak, which is a moment and gone, this is a condition: it is true for as
## long as the other fish is under this one, so the spell's own cooldown is the
## only thing pacing it.
func _tick_overhead() -> void:
	if fish == null or not is_alive() or _hang_left > 0.0 or is_stunned():
		return
	var ready := fish.ready_spells(SpellData.Trigger.WHEN_OVER_TARGET)
	if ready.is_empty():
		return
	var spell := ready[0]
	var slam := spell.data as SlamSpellData
	if slam == null:
		return
	var target := _target_below(slam)
	if target == null:
		return
	var damage := spell.try_cast_at(caster_power(spell.data))
	if damage == SpellInstance.NOT_READY:
		return
	cast_spell.emit(spell.data, target)
	var dealt := target.slam_down(damage, slam.slam_scale, self, not slam.is_magical())
	if dealt > 0:
		dealt_damage.emit(target, dealt)

## The nearest fish this one may hit that is underneath it: within `reach` to
## either side and at least `min_drop` below. Null when it is standing over
## nobody, which is most of the time.
func _target_below(spell: SlamSpellData) -> BattleFish:
	var best: BattleFish = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as BattleFish
		if other == null or not can_hit(other):
			continue
		var offset := global_position - other.global_position
		if offset.y < spell.min_drop:
			continue
		var flat := Vector2(offset.x, offset.z).length()
		if flat > spell.reach or flat >= best_distance:
			continue
		best_distance = flat
		best = other
	return best

## Spots the fish putting something solid back under itself - the other end of
## the hop from _tick_peak(). `_was_grounded` is updated whatever happens next,
## so a fish that lands stunned does not fire the moment it comes round.
func _tick_landing() -> void:
	var landed := _grounded and not _was_grounded
	_was_grounded = _grounded
	if not landed or fish == null or not is_alive() or is_stunned() or _hang_left > 0.0:
		return
	for spell in fish.ready_spells(SpellData.Trigger.ON_LANDING):
		var burn := spell.data as BurnZoneSpellData
		if burn == null:
			continue
		var damage := spell.try_cast_at(caster_power(spell.data))
		if damage == SpellInstance.NOT_READY:
			continue
		cast_spell.emit(spell.data, null)
		_light_zone(burn, damage)

## Leaves a patch of fire where the fish just came down. Parented alongside it
## rather than under it, like every other effect, so it stays where it was lit
## and outlives the fish that lit it.
func _light_zone(spell: BurnZoneSpellData, damage: int) -> void:
	var zone := SpellFireZone.light(_effect_parent(), global_position, spell, damage, self)
	if zone != null:
		zone.hit_fish.connect(_on_bubble_hit)

## Spends a spell that was waiting for the top of a hop. Nothing to shoot at
## means the charge is kept rather than spent on the scenery - unlike an ON_HIT
## spell, this one is aimed, so firing it at nobody would just waste it.
func _cast_at_peak() -> void:
	if fish == null:
		return
	# The first one only: a volley takes the fish over, so a second spell
	# waiting on the peak has to wait for the next hop.
	var ready := fish.ready_spells(SpellData.Trigger.AT_JUMP_PEAK)
	if ready.is_empty():
		return
	var spell := ready[0]
	var volley := spell.data as BubbleSpellData
	if volley == null:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	var damage := spell.try_cast_at(caster_power(spell.data))
	if damage == SpellInstance.NOT_READY:
		return
	cast_spell.emit(spell.data, target)
	_start_volley(volley, damage, target)

## Stops the fish dead at the top of its hop and starts the bubbles coming. The
## body is frozen rather than slowed: a fish still drifting upwards while it
## fires reads as one that got interrupted, not one taking aim.
func _start_volley(spell: BubbleSpellData, damage: int, target: BattleFish) -> void:
	_volley = spell
	_volley_target = target
	_volley_damage = damage
	_volley_shots = spell.count
	_volley_timer = 0.0
	_hang_left = maxf(spell.hang_time, 0.01)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true

## Runs a volley that is already going: one bubble every `interval`, and the
## fish let go again once `hang_time` is up. A fish that dies in mid-volley
## drops the rest of it and falls.
func _tick_volley(delta: float) -> void:
	if _hang_left <= 0.0:
		return
	if not is_alive() or _volley == null:
		_end_hang()
		return
	_hang_left = maxf(0.0, _hang_left - delta)
	_volley_timer -= delta
	# maxf: an interval of 0 would otherwise never let the loop end.
	var interval := maxf(_volley.interval, 0.01)
	while _volley_shots > 0 and _volley_timer <= 0.0:
		_fire_bubble()
		_volley_shots -= 1
		_volley_timer += interval
	if _hang_left <= 0.0:
		_end_hang()

## Hands the fish back to gravity and drops whatever was left of the volley.
func _end_hang() -> void:
	_hang_left = 0.0
	_volley = null
	_volley_target = null
	_volley_shots = 0
	if freeze:
		freeze = false

## One bubble, aimed at wherever the target is standing at this instant. It is
## fired and forgotten - the bubble does not follow the fish it was aimed at,
## which is the whole reason a volley can be dodged.
func _fire_bubble() -> void:
	var target := _volley_target
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	var direction := target.global_position - global_position
	if direction.is_zero_approx():
		return
	direction = direction.normalized()
	# Out at the nose rather than at the middle of the fish, so the bubbles look
	# spat rather than dropped.
	var bubble := SpellBubble.fire(_effect_parent(),
		global_position + direction * world_length() * 0.5,
		direction, _volley, _volley_damage, self)
	if bubble != null:
		bubble.hit_fish.connect(_on_bubble_hit)

## Something this fish left behind - a bubble in flight, a patch of fire - is
## this fish landing a hit, as far as anything watching is concerned.
func _on_bubble_hit(target: BattleFish, amount: int) -> void:
	dealt_damage.emit(target, amount)

## The closest fish this one is allowed to hit, or null when there is nobody
## left to aim at.
func _nearest_enemy() -> BattleFish:
	var best: BattleFish = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as BattleFish
		if other == null or not can_hit(other):
			continue
		var distance := global_position.distance_squared_to(other.global_position)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best

## Throws the fish that set the blast off back the way it came. It takes none of
## the blast's damage - can_hit() rules itself out - but an explosion under its
## own nose that left it standing there would read as somebody else's.
func _recoil(spell: ExplosionSpellData, origin: Vector3, damage: int) -> void:
	_shove(_recoil_direction(origin), damage,
		spell.knockback_at(0.0) * spell.self_knockback)

## Back the way the fish was travelling when it hit, which is the one direction
## that works for a wall as well as for another fish. Straight out of the blast
## if it was barely moving, and anywhere at all if it is sitting on top of it.
func _recoil_direction(origin: Vector3) -> Vector3:
	var approach := _approach_velocity
	approach.y = 0.0
	if approach.length_squared() > 0.01:
		return -approach.normalized()
	var away := global_position - origin
	away.y = 0.0
	return away.normalized() if away.length_squared() > 0.0001 else _random_horizontal()

## Blows up at `origin`: every fish this one is allowed to hit and that stands
## inside the spell's radius takes the full damage, thrown outwards by however
## close to the middle of it it was. The caster is not hurt by its own blast -
## can_hit() rules out itself and its team - only thrown by it.
func _explode(spell: ExplosionSpellData, origin: Vector3, damage: int) -> void:
	SpellExplosion.burst(_effect_parent(), origin, spell)
	_recoil(spell, origin, damage)
	for node in get_tree().get_nodes_in_group(GROUP):
		var target := node as BattleFish
		if target == null or not can_hit(target):
			continue
		var distance := target.global_position.distance_to(origin)
		if distance > spell.radius:
			continue
		var dealt := target.take_blast(damage, origin, spell.knockback_at(distance),
			self, not spell.is_magical())
		if dealt > 0:
			dealt_damage.emit(target, dealt)

## Near enough to where a contact happened: halfway between the two fish, or the
## fish itself when it ran into scenery. The solver knows the real contact point
## but body_entered is not handed it, and half a fish either way is nothing next
## to a blast three units across.
func _contact_point(other: BattleFish) -> Vector3:
	if other == null or not is_instance_valid(other):
		return global_position
	return (global_position + other.global_position) * 0.5

## Where effects that happen in the world are parented - alongside this fish
## rather than under it, so a blast stays where it went off and outlives the
## fish that set it off.
func _effect_parent() -> Node3D:
	var parent := get_parent() as Node3D
	return parent if parent != null else self

# -- Death --------------------------------------------------------------------

func _on_fish_died() -> void:
	if _dead:
		return
	_dead = true
	_hit_cooldowns.clear()
	_clear_dot()
	_last_stand_left = 0.0
	_end_clone()
	# Frozen in mid-air firing bubbles when it died: let it drop.
	_end_hang()
	# It stops flopping and turns belly up - _sprite_roll() handles the turn -
	# but keeps its physics so it drops and settles instead of freezing in
	# mid-air. The arena frees it when it wants.
	_face_the_tumble()
	_sprite.modulate = tint.darkened(0.45).lerp(Color(0.55, 0.55, 0.60, 1.0), 0.5)
	died.emit(self)
