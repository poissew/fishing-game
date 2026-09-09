class_name Shopkeeper
extends StaticBody3D

## A vendor standing in the world. Anything the player carries can be offered;
## right now they only deal in fish. The visual is a placeholder box.
##
## Walking up to one is handled on the player side (its InteractRange Area3D),
## so a shopkeeper knows nothing about the player — it just quotes prices.

@export var shop_name: String = "Fishmonger"
## Share of an item's value the shopkeeper actually pays out.
@export_range(0.0, 2.0, 0.05) var buy_rate: float = 1.0

## What this shopkeeper pays for `item`. 0 means they will not take it.
func offer_for(item: ItemInstance) -> int:
	if not (item is FishInstance):
		return 0
	var value := (item as FishInstance).get_value()
	if value <= 0:
		return 0
	return maxi(1, int(round(value * buy_rate)))
