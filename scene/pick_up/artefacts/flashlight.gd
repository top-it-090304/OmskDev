extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Flashlight"
	artefact_description = "Точный свет\n+1 к урону\n+3 к скорости\n+5% шанс крита"
	damage_bonus = 1
	speed_bonus = 3
	crit_chance_bonus = 0.05
	super._ready()
