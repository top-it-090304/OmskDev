extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Waffle"
	artefact_description = "+20 к здоровью"
	health_bonus = 20
	super._ready()
