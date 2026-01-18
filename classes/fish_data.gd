class_name FishData
extends Item

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	ULTRARARE,
	LEGENDARY,
	GOD
}

@export_category("Base Data")
@export var min_size: float
@export var max_size: float
@export var base_value: int
@export var mesh: PackedScene
@export var rarity:Rarity

@export_category("Advanced Shit")
@export var price_curve: Curve
