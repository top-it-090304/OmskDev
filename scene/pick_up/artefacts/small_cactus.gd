extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Small Cactus"
	artefact_description = "Колючий и быстрый\n+1 к урону\n+5 к скорости\n+3% уклонения"
	damage_bonus = 1
	speed_bonus = 5
	dodge_chance_bonus = 0.03
	super._ready()
