## One leech: it lies on the floor until something stands on it, then rides that
## fish and drinks until it is full.
##
## Two lives in one node. On the floor it is waiting and does nothing but look
## for a fish it may catch; attached it stops caring about the floor entirely
## and follows its victim, which is why it is drawn billboarded rather than laid
## flat the way SpellFireZone is - it spends most of its life on the side of a
## fish rather than on the ground.
##
## Like every other effect that outlives its caster it carries its own copy of
## what it needs: the damage rolled when it was dropped, and the team it must
## not bite. What it cannot carry is the healing - that goes to a fish that has
## to still be there, so the owner is checked every mouthful and a leech whose
## owner has died simply keeps drinking for nothing.
class_name SpellLeech
extends Sprite3D

## Used when the spell brings no art of its own.
const DEFAULT_TEXTURE: Texture2D = preload("res://icon.svg")

## How far above the floor a waiting leech sits, so it does not z-fight it.
const GROUND_LIFT := 0.04
## And how far up the side of a fish it climbs once it has latched on.
const RIDE_HEIGHT := 0.12

## It twitches while it waits, so a leech on the floor is not mistaken for a
## decal that has been left behind.
const IDLE_PULSE := 0.18
const IDLE_RATE := 2.4
## Share of its remaining life over which it fades out.
const FADE_LAST := 0.3

## Fired when a mouthful takes health off something, so the owner can report it.
## There is no signal for the healing: that arrives on the owner itself, as
## BattleFish.healed, which is where anything watching would look for it.
signal hit_fish(target: BattleFish, amount: int)

var _spell: LeechSpellData = null
var _damage := 0
var _team := -1
var _caster: BattleFish = null
var _victim: BattleFish = null
var _left := 0.0
## The full length of whichever life it is living - `life` while it waits,
## `duration` once it has latched on - so the fade is measured against the right
## clock rather than always against the long one.
var _span := 1.0
var _timer := 0.0
var _age := 0.0

## Drops a leech at `ground`, which is the floor the fish came down on. The
## caller keeps hold of it for the signals and to count its own stack.
static func drop(parent: Node3D, ground: Vector3, spell: LeechSpellData,
		damage: int, caster: BattleFish) -> SpellLeech:
	if parent == null or spell == null or caster == null:
		return null
	var leech := SpellLeech.new()
	leech._spell = spell
	leech._damage = damage
	leech._caster = caster
	leech._team = caster.team
	leech._left = maxf(spell.life, 0.1)
	leech._span = leech._left
	leech.texture = spell.texture if spell.texture != null else DEFAULT_TEXTURE
	leech.modulate = spell.tint
	leech.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	leech.shaded = false
	# Billboarded, like the bubble and unlike a patch of fire: it ends up stuck
	# to the side of a fish, where a quad lying flat would be edge-on.
	leech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	leech.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	leech.pixel_size = spell.leech_size / maxf(float(leech.texture.get_width()), 1.0)
	parent.add_child(leech)
	leech.global_position = ground + Vector3.UP * GROUND_LIFT
	return leech

## Whether this one has caught something and is drinking.
func is_attached() -> bool:
	return _victim != null and is_instance_valid(_victim)

func _process(delta: float) -> void:
	if _spell == null:
		return
	_age += delta
	var fade := clampf(_left / (maxf(_span, 0.1) * FADE_LAST), 0.0, 1.0)
	if is_attached():
		modulate = _spell.fed_tint
		modulate.a = _spell.fed_tint.a * fade
		return
	# Waiting: breathing quietly on the floor.
	modulate = _spell.tint
	modulate.a = _spell.tint.a * fade \
		* (1.0 - IDLE_PULSE + IDLE_PULSE * sin(_age * TAU * IDLE_RATE))

func _physics_process(delta: float) -> void:
	if _spell == null:
		queue_free()
		return
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	if is_attached():
		_ride(delta)
	elif _victim != null:
		# It was riding a fish that has since been freed: nothing to hold on to.
		queue_free()
	else:
		_look_for_a_fish()

## Rides its victim and drinks on the clock.
func _ride(delta: float) -> void:
	global_position = _victim.global_position + Vector3.UP * RIDE_HEIGHT
	if not _victim.is_alive():
		queue_free()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer += maxf(_spell.interval, 0.05)
	_bite()

## One mouthful: off the victim, and as much of it as the spell allows back into
## the fish that dropped this.
func _bite() -> void:
	var source: BattleFish = _caster if is_instance_valid(_caster) else null
	# No shove: a leech that threw its victim across the arena every half second
	# would be shaking it off rather than drinking from it.
	var dealt := _victim.take_blast(_damage, _victim.global_position, 0.0, source,
		BattleFish.kind_of(_spell))
	if dealt <= 0:
		return
	hit_fish.emit(_victim, dealt)
	if source == null or not source.is_alive():
		return
	source.heal(_spell.healing_for(dealt))

## Looks for something standing on it. The first fish it may bite that is close
## enough along the floor and low enough above it gets the leech.
func _look_for_a_fish() -> void:
	for node in get_tree().get_nodes_in_group(BattleFish.GROUP):
		var fish := node as BattleFish
		if not _may_bite(fish):
			continue
		var offset := fish.global_position - global_position
		if absf(offset.y) > _spell.height:
			continue
		offset.y = 0.0
		if offset.length() > _spell.radius + fish.world_length() * 0.25:
			continue
		_victim = fish
		# Its own clock starts again the moment it latches on: the time it spent
		# waiting is not time it spent drinking.
		_left = maxf(_spell.duration, 0.1)
		_span = _left
		_timer = maxf(_spell.interval, 0.05)
		return

## The team half of BattleFish.can_hit(), with the fish that dropped it ruled
## out: a fish lands in the middle of its own leeches every single time.
func _may_bite(fish: BattleFish) -> bool:
	if fish == null or not fish.is_alive():
		return false
	if is_instance_valid(_caster) and fish == _caster:
		return false
	return _team < 0 or fish.team != _team
