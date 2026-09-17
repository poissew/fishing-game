## The beam itself: a bar of light drawn from the fish to wherever the shot
## ends, on screen for as long as the shot lasts and then gone.
##
## Presentation only - BattleFish works out who is standing in the line, because
## BattleFish owns the rules about who may be hit by anything. It carries its
## own lifetime, so it goes whether or not the fish that fired it is still there.
##
## **It is a quad standing in the world, not a billboard.** A beam has a
## direction, and the whole point of the picture is which way it is pointing, so
## it cannot turn to face the camera the way the fish do. The cost is the same
## one the fish pay for tumbling: a beam fired straight at or away from the
## camera is drawn nearly edge-on. The arena is 8 wide and 5 deep, so most shots
## run across it rather than into it.
class_name SpellBeam
extends Sprite3D

const TEX_W := 32
const TEX_H := 8
## Share of its life spent fading out at the end.
const FADE_LAST := 0.45

static var _default_texture: ImageTexture = null

var _life := 0.0
var _left := 0.0
var _base_alpha := 1.0

## Draws a beam of `length` running along `direction` from `origin`. The caller
## adds nothing else - it shines, it fades, it frees itself.
static func fire(parent: Node3D, origin: Vector3, direction: Vector3,
		length: float, spell: LaserSpellData) -> SpellBeam:
	if parent == null or spell == null or direction.is_zero_approx() or length <= 0.0:
		return null
	var beam := SpellBeam.new()
	beam._life = maxf(spell.beam_time, 0.05)
	beam._left = beam._life
	beam._base_alpha = spell.tint.a
	beam.texture = _shared_texture()
	beam.modulate = spell.tint
	beam.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	beam.shaded = false
	# Blended, not cut: the bar has soft edges and it fades on the way out.
	beam.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	beam.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	beam.pixel_size = maxf(spell.thickness, 0.01) / float(TEX_H)
	parent.add_child(beam)

	# Laid along the shot: local X runs down the beam, local Y is world up, so
	# the quad's face ends up perpendicular to both - which is roughly at the
	# camera for anything fired across the arena.
	var forward := direction.normalized()
	var up := Vector3.UP
	var side := forward.cross(up)
	if side.is_zero_approx():
		side = Vector3.BACK
	beam.global_position = origin + forward * length * 0.5
	beam.global_basis = Basis(forward, up, side.normalized())
	# pixel_size sized the thickness; the stretch along X makes the length.
	beam.scale.x = length / maxf(float(TEX_W) * beam.pixel_size, 0.0001)
	return beam

func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var fade := clampf((_left / _life) / FADE_LAST, 0.0, 1.0)
	modulate.a = _base_alpha * fade

## A bar: bright down the middle, soft at the top and bottom. White, so the
## spell's own tint decides the colour.
static func _shared_texture() -> ImageTexture:
	if _default_texture != null:
		return _default_texture
	var image := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var middle := (TEX_H - 1) * 0.5
	for y in TEX_H:
		var edge := absf(float(y) - middle) / middle
		var alpha := clampf(1.0 - edge * edge, 0.0, 1.0)
		for x in TEX_W:
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_default_texture = ImageTexture.create_from_image(image)
	return _default_texture
