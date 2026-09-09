class_name Player
extends CharacterBody3D

var inventory:Inventory = Inventory.new()
var inventory_ui:UIInventory = null

var hands:Hands = Hands.new()

## The rod currently held in a hand, if any. Hands are the source of truth.
var equipped_rod: RodInstance:
	get:
		return hands.get_rod()

var bobber: PackedScene = load("res://objects/Bobber.tscn")

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var _world = $".."

@onready var head:Node3D = $head
@onready var camera:Camera3D = $head/Camera3D
@onready var hands_viewmodel:HandsViewmodel = $head/Camera3D/HandsViewmodel

@onready var player_luck:int = 0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().quit()

	if event.is_action_pressed("open_inventory"):
		_toggle_inventory()

	if not inventory_ui.visible and Input.is_action_just_pressed("left_click"):
		use_rod()

func _ready() -> void:
	var inv = load("res://ui/UI_Inventory.tscn")
	inventory_ui = inv.instantiate()
	inventory.height = 8
	inventory.width = 10
	inventory_ui.bind_inventory(inventory)
	inventory_ui.item_requested_equip.connect(_on_equip_requested)
	add_child(inventory_ui)

	hands_viewmodel.bind_hands(hands, camera)
	inventory_ui.bind_hands(hands, hands_viewmodel)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var _inst = RodInstance.new()
	_inst = _inst.create_rod_instance(Itemdb.get_item(100))
	equip_item(_inst, Hands.Slot.RIGHT)

func _unhandled_input(event: InputEvent) -> void:
	if inventory_ui.visible:
		return
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * options.MOUSE_SENS)
		camera.rotate_x(-event.relative.y * options.MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	if inventory_ui.visible:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (head.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _toggle_inventory() -> void:
	if inventory_ui.visible:
		inventory_ui.close()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		inventory_ui.open()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_equip_requested(item: ItemInstance) -> void:
	if equip_item(item):
		_toggle_inventory()

## Move `item` into a hand. `slot` < 0 picks a free hand (right hand otherwise).
## Whatever the hand was holding goes back to the inventory, or is swapped when
## the item itself came from the other hand.
func equip_item(item: ItemInstance, slot: int = -1) -> bool:
	if item == null:
		return false

	if slot < 0:
		slot = hands.first_free_slot()
		if slot < 0:
			slot = Hands.Slot.RIGHT

	var from := hands.slot_of(item)
	if from == slot:
		return true

	var displaced := hands.get_item(slot)
	if from >= 0:
		hands.set_item(from, displaced)
		hands.set_item(slot, item)
		return true

	if displaced != null and not inventory.add_or_place(displaced):
		return false

	inventory.items.erase(item)
	hands.set_item(slot, item)
	return true

## Put whatever is in `slot` back into the inventory.
func unequip_slot(slot: int) -> bool:
	var item := hands.get_item(slot)
	if item == null:
		return false
	if not inventory.add_or_place(item):
		return false
	hands.clear(slot)
	return true

func unequip_rod() -> bool:
	var slot := hands.slot_of_rod()
	if slot < 0:
		return false
	return unequip_slot(slot)

func can_fish() -> bool:
	return equipped_rod != null and not equipped_rod.is_broken()

func use_rod() -> void:
	if equipped_rod == null:
		return
	if can_fish():
		cast_bobber()
		equipped_rod.durability -= 1
	elif not can_fish():
		print("canne cassée")
		unequip_rod()

func cast_bobber():
	var current_bobber:Bobber = bobber.instantiate()
	current_bobber.loot_rolled.connect(_on_bobber_fish_caught)
	_world.add_child(current_bobber)

	var forward := -camera.global_transform.basis.z
	var start_pos := camera.global_transform.origin + forward * 0.5

	current_bobber.global_position = start_pos

	var force := forward * 10.0 + Vector3.UP * 3.0
	current_bobber.apply_central_impulse(force)
	current_bobber.reel_target = camera
	current_bobber.reel_speed = 6.0 + equipped_rod.data.reel_speed
	current_bobber.ttf.wait_time = randomizer.RNG.randf_range(1, 15 - equipped_rod.data.reel_speed) - player_luck
	current_bobber.start_timer()

func _on_bobber_fish_caught(fish_data: Item, amount: int) -> void:
	for i in range(amount):
		var fish_instance := FishInstance.new().create_fish_instance(fish_data)
		if not inventory.add_or_place(fish_instance):
			_on_inventory_full_when_fishing(fish_instance)

func _on_inventory_full_when_fishing(fish_instance: FishInstance) -> void:
	print("Inventaire plein : poisson relâché : ", fish_instance)
