## The pop of light a camera makes: on screen for a fraction of a second,
## growing and fading, then gone.
##
## Presentation only, the same as SpellExplosion - BattleFish works out who was
## caught in it, because BattleFish is what owns the rules about who may be
## caught in anything. Built in code and drawing its own starburst, because the
## project has no camera art and a spell that needs none can be looked at the
## day it is written.
class_name SpellFlash
extends Sprite3D

const TEX_SIZE := 16
## How big the burst starts and ends, as a share of the size it is given.
const GROW_FROM := 0.55
const GROW_TO := 1.35

static var _default_texture: ImageTexture = null

var _life := 0.0
var _left := 0.0

## Puts a flash in the world under `parent`. The caller decides where; this only
## knows how to be bright.
static func burst(parent: Node3D, origin: Vector3, spell: PaparazziSpellData) -> SpellFlash:
	if parent == null or spell == null:
		return null
	var flash := SpellFlash.new()
	flash._life = maxf(spell.flash_time, 0.01)
	flash._left = flash._life
	flash.texture = spell.texture if spell.texture != null else _shared_texture()
	flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flash.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Alpha blended rather than cut, unlike every other effect in the arena: the
	# whole point of a flash is that it fades, and a cutout cannot.
	flash.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	flash.shaded = false
	flash.pixel_size = spell.flash_size / maxf(float(flash.texture.get_height()), 1.0)
	parent.add_child(flash)
	flash.global_position = origin
	return flash

func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var spent := 1.0 - _left / _life
	scale = Vector3.ONE * lerpf(GROW_FROM, GROW_TO, spent)
	modulate.a = _left / _life

## A starburst drawn in code: a white core, four spikes on the axes and four
## shorter ones on the diagonals. Built once and shared by every flash.
static func _shared_texture() -> ImageTexture:
	if _default_texture != null:
		return _default_texture
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var centre := (TEX_SIZE - 1) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var dx := float(x) - centre
			var dy := float(y) - centre
			var distance := Vector2(dx, dy).length()
			var lit := distance <= 3.5
			if not lit and distance <= 7.5 and (absf(dx) <= 0.6 or absf(dy) <= 0.6):
				lit = true
			if not lit and distance <= 5.5 and absf(absf(dx) - absf(dy)) <= 0.6:
				lit = true
			if lit:
				image.set_pixel(x, y, Color.WHITE)
	_default_texture = ImageTexture.create_from_image(image)
	return _default_texture
