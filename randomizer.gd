extends Node

var RNG = RandomNumberGenerator.new()

func _init() -> void:
	RNG.randomize()
