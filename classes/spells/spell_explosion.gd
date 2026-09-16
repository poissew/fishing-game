## The blast an ExplosionSpellData draws: one run of its animation at the point
## of impact, then it frees itself.
##
## Presentation only. It does no damage and knows nothing about who set it off -
## BattleFish works out who is caught in the blast, because BattleFish is what
## owns the rules about who may hit whom. That keeps this usable for any effect
## that wants a puff of animation somewhere in the world.
##
## Built in code rather than from a scene: it is a single node whose every
## property is decided by the spell that fired it, so a .tscn would have nothing
## in it worth editing.
class_name SpellExplosion
extends AnimatedSprite3D

const DEFAULT_ANIM := &"default"

## Puts a blast in the world under `parent`, sized off the spell that fired it.
## Parent it to the arena rather than to the fish: the explosion stays where it
## went off, and outlives a fish that is freed the moment after.
static func burst(parent: Node3D, origin: Vector3, spell: ExplosionSpellData) -> SpellExplosion:
	if parent == null or spell == null or spell.frames == null:
		return null
	var blast := SpellExplosion.new()
	blast.sprite_frames = spell.frames
	blast.animation = blast._first_animation()
	# Billboarded, unlike the fish: a blast has no side to be seen from, and
	# reading edge-on for a frame the way a fish can would just look like a
	# dropped frame.
	blast.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	blast.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	blast.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	blast.shaded = false
	blast.pixel_size = blast._pixel_size_for(spell.visual_size())
	parent.add_child(blast)
	blast.global_position = origin
	return blast

func _ready() -> void:
	animation_finished.connect(queue_free)
	play()

## "default" when the SpriteFrames has one, otherwise whatever it does have.
func _first_animation() -> StringName:
	if sprite_frames == null:
		return DEFAULT_ANIM
	if sprite_frames.has_animation(DEFAULT_ANIM):
		return DEFAULT_ANIM
	var names := sprite_frames.get_animation_names()
	return StringName(names[0]) if not names.is_empty() else DEFAULT_ANIM

## Scaled off the first frame's height, so the art is `height` world units tall
## whatever resolution it was drawn at - the same trick BattleFish uses to size
## a fish off its icon, by height rather than width because a blast is taller
## than it is wide.
func _pixel_size_for(height: float) -> float:
	var texture := sprite_frames.get_frame_texture(animation, 0) if sprite_frames != null else null
	if texture == null or texture.get_height() <= 0:
		return 0.01
	return height / float(texture.get_height())
