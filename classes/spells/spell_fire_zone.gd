## A patch of burning floor: it sits where it was lit, burns anything standing
## in it on a timer, and goes out on its own.
##
## Like SpellBubble it carries everything it needs - the damage rolled when it
## was lit, and the team of whoever lit it - so it keeps burning after that fish
## has been freed. And like the bubble, its own `_may_hit()` is the team half of
## BattleFish.can_hit() without the "is the attacker still alive" half, because
## fire does not care.
##
## The animation is **stretched over the whole duration** rather than looped:
## the frames it is given start as a flare and end in smoke, which is exactly
## the shape of a fire burning itself out, so one slow playthrough is the whole
## effect. `speed_scale` is what does it.
class_name SpellFireZone
extends AnimatedSprite3D

const DEFAULT_ANIM := &"default"

## Fired when the fire takes health off something, so whoever lit it can report
## the damage as its own.
signal hit_fish(target: BattleFish, amount: int)

var _spell: BurnZoneSpellData = null
var _damage := 0
var _team := -1
var _caster: BattleFish = null
var _left := 0.0
var _timer := 0.0

## Lights a patch at `origin`. The caller adds nothing else - it burns, it
## reports what it burnt, and it frees itself.
static func light(parent: Node3D, origin: Vector3, spell: BurnZoneSpellData,
		damage: int, caster: BattleFish) -> SpellFireZone:
	if parent == null or spell == null or spell.frames == null or caster == null:
		return null
	var zone := SpellFireZone.new()
	zone._spell = spell
	zone._damage = damage
	zone._caster = caster
	zone._team = caster.team
	zone._left = spell.duration
	zone._timer = spell.interval
	zone.sprite_frames = spell.frames
	zone.animation = zone._first_animation()
	zone.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	zone.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	zone.shaded = false
	zone.pixel_size = zone._pixel_size_for(spell.zone_size)
	# Stood on the ground rather than centred on it: the offset lifts the image
	# by half its own height, so its bottom edge is where the fish landed.
	var texture := spell.frames.get_frame_texture(zone.animation, 0)
	if texture != null:
		zone.offset = Vector2(0.0, texture.get_height() * 0.5)
	parent.add_child(zone)
	zone.global_position = origin
	return zone

func _ready() -> void:
	# One playthrough stretched over the whole burn. A zone that outlasts its
	# own animation would otherwise stand there on the last frame.
	speed_scale = _anim_length() / maxf(_spell.duration, 0.01) if _spell != null else 1.0
	play()

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
		# Physical: a burn that scales off how hard the fish hits is a burn
		# armour can do something about. See BurnZoneSpellData.
		var dealt := fish.take_tick_damage(_damage, source, not _spell.is_magical())
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

func _first_animation() -> StringName:
	if sprite_frames == null:
		return DEFAULT_ANIM
	if sprite_frames.has_animation(DEFAULT_ANIM):
		return DEFAULT_ANIM
	var names := sprite_frames.get_animation_names()
	return StringName(names[0]) if not names.is_empty() else DEFAULT_ANIM

## Seconds one playthrough would take at the frames' own speed.
func _anim_length() -> float:
	if sprite_frames == null or not sprite_frames.has_animation(animation):
		return 1.0
	var speed := sprite_frames.get_animation_speed(animation)
	if speed <= 0.0:
		return 1.0
	return sprite_frames.get_frame_count(animation) / speed

## Sized off the first frame's height, the same way the blast and the bubble
## are sized off theirs.
func _pixel_size_for(height: float) -> float:
	var texture := sprite_frames.get_frame_texture(animation, 0) if sprite_frames != null else null
	if texture == null or texture.get_height() <= 0:
		return 0.01
	return height / float(texture.get_height())
