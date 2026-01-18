class_name Player
extends CharacterBody3D

var inventory:Inventory = Inventory.new()

var equipped_rod: RodInstance = null

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var head:Node3D = $head
@onready var camera:Camera3D = $head/Camera3D

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") :
		get_tree().quit()
		
	if Input.is_action_just_pressed("left_click") :
		use_rod()

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var _inst = RodInstance.new()
	print(Itemdb.get_item(100))
	_inst = _inst.create_rod_instance(Itemdb.get_item(100))
	inventory.height = 16
	inventory.width = 20
	inventory.place_item(_inst, Vector2i(0,0))
	_equip_rod(_inst)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * options.MOUSE_SENS)
		camera.rotate_x(-event.relative.y * options.MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (head.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func equip_item(item: ItemInstance) -> bool:
	if item is RodInstance:
		return _equip_rod(item)
	return false

func _equip_rod(rod: RodInstance) -> bool:
	# Si une canne est déjà équipée, on la remet dans l’inventaire
	if equipped_rod != null:
		if not inventory.place_item(equipped_rod, equipped_rod.position):
			return false
		equipped_rod = null

	# Retirer la canne de l’inventaire
	inventory.items.erase(rod)

	equipped_rod = rod
	return true

func unequip_rod() -> bool:
	if equipped_rod == null:
		return false

	var placed := inventory.place_item(equipped_rod, Vector2i(0, 0))
	if placed:
		equipped_rod = null
	return placed

func can_fish() -> bool:
	return equipped_rod != null and not equipped_rod.is_broken()

func use_rod() -> void:
	if equipped_rod == null:
		return
	if can_fish() :
		print("pêche ta grand mère")
		equipped_rod.durability -= 1
	
	elif equipped_rod != null and !can_fish() :
		print("canne cassée")
		unequip_rod()
