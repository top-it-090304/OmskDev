extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Bottle"
	artefact_description = "+15 к здоровью"
	health_bonus = 15
	super._ready()
