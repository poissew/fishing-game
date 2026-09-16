## One bubble in flight: it travels in a straight line at a fixed speed and pops
## on the first fish it is allowed to hit, or when it runs out of range.
##
## It carries its own copy of everything it needs - the damage rolled at the
## moment it was fired, and the caster's team - so it keeps flying, and keeps
## hitting, after the fish that fired it has been freed. That is also why the
## team check here is not BattleFish.can_hit(): that one asks whether the
## attacker is still alive, and a bubble does not care.
##
## It does not home. The direction is fixed at the muzzle, which is what makes
## a volley dodgeable at all.
class_name SpellBubble
extends Sprite3D

## Fired when this bubble takes health off something. `amount` is what the
## target actually lost. BattleFish re-emits it as its own dealt_damage.
signal hit_fish(target: BattleFish, amount: int)

## Share of a fish's own length that counts as its width for being hit by one of
## these. Well under half: a fish is long and shallow, and a bubble that popped
## on a sphere the length of a shark would be impossible to dodge.
const TARGET_GIRTH := 0.35

## The drawn bubble, when the spell does not bring a texture of its own.
const TEX_SIZE := 16
const RIM := Color(0.62, 0.86, 1.00, 1.0)
const SHINE := Color(0.95, 1.00, 1.00, 1.0)

static var _default_texture: ImageTexture = null

var _spell: BubbleSpellData = null
var _velocity := Vector3.ZERO
var _damage := 0
## The caster's team, copied so the bubble outlives the caster.
var _team := -1
var _caster: BattleFish = null
var _travelled := 0.0

## Puts a bubble in the world under `parent`, travelling along `direction`. The
## caller keeps hold of it long enough to connect hit_fish.
static func fire(parent: Node3D, origin: Vector3, direction: Vector3,
		spell: BubbleSpellData, damage: int, caster: BattleFish) -> SpellBubble:
	if parent == null or spell == null or caster == null or direction.is_zero_approx():
		return null
	var bubble := SpellBubble.new()
	bubble._spell = spell
	bubble._damage = damage
	bubble._caster = caster
	bubble._team = caster.team
	bubble._velocity = direction.normalized() * spell.speed(caster.magic_dmg())
	bubble.texture = spell.texture if spell.texture != null else _shared_texture()
	# Billboarded and unshaded, the same as the blast: a bubble has no side to
	# be seen from, and nothing else in the arena is lit either.
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bubble.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	bubble.shaded = false
	bubble.pixel_size = spell.bubble_size / maxf(float(bubble.texture.get_width()), 1.0)
	parent.add_child(bubble)
	bubble.global_position = origin
	return bubble

## Moved by hand rather than by the physics server: a bubble has no mass, is not
## meant to bounce off anything, and walking the battler group is the same way
## the explosion finds what it caught.
func _physics_process(delta: float) -> void:
	if _spell == null:
		queue_free()
		return
	var step := _velocity * delta
	global_position += step
	_travelled += step.length()
	if _travelled >= _spell.max_range:
		queue_free()
		return

	var target := _first_fish_touched()
	if target == null:
		return
	var dealt := target.take_blast(_damage, global_position, _spell.knockback_scale,
		_caster if is_instance_valid(_caster) else null)
	if dealt > 0:
		hit_fish.emit(target, dealt)
	queue_free()

## The first fish this bubble is inside of, or null. First rather than nearest:
## two fish close enough to both be touched by one bubble are close enough that
## it does not matter which of them it pops on.
func _first_fish_touched() -> BattleFish:
	for node in get_tree().get_nodes_in_group(BattleFish.GROUP):
		var fish := node as BattleFish
		if not _may_hit(fish):
			continue
		var reach := _spell.hit_radius + fish.world_length() * TARGET_GIRTH
		if global_position.distance_to(fish.global_position) <= reach:
			return fish
	return null

## The team half of BattleFish.can_hit() and nothing else - dead fish, team
## mates and the caster itself are out, everything else is fair game.
func _may_hit(fish: BattleFish) -> bool:
	if fish == null or not fish.is_alive():
		return false
	if is_instance_valid(_caster) and fish == _caster:
		return false
	return _team < 0 or fish.team != _team

## A bubble drawn in code: a ring of pixels with a shine in the upper left. The
## project has no bubble art, and a spell that needs none can be looked at the
## day it is written - put a texture on the resource and it takes over.
##
## Built once and shared: every bubble in the arena is the same 16 pixels.
static func _shared_texture() -> ImageTexture:
	if _default_texture != null:
		return _default_texture
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var centre := (TEX_SIZE - 1) * 0.5
	var outer := TEX_SIZE * 0.5 - 1.0
	var inner := outer - 1.6
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var distance := Vector2(x - centre, y - centre).length()
			if distance <= outer and distance >= inner:
				image.set_pixel(x, y, RIM)
	image.set_pixel(4, 4, SHINE)
	image.set_pixel(5, 4, SHINE)
	image.set_pixel(4, 5, SHINE)
	_default_texture = ImageTexture.create_from_image(image)
	return _default_texture
