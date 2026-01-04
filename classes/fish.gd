class_name Fish
extends Node3D

@export var data: FishData
var current_size: float = 0.0
var current_value: float = 0.0

@onready var model: MeshInstance3D = $model

func _ready() -> void:
	if model == null :
		model = find_child("model")
	model.mesh = data.mesh
	_apply_random_scale()

func _apply_random_scale() -> void:
	var scale_factor := randomizer.RNG.randf_range(data.min_size, data.max_size)
	model.scale = Vector3.ONE * scale_factor
	current_size = scale_factor
