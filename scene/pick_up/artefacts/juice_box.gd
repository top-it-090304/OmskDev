extends "res://scene/pick_up/artefacts/artefact_pickup.gd"

func _ready():
	artefact_name = "Juice Box"
	artefact_description = "+8 к скорости"
	speed_bonus = 8
	super._ready()
