extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Metal Shield"
	artefact_description = "+100 к здоровью"
	health_bonus = 100
	super._ready()
