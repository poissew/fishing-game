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

@onready var ttf:Timer = $TimeToFish
var current_state:BOBBER_STATE = BOBBER_STATE.IN_AIR
@export var fishing_loot: LootTable
var rng:RandomNumberGenerator = randomizer.RNG

signal loot_rolled(item: Item, amount: int)

func _on_successful_reel():
	assert(fishing_loot != null, "Bobber: fishing_loot non assignée")

	var entry:LootEntry = fishing_loot.pick_entry(rng)
	var amount:int = entry.roll_amount(rng)

	emit_signal("loot_rolled", entry.item, amount)

func _physics_process(delta: float) -> void:
	match current_state :
		BOBBER_STATE.IN_AIR :
			pass
		
		BOBBER_STATE.IN_WATER :
			_water_behavior()
			
		BOBBER_STATE.REELING :
			_reel_behavior()
		
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
	if area.is_in_group("water") :
		set_loot_table( get_water_state(area.get_groups()) )
		current_state = BOBBER_STATE.IN_WATER
		gravity_scale = 0.0
		linear_damp = 8.0

func _on_area_3d_area_exited(area: Area3D) -> void:
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
		current_state = BOBBER_STATE.REELING
		
func _reel_behavior() -> void :
	_on_successful_reel()
	queue_free()

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
