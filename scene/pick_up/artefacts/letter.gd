extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Letter"
	artefact_description = "+5 к здоровью, +5 к скорости"
	health_bonus = 5
	speed_bonus = 5
	super._ready()
