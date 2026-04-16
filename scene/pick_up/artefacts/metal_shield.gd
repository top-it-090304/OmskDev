extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Metal Shield"
	artefact_description = "Надежная защита\n+15 к броне\n+50 к здоровью"
	armor_bonus = 15
	health_bonus = 50
	super._ready()
