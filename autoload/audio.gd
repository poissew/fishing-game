## Every sound the game makes goes through here.
##
## Three kinds of audio, each on its own mixer bus so the player can set them
## independently later: MUSIC (one track at a time, crossfaded), SOUNDSCAPE
## (looping ambience, any number of layers at once) and SFX (one-shots, either
## flat or placed in the world). UI is a fourth bus for menu clicks, which want
## to stay audible when somebody has pulled the game's sound effects down.
##
## The buses themselves live in default_bus_layout.tres, which Godot loads
## before anything else runs. This node only routes to them and fades things in
## and out; the mixer is the AudioServer's, so an options screen drives it
## through set_volume() / set_muted() without knowing what is playing.
##
## Like `daynight` and `gamephase` this owns no scene and knows nothing about
## the game: it is asked to play things, it never goes looking for them.
extends Node

## The mixer tracks. Anything added here needs a matching bus in the layout and
## an entry in BUS_NAMES.
enum Bus {
	MASTER,     ## Everything, and what an overall volume slider drives.
	MUSIC,      ## Composed tracks.
	SOUNDSCAPE, ## Looping ambience: water, wind, the arena crowd.
	SFX,        ## One-shots, in the world or flat.
	UI,         ## Menus and HUD. Deliberately not SFX.
}

## A bus's level changed, with its new linear volume (0..1). This is what an
## options screen listens to if anything other than it can move the sliders.
signal volume_changed(bus: Bus, linear: float)
## A bus was muted or unmuted.
signal mute_changed(bus: Bus, muted: bool)
## Music started, stopped (null) or was swapped for another track.
signal music_changed(stream: AudioStream)

## Bus names as written in default_bus_layout.tres. A name missing from the
## layout falls back to Master in _resolve_buses(), so a half-set-up mixer is
## quiet in the options screen rather than fatal in the game.
const BUS_NAMES := {
	Bus.MASTER: &"Master",
	Bus.MUSIC: &"Music",
	Bus.SOUNDSCAPE: &"Soundscape",
	Bus.SFX: &"SFX",
	Bus.UI: &"UI",
}

## Flat one-shot players made up front and reused. The pool grows as far as
## MAX_VOICES if a moment needs more, and past that the oldest still-sounding
## voice is taken - a sound cut short is better than an allocation mid-fight.
const VOICES := 16
const MAX_VOICES := 32

## Where a fade-out ends before the player is stopped. Low enough to be
## inaudible, high enough that linear_to_db()'s -inf never reaches a tween.
const SILENT_DB := -60.0

## Default crossfades, in seconds. Ambience wants longer than music, because
## nobody is supposed to notice it change.
const MUSIC_FADE := 1.5
const SOUNDSCAPE_FADE := 2.0

## Set by set_volume() so get_volume() hands back what was asked for rather
## than a value round-tripped through decibels.
var _levels: Dictionary = {}
## Bus -> the name actually resolved against the layout.
var _names: Dictionary = {}

var _voices: Array[AudioStreamPlayer] = []
var _steal := 0

## Two music players, crossfaded against each other. _playing is the index of
## whichever is carrying the current track.
var _music: Array[AudioStreamPlayer] = []
var _playing := 0

## StringName -> AudioStreamPlayer, one per ambience layer.
var _soundscapes: Dictionary = {}

## What world-placed one-shots are parented to. Every SubViewport in the game
## shares the root's World3D, so this node is a fine parent and is the default;
## bind_world() is for a scene that gives its viewport a world of its own.
var _world: Node = null

func _ready() -> void:
	# Sound carries on while the tree is paused: a pause menu with silence
	# behind it sounds like a crash.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_buses()
	for _i in VOICES:
		_voices.append(_make_voice(Bus.SFX))
	for _i in 2:
		var player := _make_voice(Bus.MUSIC)
		player.volume_db = SILENT_DB
		_music.append(player)

# ── Sound effects ─────────────────────────────────────────────────────────────

## Play `stream` once, unplaced - a reel, a bite, anything that does not come
## from somewhere in particular. `jitter` is how far the pitch may wander
## either side of 1.0, which is what keeps a sound repeated twice a second
## from turning into a machine.
func play_sfx(stream: AudioStream, volume_db := 0.0, jitter := 0.0) -> AudioStreamPlayer:
	return _play_flat(stream, Bus.SFX, volume_db, jitter)

## The same, on the UI bus.
func play_ui(stream: AudioStream, volume_db := 0.0, jitter := 0.0) -> AudioStreamPlayer:
	return _play_flat(stream, Bus.UI, volume_db, jitter)

## Play `stream` once at a point in the world. The player is made for the call
## and frees itself when the sound ends, so the stream must not loop.
func play_sfx_at(stream: AudioStream, where: Vector3, volume_db := 0.0, jitter := 0.0) -> AudioStreamPlayer3D:
	var player := _make_positional(stream, volume_db, jitter)
	if player == null:
		return null
	_world_parent().add_child(player)
	player.global_position = where
	player.play()
	return player

## Play `stream` once on `host`, following it about - a fish's own splash,
## which should move with the fish rather than stay where it started. The
## player is freed with the sound or with the host, whichever goes first.
func play_sfx_on(host: Node3D, stream: AudioStream, volume_db := 0.0, jitter := 0.0) -> AudioStreamPlayer3D:
	if not is_instance_valid(host):
		return null
	var player := _make_positional(stream, volume_db, jitter)
	if player == null:
		return null
	host.add_child(player)
	player.play()
	return player

# ── Music ─────────────────────────────────────────────────────────────────────

## Put `stream` on, crossfading out whatever was playing. Asking for the track
## already playing does nothing, so a scene is free to call this every time it
## is entered. A null stream is the same as stop_music().
func play_music(stream: AudioStream, fade := MUSIC_FADE, volume_db := 0.0) -> void:
	if stream == null:
		stop_music(fade)
		return
	var current := _music[_playing] as AudioStreamPlayer
	if current.playing and current.stream == stream:
		return
	_playing = 1 - _playing
	var next := _music[_playing] as AudioStreamPlayer
	_fade(current, SILENT_DB, fade, true)
	_start_loop(next, stream)
	_fade(next, volume_db, fade)
	music_changed.emit(stream)

## Fade the current track out and stop it.
func stop_music(fade := MUSIC_FADE) -> void:
	var current := _music[_playing] as AudioStreamPlayer
	if not current.playing:
		return
	_fade(current, SILENT_DB, fade, true)
	music_changed.emit(null)

func is_music_playing() -> bool:
	return (_music[_playing] as AudioStreamPlayer).playing

## The track currently on, or null.
func current_music() -> AudioStream:
	var current := _music[_playing] as AudioStreamPlayer
	return current.stream if current.playing else null

# ── Soundscapes ───────────────────────────────────────────────────────────────

## Fade an ambience layer in under `id`, looping until it is stopped. Layers
## are independent - water, wind and birds can all be running at once - and
## asking again for the layer already playing only moves its level, so a layer
## can be told to get quieter without being restarted.
func play_soundscape(id: StringName, stream: AudioStream, fade := SOUNDSCAPE_FADE, volume_db := 0.0) -> void:
	if stream == null:
		stop_soundscape(id, fade)
		return
	var player := _soundscapes.get(id) as AudioStreamPlayer
	if player != null and player.playing and player.stream == stream:
		_fade(player, volume_db, fade)
		return
	if player != null:
		_fade(player, SILENT_DB, fade, true, true)
	player = _make_voice(Bus.SOUNDSCAPE)
	_soundscapes[id] = player
	_start_loop(player, stream)
	_fade(player, volume_db, fade)

## Fade a layer out and drop it.
func stop_soundscape(id: StringName, fade := SOUNDSCAPE_FADE) -> void:
	var player := _soundscapes.get(id) as AudioStreamPlayer
	if player == null:
		return
	_soundscapes.erase(id)
	_fade(player, SILENT_DB, fade, true, true)

## Fade every layer out - what a scene change wants.
func stop_soundscapes(fade := SOUNDSCAPE_FADE) -> void:
	for id in _soundscapes.keys():
		stop_soundscape(id, fade)

func is_soundscape_playing(id: StringName) -> bool:
	var player := _soundscapes.get(id) as AudioStreamPlayer
	return player != null and player.playing

## Silence everything at once, music included.
func stop_all(fade := 0.0) -> void:
	stop_music(fade)
	stop_soundscapes(fade)
	for voice in _voices:
		voice.stop()

# ── The mixer ─────────────────────────────────────────────────────────────────

## Set a bus's level, 0 (silent) to 1 (as recorded). This is what an options
## slider drives; the value is kept as given so the slider reads back the same
## number it wrote rather than a decibel round-trip.
func set_volume(bus: Bus, linear: float) -> void:
	var level := clampf(linear, 0.0, 1.0)
	_levels[bus] = level
	# linear_to_db(0) is -inf, which the mixer would rather not be handed.
	var db := linear_to_db(level) if level > 0.0 else SILENT_DB
	AudioServer.set_bus_volume_db(bus_index(bus), db)
	volume_changed.emit(bus, level)

## What set_volume() was last given for this bus, 1.0 if it has not been set.
func get_volume(bus: Bus) -> float:
	return _levels.get(bus, 1.0)

func set_muted(bus: Bus, muted: bool) -> void:
	AudioServer.set_bus_mute(bus_index(bus), muted)
	mute_changed.emit(bus, muted)

func is_muted(bus: Bus) -> bool:
	return AudioServer.is_bus_mute(bus_index(bus))

## Every bus and its level, for saving. Keys are the enum's own ints.
func volumes() -> Dictionary:
	var out := {}
	for bus in BUS_NAMES:
		out[bus] = get_volume(bus)
	return out

## Put back what volumes() gave, ignoring anything that is no longer a bus.
func apply_volumes(saved: Dictionary) -> void:
	for bus in saved:
		if BUS_NAMES.has(bus):
			set_volume(bus, float(saved[bus]))

## The AudioServer index of a bus, for anything wanting to reach past this node
## - an effect on the ambience, a spectrum analyser on the music.
func bus_index(bus: Bus) -> int:
	return AudioServer.get_bus_index(_bus_name(bus))

# ── Plumbing ──────────────────────────────────────────────────────────────────

## Point world-placed one-shots at a different parent. Only needed by a scene
## that gives its viewport its own World3D; nothing in the game does today.
func bind_world(world: Node) -> void:
	_world = world

func _resolve_buses() -> void:
	for bus in BUS_NAMES:
		var bus_name := BUS_NAMES[bus] as StringName
		if AudioServer.get_bus_index(bus_name) == -1:
			push_warning("audio: bus '%s' missing from the layout, falling back to Master" % bus_name)
			bus_name = BUS_NAMES[Bus.MASTER]
		_names[bus] = bus_name

func _bus_name(bus: Bus) -> StringName:
	return _names.get(bus, BUS_NAMES[Bus.MASTER])

func _world_parent() -> Node:
	return _world if is_instance_valid(_world) else self

func _make_voice(bus: Bus) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = _bus_name(bus)
	# Connected once, here, rather than wherever a loop is started: a bound
	# callable is not equal to the one it was bound from, so is_connected()
	# cannot be trusted to keep a later connect() from stacking up.
	player.finished.connect(_on_finished.bind(player))
	add_child(player)
	return player

func _make_positional(stream: AudioStream, volume_db: float, jitter: float) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = _bus_name(Bus.SFX)
	player.volume_db = volume_db
	player.pitch_scale = _jitter(jitter)
	# A one-shot has nothing left to say once it is over, and nothing owns it.
	player.finished.connect(player.queue_free)
	return player

func _play_flat(stream: AudioStream, bus: Bus, volume_db: float, jitter: float) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := _take_voice()
	player.bus = _bus_name(bus)
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = _jitter(jitter)
	player.play()
	return player

## A free one-shot player: an idle one, a new one while there is room, and
## failing both the next in line whatever it is in the middle of.
func _take_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	if _voices.size() < MAX_VOICES:
		var grown := _make_voice(Bus.SFX)
		_voices.append(grown)
		return grown
	var stolen := _voices[_steal] as AudioStreamPlayer
	_steal = (_steal + 1) % _voices.size()
	stolen.stop()
	return stolen

## All rolls go through the shared generator, this one included.
func _jitter(amount: float) -> float:
	if amount <= 0.0:
		return 1.0
	return 1.0 + randomizer.RNG.randf_range(-amount, amount)

## Start `player` on a stream that has to keep going, silent, for a fade to
## bring up. Streams that loop by their import settings never finish; the ones
## that do not are started again in _on_finished(), so a track loops either
## way and nothing has to care which kind it was handed.
func _start_loop(player: AudioStreamPlayer, stream: AudioStream) -> void:
	player.stop()
	player.stream = stream
	player.volume_db = SILENT_DB
	player.pitch_scale = 1.0
	player.set_meta(&"looping", true)
	player.play()

func _on_finished(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player) and player.get_meta(&"looping", false):
		player.play()

## Take `player` to `to_db` over `seconds`, stopping it at the end if asked and
## freeing it too if it was made for one layer. One fade at a time per player:
## a layer told to go quiet while it is still fading in has to have the first
## tween killed, or the two argue over the same property.
func _fade(player: AudioStreamPlayer, to_db: float, seconds: float, stop_after := false, free_after := false) -> void:
	var running := player.get_meta(&"fade", null) as Tween
	if running != null and running.is_valid():
		running.kill()
	if seconds <= 0.0:
		player.volume_db = to_db
		if stop_after:
			_end(player, free_after)
		return
	var tween := create_tween()
	player.set_meta(&"fade", tween)
	tween.tween_property(player, ^"volume_db", to_db, seconds)
	if stop_after:
		tween.tween_callback(_end.bind(player, free_after))

## The looping flag comes off first: stopping a player fires `finished`, and a
## layer still marked as looping would start itself straight back up.
func _end(player: AudioStreamPlayer, free_after: bool) -> void:
	if not is_instance_valid(player):
		return
	player.set_meta(&"looping", false)
	player.stop()
	if free_after:
		player.queue_free()
