class_name Wallet
extends Resource

## The player's money. Kept as a Resource like Inventory / Hands so the UI can
## just listen to the built-in `changed` signal to redraw.

@export var money: int = 0

## Credit (or debit, with a negative amount) the wallet. Never goes below zero.
func add(amount: int) -> void:
	if amount == 0:
		return
	money = maxi(0, money + amount)
	emit_changed()

func can_afford(amount: int) -> bool:
	return money >= amount

func spend(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false
	add(-amount)
	return true
