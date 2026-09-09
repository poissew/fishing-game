class_name Bobber
extends RigidBody3D

const WATER_STATE_TO_TABLE := {
	WATER_STATE.DEFAULT: "default",
	WATER_STATE.TROPICAL: "tropical",
	WATER_STATE.ATLANTIC: "atlantic",
}

enum WATER_STATE {
	DEFAULT,
	TROPICAL,
	ATLANTIC,
	MUD,
	LAVA
}

enum BOBBER_STATE { ## état du bobber (ex: en l'air, dans l'eau etc...)
	IN_AIR, ## Comportement en l'air. / Déja géré par Rigidbody3D normalementt
	IN_WATER, ## Comportement dans l'eau
	BITE, ## Comportement quand un poisson mord
	REELING ## Comportement quand on ramène la canne vers soi
}

@onready var splash_part:PackedScene = load("res://objects/particles/water_splash.tscn")
@onready var ttf:Timer = $TimeToFish
var current_state:BOBBER_STATE = BOBBER_STATE.IN_AIR
@export var fishing_loot: LootTable
var rng:RandomNumberGenerator = randomizer.RNG

## Cible vers laquelle le bobber revient pendant l'animation de reel.
var reel_target: Node3D = null
## Vitesse de retour du bobber (unités/seconde).
var reel_speed: float = 10.0

const REEL_TARGET_OFFSET := Vector3(0.0, -0.25, 0.0)
const REEL_ARRIVAL_DIST := 0.6
## Le poisson pend sous le bobber : offset volontairement petit, la mare fait
## ~0.15 unité d'épaisseur et un offset plus grand spawn le sprite sous le sol.
const CAUGHT_HANG_OFFSET := Vector3(0.0, -0.18, 0.0)
## Hauteur visée du sprite en unités monde, pour un poisson de taille 1.0.
## Le pixel_size est calculé à partir de ça, donc n'importe quelle résolution
## d'icône donne un poisson de la bonne taille.
const CAUGHT_WORLD_HEIGHT := 0.35
## Vitesses de rotation (rad/s) tirées au sort pour le tumble du loot.
## Z (rotation dans le plan de l'écran) est plus rapide : c'est l'axe sur lequel
## un sprite plat reste toujours visible.
const CAUGHT_SPIN_RANGE := Vector2(3.0, 7.0)
const CAUGHT_SPIN_ROLL_RANGE := Vector2(8.0, 16.0)

var _reel_start_pos: Vector3
var _reel_distance: float = 1.0
var _reel_progress: float = 0.0
var _reel_time: float = 0.0
var _caught_visual: Node3D = null
var _caught_spin: Vector3 = Vector3.ZERO
static var _placeholder_texture: Texture2D = null
var _pending_item: Item = null
var _pending_amount: int = 0

signal loot_rolled(item: Item, amount: int)

func _roll_loot() -> void:
	assert(fishing_loot != null, "Bobber: fishing_loot non assignée")

	var entry:LootEntry = fishing_loot.pick_entry(rng)
	_pending_item = entry.item
	_pending_amount = entry.roll_amount(rng)

func _on_successful_reel():
	emit_signal("loot_rolled", _pending_item, _pending_amount)

func _physics_process(delta: float) -> void:
	match current_state :
		BOBBER_STATE.IN_AIR :
			pass
		
		BOBBER_STATE.IN_WATER :
			_water_behavior()
			
		BOBBER_STATE.REELING :
			_reel_behavior(delta)
		
		BOBBER_STATE.BITE :
			_bite_behavior()

func _water_behavior() -> void :
	var h_vector:Vector3 = Vector3(linear_velocity.x, 0, linear_velocity.z)
	var v := linear_velocity
	v.y = 0.0
	v.x = lerp(v.x, 0.0, 6.0 * get_physics_process_delta_time())
	v.z = lerp(v.z, 0.0, 6.0 * get_physics_process_delta_time())
	linear_velocity = v
	h_vector.lerp(-linear_velocity, 0.1)
	apply_force(Vector3.UP * 40 + h_vector)
	
	if ttf.is_stopped() :
		current_state = BOBBER_STATE.BITE

func _on_area_3d_area_entered(area: Area3D) -> void:
	if current_state == BOBBER_STATE.REELING :
		return
	if area.is_in_group("water") :
		set_loot_table( get_water_state(area.get_groups()) )
		current_state = BOBBER_STATE.IN_WATER
		gravity_scale = 0.0
		linear_damp = 8.0

func _on_area_3d_area_exited(area: Area3D) -> void:
	if current_state == BOBBER_STATE.REELING :
		return
	if area.is_in_group("water") :
		current_state = BOBBER_STATE.IN_AIR
		gravity_scale = 1.0
		linear_damp = 0.05

func start_timer() -> void :
	ttf.start()

func _bite_behavior() -> void :
	return

func _unhandled_input(event: InputEvent) -> void:
	if current_state == BOBBER_STATE.BITE \
	and event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_RIGHT \
	and event.pressed:
		_start_reel()

## Prépare l'animation de retour : tire le loot, accroche le poisson sous le
## bobber et coupe la physique pour piloter la trajectoire à la main.
func _start_reel() -> void :
	current_state = BOBBER_STATE.REELING
	ttf.stop()

	_roll_loot()
	_spawn_caught_visual()

	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0
	$Area3D.monitoring = false
	$Area3D.monitorable = false

	_reel_start_pos = global_position
	_reel_progress = 0.0
	_reel_time = 0.0
	_reel_distance = maxf(_reel_start_pos.distance_to(_get_reel_target_pos()), 0.001)

func _reel_behavior(delta: float) -> void :
	if reel_target == null or not is_instance_valid(reel_target) :
		_finish_reel()
		return

	var target := _get_reel_target_pos()
	_reel_time += delta
	_reel_progress = minf(_reel_progress + (reel_speed * delta) / _reel_distance, 1.0)

	# ease < 1 : départ rapide (le coup de canne) puis arrivée en douceur.
	var eased := ease(_reel_progress, 0.65)
	var arc := clampf(_reel_distance * 0.12, 0.2, 1.2)
	global_position = _reel_start_pos.lerp(target, eased) + Vector3.UP * arc * sin(PI * _reel_progress)

	_animate_caught_visual(delta)

	if _reel_progress >= 1.0 or global_position.distance_to(target) <= REEL_ARRIVAL_DIST :
		_finish_reel()

func _finish_reel() -> void :
	_on_successful_reel()
	queue_free()

func _get_reel_target_pos() -> Vector3 :
	if reel_target == null or not is_instance_valid(reel_target) :
		return global_position
	return reel_target.global_position + REEL_TARGET_OFFSET

## Accroche une représentation du loot sous le bobber. Full Sprite3D : plus de
## branche mesh, l'icône de l'Item est la seule source visuelle.
func _spawn_caught_visual() -> void :
	if _pending_item == null :
		return

	var holder := Node3D.new()
	holder.position = CAUGHT_HANG_OFFSET
	add_child(holder)
	_caught_visual = holder

	var texture := _pending_item.icon
	if texture == null :
		texture = _get_placeholder_texture()

	var size_factor := 1.0
	var fish_data := _pending_item as FishData
	if fish_data != null :
		size_factor = rng.randf_range(fish_data.min_size, fish_data.max_size)

	var sprite := Sprite3D.new()
	sprite.texture = texture
	# pixel_size dérivé de la hauteur de la texture : une icône 16px et une
	# icône 512px donnent le même poisson à l'écran.
	sprite.pixel_size = (CAUGHT_WORLD_HEIGHT * size_factor) / maxf(float(texture.get_height()), 1.0)
	# Pas de billboard : il écraserait la rotation du holder et le tumble ne se
	# verrait pas. double_sided garde le sprite lisible de dos.
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.double_sided = true
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	holder.add_child(sprite)

	_roll_caught_spin()

## Damier magenta/noir généré à la volée, affiché tant qu'un Item n'a pas
## d'icône. Évite le "rien ne s'affiche" silencieux.
static func _get_placeholder_texture() -> Texture2D :
	if _placeholder_texture != null :
		return _placeholder_texture

	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8 :
		for x in 8 :
			var lit := (x / 2 + y / 2) % 2 == 0
			img.set_pixel(x, y, Color.MAGENTA if lit else Color.BLACK)
	_placeholder_texture = ImageTexture.create_from_image(img)
	return _placeholder_texture

## Tire une vitesse de rotation aléatoire sur les trois axes (sens compris).
func _roll_caught_spin() -> void :
	_caught_spin = Vector3(
		_random_spin(CAUGHT_SPIN_RANGE),
		_random_spin(CAUGHT_SPIN_RANGE),
		_random_spin(CAUGHT_SPIN_ROLL_RANGE),
	)

func _random_spin(range_limits: Vector2) -> float :
	var speed := rng.randf_range(range_limits.x, range_limits.y)
	return speed if rng.randf() < 0.5 else -speed

## Fait partir le loot en vrille sur les trois axes pendant le retour.
func _animate_caught_visual(delta: float) -> void :
	if _caught_visual == null :
		return
	_caught_visual.rotate_object_local(Vector3.RIGHT, _caught_spin.x * delta)
	_caught_visual.rotate_object_local(Vector3.UP, _caught_spin.y * delta)
	_caught_visual.rotate_object_local(Vector3.BACK, _caught_spin.z * delta)

func get_water_state(groups:Array[StringName]) -> WATER_STATE :
	for group in groups :
		match group :
			"atlantic":
				return WATER_STATE.ATLANTIC
			"lava":
				return WATER_STATE.LAVA
			"mud":
				return WATER_STATE.MUD
			"tropical":
				return WATER_STATE.TROPICAL
	return WATER_STATE.DEFAULT

func set_loot_table(state:WATER_STATE) -> void :
	fishing_loot = Tablesdb.get_table(WATER_STATE_TO_TABLE[state])
