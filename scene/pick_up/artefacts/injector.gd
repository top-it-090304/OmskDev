extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Injector"
	artefact_description = "+3 к урону, +15 к скорости"
	damage_bonus = 3
	speed_bonus = 15
	super._ready()
