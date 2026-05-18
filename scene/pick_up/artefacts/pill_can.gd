extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Pill Can"
	artefact_description = "+15 к здоровью, +1 к урону"
	health_bonus = 15
	damage_bonus = 1
	super._ready()
