extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Milk Box"
	artefact_description = "+10 к здоровью, +3 к скорости"
	health_bonus = 10
	speed_bonus = 3
	super._ready()
