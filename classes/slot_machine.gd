class_name SlotMachine
extends StaticBody3D

## A one-armed bandit by the pond: pay cash, pull, and either a SpellCharm drops
## out or nothing does. Placed in TrenchBroom as [code]slot_machine_spawn[/code].
##
## Like Shopkeeper it knows nothing about the player. It names a price and
## rolls a prize; taking the money and handing the charm over is Player's job
## (Player.gamble()), and the reels are UISlotMachine's. The visual is a
## placeholder cabinet.

@export var machine_name: String = "Lucky Lure"
## What one pull costs.
@export_range(0, 1000, 1, "or_greater") var cost: int = 20
## Chance a pull pays out a spell at all. The rest of the time the money is gone.
@export_range(0.0, 1.0, 0.01) var win_chance: float = 0.4
## What it can pay out, drawn evenly. Empty means every spell in
## FishData.SPELL_POOL, so a new spell shows up in the machine on its own.
@export var spell_pool: Array[SpellData] = []

@export_category("Sound")
## Each of these is optional; a machine with none of them set is silent.
@export var sfx_pull: AudioStream
@export var sfx_win: AudioStream
@export var sfx_lose: AudioStream

## The cabinet's name board and price tag, filled from the exports so a map
## that renames or reprices the machine does not leave the old ones painted on.
@onready var _sign: Label3D = get_node_or_null("Sign")
@onready var _price: Label3D = get_node_or_null("Price")

func _ready() -> void:
	if _sign != null:
		_sign.text = machine_name.to_upper()
	if _price != null:
		_price.text = "$%d A PULL" % cost

## Every spell this machine can pay out.
func prizes() -> Array[SpellData]:
	var pool: Array[SpellData] = []
	if spell_pool.is_empty():
		pool.assign(FishData.SPELL_POOL)
	else:
		pool.assign(spell_pool)
	return pool

## One pull: a spell, or null for nothing. Does not charge anything - the
## caller has already taken [member cost].
func pull() -> SpellData:
	var pool := prizes()
	if pool.is_empty() or randomizer.RNG.randf() >= win_chance:
		return null
	return pool[randomizer.RNG.randi_range(0, pool.size() - 1)]
