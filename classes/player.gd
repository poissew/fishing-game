class_name Player
extends CharacterBody3D

var inventory:Inventory = Inventory.new()
var inventory_ui:UIInventory = null

var hands:Hands = Hands.new()

var wallet:Wallet = Wallet.new()
var shop_ui:UIShop = null
var clock_ui:UIDayNightIcon = null
var day_timer_ui:UIDayTimer = null
## End-of-day screens. `gamephase` says when the game moves between fishing and
## battling; these two are how that shows up on screen.
var fish_select_ui:UIFishSelect = null
var battle_ui:UIBattle = null
var slot_ui:UISlotMachine = null
## Shopkeeper whose range the player is standing in, or null.
var _nearby_shopkeeper: Shopkeeper = null
## Slot machine whose range the player is standing in, or null.
var _nearby_machine: SlotMachine = null

## The rod currently held in a hand, if any. Hands are the source of truth.
var equipped_rod: RodInstance:
	get:
		return hands.get_rod()

var bobber: PackedScene = load("res://objects/Bobber.tscn")

const SPEED = 5.0

@onready var _world = $".."

@onready var interact_range:Area3D = $InteractRange
@onready var head:Node3D = $head
@onready var camera:Camera3D = $head/Camera3D
@onready var hands_viewmodel:HandsViewmodel = $head/Camera3D/HandsViewmodel

@onready var player_luck:int = 0

func _input(event: InputEvent) -> void:
	# The fishing day is over: the selection and battle screens own the input
	# until the round has been settled, and the world - debug shortcuts included
	# - is on hold behind them.
	if not gamephase.is_fishing():
		return

	# Dev shortcut: skip to nightfall, then to the next morning, so the whole
	# 20-minute cycle does not have to be sat through. Checked ahead of
	# everything else so it keeps working with the inventory or shop open.
	if event.is_action_pressed("debug_skip_time"):
		daynight.skip_to_next_phase()
		return

	if event.is_action_pressed("pause"):
		if shop_ui.is_open:
			_close_shop()
		elif slot_ui.is_open:
			_close_slot_machine()
		elif inventory_ui.visible:
			_toggle_inventory()
		else:
			get_tree().quit()
		return

	if shop_ui.is_open or slot_ui.is_open:
		return

	if event.is_action_pressed("open_inventory"):
		_toggle_inventory()

	if inventory_ui.visible:
		return

	if event.is_action_pressed("interact"):
		if _nearby_shopkeeper != null:
			_open_shop(_nearby_shopkeeper)
			return
		if _nearby_machine != null:
			_open_slot_machine(_nearby_machine)
			return

	if Input.is_action_just_pressed("left_click"):
		use_rod()

func _ready() -> void:
	# First of the UI children on purpose: the inventory and shop both dim the
	# whole screen when they open, and being underneath them means the clock
	# gets dimmed along with the world instead of floating over the overlay.
	var clock = load("res://ui/UI_DayNightIcon.tscn")
	clock_ui = clock.instantiate()
	add_child(clock_ui)

	var timer = load("res://ui/UI_DayTimer.tscn")
	day_timer_ui = timer.instantiate()
	add_child(day_timer_ui)

	var inv = load("res://ui/UI_Inventory.tscn")
	inventory_ui = inv.instantiate()
	inventory.height = 8
	inventory.width = 10
	inventory_ui.bind_inventory(inventory)
	inventory_ui.item_requested_equip.connect(_on_equip_requested)
	add_child(inventory_ui)

	var shop = load("res://ui/UI_Shop.tscn")
	shop_ui = shop.instantiate()
	shop_ui.bind_wallet(wallet)
	shop_ui.sell_requested.connect(_on_sell_requested)
	shop_ui.sell_all_requested.connect(_on_sell_all_requested)
	shop_ui.close_requested.connect(_close_shop)
	add_child(shop_ui)

	var slot = load("res://ui/UI_SlotMachine.tscn")
	slot_ui = slot.instantiate()
	slot_ui.bind_wallet(wallet)
	slot_ui.pull_requested.connect(_on_pull_requested)
	slot_ui.close_requested.connect(_close_slot_machine)
	add_child(slot_ui)

	# Added last, so the end-of-day screens draw over every other panel.
	var select = load("res://ui/UI_FishSelect.tscn")
	fish_select_ui = select.instantiate()
	fish_select_ui.fish_chosen.connect(_on_fish_chosen)
	fish_select_ui.skip_requested.connect(_on_battle_skipped)
	add_child(fish_select_ui)

	var battle = load("res://ui/UI_Battle.tscn")
	battle_ui = battle.instantiate()
	battle_ui.battle_finished.connect(_on_battle_finished)
	add_child(battle_ui)

	gamephase.selection_started.connect(_on_selection_started)
	gamephase.battle_started.connect(_on_battle_started)
	gamephase.battle_ended.connect(_on_battle_ended)
	gamephase.phase_changed.connect(_on_game_phase_changed)

	interact_range.body_entered.connect(_on_interact_range_entered)
	interact_range.body_exited.connect(_on_interact_range_exited)

	hands_viewmodel.bind_hands(hands, camera)
	inventory_ui.bind_hands(hands, hands_viewmodel)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var _inst = RodInstance.new()
	_inst = _inst.create_rod_instance(Itemdb.get_item(100))
	equip_item(_inst, Hands.Slot.RIGHT)

func _unhandled_input(event: InputEvent) -> void:
	if inventory_ui.visible or shop_ui.is_open or slot_ui.is_open or not gamephase.is_fishing():
		return
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * options.MOUSE_SENS)
		camera.rotate_x(-event.relative.y * options.MOUSE_SENS)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	if inventory_ui.visible or shop_ui.is_open or slot_ui.is_open or not gamephase.is_fishing():
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

## Everything the player has on them: the inventory grid plus both hands.
## The array is a copy, so it is safe to remove items while iterating it.
func carried_items() -> Array[ItemInstance]:
	var carried: Array[ItemInstance] = []
	carried.append_array(inventory.items)
	for slot in Hands.SLOT_COUNT:
		var item := hands.get_item(slot)
		if item != null:
			carried.append(item)
	return carried

## Just the fish out of carried_items() - what can be sent to the arena.
func carried_fish() -> Array[FishInstance]:
	var fish: Array[FishInstance] = []
	for item in carried_items():
		if item is FishInstance:
			fish.append(item as FishInstance)
	return fish

# ── Day / battle phases ───────────────────────────────────────────────────────

## The fishing day ran out. Whatever the player was in the middle of is closed
## down and the selection screen takes over.
func _on_selection_started() -> void:
	if inventory_ui.visible:
		inventory_ui.close()
	if shop_ui.is_open:
		shop_ui.close()
	if slot_ui.is_open:
		slot_ui.close()
	_clear_bobbers()
	fish_select_ui.open(carried_fish())

func _on_fish_chosen(fish: FishInstance) -> void:
	gamephase.send_to_battle(fish)

func _on_battle_skipped() -> void:
	fish_select_ui.close()
	gamephase.skip_battle()

## `gamephase` has handed the champion over. The placeholder card stands in for
## the arena; when the arena scene exists it binds to the same signal and this
## goes away.
func _on_battle_started(fish: FishInstance) -> void:
	fish_select_ui.close()
	battle_ui.open(fish)

func _on_battle_finished(won: bool) -> void:
	gamephase.end_battle(won)

## A fish that lost its fight does not come home; a winner stays in the
## inventory, ready to be sold or sent out again tomorrow.
func _on_battle_ended(won: bool, fish: FishInstance) -> void:
	battle_ui.close()
	if fish != null and (not won or not fish.is_alive()):
		_take_carried(fish)

## The mouse belongs to the panels while the day is being wrapped up, and to
## the camera the rest of the time.
func _on_game_phase_changed(_phase: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if gamephase.is_fishing() \
		else Input.MOUSE_MODE_VISIBLE

## Any bobber still floating out there belongs to a day that is over.
func _clear_bobbers() -> void:
	for child in _world.get_children():
		if child is Bobber:
			child.queue_free()

# ── Shop ──────────────────────────────────────────────────────────────────────

## The InteractRange Area3D sweeps up everything solid around the player;
## shopkeepers and slot machines are what can be talked to.
func _on_interact_range_entered(body: Node3D) -> void:
	if body is Shopkeeper:
		_nearby_shopkeeper = body as Shopkeeper
	elif body is SlotMachine:
		_nearby_machine = body as SlotMachine
	_update_prompts()

func _on_interact_range_exited(body: Node3D) -> void:
	if body == _nearby_shopkeeper:
		_nearby_shopkeeper = null
		if shop_ui.is_open:
			_close_shop()
	elif body == _nearby_machine:
		_nearby_machine = null
		if slot_ui.is_open:
			_close_slot_machine()
	_update_prompts()

## Both prompts sit in the same spot, so only one is shown at a time - the
## shopkeeper's, since that is also who E talks to when both are in reach.
func _update_prompts() -> void:
	shop_ui.set_nearby(_nearby_shopkeeper)
	slot_ui.set_nearby(_nearby_machine if _nearby_shopkeeper == null else null)

func _open_shop(keeper: Shopkeeper) -> void:
	shop_ui.open(keeper, carried_items())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_shop() -> void:
	shop_ui.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Sell one carried item to the shopkeeper the player is standing next to.
## Returns what was paid, or 0 when the sale did not happen.
func sell_item(item: ItemInstance) -> int:
	if _nearby_shopkeeper == null or item == null:
		return 0
	var price := _nearby_shopkeeper.offer_for(item)
	if price <= 0 or not _take_carried(item):
		return 0
	wallet.add(price)
	return price

func sell_all_fish() -> int:
	var total := 0
	for item in carried_items():
		if item is FishInstance:
			total += sell_item(item)
	return total

## Remove `item` from wherever the player is carrying it.
func _take_carried(item: ItemInstance) -> bool:
	var slot := hands.slot_of(item)
	if slot >= 0:
		hands.clear(slot)
		return true
	if inventory.items.has(item):
		inventory.items.erase(item)
		return true
	return false

func _on_sell_requested(item: ItemInstance) -> void:
	sell_item(item)
	shop_ui.refresh(carried_items())

func _on_sell_all_requested() -> void:
	sell_all_fish()
	shop_ui.refresh(carried_items())

# ── Slot machine ──────────────────────────────────────────────────────────────

func _open_slot_machine(machine: SlotMachine) -> void:
	slot_ui.open(machine)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_slot_machine() -> void:
	slot_ui.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## One pull of the machine the player is standing at. The money is taken and
## any prize is in the inventory before this returns - the reels only show it.
## Returns {"ok": true, "spell": SpellData or null for nothing} for a pull that
## happened, or {"ok": false, "reason": String} for one turned down before any
## money moved.
func gamble(machine: SlotMachine) -> Dictionary:
	if machine == null:
		return {"ok": false, "reason": ""}
	if not wallet.can_afford(machine.cost):
		return {"ok": false, "reason": "Not enough cash."}
	# Checked before paying: a win with nowhere to put it would be money gone
	# for nothing. A charm is 1x1, so any free cell will do.
	if not inventory.has_space_for(SpellCharm.create(null)):
		return {"ok": false, "reason": "No room in your bag for a charm."}
	if machine.cost > 0 and not wallet.spend(machine.cost):
		return {"ok": false, "reason": "Not enough cash."}
	var spell := machine.pull()
	if spell != null:
		inventory.add_or_place(SpellCharm.create(spell))
	return {"ok": true, "spell": spell}

func _on_pull_requested() -> void:
	if _nearby_machine == null or slot_ui.is_spinning():
		return
	var result := gamble(_nearby_machine)
	if not result["ok"]:
		slot_ui.refuse(result["reason"])
		return
	if _nearby_machine.sfx_pull != null:
		audio.play_ui(_nearby_machine.sfx_pull)
	slot_ui.spin(result["spell"])

# ── Fishing ───────────────────────────────────────────────────────────────────

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
