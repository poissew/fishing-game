## One bolt of lightning on its way down: a mark on the floor, a wait, and then
## the strike itself.
##
## The mark is the spell. It goes down where the target was standing when the
## strike was called and does not follow it, so the whole of the wind-up is a
## warning the target can do something about - which is why the marker is drawn
## at exactly `radius` across, the same as the ground it will actually hit.
##
## Like SpellFireZone and SpellBubble it carries everything it needs - the
## damage rolled when it was called, and the caster's team - so it lands whether
## or not the fish that called it is still alive. Its `_may_hit()` is the team
## half of BattleFish.can_hit() without the "is the attacker still standing"
## half, for the same reason: the sky does not care.
class_name SpellStrike
extends Node3D

## Used when the spell brings no mark of its own.
const DEFAULT_TEXTURE: Texture2D = preload("res://icon.svg")

## How far above the floor the mark sits - out of the floor's own depth, close
## enough that it still reads as lying on it. Same as SpellFireZone.
const GROUND_LIFT := 0.02

## The mark closes in as the bolt gets nearer: it starts this much wider than
## the ground it covers and is exactly that size when the strike lands.
const MARK_OPEN := 1.45
## And it blinks while it waits, faster as the moment approaches.
const BLINK_MIN := 0.45
const BLINK_RATE_START := 2.0
const BLINK_RATE_END := 9.0

## The drawn bolt, when the spell brings none.
const BOLT_W := 16
const BOLT_H := 64
## Half-width of the bright core of it, in texture pixels.
const BOLT_CORE := 2.4

## Fired when the bolt takes health off something, so whoever called it can
## report the damage as its own.
signal hit_fish(target: BattleFish, amount: int)

static var _bolt_texture: ImageTexture = null

var _spell: LightningSpellData = null
var _damage := 0
var _team := -1
var _caster: BattleFish = null
var _left := 0.0
var _struck := false
var _mark: Sprite3D = null
var _bolt: Sprite3D = null
var _mark_alpha := 1.0
var _bolt_alpha := 1.0

## Marks the floor at `ground` and starts the clock. The caller adds nothing
## else - it waits, it strikes, it reports what it hit, and it frees itself.
static func call_down(parent: Node3D, ground: Vector3, spell: LightningSpellData,
		damage: int, caster: BattleFish) -> SpellStrike:
	if parent == null or spell == null or caster == null:
		return null
	var strike := SpellStrike.new()
	strike._spell = spell
	strike._damage = damage
	strike._caster = caster
	strike._team = caster.team
	strike._left = maxf(spell.windup, 0.0)
	parent.add_child(strike)
	strike.global_position = ground
	strike._draw_mark()
	return strike

## The warning on the floor: flat, unshaded, and exactly as wide as the ground
## the bolt will cover, so what is drawn and what is dangerous are one thing.
func _draw_mark() -> void:
	_mark = Sprite3D.new()
	_mark.texture = _spell.texture if _spell.texture != null else DEFAULT_TEXTURE
	_mark.modulate = _spell.tint
	_mark_alpha = _spell.tint.a
	_mark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mark.shaded = false
	_mark.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_mark.pixel_size = _size_for(_mark.texture, _spell.radius * 2.0)
	add_child(_mark)
	_mark.position = Vector3.UP * GROUND_LIFT
	# Face up. Set once the node is in the tree, so the parent's own basis is
	# accounted for.
	_mark.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)

## The bolt: upright, standing on the marked ground rather than centred on it.
func _draw_bolt() -> void:
	_bolt = Sprite3D.new()
	_bolt.texture = _shared_bolt()
	_bolt.modulate = _spell.bolt_tint
	_bolt_alpha = _spell.bolt_tint.a
	_bolt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_bolt.shaded = false
	_bolt.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	# Billboarded, unlike SpellBeam: a bolt is drawn the same from every side,
	# and it is the one thing here that has no direction along the floor.
	_bolt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bolt.pixel_size = maxf(_spell.bolt_height, 0.1) / float(BOLT_H)
	add_child(_bolt)
	_bolt.position = Vector3.UP * _spell.bolt_height * 0.5
	_bolt.scale.x = _spell.bolt_width / maxf(float(BOLT_W) * _bolt.pixel_size, 0.0001)

func _process(_delta: float) -> void:
	if _spell == null:
		return
	if not _struck and _mark != null:
		var spent := 1.0 - clampf(_left / maxf(_spell.windup, 0.01), 0.0, 1.0)
		# Blinking faster and closing in: two ways of saying the same thing, and
		# at 480x270 a marker wants saying twice.
		var rate := lerpf(BLINK_RATE_START, BLINK_RATE_END, spent)
		_mark.modulate.a = _mark_alpha * lerpf(BLINK_MIN, 1.0,
			0.5 + 0.5 * sin(spent * _spell.windup * TAU * rate))
		var open := lerpf(MARK_OPEN, 1.0, spent)
		_mark.scale = Vector3(open, open, 1.0)
	elif _bolt != null:
		var fade := clampf(_left / maxf(_spell.bolt_time, 0.05), 0.0, 1.0)
		_bolt.modulate.a = _bolt_alpha * fade
		if _mark != null:
			_mark.modulate.a = _mark_alpha * fade

func _physics_process(delta: float) -> void:
	if _spell == null:
		queue_free()
		return
	_left -= delta
	if _left > 0.0:
		return
	if not _struck:
		# The moment the wind-up runs out: it lands, once, on whatever is
		# standing there now.
		_struck = true
		_left = maxf(_spell.bolt_time, 0.05)
		_draw_bolt()
		_strike()
		return
	queue_free()

## Everything standing on the marked ground this instant takes the bolt. It is
## a column from the sky, so how high off the floor a fish happens to be makes
## no difference - only how far it is from the middle of the mark.
func _strike() -> void:
	var source: BattleFish = _caster if is_instance_valid(_caster) else null
	for node in get_tree().get_nodes_in_group(BattleFish.GROUP):
		var fish := node as BattleFish
		if not _may_hit(fish):
			continue
		var offset := fish.global_position - global_position
		offset.y = 0.0
		if offset.length() > _spell.radius + fish.world_length() * _spell.target_girth:
			continue
		var dealt := fish.take_blast(_damage, global_position,
			_spell.knockback_scale, source, BattleFish.kind_of(_spell))
		if dealt > 0:
			hit_fish.emit(fish, dealt)

## The team half of BattleFish.can_hit(), with the fish that called it down out
## of it - lightning that struck its own caller would be a different spell.
func _may_hit(fish: BattleFish) -> bool:
	if fish == null or not fish.is_alive():
		return false
	if is_instance_valid(_caster) and fish == _caster:
		return false
	return _team < 0 or fish.team != _team

## Sized off the texture's own width, so a mark is `width` world units across
## whatever resolution the art was drawn at.
func _size_for(texture: Texture2D, width: float) -> float:
	if texture == null or texture.get_width() <= 0:
		return 0.01
	return width / float(texture.get_width())

## A jagged white bolt, built once and shared. White, so the spell's own tint
## decides the colour.
static func _shared_bolt() -> ImageTexture:
	if _bolt_texture != null:
		return _bolt_texture
	var image := Image.create(BOLT_W, BOLT_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	# Where the bolt is, across the strip, at five heights down it: a share of
	# the half-width either side of the middle.
	var kinks := PackedFloat32Array([0.0, 0.45, -0.40, 0.30, 0.0])
	var middle := (BOLT_W - 1) * 0.5
	for y in BOLT_H:
		var along := float(y) / float(BOLT_H - 1) * float(kinks.size() - 1)
		var step := mini(int(along), kinks.size() - 2)
		var centre := middle + lerpf(kinks[step], kinks[step + 1],
			along - float(step)) * middle
		for x in BOLT_W:
			var edge := absf(float(x) - centre) / BOLT_CORE
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0,
				clampf(1.0 - edge * edge, 0.0, 1.0)))
	_bolt_texture = ImageTexture.create_from_image(image)
	return _bolt_texture
