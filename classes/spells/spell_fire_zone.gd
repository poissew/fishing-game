## A patch of burning floor: a flat marker lying on the ground where it was lit,
## burning anything standing on it on a timer, until it goes out.
##
## Drawn as a **ground quad rather than an upright sprite**, so what the player
## sees is the ground the zone actually covers - it is drawn at exactly `radius`
## across, so the picture and the hitbox are the same thing. A `Decal` would be
## the other way to do it, but the project's feature tag is GL Compatibility and
## Godot does not render decals there at all; a flat unshaded quad looks the
## same on a flat floor and works under either renderer.
##
## Like SpellBubble it carries everything it needs - the damage rolled when it
## was lit, and the team of whoever lit it - so it keeps burning after that fish
## has been freed. And like the bubble, its own `_may_hit()` is the team half of
## BattleFish.can_hit() without the "is the attacker still alive" half, because
## fire does not care.
class_name SpellFireZone
extends Sprite3D

## Used when the spell brings no texture of its own.
const DEFAULT_TEXTURE: Texture2D = preload("res://icon.svg")

## How far above the floor the marker sits. Enough to stay out of the floor's
## own depth, little enough that it still reads as lying on it.
const GROUND_LIFT := 0.02

## The marker breathes rather than sitting flat and dead, so a zone that is
## still burning is told apart at a glance from one that is about to go out.
const PULSE_MIN := 0.78
const PULSE_MAX := 1.00
const PULSE_RATE := 1.6
## Share of the burn left over which it fades away.
const FADE_LAST := 0.25

## Fired when the fire takes health off something, so whoever lit it can report
## the damage as its own.
signal hit_fish(target: BattleFish, amount: int)

var _spell: BurnZoneSpellData = null
var _damage := 0
var _team := -1
var _caster: BattleFish = null
var _left := 0.0
var _timer := 0.0
var _base_alpha := 1.0

## Lights a patch at `origin`, which is the floor the fish came down on. The
## caller adds nothing else - it burns, it reports what it burnt, and it frees
## itself.
static func light(parent: Node3D, origin: Vector3, spell: BurnZoneSpellData,
		damage: int, caster: BattleFish) -> SpellFireZone:
	if parent == null or spell == null or caster == null:
		return null
	var zone := SpellFireZone.new()
	zone._spell = spell
	zone._damage = damage
	zone._caster = caster
	zone._team = caster.team
	zone._left = spell.duration
	zone._timer = spell.interval
	zone.texture = spell.texture if spell.texture != null else DEFAULT_TEXTURE
	zone.modulate = spell.tint
	zone._base_alpha = spell.tint.a
	zone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	zone.shaded = false
	# Blended rather than cut out: the marker is meant to be seen through, and
	# it fades as the fire burns down.
	zone.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	zone.pixel_size = zone._pixel_size_for(spell.radius * 2.0)
	parent.add_child(zone)
	zone.global_position = origin + Vector3.UP * GROUND_LIFT
	# Face up. Rotations are set after the node is in the tree so the parent's
	# own basis is accounted for.
	zone.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	return zone

func _process(_delta: float) -> void:
	if _spell == null:
		return
	var spent := 1.0 - clampf(_left / maxf(_spell.duration, 0.01), 0.0, 1.0)
	var pulse := lerpf(PULSE_MIN, PULSE_MAX,
		0.5 + 0.5 * sin(spent * _spell.duration * TAU * PULSE_RATE))
	# Dying away over the last of it, so a zone about to go out looks like one.
	var fade := clampf((1.0 - spent) / FADE_LAST, 0.0, 1.0)
	modulate.a = _base_alpha * pulse * fade

func _physics_process(delta: float) -> void:
	if _spell == null:
		queue_free()
		return
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer += maxf(_spell.interval, 0.01)
	_burn()

## Everything standing in the fire this instant takes a tick of it.
func _burn() -> void:
	var source: BattleFish = _caster if is_instance_valid(_caster) else null
	for node in get_tree().get_nodes_in_group(BattleFish.GROUP):
		var fish := node as BattleFish
		if not _may_hit(fish):
			continue
		var offset := fish.global_position - global_position
		if absf(offset.y) > _spell.height:
			continue
		offset.y = 0.0
		if offset.length() > _spell.radius:
			continue
		# Physical, because the spell is: a burn that scales off how hard the
		# fish hits is a burn armour can do something about, and not one a ward
		# turns aside. See BurnZoneSpellData.
		var dealt := fish.take_tick_damage(_damage, source, BattleFish.kind_of(_spell))
		if dealt > 0:
			hit_fish.emit(fish, dealt)

## The team half of BattleFish.can_hit(), and the fish that lit it is out of it:
## it lands in the middle of its own fire every single time.
func _may_hit(fish: BattleFish) -> bool:
	if fish == null or not fish.is_alive():
		return false
	if is_instance_valid(_caster) and fish == _caster:
		return false
	return _team < 0 or fish.team != _team

## Sized off the texture's own width, so the marker is `width` world units
## across whatever resolution the art was drawn at - the same trick the blast
## and the bubble use.
func _pixel_size_for(width: float) -> float:
	if texture == null or texture.get_width() <= 0:
		return 0.01
	return width / float(texture.get_width())
