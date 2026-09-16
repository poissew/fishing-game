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
## Spells are not implemented yet. magic_dmg is read off the fish and exposed
## here so that when they land they can roll their damage and feed it into the
## same take_damage() a touch uses - nothing else needs to change.
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
const KNOCKBACK_MAX_SPEED := 2.5

## Fired after this fish lands a touch. `amount` is what the target actually
## lost, so an overkill hit reports the health it really took off.
signal dealt_damage(target: BattleFish, amount: int)
## Fired when this fish loses health. `from` is the fish that did it, or null
## for damage that came from somewhere else.
signal took_damage(amount: int, from: BattleFish)
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
	_flop_timer = _roll_flop_delay()
	body_entered.connect(_on_body_entered)
	_apply_fish()

## Puts `fish_instance` in this body. The fish enters the arena at full health,
## the way gamephase sends a champion in; set current_health afterwards if a
## fight is being resumed rather than started.
func bind_fish(fish_instance: FishInstance) -> void:
	if fish != null and fish.died.is_connected(_on_fish_died):
		fish.died.disconnect(_on_fish_died)
	fish = fish_instance
	_dead = false
	if fish != null:
		fish.reset_health()
		fish.died.connect(_on_fish_died)
	# bind_fish() is usually called before the body is in the tree, so the
	# @onready nodes are not there yet - _ready() picks the work back up.
	if is_node_ready():
		_apply_fish()

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

## How long this fish is in world units, nose to tail. Same curve as the held
## viewmodel, scaled up: the arena is looked at rather than glanced down at, so
## the fish in it are bigger than the one in the hand.
func world_length() -> float:
	if fish == null or fish.size <= 0.0:
		return BASE_LEN
	return clampf(BASE_LEN * sqrt(fish.size), MIN_LEN, MAX_LEN)

# -- Stats --------------------------------------------------------------------

## Damage this fish deals on contact.
func phys_dmg() -> int:
	return fish.phys_dmg if fish != null else 0

## Damage this fish's spells scale off. Nothing casts yet; SpellInstance takes
## the FishInstance itself and picks this or phys_dmg depending on the type.
func magic_dmg() -> int:
	return fish.magic_dmg if fish != null else 0

func is_alive() -> bool:
	return fish != null and fish.is_alive() and not _dead

## 0.0 dead, 1.0 untouched. For a health bar over the fish.
func health_ratio() -> float:
	return fish.health_ratio() if fish != null else 0.0

## Takes `amount` off the bound fish and returns what it actually lost. Every
## source of damage goes through here - a touch today, a spell once they exist.
func take_damage(amount: int, from: BattleFish = null) -> int:
	if not is_alive():
		return 0
	var dealt := fish.take_damage(amount)
	if dealt > 0:
		_flash_left = HIT_FLASH
		# Knocked back by the size of the hit, not by the health it managed to
		# take off: a killing blow shoves just as hard when the fish had one
		# point left as when it had all of them.
		_knock_back(amount, from)
		took_damage.emit(dealt, from)
	return dealt

## Shoves this fish away from whatever hit it, harder the more the hit was
## worth. Damage that came from nowhere in particular - a spell with no caster
## given - leaves it where it stands rather than picking a direction on its own.
##
## A killing blow still lands one: the fish is already dead by the time this
## runs, and being knocked over by the hit that did it is exactly right.
func _knock_back(amount: int, from: BattleFish) -> void:
	if from == null or not is_instance_valid(from):
		return
	var away := global_position - from.global_position
	away.y = 0.0
	# Dead centre on top of each other: any direction will do.
	away = away.normalized() if away.length_squared() > 0.0001 else _random_horizontal()
	var direction := (away + Vector3.UP * KNOCKBACK_LIFT).normalized()
	var impulse := direction * float(amount) * KNOCKBACK_PER_DAMAGE
	apply_central_impulse(impulse.limit_length(mass * KNOCKBACK_MAX_SPEED))

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
	_tick_flop(delta)
	_tick_look(delta)

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
	if not is_alive():
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
## much of chase_bias the distance leaves in play.
func _flop_direction() -> Vector3:
	var wander := _random_horizontal()
	if chase_target == null or not is_instance_valid(chase_target) or chase_bias <= 0.0:
		return wander
	var towards := chase_target.global_position - global_position
	towards.y = 0.0
	var distance := towards.length()
	if distance < 0.0001:
		return wander
	var bias := chase_bias * _chase_strength(distance)
	return wander.lerp(towards / distance, bias).normalized()

## How much of chase_bias survives at `distance`: all of it up close, falling
## off to CHASE_FAR_SCALE of it once the other fish is right across the floor.
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
	var other := body as BattleFish
	if other == null:
		return
	_hit(other)

## Lands a touch on `other`. Both bodies run this on their own side of the
## collision, so a head-on flop trades damage both ways.
func _hit(other: BattleFish) -> void:
	if not can_hit(other):
		return
	var id := other.get_instance_id()
	if _hit_cooldowns.has(id):
		return
	_hit_cooldowns[id] = HIT_COOLDOWN
	var dealt := other.take_damage(phys_dmg(), self)
	if dealt > 0:
		dealt_damage.emit(other, dealt)

# -- Death --------------------------------------------------------------------

func _on_fish_died() -> void:
	if _dead:
		return
	_dead = true
	_hit_cooldowns.clear()
	# It stops flopping and turns belly up - _sprite_roll() handles the turn -
	# but keeps its physics so it drops and settles instead of freezing in
	# mid-air. The arena frees it when it wants.
	_face_the_tumble()
	_sprite.modulate = tint.darkened(0.45).lerp(Color(0.55, 0.55, 0.60, 1.0), 0.5)
	died.emit(self)
