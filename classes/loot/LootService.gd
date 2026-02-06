# FishPicker.gd
extends Node
class_name FishPicker

func pick_random_fish(from_items: Array) -> FishData:
	var fishes: Array[FishData] = []
	var total := 0

	for it in from_items:
		if it is FishData:
			fishes.append(it)
			total += it.weight

	assert(total > 0, "Aucun FishData avec weight > 0")

	var roll := randi_range(1, total)
	var acc := 0

	for fish in fishes:
		acc += fish.weight
		if roll <= acc:
			return fish

	return fishes[-1] # fallback sécurité
