extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Ramen Bowl"
	artefact_description = "+25 к здоровью"
	health_bonus = 25
	super._ready()
